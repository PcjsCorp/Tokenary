import assert from "node:assert/strict";
import {
  createHash,
  generateKeyPairSync,
} from "node:crypto";
import { EventEmitter } from "node:events";
import {
  chmod,
  mkdir,
  mkdtemp,
  readFile,
  realpath,
  rename,
  rm,
  symlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Readable } from "node:stream";
import { afterEach, before, test } from "node:test";

import {
  keypairMain,
  parseRequestProofKeyValue,
  prepareValidatedKeypair,
  readBoundedRegularFile,
  readExpectedRequestProofKeyFingerprint,
  readRequestProofKeyFromKeychain,
  readValidatedRequestProofKey,
  SafePreflightError,
  validateKeypair as validateKeypairWithDependencies,
} from "./validate-keypair.mjs";

const EXPECTED_KID = "tool-test-kid";
const REQUEST_PROOF_KEY =
  "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8";
const OTHER_REQUEST_PROOF_KEY =
  "ICEiIyQlJicoKSorLC0uLzAxMjM0NTY3ODk6Ozw9Pj8";
const REQUEST_PROOF_KEY_FINGERPRINT = createHash("sha256")
  .update(REQUEST_PROOF_KEY, "ascii")
  .digest("hex");
const OTHER_REQUEST_PROOF_KEY_FINGERPRINT = createHash("sha256")
  .update(OTHER_REQUEST_PROOF_KEY, "ascii")
  .digest("hex");
const temporaryDirectories = [];
let rsa2048;
let otherRsa2048;
let rsa3072;
let rsa2048Exponent3;

function validateKeypair(
  options,
  expectedFingerprint = REQUEST_PROOF_KEY_FINGERPRINT,
) {
  const {
    appProofKey = REQUEST_PROOF_KEY,
    ...keypairOptions
  } = options;
  return validateKeypairWithDependencies(keypairOptions, {
    expectedRequestProofKeyFingerprint:
      expectedFingerprint,
    requestProofKeyReader: async ({ expectedFingerprint: pinned }) =>
      parseRequestProofKeyValue(appProofKey, pinned),
  });
}

function generateFixture(modulusLength, publicExponent = 65_537) {
  const { privateKey, publicKey } = generateKeyPairSync("rsa", {
    modulusLength,
    publicExponent,
  });
  return {
    pkcs8: privateKey.export({ format: "pem", type: "pkcs8" }).toString(),
    pkcs1: privateKey.export({ format: "pem", type: "pkcs1" }).toString(),
    spki: publicKey.export({ format: "pem", type: "spki" }).toString(),
  };
}

function keychainChild(output) {
  const child = new EventEmitter();
  child.stdout = Readable.from([Buffer.from(output)]);
  child.kill = () => true;
  setImmediate(() => child.emit("close", 0, null));
  return child;
}

before(() => {
  rsa2048 = generateFixture(2_048);
  otherRsa2048 = generateFixture(2_048);
  rsa3072 = generateFixture(3_072);
  rsa2048Exponent3 = generateFixture(2_048, 3);
});

afterEach(async () => {
  await Promise.all(
    temporaryDirectories.splice(0).map((path) =>
      rm(path, { recursive: true, force: true }),
    ),
  );
});

async function writeFixture({
  privatePem = rsa2048.pkcs8,
  publicPem = rsa2048.spki,
  secretsMode = 0o600,
  appProofKey = REQUEST_PROOF_KEY,
  rawSecrets,
  directory: suppliedDirectory,
} = {}) {
  const directory =
    suppliedDirectory ??
    await realpath(
      await mkdtemp(join(tmpdir(), "alchemy-jwt-preflight-")),
    );
  if (suppliedDirectory === undefined) {
    temporaryDirectories.push(directory);
  }
  const secretsFile = join(directory, "secrets.json");
  const publicKeyFile = join(directory, "public.pem");
  const secrets =
    rawSecrets ??
    JSON.stringify({
      ALCHEMY_JWT_PRIVATE_KEY: privatePem,
      ALCHEMY_JWT_REQUEST_PROOF_KEY: REQUEST_PROOF_KEY,
    });
  await writeFile(secretsFile, secrets, { mode: 0o600 });
  await chmod(secretsFile, secretsMode);
  await writeFile(publicKeyFile, publicPem, { mode: 0o644 });
  return {
    secretsFile,
    publicKeyFile,
    appProofKey,
    expectedKid: EXPECTED_KID,
  };
}

test("accepts matching RSA and Worker/app request-proof keys", async () => {
  await assert.doesNotReject(validateKeypair(await writeFixture()));
});

test("strict proof-key parser rejects alternate environment encodings", () => {
  assert.deepEqual(
    parseRequestProofKeyValue(
      REQUEST_PROOF_KEY,
      REQUEST_PROOF_KEY_FINGERPRINT,
    ),
    Buffer.from(REQUEST_PROOF_KEY, "base64url"),
  );

  for (const appProofKey of [
    `\ufeff${REQUEST_PROOF_KEY}`,
    `${REQUEST_PROOF_KEY}\r\n`,
    `${REQUEST_PROOF_KEY}=`,
    `${REQUEST_PROOF_KEY}\n\n`,
    `${REQUEST_PROOF_KEY.slice(0, 42)}\xff`,
  ]) {
    assert.throws(
      () => parseRequestProofKeyValue(
        appProofKey,
        REQUEST_PROOF_KEY_FINGERPRINT,
      ),
      /app proof key must be a canonical 32-byte base64url key/u,
    );
  }
});

test("proof-key lookup prefers the environment and falls back to Keychain", async () => {
  let keychainReads = 0;
  const controller = new AbortController();
  const environment = {
    ALCHEMY_JWT_REQUEST_PROOF_KEY: REQUEST_PROOF_KEY,
  };
  const environmentKey = await readValidatedRequestProofKey({
    environment,
    abortSignal: controller.signal,
    expectedFingerprint: REQUEST_PROOF_KEY_FINGERPRINT,
    keychainReader: async () => {
      keychainReads += 1;
      return OTHER_REQUEST_PROOF_KEY;
    },
  });
  assert.deepEqual(
    environmentKey,
    Buffer.from(REQUEST_PROOF_KEY, "base64url"),
  );
  assert.equal(environment.ALCHEMY_JWT_REQUEST_PROOF_KEY, undefined);
  assert.equal(keychainReads, 0);
  environmentKey.fill(0);

  const keychainKey = await readValidatedRequestProofKey({
    environment: {},
    abortSignal: controller.signal,
    expectedFingerprint: REQUEST_PROOF_KEY_FINGERPRINT,
    keychainReader: async (dependencies) => {
      keychainReads += 1;
      assert.equal(dependencies.abortSignal, controller.signal);
      assert.equal(dependencies.maxOutputBytes, 44);
      return REQUEST_PROOF_KEY;
    },
  });
  assert.deepEqual(
    keychainKey,
    Buffer.from(REQUEST_PROOF_KEY, "base64url"),
  );
  assert.equal(keychainReads, 1);
  keychainKey.fill(0);

  const malformedEnvironment = {
    ALCHEMY_JWT_REQUEST_PROOF_KEY: "not-a-canonical-proof-key",
  };
  await assert.rejects(
    readValidatedRequestProofKey({
      environment: malformedEnvironment,
      expectedFingerprint: REQUEST_PROOF_KEY_FINGERPRINT,
      keychainReader: async () => {
        keychainReads += 1;
        return REQUEST_PROOF_KEY;
      },
    }),
    /canonical 32-byte base64url key/u,
  );
  assert.equal(
    Object.hasOwn(
      malformedEnvironment,
      "ALCHEMY_JWT_REQUEST_PROOF_KEY",
    ),
    false,
  );
  assert.equal(keychainReads, 1);

  await assert.rejects(
    readValidatedRequestProofKey({
      environment: {},
      expectedFingerprint: REQUEST_PROOF_KEY_FINGERPRINT,
      keychainReader: async () => `${REQUEST_PROOF_KEY}\n`,
    }),
    /canonical 32-byte base64url key/u,
  );
});

test("keypair preparation captures the proof environment before file reads", async () => {
  const options = await writeFixture();
  await rm(options.secretsFile);
  const environment = {
    ALCHEMY_JWT_REQUEST_PROOF_KEY: REQUEST_PROOF_KEY,
  };

  const preparation = prepareValidatedKeypair(options, {
    expectedRequestProofKeyFingerprint:
      REQUEST_PROOF_KEY_FINGERPRINT,
    requestProofKeyEnvironment: environment,
  });
  assert.equal(
    Object.hasOwn(
      environment,
      "ALCHEMY_JWT_REQUEST_PROOF_KEY",
    ),
    false,
  );
  environment.ALCHEMY_JWT_REQUEST_PROOF_KEY =
    "reintroduced-proof-secret";

  await assert.rejects(
    preparation,
    /key input file could not be read safely/u,
  );
  assert.equal(
    Object.hasOwn(
      environment,
      "ALCHEMY_JWT_REQUEST_PROOF_KEY",
    ),
    false,
  );
});

test("proof-key Keychain reads enforce the 44-byte presentation cap", async () => {
  const dependencies = {
    getUserInfo: () => ({
      homedir: "/Users/tester",
      username: "tester",
    }),
  };
  assert.equal(
    await readRequestProofKeyFromKeychain({
      ...dependencies,
      spawnProcess: () => keychainChild(`${REQUEST_PROOF_KEY}\n`),
    }),
    REQUEST_PROOF_KEY,
  );
  await assert.rejects(
    readRequestProofKeyFromKeychain({
      ...dependencies,
      spawnProcess: () =>
        keychainChild(`${REQUEST_PROOF_KEY}A\n`),
    }),
    /local secret is unavailable/u,
  );
});

test("proof-key and keypair cancellation preserve the exact Error", async () => {
  const controller = new AbortController();
  const reason = new Error("cancel proof-key lookup");
  controller.abort(reason);
  let keychainReads = 0;
  await assert.rejects(
    readValidatedRequestProofKey({
      environment: {},
      abortSignal: controller.signal,
      expectedFingerprint: REQUEST_PROOF_KEY_FINGERPRINT,
      keychainReader: async () => {
        keychainReads += 1;
        return REQUEST_PROOF_KEY;
      },
    }),
    (error) => error === reason,
  );
  assert.equal(keychainReads, 0);

  const options = await writeFixture();
  const { appProofKey: _appProofKey, ...keypairOptions } = options;
  let proofReaderCalls = 0;
  await assert.rejects(
    validateKeypairWithDependencies(keypairOptions, {
      abortSignal: controller.signal,
      expectedRequestProofKeyFingerprint:
        REQUEST_PROOF_KEY_FINGERPRINT,
      requestProofKeyReader: async () => {
        proofReaderCalls += 1;
        return Buffer.from(REQUEST_PROOF_KEY, "base64url");
      },
    }),
    (error) => error === reason,
  );
  assert.equal(proofReaderCalls, 0);
});

test("keypair validation passes its abort signal to the proof reader", async () => {
  const controller = new AbortController();
  const options = await writeFixture();
  const { appProofKey: _appProofKey, ...keypairOptions } = options;
  let observedDependencies;

  await validateKeypairWithDependencies(keypairOptions, {
    abortSignal: controller.signal,
    expectedRequestProofKeyFingerprint:
      REQUEST_PROOF_KEY_FINGERPRINT,
    requestProofKeyReader: async (dependencies) => {
      observedDependencies = dependencies;
      return parseRequestProofKeyValue(
        REQUEST_PROOF_KEY,
        dependencies.expectedFingerprint,
      );
    },
  });

  assert.equal(
    observedDependencies.abortSignal,
    controller.signal,
  );
  assert.equal(
    observedDependencies.expectedFingerprint,
    REQUEST_PROOF_KEY_FINGERPRINT,
  );
  assert.equal(
    Object.hasOwn(observedDependencies, "preparedCredential"),
    false,
  );
});

test("keypair validation preserves cancellation when the proof reader rejects", async () => {
  const controller = new AbortController();
  const reason = new Error("cancel rejected proof lookup");
  const options = await writeFixture();
  const { appProofKey: _appProofKey, ...keypairOptions } = options;

  await assert.rejects(
    validateKeypairWithDependencies(keypairOptions, {
      abortSignal: controller.signal,
      expectedRequestProofKeyFingerprint:
        REQUEST_PROOF_KEY_FINGERPRINT,
      requestProofKeyReader: async ({ abortSignal }) => {
        assert.equal(abortSignal, controller.signal);
        controller.abort(reason);
        throw new Error("injected proof-reader wrapper");
      },
    }),
    (error) => error === reason,
  );
});

test("fingerprint file parser requires exact lowercase SHA-256 text", async () => {
  const directory = await realpath(
    await mkdtemp(
      join(tmpdir(), "alchemy-jwt-fingerprint-test-"),
    ),
  );
  temporaryDirectories.push(directory);
  const fingerprintPath = join(directory, "proof-key.sha256");
  await writeFile(
    fingerprintPath,
    `${REQUEST_PROOF_KEY_FINGERPRINT}\n`,
    { mode: 0o644 },
  );
  assert.equal(
    await readExpectedRequestProofKeyFingerprint(fingerprintPath),
    REQUEST_PROOF_KEY_FINGERPRINT,
  );

  for (const malformed of [
    REQUEST_PROOF_KEY_FINGERPRINT.toUpperCase(),
    `\ufeff${REQUEST_PROOF_KEY_FINGERPRINT}`,
    `${REQUEST_PROOF_KEY_FINGERPRINT}\r\n`,
  ]) {
    await writeFile(fingerprintPath, malformed, { mode: 0o644 });
    await assert.rejects(
      readExpectedRequestProofKeyFingerprint(fingerprintPath),
      /(fingerprint file|key input file size) is invalid/u,
    );
  }
});

test("rejects a valid proof key that does not match the pinned fingerprint", async () => {
  const options = await writeFixture();
  await assert.rejects(
    validateKeypair(options, OTHER_REQUEST_PROOF_KEY_FINGERPRINT),
    /does not match the pinned fingerprint/u,
  );
});

test("rejects a mismatched app request-proof key", async () => {
  await assert.rejects(
    validateKeypair(
      await writeFixture({ appProofKey: OTHER_REQUEST_PROOF_KEY }),
      OTHER_REQUEST_PROOF_KEY_FINGERPRINT,
    ),
    /Worker and app request-proof keys do not match/u,
  );
});

test("rejects malformed request-proof keys", async () => {
  await assert.rejects(
    validateKeypair(
      await writeFixture({
        rawSecrets: JSON.stringify({
          ALCHEMY_JWT_PRIVATE_KEY: rsa2048.pkcs8,
          ALCHEMY_JWT_REQUEST_PROOF_KEY: `${REQUEST_PROOF_KEY}=`,
        }),
      }),
    ),
    /request-proof secret must be a canonical 32-byte base64url key/u,
  );
  for (const appProofKey of [
    `${REQUEST_PROOF_KEY}\n\n`,
    `${REQUEST_PROOF_KEY}\r\n`,
    `${REQUEST_PROOF_KEY} `,
    `${REQUEST_PROOF_KEY}=`,
  ]) {
    await assert.rejects(
      validateKeypair(await writeFixture({ appProofKey })),
      /app proof key must be a canonical 32-byte base64url key/u,
    );
  }
});

test("rejects a mismatched public key", async () => {
  await assert.rejects(
    validateKeypair(
      await writeFixture({ publicPem: otherRsa2048.spki }),
    ),
    (error) =>
      error instanceof SafePreflightError &&
      error.message === "private and public keys do not match",
  );
});

test("rejects PKCS1 private key input", async () => {
  await assert.rejects(
    validateKeypair(await writeFixture({ privatePem: rsa2048.pkcs1 })),
    /private key must be unencrypted PKCS8 PEM/u,
  );
});

test("rejects concatenated private and public PEM envelopes", async () => {
  await assert.rejects(
    validateKeypair(
      await writeFixture({
        privatePem: rsa2048.pkcs8 + otherRsa2048.pkcs8,
      }),
    ),
    /private key must be unencrypted PKCS8 PEM/u,
  );
  await assert.rejects(
    validateKeypair(
      await writeFixture({
        publicPem: rsa2048.spki + otherRsa2048.spki,
      }),
    ),
    /public key must be SPKI PEM/u,
  );
});

test("rejects non-RSA-2048 keys", async () => {
  await assert.rejects(
    validateKeypair(
      await writeFixture({
        privatePem: rsa3072.pkcs8,
        publicPem: rsa3072.spki,
      }),
    ),
    /keypair must use RSA-2048/u,
  );
});

test("rejects RSA-2048 keys with a non-65537 public exponent", async () => {
  await assert.rejects(
    validateKeypair(
      await writeFixture({
        privatePem: rsa2048Exponent3.pkcs8,
        publicPem: rsa2048Exponent3.spki,
      }),
    ),
    /public exponent 65537/u,
  );
});

test("requires exact mode 0600 for the secrets file", async () => {
  for (const secretsMode of [0o400, 0o644, 0o700]) {
    await assert.rejects(
      validateKeypair(await writeFixture({ secretsMode })),
      /permissions must be exactly 0600/u,
    );
  }
});

test("requires an owner-only secrets directory", async () => {
  const options = await writeFixture();
  await chmod(temporaryDirectories.at(-1), 0o755);

  await assert.rejects(
    validateKeypair(options),
    /secrets directory permissions must deny group and world access/u,
  );
});

test("rejects a non-sticky writable ancestor", async () => {
  const outer = await realpath(
    await mkdtemp(
      join(tmpdir(), "alchemy-jwt-preflight-ancestor-"),
    ),
  );
  temporaryDirectories.push(outer);
  const writableAncestor = join(outer, "writable");
  const protectedDirectory = join(writableAncestor, "protected");
  await mkdir(writableAncestor, { mode: 0o700 });
  await mkdir(protectedDirectory, { mode: 0o700 });
  const options = await writeFixture({
    directory: protectedDirectory,
  });
  await chmod(writableAncestor, 0o777);

  await assert.rejects(
    validateKeypair(options),
    /directory permissions are unsafe/u,
  );
});

test("accepts a trusted sticky writable ancestor", async () => {
  const outer = await realpath(
    await mkdtemp(
      join(tmpdir(), "alchemy-jwt-preflight-sticky-"),
    ),
  );
  temporaryDirectories.push(outer);
  const stickyAncestor = join(outer, "sticky");
  const protectedDirectory = join(stickyAncestor, "protected");
  await mkdir(stickyAncestor, { mode: 0o700 });
  await mkdir(protectedDirectory, { mode: 0o700 });
  const options = await writeFixture({
    directory: protectedDirectory,
  });
  await chmod(stickyAncestor, 0o1777);

  await assert.doesNotReject(validateKeypair(options));
});

test("rejects final-component key input symlinks", async () => {
  const options = await writeFixture();
  const directory = temporaryDirectories.at(-1);
  const secretLink = join(directory, "secret-link.json");
  const publicLink = join(directory, "public-link.pem");
  await symlink(options.secretsFile, secretLink);
  await symlink(options.publicKeyFile, publicLink);

  await assert.rejects(
    validateKeypair({ ...options, secretsFile: secretLink }),
    /symlinks are not allowed/u,
  );
  await assert.rejects(
    validateKeypair({ ...options, publicKeyFile: publicLink }),
    /symlinks are not allowed/u,
  );
});

test("detects pathname replacement while reading", async () => {
  const options = await writeFixture();
  const originalBytes = await readFile(options.secretsFile);
  const replacedPath = `${options.secretsFile}.replaced`;

  await assert.rejects(
    readBoundedRegularFile(
      options.secretsFile,
      32 * 1_024,
      {
        requirePrivatePermissions: true,
        afterFirstRead: async () => {
          await rename(options.secretsFile, replacedPath);
          await writeFile(options.secretsFile, originalBytes, {
            mode: 0o600,
          });
        },
      },
    ),
    /changed while it was being validated/u,
  );
});

test("detects same-inode content mutation while reading", async () => {
  const options = await writeFixture();
  const originalBytes = await readFile(options.secretsFile);
  const replacementBytes = Buffer.alloc(
    originalBytes.byteLength,
    0x78,
  );

  await assert.rejects(
    readBoundedRegularFile(
      options.secretsFile,
      32 * 1_024,
      {
        requirePrivatePermissions: true,
        afterFirstRead: async () => {
          await writeFile(options.secretsFile, replacementBytes);
        },
      },
    ),
    /changed while it was being validated/u,
  );
});

test("rejects missing and unreadable key inputs without disclosing paths", async () => {
  const missing = await writeFixture();
  const missingPath = join(
    temporaryDirectories.at(-1),
    "missing-private-bundle.json",
  );
  await assert.rejects(
    validateKeypair({ ...missing, secretsFile: missingPath }),
    (error) =>
      error instanceof SafePreflightError &&
      error.message === "key input file could not be read safely" &&
      !error.message.includes(missingPath),
  );

  const unreadable = await writeFixture();
  await chmod(unreadable.secretsFile, 0o000);
  await assert.rejects(
    validateKeypair(unreadable),
    (error) =>
      error instanceof SafePreflightError &&
      error.message === "key input file could not be read safely" &&
      !error.message.includes(unreadable.secretsFile),
  );
});

test("rejects malformed and incorrectly shaped secret bundles", async () => {
  await assert.rejects(
    validateKeypair(await writeFixture({ rawSecrets: "{" })),
    /valid UTF-8 JSON/u,
  );
  await assert.rejects(
    validateKeypair(await writeFixture({ rawSecrets: "{}" })),
    /must contain exactly the signing and request-proof keys/u,
  );
});

test("the keypair CLI rethrows cancellation instead of reporting failure", async () => {
  const options = await writeFixture();
  const controller = new AbortController();
  const reason = new Error("cancel keypair CLI");
  controller.abort(reason);
  const errors = [];
  let proofReaderCalls = 0;

  await assert.rejects(
    keypairMain(
      [
        "--secrets-file",
        options.secretsFile,
        "--public-key-file",
        options.publicKeyFile,
        "--expected-kid",
        EXPECTED_KID,
      ],
      {
        abortSignal: controller.signal,
        expectedRequestProofKeyFingerprint:
          REQUEST_PROOF_KEY_FINGERPRINT,
        stderr: (message) => errors.push(message),
        requestProofKeyReader: async () => {
          proofReaderCalls += 1;
          return Buffer.from(REQUEST_PROOF_KEY, "base64url");
        },
      },
    ),
    (error) => error === reason,
  );
  assert.deepEqual(errors, []);
  assert.equal(proofReaderCalls, 0);
});

test("CLI failures never disclose supplied secret material", async () => {
  const sentinel = "never-print-this-private-key-sentinel";
  const options = await writeFixture({
    rawSecrets: JSON.stringify({
      ALCHEMY_JWT_PRIVATE_KEY: sentinel,
      ALCHEMY_JWT_REQUEST_PROOF_KEY: REQUEST_PROOF_KEY,
    }),
  });
  const output = [];
  const errors = [];
  const exitCode = await keypairMain(
    [
      "--secrets-file",
      options.secretsFile,
      "--public-key-file",
      options.publicKeyFile,
      "--expected-kid",
      EXPECTED_KID,
    ],
    {
      expectedRequestProofKeyFingerprint:
        REQUEST_PROOF_KEY_FINGERPRINT,
      stdout: (message) => output.push(message),
      stderr: (message) => errors.push(message),
      requestProofKeyReader: async ({ expectedFingerprint }) =>
        parseRequestProofKeyValue(
          REQUEST_PROOF_KEY,
          expectedFingerprint,
        ),
    },
  );

  assert.equal(exitCode, 1);
  assert.doesNotMatch(output.join("\n"), new RegExp(sentinel, "u"));
  assert.doesNotMatch(errors.join("\n"), new RegExp(sentinel, "u"));
  assert.match(errors.join("\n"), /keypair-preflight: failed/u);
});
