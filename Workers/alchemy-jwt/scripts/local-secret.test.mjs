import assert from "node:assert/strict";
import {
  EventEmitter,
  getEventListeners,
} from "node:events";
import {
  PassThrough,
  Readable,
} from "node:stream";
import { test } from "node:test";
import { runInNewContext } from "node:vm";

import {
  captureEnvironmentLocalSecret,
  disposeCapturedEnvironmentLocalSecret,
  readCapturedEnvironmentOrLoginKeychainSecret,
  readEnvironmentOrLoginKeychainSecret,
  readLoginKeychainPassword,
  SafeLocalSecretError,
} from "./local-secret.mjs";

function childResult(output, {
  code = 0,
  signal = null,
} = {}) {
  const child = new EventEmitter();
  child.stdout = Readable.from([Buffer.from(output)]);
  child.kill = () => true;
  setImmediate(() => {
    child.emit("close", code, signal);
  });
  return child;
}

function controlledChild() {
  const child = new EventEmitter();
  child.stdout = new PassThrough();
  child.killSignals = [];
  child.kill = (signal) => {
    child.killSignals.push(signal);
    return true;
  };
  return child;
}

function controlledTimers() {
  let nextIdentifier = 1;
  const pending = new Map();
  const scheduledDelays = [];
  return {
    scheduleTimeout(callback, delay) {
      const handle = {
        identifier: nextIdentifier,
        unref() {},
      };
      nextIdentifier += 1;
      scheduledDelays.push(delay);
      pending.set(handle, { callback, delay });
      return handle;
    },
    cancelTimeout(handle) {
      pending.delete(handle);
    },
    run(delay) {
      const match = [...pending].find(
        ([, entry]) => entry.delay === delay,
      );
      assert.ok(match, `expected a pending ${delay}ms timer`);
      const [handle, entry] = match;
      pending.delete(handle);
      entry.callback();
    },
    get pendingCount() {
      return pending.size;
    },
    scheduledDelays,
  };
}

function keychainDependencies(overrides = {}) {
  return {
    getUserInfo: () => ({
      homedir: "/Users/tester",
      username: "tester",
    }),
    ...overrides,
  };
}

test("environment lookup takes precedence and clears the inherited secret", async () => {
  const environment = {
    HOME: "/Users/tester",
    USER: "tester",
    TEST_LOCAL_SECRET: "environment-secret",
  };
  let keychainReads = 0;
  assert.equal(
    await readEnvironmentOrLoginKeychainSecret(
      "TEST_LOCAL_SECRET",
      {
        environment,
        keychainReader: async () => {
          keychainReads += 1;
          return "keychain-secret";
        },
      },
    ),
    "environment-secret",
  );
  assert.equal(environment.TEST_LOCAL_SECRET, undefined);
  assert.equal(keychainReads, 0);
});

test("a captured environment secret is an opaque single-use handoff", async () => {
  const environment = {
    TEST_LOCAL_SECRET: "captured-environment-secret",
  };
  const capturedSecret = captureEnvironmentLocalSecret(
    "TEST_LOCAL_SECRET",
    environment,
  );
  let keychainReads = 0;

  assert.equal(environment.TEST_LOCAL_SECRET, undefined);
  environment.TEST_LOCAL_SECRET = "reintroduced-secret";
  assert.equal(
    await readCapturedEnvironmentOrLoginKeychainSecret(
      capturedSecret,
      {
        keychainReader: async () => {
          keychainReads += 1;
          return "must-not-run";
        },
      },
    ),
    "captured-environment-secret",
  );
  assert.equal(environment.TEST_LOCAL_SECRET, undefined);
  assert.equal(keychainReads, 0);
  await assert.rejects(
    readCapturedEnvironmentOrLoginKeychainSecret(
      capturedSecret,
    ),
    /local secret lookup is invalid/u,
  );

  const keychainEnvironment = {
    TEST_LOCAL_SECRET: "",
  };
  const capturedKeychainFallback = captureEnvironmentLocalSecret(
    "TEST_LOCAL_SECRET",
    keychainEnvironment,
  );
  assert.equal(
    await readCapturedEnvironmentOrLoginKeychainSecret(
      capturedKeychainFallback,
      {
        keychainReader: async () => {
          keychainEnvironment.TEST_LOCAL_SECRET =
            "reintroduced-during-keychain";
          return "keychain-secret";
        },
      },
    ),
    "keychain-secret",
  );
  assert.equal(keychainEnvironment.TEST_LOCAL_SECRET, undefined);

  const discardedEnvironment = {
    TEST_LOCAL_SECRET: "discarded-environment-secret",
  };
  const discardedSecret = captureEnvironmentLocalSecret(
    "TEST_LOCAL_SECRET",
    discardedEnvironment,
  );
  discardedEnvironment.TEST_LOCAL_SECRET = "reintroduced-discard";
  disposeCapturedEnvironmentLocalSecret(discardedSecret);
  assert.equal(discardedEnvironment.TEST_LOCAL_SECRET, undefined);
  await assert.rejects(
    readCapturedEnvironmentOrLoginKeychainSecret(
      discardedSecret,
    ),
    /local secret lookup is invalid/u,
  );
});

test("an empty environment value falls back to login Keychain", async () => {
  const environment = {
    TEST_LOCAL_SECRET: "",
  };
  const controller = new AbortController();
  assert.equal(
    await readEnvironmentOrLoginKeychainSecret(
      "TEST_LOCAL_SECRET",
      {
        environment,
        abortSignal: controller.signal,
        keychainReader: async (name, dependencies) => {
          assert.equal(name, "TEST_LOCAL_SECRET");
          assert.equal(
            dependencies.abortSignal,
            controller.signal,
          );
          return "keychain-secret";
        },
      },
    ),
    "keychain-secret",
  );
  assert.equal(environment.TEST_LOCAL_SECRET, undefined);
});

test("a pre-aborted lookup preserves the exact Error and never spawns", async () => {
  const controller = new AbortController();
  const reason = new Error("cancel keychain lookup");
  controller.abort(reason);
  let spawnCalls = 0;

  await assert.rejects(
    readLoginKeychainPassword(
      "TEST_LOCAL_SECRET",
      keychainDependencies({
        abortSignal: controller.signal,
        spawnProcess: () => {
          spawnCalls += 1;
          return childResult("must-not-run\n");
        },
      }),
    ),
    (error) => error === reason,
  );
  assert.equal(spawnCalls, 0);
});

test("a cross-realm Error abort reason retains exact identity", async () => {
  const controller = new AbortController();
  const reason = runInNewContext("new Error('cross-realm abort')");
  controller.abort(reason);

  await assert.rejects(
    readLoginKeychainPassword(
      "TEST_LOCAL_SECRET",
      keychainDependencies({
        abortSignal: controller.signal,
        spawnProcess: () => assert.fail("pre-abort must not spawn"),
      }),
    ),
    (error) => error === reason,
  );
});

test("a non-Error abort reason is normalized without disclosure", async () => {
  const controller = new AbortController();
  controller.abort("secret abort sentinel");

  await assert.rejects(
    readLoginKeychainPassword(
      "TEST_LOCAL_SECRET",
      keychainDependencies({
        abortSignal: controller.signal,
        spawnProcess: () => childResult("must-not-run\n"),
      }),
    ),
    (error) =>
      error instanceof SafeLocalSecretError &&
      error.message === "local secret is unavailable" &&
      !error.message.includes("sentinel"),
  );
});

test("a revoked Proxy abort reason terminates and normalizes safely", async () => {
  const child = controlledChild();
  const timers = controlledTimers();
  const controller = new AbortController();
  const revocable = Proxy.revocable({}, {});
  revocable.revoke();
  const lookup = readLoginKeychainPassword(
    "TEST_LOCAL_SECRET",
    keychainDependencies({
      abortSignal: controller.signal,
      spawnProcess: () => child,
      scheduleTimeout: timers.scheduleTimeout,
      cancelTimeout: timers.cancelTimeout,
    }),
  );

  controller.abort(revocable.proxy);
  assert.deepEqual(child.killSignals, ["SIGTERM"]);
  child.emit("close", null, "SIGTERM");
  await assert.rejects(
    lookup,
    (error) =>
      error instanceof SafeLocalSecretError &&
      error.message === "local secret is unavailable",
  );
  assert.equal(timers.pendingCount, 0);
});

test("the environment wrapper uses its existing non-Error availability failure", async () => {
  const controller = new AbortController();
  controller.abort("secret wrapper abort sentinel");

  await assert.rejects(
    readEnvironmentOrLoginKeychainSecret(
      "TEST_LOCAL_SECRET",
      {
        environment: {
          TEST_LOCAL_SECRET: "must-be-scrubbed",
        },
        abortSignal: controller.signal,
      },
    ),
    (error) =>
      error instanceof SafeLocalSecretError &&
      error.message ===
        "TEST_LOCAL_SECRET is unavailable in the environment and login Keychain" &&
      !error.message.includes("sentinel"),
  );
});

test("the environment wrapper observes abort after a custom reader resolves", async () => {
  const controller = new AbortController();
  const reason = new Error("cancel custom keychain reader");

  await assert.rejects(
    readEnvironmentOrLoginKeychainSecret(
      "TEST_LOCAL_SECRET",
      {
        environment: {},
        abortSignal: controller.signal,
        keychainReader: async () => {
          controller.abort(reason);
          return "must-not-return";
        },
      },
    ),
    (error) => error === reason,
  );
});

test("the current abort reason outranks an injected generic cancellation", async () => {
  const controller = new AbortController();
  const reason = new Error("preserve current cancellation");

  await assert.rejects(
    readEnvironmentOrLoginKeychainSecret(
      "TEST_LOCAL_SECRET",
      {
        environment: {},
        abortSignal: controller.signal,
        keychainReader: async () => {
          controller.abort(reason);
          throw new SafeLocalSecretError(
            "injected generic cancellation",
          );
        },
      },
    ),
    (error) => error === reason,
  );
});

test("Keychain lookup uses effective OS identity despite stale environment values", async () => {
  let invocation;
  let userInfoReads = 0;
  const password = await readLoginKeychainPassword(
    "TEST_LOCAL_SECRET",
    {
      environment: {
        HOME: "/Users/stale",
        USER: "stale",
      },
      getUserInfo: () => {
        userInfoReads += 1;
        return {
          homedir: "/Users/effective",
          username: "effective",
        };
      },
      spawnProcess: (command, arguments_, options) => {
        invocation = { command, arguments_, options };
        return childResult("keychain-secret\n");
      },
    },
  );

  assert.equal(password, "keychain-secret");
  assert.equal(userInfoReads, 1);
  assert.equal(invocation.command, "/usr/bin/security");
  assert.deepEqual(invocation.arguments_, [
    "find-generic-password",
    "-a",
    "effective",
    "-s",
    "TEST_LOCAL_SECRET",
    "-w",
    "/Users/effective/Library/Keychains/login.keychain-db",
  ]);
  assert.deepEqual(invocation.options, {
    env: {},
    shell: false,
    stdio: ["ignore", "pipe", "ignore"],
  });
});

test("Keychain lookup rejects invalid effective OS identities before spawning", async () => {
  let spawnCalls = 0;
  const invalidIdentityProviders = [
    () => undefined,
    () => ({ username: "tester" }),
    () => ({ homedir: "/Users/tester" }),
    () => ({
      homedir: "Users/tester",
      username: "tester",
    }),
    () => {
      throw new Error("identity sentinel");
    },
  ];

  for (const getUserInfo of invalidIdentityProviders) {
    await assert.rejects(
      readLoginKeychainPassword(
        "TEST_LOCAL_SECRET",
        keychainDependencies({
          getUserInfo,
          spawnProcess: () => {
            spawnCalls += 1;
            return childResult("must-not-run\n");
          },
        }),
      ),
      (error) =>
        error instanceof SafeLocalSecretError &&
        error.message === "local secret is unavailable" &&
        !error.message.includes("sentinel"),
    );
  }
  assert.equal(spawnCalls, 0);

  await assert.rejects(
    readLoginKeychainPassword(
      "TEST_LOCAL_SECRET",
      keychainDependencies({
        getUserInfo: null,
        spawnProcess: () => {
          spawnCalls += 1;
          return childResult("must-not-run\n");
        },
      }),
    ),
    /local secret lookup is invalid/u,
  );
  assert.equal(spawnCalls, 0);
});

test("Keychain lookup removes exactly the security presentation newline", async () => {
  const dependencies = keychainDependencies();
  assert.equal(
    await readLoginKeychainPassword(
      "TEST_LOCAL_SECRET",
      {
        ...dependencies,
        spawnProcess: () => childResult("stored-newline\n\n"),
      },
    ),
    "stored-newline\n",
  );
  await assert.rejects(
    readLoginKeychainPassword(
      "TEST_LOCAL_SECRET",
      {
        ...dependencies,
        spawnProcess: () => childResult("missing-presentation-newline"),
      },
    ),
    SafeLocalSecretError,
  );
});

test("Keychain lookup preserves a leading UTF-8 BOM for caller validation", async () => {
  const output = Buffer.concat([
    Buffer.from([0xef, 0xbb, 0xbf]),
    Buffer.from("keychain-secret\n"),
  ]);

  assert.equal(
    await readLoginKeychainPassword(
      "TEST_LOCAL_SECRET",
      keychainDependencies({
        spawnProcess: () => childResult(output),
      }),
    ),
    "\u{feff}keychain-secret",
  );
});

test("Keychain lookup fails closed on command failure or oversized output", async () => {
  const dependencies = keychainDependencies();
  await assert.rejects(
    readLoginKeychainPassword(
      "TEST_LOCAL_SECRET",
      {
        ...dependencies,
        spawnProcess: () => childResult("secret\n", { code: 44 }),
      },
    ),
    SafeLocalSecretError,
  );
  await assert.rejects(
    readLoginKeychainPassword(
      "TEST_LOCAL_SECRET",
      {
        ...dependencies,
        maxOutputBytes: 4,
        spawnProcess: () => childResult("oversized\n"),
      },
    ),
    SafeLocalSecretError,
  );
});

test("an in-flight abort escalates TERM to KILL and waits for close", async () => {
  const child = controlledChild();
  const timers = controlledTimers();
  const controller = new AbortController();
  const reason = new Error("cancel keychain lookup");
  let settled = false;
  const lookup = readLoginKeychainPassword(
    "TEST_LOCAL_SECRET",
    keychainDependencies({
      abortSignal: controller.signal,
      spawnProcess: () => child,
      scheduleTimeout: timers.scheduleTimeout,
      cancelTimeout: timers.cancelTimeout,
    }),
  );
  void lookup.then(
    () => {
      settled = true;
    },
    () => {
      settled = true;
    },
  );

  assert.deepEqual(timers.scheduledDelays, [30_000]);
  assert.equal(
    getEventListeners(controller.signal, "abort").length,
    1,
  );
  controller.abort(reason);
  assert.deepEqual(child.killSignals, ["SIGTERM"]);
  assert.deepEqual(timers.scheduledDelays, [30_000, 2_000]);
  assert.equal(settled, false);

  timers.run(2_000);
  assert.deepEqual(
    child.killSignals,
    ["SIGTERM", "SIGKILL"],
  );
  assert.equal(settled, false);

  child.emit("close", null, "SIGKILL");
  await assert.rejects(lookup, (error) => error === reason);
  assert.equal(timers.pendingCount, 0);
  assert.equal(
    getEventListeners(controller.signal, "abort").length,
    0,
  );
  assert.equal(child.listenerCount("error"), 0);
  assert.equal(child.listenerCount("close"), 0);
  assert.equal(child.stdout.listenerCount("error"), 0);
  assert.equal(child.stdout.listenerCount("data"), 0);
});

test("success clears the deadline, abort listener, and stream listeners", async () => {
  const child = controlledChild();
  const timers = controlledTimers();
  const controller = new AbortController();
  const lookup = readLoginKeychainPassword(
    "TEST_LOCAL_SECRET",
    keychainDependencies({
      abortSignal: controller.signal,
      spawnProcess: () => child,
      scheduleTimeout: timers.scheduleTimeout,
      cancelTimeout: timers.cancelTimeout,
    }),
  );
  const emitted = Buffer.from("keychain-secret\n");

  child.stdout.write(emitted);
  child.emit("close", 0, null);

  assert.equal(await lookup, "keychain-secret");
  assert.deepEqual(emitted, Buffer.alloc(emitted.byteLength));
  assert.deepEqual(timers.scheduledDelays, [30_000]);
  assert.equal(timers.pendingCount, 0);
  assert.equal(
    getEventListeners(controller.signal, "abort").length,
    0,
  );
  assert.equal(child.listenerCount("error"), 0);
  assert.equal(child.listenerCount("close"), 0);
  assert.equal(child.stdout.listenerCount("error"), 0);
  assert.equal(child.stdout.listenerCount("data"), 0);
});

test("the fixed deadline escalates and safely rejects after close", async () => {
  const child = controlledChild();
  const timers = controlledTimers();
  let settled = false;
  const lookup = readLoginKeychainPassword(
    "TEST_LOCAL_SECRET",
    keychainDependencies({
      spawnProcess: () => child,
      scheduleTimeout: timers.scheduleTimeout,
      cancelTimeout: timers.cancelTimeout,
    }),
  );
  void lookup.then(
    () => {
      settled = true;
    },
    () => {
      settled = true;
    },
  );

  timers.run(30_000);
  assert.deepEqual(child.killSignals, ["SIGTERM"]);
  assert.deepEqual(timers.scheduledDelays, [30_000, 2_000]);
  assert.equal(settled, false);
  timers.run(2_000);
  assert.deepEqual(
    child.killSignals,
    ["SIGTERM", "SIGKILL"],
  );
  assert.equal(settled, false);

  child.emit("close", null, "SIGKILL");
  await assert.rejects(lookup, SafeLocalSecretError);
  assert.equal(timers.pendingCount, 0);
});

test("an abort observed after timeout wins before process close", async () => {
  const child = controlledChild();
  const timers = controlledTimers();
  const controller = new AbortController();
  const reason = new Error("caller cancelled timed-out lookup");
  const lookup = readLoginKeychainPassword(
    "TEST_LOCAL_SECRET",
    keychainDependencies({
      abortSignal: controller.signal,
      spawnProcess: () => child,
      scheduleTimeout: timers.scheduleTimeout,
      cancelTimeout: timers.cancelTimeout,
    }),
  );

  timers.run(30_000);
  assert.deepEqual(child.killSignals, ["SIGTERM"]);
  controller.abort(reason);
  assert.deepEqual(child.killSignals, ["SIGTERM"]);
  timers.run(2_000);
  child.emit("close", null, "SIGKILL");

  await assert.rejects(lookup, (error) => error === reason);
  assert.equal(timers.pendingCount, 0);
});

test("oversized output is zeroed, drained, and rejected only after close", async () => {
  const child = controlledChild();
  const timers = controlledTimers();
  let settled = false;
  const lookup = readLoginKeychainPassword(
    "TEST_LOCAL_SECRET",
    keychainDependencies({
      maxOutputBytes: 4,
      spawnProcess: () => child,
      scheduleTimeout: timers.scheduleTimeout,
      cancelTimeout: timers.cancelTimeout,
    }),
  );
  void lookup.then(
    () => {
      settled = true;
    },
    () => {
      settled = true;
    },
  );

  const oversized = Buffer.from("oversized");
  const discarded = Buffer.from("discarded");
  child.stdout.write(oversized);
  child.stdout.write(discarded);
  assert.deepEqual(oversized, Buffer.alloc(oversized.byteLength));
  assert.deepEqual(discarded, Buffer.alloc(discarded.byteLength));
  assert.deepEqual(child.killSignals, ["SIGTERM"]);
  assert.equal(child.stdout.listenerCount("data"), 1);
  assert.equal(settled, false);

  child.emit("close", null, "SIGTERM");
  await assert.rejects(lookup, SafeLocalSecretError);
  assert.equal(timers.pendingCount, 0);
  assert.equal(child.stdout.listenerCount("data"), 0);
});

test("a stdout error is normalized but does not settle before close", async () => {
  const child = controlledChild();
  const timers = controlledTimers();
  let settled = false;
  const lookup = readLoginKeychainPassword(
    "TEST_LOCAL_SECRET",
    keychainDependencies({
      spawnProcess: () => child,
      scheduleTimeout: timers.scheduleTimeout,
      cancelTimeout: timers.cancelTimeout,
    }),
  );
  void lookup.then(
    () => {
      settled = true;
    },
    () => {
      settled = true;
    },
  );

  child.stdout.emit("error", new Error("secret stream sentinel"));
  assert.deepEqual(child.killSignals, ["SIGTERM"]);
  assert.equal(settled, false);
  child.emit("close", null, "SIGTERM");

  await assert.rejects(
    lookup,
    (error) =>
      error instanceof SafeLocalSecretError &&
      error.message === "local secret is unavailable" &&
      !error.message.includes("sentinel"),
  );
  assert.equal(timers.pendingCount, 0);
});

test("a missing stdout pipe is still reaped before rejection", async () => {
  const child = controlledChild();
  const timers = controlledTimers();
  child.stdout = undefined;
  let settled = false;
  const lookup = readLoginKeychainPassword(
    "TEST_LOCAL_SECRET",
    keychainDependencies({
      spawnProcess: () => child,
      scheduleTimeout: timers.scheduleTimeout,
      cancelTimeout: timers.cancelTimeout,
    }),
  );
  void lookup.then(
    () => {
      settled = true;
    },
    () => {
      settled = true;
    },
  );

  assert.deepEqual(child.killSignals, ["SIGTERM"]);
  assert.equal(settled, false);
  child.emit("close", null, "SIGTERM");
  await assert.rejects(lookup, SafeLocalSecretError);
  assert.equal(timers.pendingCount, 0);
});

test("Keychain output cannot exceed the 4,097-byte hard cap", async () => {
  const maximumPassword = "x".repeat(4_096);
  assert.equal(
    await readLoginKeychainPassword(
      "TEST_LOCAL_SECRET",
      keychainDependencies({
        spawnProcess: () =>
          childResult(`${maximumPassword}\n`),
      }),
    ),
    maximumPassword,
  );
  await assert.rejects(
    readLoginKeychainPassword(
      "TEST_LOCAL_SECRET",
      keychainDependencies({
        maxOutputBytes: 4_098,
        spawnProcess: () => childResult("secret\n"),
      }),
    ),
    /local secret lookup is invalid/u,
  );
});
