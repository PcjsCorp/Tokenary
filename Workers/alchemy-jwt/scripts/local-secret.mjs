#!/usr/bin/env node

import { spawn } from "node:child_process";
import { userInfo } from "node:os";
import {
  isAbsolute,
  resolve,
} from "node:path";
import process from "node:process";
import { types as utilTypes } from "node:util";

const SECRET_NAME = /^[A-Z][A-Z0-9_]{0,127}$/u;
const DEFAULT_MAX_OUTPUT_BYTES = 4_097;
const KEYCHAIN_TIMEOUT_MILLISECONDS = 30_000;
const TERMINATION_GRACE_MILLISECONDS = 2_000;
const capturedEnvironmentSecrets = new WeakMap();

export class SafeLocalSecretError extends Error {
  constructor(message) {
    super(message);
    this.name = "SafeLocalSecretError";
  }
}

function fail(message) {
  return new SafeLocalSecretError(message);
}

function isAbortSignal(value) {
  try {
    return (
      value === undefined ||
      (
        typeof value === "object" &&
        value !== null &&
        typeof value.aborted === "boolean" &&
        typeof value.addEventListener === "function" &&
        typeof value.removeEventListener === "function"
      )
    );
  } catch {
    return false;
  }
}

function isValidSecretEnvironment(name, environment) {
  return (
    typeof name === "string" &&
    SECRET_NAME.test(name) &&
    typeof environment === "object" &&
    environment !== null &&
    !Array.isArray(environment)
  );
}

function nativeAbortReason(abortSignal) {
  try {
    const reason = abortSignal.reason;
    return utilTypes.isNativeError(reason)
      ? reason
      : undefined;
  } catch {
    return undefined;
  }
}

function cancellationFailure(abortSignal) {
  return nativeAbortReason(abortSignal) ??
    fail("local secret is unavailable");
}

export function throwIfLocalSecretAborted(abortSignal) {
  if (abortSignal?.aborted === true) {
    throw cancellationFailure(abortSignal);
  }
}

export function rethrowLocalSecretCancellation(
  error,
  abortSignal,
) {
  if (
    abortSignal?.aborted === true
  ) {
    const reason = nativeAbortReason(abortSignal);
    if (reason !== undefined) {
      throw reason;
    }
  }
}

export function captureEnvironmentLocalSecret(
  name,
  environment = process.env,
) {
  if (!isValidSecretEnvironment(name, environment)) {
    throw fail("local secret lookup is invalid");
  }

  let environmentValue;
  try {
    environmentValue = environment[name];
    delete environment[name];
  } catch {
    throw fail("local secret lookup is invalid");
  }

  const capturedSecret = Object.freeze({});
  capturedEnvironmentSecrets.set(capturedSecret, {
    environment,
    environmentValue,
    name,
  });
  return capturedSecret;
}

export function disposeCapturedEnvironmentLocalSecret(
  capturedSecret,
) {
  const state = capturedEnvironmentSecrets.get(capturedSecret);
  if (state === undefined) {
    return;
  }
  try {
    delete state.environment[state.name];
  } catch {
  }
  state.environmentValue = undefined;
  capturedEnvironmentSecrets.delete(capturedSecret);
}

function safeKill(child, signal) {
  try {
    child.kill(signal);
  } catch {
  }
}

function safeCancelTimeout(cancelTimeout, handle) {
  if (handle === undefined) {
    return;
  }
  try {
    cancelTimeout(handle);
  } catch {
  }
}

function safeRemoveListener(emitter, eventName, listener) {
  try {
    emitter?.removeListener?.(eventName, listener);
  } catch {
  }
}

export async function readLoginKeychainPassword(
  name,
  {
    spawnProcess = spawn,
    getUserInfo = userInfo,
    maxOutputBytes = DEFAULT_MAX_OUTPUT_BYTES,
    abortSignal,
    scheduleTimeout = setTimeout,
    cancelTimeout = clearTimeout,
  } = {},
) {
  if (
    typeof name !== "string" ||
    !SECRET_NAME.test(name) ||
    typeof getUserInfo !== "function" ||
    !Number.isSafeInteger(maxOutputBytes) ||
    maxOutputBytes < 2 ||
    maxOutputBytes > DEFAULT_MAX_OUTPUT_BYTES ||
    !isAbortSignal(abortSignal) ||
    typeof scheduleTimeout !== "function" ||
    typeof cancelTimeout !== "function"
  ) {
    throw fail("local secret lookup is invalid");
  }
  throwIfLocalSecretAborted(abortSignal);

  let keychainAccount;
  let keychainHome;
  try {
    const currentUser = getUserInfo();
    keychainAccount = currentUser?.username;
    keychainHome = currentUser?.homedir;
  } catch {
    throw fail("local secret is unavailable");
  }
  if (
    typeof keychainAccount !== "string" ||
    keychainAccount === "" ||
    typeof keychainHome !== "string" ||
    !isAbsolute(keychainHome)
  ) {
    throw fail("local secret is unavailable");
  }
  const keychainPath = resolve(
    keychainHome,
    "Library/Keychains/login.keychain-db",
  );

  let child;
  try {
    child = spawnProcess(
      "/usr/bin/security",
      [
        "find-generic-password",
        "-a",
        keychainAccount,
        "-s",
        name,
        "-w",
        keychainPath,
      ],
      {
        env: {},
        shell: false,
        stdio: ["ignore", "pipe", "ignore"],
      },
    );
  } catch (error) {
    rethrowLocalSecretCancellation(error, abortSignal);
    throw fail("local secret is unavailable");
  }

  const chunks = [];
  let totalBytes = 0;
  let output;
  let failure;
  let discardOutput = false;
  let closed = false;
  let terminationStarted = false;
  let timeoutHandle;
  let forceKillHandle;
  let abortListenerAttached = false;
  const stdout = child.stdout;

  const eraseChunks = () => {
    for (const chunk of chunks) {
      chunk.fill(0);
    }
    chunks.length = 0;
    totalBytes = 0;
  };
  const recordFailure = (error) => {
    if (failure === undefined) {
      failure = error;
    }
    discardOutput = true;
    eraseChunks();
  };
  const schedule = (callback, delay) => {
    try {
      const handle = scheduleTimeout(callback, delay);
      handle?.unref?.();
      return handle;
    } catch {
      return undefined;
    }
  };
  const beginTermination = () => {
    if (terminationStarted || closed) {
      return;
    }
    terminationStarted = true;
    safeKill(child, "SIGTERM");
    if (!closed) {
      forceKillHandle = schedule(() => {
        forceKillHandle = undefined;
        if (!closed) {
          safeKill(child, "SIGKILL");
        }
      }, TERMINATION_GRACE_MILLISECONDS);
    }
  };
  const onAbort = () => {
    if (closed) {
      return;
    }
    failure = cancellationFailure(abortSignal);
    discardOutput = true;
    eraseChunks();
    beginTermination();
  };
  const onChildError = () => {
    if (closed) {
      return;
    }
    recordFailure(fail("local secret is unavailable"));
    beginTermination();
  };
  const onStdoutError = () => {
    if (closed) {
      return;
    }
    recordFailure(fail("local secret is unavailable"));
    beginTermination();
  };
  const onStdoutData = (chunk) => {
    let bytes;
    try {
      bytes = Buffer.from(chunk);
      if (typeof chunk?.fill === "function") {
        chunk.fill(0);
      }
    } catch {
      recordFailure(fail("local secret is unavailable"));
      beginTermination();
      return;
    }

    if (discardOutput) {
      bytes.fill(0);
      return;
    }
    if (totalBytes + bytes.byteLength > maxOutputBytes) {
      bytes.fill(0);
      recordFailure(fail("local secret is unavailable"));
      beginTermination();
      return;
    }
    totalBytes += bytes.byteLength;
    chunks.push(bytes);
  };

  let resolveClose;
  const closePromise = new Promise((resolveSettlement) => {
    resolveClose = resolveSettlement;
  });
  const onClose = (code, signal) => {
    if (closed) {
      return;
    }
    closed = true;
    safeCancelTimeout(cancelTimeout, timeoutHandle);
    timeoutHandle = undefined;
    safeCancelTimeout(cancelTimeout, forceKillHandle);
    forceKillHandle = undefined;
    resolveClose({ code, signal });
  };

  child.on("error", onChildError);
  child.once("close", onClose);
  if (
    stdout !== null &&
    stdout !== undefined &&
    typeof stdout.on === "function" &&
    typeof stdout.removeListener === "function" &&
    typeof stdout.resume === "function"
  ) {
    stdout.on("error", onStdoutError);
    stdout.on("data", onStdoutData);
  } else {
    recordFailure(fail("local secret is unavailable"));
    beginTermination();
  }

  try {
    abortSignal?.addEventListener("abort", onAbort, { once: true });
    abortListenerAttached = abortSignal !== undefined;
  } catch {
    recordFailure(fail("local secret is unavailable"));
    beginTermination();
  }
  timeoutHandle = schedule(() => {
    timeoutHandle = undefined;
    if (!closed) {
      recordFailure(fail("local secret is unavailable"));
      beginTermination();
    }
  }, KEYCHAIN_TIMEOUT_MILLISECONDS);
  if (timeoutHandle === undefined) {
    recordFailure(fail("local secret is unavailable"));
    beginTermination();
  }
  if (abortSignal?.aborted === true) {
    onAbort();
  }
  if (typeof stdout?.resume === "function") {
    stdout.resume();
  }

  try {
    const result = await closePromise;
    if (failure !== undefined) {
      throw failure;
    }
    if (
      result.code !== 0 ||
      result.signal !== null
    ) {
      throw fail("local secret is unavailable");
    }

    output = Buffer.concat(chunks, totalBytes);
    if (output.byteLength < 2 || output.at(-1) !== 0x0a) {
      throw fail("local secret is unavailable");
    }
    const passwordBytes = output.subarray(0, -1);
    let password;
    try {
      password = new TextDecoder("utf-8", {
        fatal: true,
        ignoreBOM: true,
      }).decode(passwordBytes);
    } catch {
      throw fail("local secret is unavailable");
    }
    return password;
  } finally {
    output?.fill(0);
    eraseChunks();
    safeCancelTimeout(cancelTimeout, timeoutHandle);
    safeCancelTimeout(cancelTimeout, forceKillHandle);
    if (abortListenerAttached) {
      try {
        abortSignal.removeEventListener("abort", onAbort);
      } catch {
      }
    }
    safeRemoveListener(child, "error", onChildError);
    safeRemoveListener(child, "close", onClose);
    safeRemoveListener(stdout, "error", onStdoutError);
    safeRemoveListener(stdout, "data", onStdoutData);
  }
}

export async function readCapturedEnvironmentOrLoginKeychainSecret(
  capturedSecret,
  {
    keychainReader = readLoginKeychainPassword,
    maxKeychainOutputBytes = DEFAULT_MAX_OUTPUT_BYTES,
    abortSignal,
  } = {},
) {
  const capturedState =
    capturedEnvironmentSecrets.get(capturedSecret);
  if (
    capturedState === undefined ||
    !Number.isSafeInteger(maxKeychainOutputBytes) ||
    maxKeychainOutputBytes < 2 ||
    maxKeychainOutputBytes > DEFAULT_MAX_OUTPUT_BYTES ||
    !isAbortSignal(abortSignal)
  ) {
    throw fail("local secret lookup is invalid");
  }

  const {
    environment,
    name,
  } = capturedState;
  const environmentValue = capturedState.environmentValue;
  capturedState.environmentValue = undefined;
  capturedEnvironmentSecrets.delete(capturedSecret);
  try {
    delete environment[name];
  } catch (error) {
    rethrowLocalSecretCancellation(error, abortSignal);
    throw fail(`${name} is unavailable in the environment and login Keychain`);
  }

  try {
    throwIfLocalSecretAborted(abortSignal);
    if (
      typeof environmentValue === "string" &&
      environmentValue !== ""
    ) {
      return environmentValue;
    }
    const keychainValue = await keychainReader(name, {
      environment,
      maxOutputBytes: maxKeychainOutputBytes,
      abortSignal,
    });
    throwIfLocalSecretAborted(abortSignal);
    return keychainValue;
  } catch (error) {
    rethrowLocalSecretCancellation(error, abortSignal);
    throw fail(`${name} is unavailable in the environment and login Keychain`);
  } finally {
    try {
      delete environment[name];
    } catch {
    }
  }
}

export async function readEnvironmentOrLoginKeychainSecret(
  name,
  {
    environment = process.env,
    keychainReader = readLoginKeychainPassword,
    maxKeychainOutputBytes = DEFAULT_MAX_OUTPUT_BYTES,
    abortSignal,
  } = {},
) {
  if (
    !isValidSecretEnvironment(name, environment) ||
    !Number.isSafeInteger(maxKeychainOutputBytes) ||
    maxKeychainOutputBytes < 2 ||
    maxKeychainOutputBytes > DEFAULT_MAX_OUTPUT_BYTES ||
    !isAbortSignal(abortSignal)
  ) {
    throw fail("local secret lookup is invalid");
  }

  const capturedSecret = captureEnvironmentLocalSecret(
    name,
    environment,
  );
  return readCapturedEnvironmentOrLoginKeychainSecret(
    capturedSecret,
    {
      keychainReader,
      maxKeychainOutputBytes,
      abortSignal,
    },
  );
}
