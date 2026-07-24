#!/usr/bin/env node

import {
  constants,
} from "node:fs";
import {
  link,
  lstat,
  open,
  rm,
} from "node:fs/promises";
import {
  basename,
  dirname,
  resolve,
} from "node:path";
import process from "node:process";
import {
  fileURLToPath,
  pathToFileURL,
} from "node:url";

import {
  createSignedBrokerRequest,
  fetchBoundedWithTimeout,
  readAppProofKey,
  validateIssuancePayload,
} from "./live-validate.mjs";

const DEFAULT_BROKER_URL = "https://api.lil.org/v1/alchemy/jwt";
const REQUEST_PROOF_HEADER = "X-Lil-Alchemy-Proof";
const DEFAULT_TIMEOUT_MS = 15_000;
const MAX_TIMEOUT_MS = 120_000;
const DEFAULT_CONCURRENCY = 8;
const MAX_CONCURRENCY = 32;
const MAX_CATALOG_BYTES = 2 * 1_024 * 1_024;
const MAX_BROKER_RESPONSE_BYTES = 32 * 1_024;
const MAX_RPC_RESPONSE_BYTES = 128 * 1_024;
const ALCHEMY_NETWORK_PATTERN =
  /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/u;
const HEX_QUANTITY_PATTERN = /^0[xX][0-9a-fA-F]{1,256}$/u;
const ISO_INSTANT_PATTERN =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/u;
const SUPPORTED_HINTS = new Set(["eip1559", "legacy", "unknown"]);

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const defaultCatalogPath = resolve(
  scriptDirectory,
  "../../../Shared/Ethereum/NetworkCatalog.json",
);

export class SafeFeeMarketProbeError extends Error {
  constructor(message) {
    super(message);
    this.name = "SafeFeeMarketProbeError";
  }
}

function fail(message) {
  return new SafeFeeMarketProbeError(message);
}

function usage() {
  return [
    "Usage: npm run probe:fee-markets -- [options]",
    "",
    "The default command prints a report and never edits the catalog.",
    "",
    "Options:",
    "  --catalog PATH              NetworkCatalog.json path",
    "  --app-proof-key-file PATH   Protected app proof-key file",
    "  --expected-kid KID          Expected Alchemy JWT key identifier",
    `  --concurrency N             Parallel networks, 1-${MAX_CONCURRENCY} (default: ${DEFAULT_CONCURRENCY})`,
    `  --timeout-ms N              Per-request timeout, 1-${MAX_TIMEOUT_MS} (default: ${DEFAULT_TIMEOUT_MS})`,
    "  --output PATH               Write an exclusive catalog candidate",
    "  --help                      Show this help",
  ].join("\n");
}

function parsePositiveInteger(value, optionName, maximum) {
  if (!/^[1-9][0-9]*$/u.test(value)) {
    throw fail(`${optionName} must be a positive integer`);
  }
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed > maximum) {
    throw fail(`${optionName} is outside the supported range`);
  }
  return parsed;
}

export function parseProbeArguments(arguments_) {
  const options = {
    catalogPath: defaultCatalogPath,
    appProofKeyFile: undefined,
    expectedKid: undefined,
    concurrency: DEFAULT_CONCURRENCY,
    timeoutMs: DEFAULT_TIMEOUT_MS,
    outputPath: undefined,
    help: false,
  };
  const valueOptions = new Map([
    ["--catalog", "catalogPath"],
    ["--app-proof-key-file", "appProofKeyFile"],
    ["--expected-kid", "expectedKid"],
    ["--concurrency", "concurrency"],
    ["--timeout-ms", "timeoutMs"],
    ["--output", "outputPath"],
  ]);
  const seen = new Set();

  for (let index = 0; index < arguments_.length; index += 1) {
    const argument = arguments_[index];
    if (argument === "--help") {
      options.help = true;
      continue;
    }

    const key = valueOptions.get(argument);
    if (key === undefined) {
      throw fail("Unknown command-line option");
    }
    if (seen.has(argument)) {
      throw fail(`Duplicate command-line option ${argument}`);
    }
    seen.add(argument);
    const value = arguments_[index + 1];
    if (value === undefined || value.startsWith("--")) {
      throw fail(`Missing value for ${argument}`);
    }
    index += 1;
    if (key === "concurrency") {
      options[key] = parsePositiveInteger(
        value,
        argument,
        MAX_CONCURRENCY,
      );
    } else if (key === "timeoutMs") {
      options[key] = parsePositiveInteger(
        value,
        argument,
        MAX_TIMEOUT_MS,
      );
    } else {
      options[key] = value;
    }
  }

  const hasProofKey = options.appProofKeyFile !== undefined;
  const hasExpectedKid = options.expectedKid !== undefined;
  if (hasProofKey !== hasExpectedKid) {
    throw fail(
      "--app-proof-key-file and --expected-kid must be provided together",
    );
  }
  if (
    hasExpectedKid &&
    !/^[\u0021-\u007e]{1,256}$/u.test(options.expectedKid)
  ) {
    throw fail("--expected-kid is invalid");
  }
  if (
    options.outputPath !== undefined &&
    resolve(options.outputPath) === resolve(options.catalogPath)
  ) {
    throw fail("Catalog output must differ from the source catalog");
  }
  return options;
}

function isPlainObject(value) {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value) &&
    Object.getPrototypeOf(value) === Object.prototype
  );
}

function canonicalAlchemyURL(network) {
  if (
    typeof network !== "string" ||
    !ALCHEMY_NETWORK_PATTERN.test(network)
  ) {
    return undefined;
  }
  return `https://${network}.g.alchemy.com/v2`;
}

export function endpointForRecord(record) {
  if (!isPlainObject(record)) {
    throw fail("Network catalog contains an invalid record");
  }
  const alchemyURL = canonicalAlchemyURL(record.alchemyNetwork);
  const fallbackURL = record.fallbackRPCURL;
  const hasAlchemy = alchemyURL !== undefined;
  const hasFallback =
    typeof fallbackURL === "string" && fallbackURL.length > 0;
  if (hasAlchemy === hasFallback) {
    throw fail("Network catalog endpoint ownership is invalid");
  }
  if (hasAlchemy) {
    return { url: alchemyURL, isAlchemy: true };
  }

  let url;
  try {
    url = new URL(fallbackURL);
  } catch {
    throw fail("Network catalog fallback endpoint is invalid");
  }
  if (
    url.protocol !== "https:" ||
    url.host === "" ||
    url.username !== "" ||
    url.password !== ""
  ) {
    throw fail("Network catalog fallback endpoint is invalid");
  }
  return { url: fallbackURL, isAlchemy: false };
}

function isCanonicalISOInstant(value) {
  if (typeof value !== "string" || !ISO_INSTANT_PATTERN.test(value)) {
    return false;
  }
  const milliseconds = Date.parse(value);
  return Number.isFinite(milliseconds) &&
    new Date(milliseconds).toISOString().replace(".000Z", "Z") === value;
}

function validateCatalogRecord(record, chainIds) {
  if (
    !Number.isSafeInteger(record?.chainId) ||
    record.chainId <= 0 ||
    chainIds.has(record.chainId)
  ) {
    throw fail("Network catalog chain ownership is invalid");
  }
  chainIds.add(record.chainId);
  endpointForRecord(record);
  const hint = record.feeMarketHint;
  if (
    !isPlainObject(hint) ||
    !SUPPORTED_HINTS.has(hint.support) ||
    !isCanonicalISOInstant(hint.checkedAt) ||
    typeof hint.observedEndpoint !== "string" ||
    hint.observedEndpoint.length === 0
  ) {
    throw fail("Network catalog fee-market hint is invalid");
  }
}

export async function readProbeCatalog(catalogPath) {
  const path = resolve(catalogPath);
  let handle;
  let sourceStats;
  let bytes;
  try {
    handle = await open(
      path,
      constants.O_RDONLY | (constants.O_NOFOLLOW ?? 0),
    );
    const statsBeforeRead = await handle.stat();
    if (
      !statsBeforeRead.isFile() ||
      statsBeforeRead.size < 0 ||
      statsBeforeRead.size > MAX_CATALOG_BYTES
    ) {
      throw fail("Network catalog could not be read safely");
    }
    bytes = await handle.readFile();
    const statsAfterRead = await handle.stat();
    const pathStats = await lstat(path);
    if (
      !pathStats.isFile() ||
      pathStats.isSymbolicLink() ||
      bytes.byteLength > MAX_CATALOG_BYTES ||
      bytes.byteLength !== statsAfterRead.size ||
      !catalogStatsMatch(statsBeforeRead, statsAfterRead) ||
      !catalogStatsMatch(statsAfterRead, pathStats)
    ) {
      throw fail("Network catalog changed while it was read");
    }
    sourceStats = statsAfterRead;
    await handle.close();
    handle = undefined;
  } catch (error) {
    await handle?.close().catch(() => undefined);
    if (error instanceof SafeFeeMarketProbeError) {
      throw error;
    }
    throw fail("Network catalog could not be read safely");
  }

  let records;
  try {
    records = JSON.parse(
      new TextDecoder("utf-8", { fatal: true }).decode(bytes),
    );
  } catch {
    throw fail("Network catalog is not valid UTF-8 JSON");
  }
  if (!Array.isArray(records) || records.length === 0) {
    throw fail("Network catalog must be a nonempty array");
  }
  const chainIds = new Set();
  records.forEach((record) => validateCatalogRecord(record, chainIds));
  return {
    path,
    records,
    mode: sourceStats.mode & 0o777,
    sourceBytes: bytes,
    sourceStats,
  };
}

function rpcSuccess(result) {
  return { kind: "success", result };
}

function rpcFailure(reason, error) {
  return { kind: "failure", reason, error };
}

function isHexQuantity(value) {
  return typeof value === "string" &&
    HEX_QUANTITY_PATTERN.test(value) &&
    value.slice(2).replace(/^0+/u, "").length <= 64;
}

function isUnsupportedMethod(outcome) {
  return outcome.kind === "failure" &&
    outcome.error?.code === -32_601;
}

export function classifyFeeMarketProbe(
  expectedChainId,
  {
    chainId,
    latestBlock,
    feeHistory,
  },
) {
  if (
    chainId.kind !== "success" ||
    !isHexQuantity(chainId.result)
  ) {
    return { support: "unknown", reason: "chain-id-unavailable" };
  }
  if (BigInt(chainId.result) !== BigInt(expectedChainId)) {
    return { support: "unknown", reason: "chain-id-mismatch" };
  }
  if (
    latestBlock.kind !== "success" ||
    !isPlainObject(latestBlock.result)
  ) {
    return { support: "unknown", reason: "latest-block-unavailable" };
  }
  if (!isHexQuantity(latestBlock.result.number)) {
    return { support: "unknown", reason: "latest-block-number-malformed" };
  }

  const hasBaseFeeField = Object.hasOwn(
    latestBlock.result,
    "baseFeePerGas",
  );
  if (
    hasBaseFeeField &&
    !isHexQuantity(latestBlock.result.baseFeePerGas)
  ) {
    return { support: "unknown", reason: "base-fee-malformed" };
  }

  let feeHistorySupport;
  if (feeHistory.kind === "success") {
    const baseFees = feeHistory.result?.baseFeePerGas;
    feeHistorySupport =
      isPlainObject(feeHistory.result) &&
      Array.isArray(baseFees) &&
      baseFees.length === 2 &&
      baseFees.every(isHexQuantity)
        ? "supported"
        : "malformed";
  } else if (isUnsupportedMethod(feeHistory)) {
    feeHistorySupport = "unsupported";
  } else {
    feeHistorySupport = "unavailable";
  }

  if (hasBaseFeeField) {
    if (feeHistorySupport === "supported") {
      if (
        BigInt(latestBlock.result.baseFeePerGas) !==
        BigInt(feeHistory.result.baseFeePerGas[0])
      ) {
        return { support: "unknown", reason: "contradictory-base-fee" };
      }
      return { support: "eip1559", reason: "base-fee-and-history" };
    }
    if (feeHistorySupport === "unsupported") {
      return {
        support: "eip1559",
        reason: "base-fee-and-history-unsupported",
      };
    }
  }
  if (!hasBaseFeeField && feeHistorySupport === "unsupported") {
    return { support: "legacy", reason: "no-base-fee-and-no-history" };
  }
  return { support: "unknown", reason: "contradictory-or-incomplete" };
}

async function rpcCall(
  endpoint,
  method,
  params,
  id,
  {
    authorization,
    timeoutMs,
    fetchImplementation,
  },
) {
  const headers = {
    Accept: "application/json",
    "Content-Type": "application/json",
  };
  if (endpoint.isAlchemy) {
    if (authorization === undefined) {
      return rpcFailure("authorization-unavailable");
    }
    headers.Authorization = `Bearer ${authorization}`;
  }

  let response;
  let bytes;
  try {
    ({ response, bytes } = await fetchBoundedWithTimeout(
      endpoint.url,
      {
        method: "POST",
        redirect: "error",
        headers,
        body: JSON.stringify({
          jsonrpc: "2.0",
          id,
          method,
          params,
        }),
      },
      timeoutMs,
      MAX_RPC_RESPONSE_BYTES,
      "fee-market RPC",
      { fetchImplementation },
    ));
  } catch {
    return rpcFailure("network-or-timeout");
  }
  if (response.status !== 200) {
    return rpcFailure(`http-${response.status}`);
  }

  let value;
  try {
    value = JSON.parse(
      new TextDecoder("utf-8", { fatal: true }).decode(bytes),
    );
  } catch {
    return rpcFailure("malformed-json");
  }
  if (
    !isPlainObject(value) ||
    value.jsonrpc !== "2.0" ||
    value.id !== id
  ) {
    return rpcFailure("malformed-response");
  }
  const hasResult = Object.hasOwn(value, "result");
  const hasError = Object.hasOwn(value, "error");
  if (hasResult === hasError) {
    return rpcFailure("malformed-response");
  }
  if (hasResult) {
    return rpcSuccess(value.result);
  }
  if (
    !isPlainObject(value.error) ||
    !Number.isSafeInteger(value.error.code) ||
    typeof value.error.message !== "string"
  ) {
    return rpcFailure("malformed-error");
  }
  return rpcFailure("rpc-error", {
    code: value.error.code,
    message: value.error.message,
  });
}

const FEE_MARKET_HINT_PERSISTENCE = Object.freeze({
  replace: "replace",
  preserve: "preserve",
});

function probeOutcome(report, persistence) {
  return { report, persistence };
}

function classifiedProbeOutcome(
  record,
  endpoint,
  checkedAt,
  probeResults,
  persistence,
) {
  return probeOutcome(
    {
      chainId: record.chainId,
      endpoint: endpoint.url,
      ...classifyFeeMarketProbe(record.chainId, probeResults),
      checkedAt,
    },
    persistence,
  );
}

async function probeCatalogRecordOutcome(
  record,
  {
    authorization,
    checkedAt,
    timeoutMs = DEFAULT_TIMEOUT_MS,
    fetchImplementation = fetch,
  },
) {
  const endpoint = endpointForRecord(record);
  if (endpoint.isAlchemy && authorization === undefined) {
    return probeOutcome(
      {
        chainId: record.chainId,
        endpoint: endpoint.url,
        support: "unknown",
        checkedAt,
        reason: "authorization-unavailable",
      },
      FEE_MARKET_HINT_PERSISTENCE.preserve,
    );
  }

  const chainId = await rpcCall(
    endpoint,
    "eth_chainId",
    [],
    1,
    { authorization, timeoutMs, fetchImplementation },
  );
  if (chainId.kind !== "success") {
    return classifiedProbeOutcome(
      record,
      endpoint,
      checkedAt,
      {
        chainId,
        latestBlock: rpcFailure("not-requested"),
        feeHistory: rpcFailure("not-requested"),
      },
      FEE_MARKET_HINT_PERSISTENCE.preserve,
    );
  }
  if (
    !isHexQuantity(chainId.result) ||
    BigInt(chainId.result) !== BigInt(record.chainId)
  ) {
    return classifiedProbeOutcome(
      record,
      endpoint,
      checkedAt,
      {
        chainId,
        latestBlock: rpcFailure("not-requested"),
        feeHistory: rpcFailure("not-requested"),
      },
      FEE_MARKET_HINT_PERSISTENCE.replace,
    );
  }

  const latestBlock = await rpcCall(
    endpoint,
    "eth_getBlockByNumber",
    ["latest", false],
    2,
    { authorization, timeoutMs, fetchImplementation },
  );
  if (latestBlock.kind !== "success") {
    return classifiedProbeOutcome(
      record,
      endpoint,
      checkedAt,
      {
        chainId,
        latestBlock,
        feeHistory: rpcFailure("not-requested"),
      },
      FEE_MARKET_HINT_PERSISTENCE.preserve,
    );
  }
  if (
    !isPlainObject(latestBlock.result) ||
    !isHexQuantity(latestBlock.result.number)
  ) {
    return classifiedProbeOutcome(
      record,
      endpoint,
      checkedAt,
      {
        chainId,
        latestBlock,
        feeHistory: rpcFailure("not-requested"),
      },
      FEE_MARKET_HINT_PERSISTENCE.replace,
    );
  }

  const hasMalformedBaseFee =
    Object.hasOwn(latestBlock.result, "baseFeePerGas") &&
    !isHexQuantity(latestBlock.result.baseFeePerGas);
  const feeHistory = await rpcCall(
    endpoint,
    "eth_feeHistory",
    ["0x1", latestBlock.result.number, []],
    3,
    { authorization, timeoutMs, fetchImplementation },
  );
  const persistence =
    feeHistory.kind === "failure" &&
    !isUnsupportedMethod(feeHistory) &&
    !hasMalformedBaseFee
      ? FEE_MARKET_HINT_PERSISTENCE.preserve
      : FEE_MARKET_HINT_PERSISTENCE.replace;
  return classifiedProbeOutcome(
    record,
    endpoint,
    checkedAt,
    {
      chainId,
      latestBlock,
      feeHistory,
    },
    persistence,
  );
}

export async function probeCatalogRecord(record, options) {
  const outcome = await probeCatalogRecordOutcome(record, options);
  return outcome.report;
}

async function acquireAlchemyAuthorization(
  options,
  {
    fetchImplementation,
    nowMilliseconds,
    proofKeyReader,
  },
) {
  if (options.appProofKeyFile === undefined) {
    return undefined;
  }
  const nowSeconds = Math.floor(nowMilliseconds / 1_000);
  const requestProofKey = await proofKeyReader(
    resolve(options.appProofKeyFile),
  );
  let signedRequest;
  try {
    signedRequest = createSignedBrokerRequest(requestProofKey, {
      timestamp: nowSeconds,
    });
  } finally {
    requestProofKey.fill(0);
  }

  const { response, bytes } = await fetchBoundedWithTimeout(
    DEFAULT_BROKER_URL,
    {
      method: "POST",
      redirect: "error",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        [REQUEST_PROOF_HEADER]: signedRequest.proof,
      },
      body: signedRequest.body,
    },
    options.timeoutMs,
    MAX_BROKER_RESPONSE_BYTES,
    "fee-market authorization",
    { fetchImplementation },
  );
  if (response.status !== 200) {
    throw fail("Alchemy authorization could not be acquired");
  }
  let value;
  try {
    value = JSON.parse(
      new TextDecoder("utf-8", { fatal: true }).decode(bytes),
    );
  } catch {
    throw fail("Alchemy authorization response is invalid");
  }
  return validateIssuancePayload(
    value,
    nowSeconds,
    options.expectedKid,
  );
}

async function mapWithConcurrency(values, concurrency, operation) {
  const results = new Array(values.length);
  let nextIndex = 0;
  async function worker() {
    while (true) {
      const index = nextIndex;
      nextIndex += 1;
      if (index >= values.length) {
        return;
      }
      results[index] = await operation(values[index]);
    }
  }
  await Promise.all(
    Array.from(
      { length: Math.min(concurrency, values.length) },
      () => worker(),
    ),
  );
  return results;
}

function checkedAtInstant(nowMilliseconds) {
  if (!Number.isFinite(nowMilliseconds) || nowMilliseconds < 0) {
    throw fail("Fee-market probe clock is invalid");
  }
  return new Date(nowMilliseconds)
    .toISOString()
    .replace(/\.\d{3}Z$/u, "Z");
}

function catalogStatsMatch(first, second) {
  return (
    first.dev === second.dev &&
    first.ino === second.ino &&
    first.mode === second.mode &&
    first.size === second.size &&
    first.mtimeMs === second.mtimeMs &&
    first.ctimeMs === second.ctimeMs
  );
}

async function assertCatalogUnchanged(
  path,
  mode,
  sourceBytes,
  sourceStats,
) {
  let currentHandle;
  try {
    currentHandle = await open(
      path,
      constants.O_RDONLY | (constants.O_NOFOLLOW ?? 0),
    );
    const currentStatsBeforeRead = await currentHandle.stat();
    if (
      !currentStatsBeforeRead.isFile() ||
      currentStatsBeforeRead.size < 0 ||
      currentStatsBeforeRead.size > MAX_CATALOG_BYTES
    ) {
      throw fail(
        "Network catalog changed while fee-market probe was running",
      );
    }
    const currentBytes = await currentHandle.readFile();
    const currentStatsAfterRead = await currentHandle.stat();
    await currentHandle.close();
    currentHandle = undefined;

    const destinationStats = await lstat(path);
    if (
      !destinationStats.isFile() ||
      destinationStats.isSymbolicLink() ||
      !catalogStatsMatch(
        currentStatsBeforeRead,
        currentStatsAfterRead,
      ) ||
      !catalogStatsMatch(currentStatsAfterRead, destinationStats) ||
      !catalogStatsMatch(sourceStats, currentStatsBeforeRead) ||
      (destinationStats.mode & 0o777) !== mode ||
      !(sourceBytes instanceof Uint8Array) ||
      currentBytes.byteLength !== currentStatsAfterRead.size ||
      currentBytes.byteLength !== sourceBytes.byteLength ||
      !currentBytes.equals(sourceBytes)
    ) {
      throw fail(
        "Network catalog changed while fee-market probe was running",
      );
    }
  } catch (error) {
    await currentHandle?.close().catch(() => undefined);
    if (error instanceof SafeFeeMarketProbeError) {
      throw error;
    }
    throw fail(
      "Network catalog changed while fee-market probe was running",
    );
  }
}

async function assertCandidateDestinationAvailable(
  sourcePath,
  outputPath,
) {
  const candidatePath = resolve(outputPath);
  if (resolve(sourcePath) === candidatePath) {
    throw fail("Catalog output must differ from the source catalog");
  }
  try {
    await lstat(candidatePath);
  } catch (error) {
    if (error?.code === "ENOENT") {
      return candidatePath;
    }
    throw fail(
      "Network catalog candidate path could not be checked safely",
    );
  }
  throw fail("Network catalog candidate output already exists");
}

async function writeCatalogCandidate(
  path,
  mode,
  records,
  sourceBytes,
  sourceStats,
  outputPath,
) {
  const sourcePath = resolve(path);
  const candidatePath = resolve(outputPath);
  if (sourcePath === candidatePath) {
    throw fail("Catalog output must differ from the source catalog");
  }

  const temporaryPath = resolve(
    dirname(candidatePath),
    `.${basename(candidatePath)}.fee-market-probe.` +
      `${process.pid}.${Date.now()}.tmp`,
  );
  let handle;
  let temporaryStats;
  let published = false;
  try {
    handle = await open(
      temporaryPath,
      constants.O_WRONLY |
        constants.O_CREAT |
        constants.O_EXCL |
        (constants.O_NOFOLLOW ?? 0),
      mode,
    );
    await handle.writeFile(
      `${JSON.stringify(records, null, 2)}\n`,
      "utf8",
    );
    await handle.chmod(mode);
    await handle.sync();
    temporaryStats = await handle.stat();
    await handle.close();
    handle = undefined;

    await assertCatalogUnchanged(
      sourcePath,
      mode,
      sourceBytes,
      sourceStats,
    );

    // Publishing with link is an atomic no-clobber operation: an existing
    // file or symlink at candidatePath makes the operation fail.
    await link(temporaryPath, candidatePath);
    published = true;
    await assertCatalogUnchanged(
      sourcePath,
      mode,
      sourceBytes,
      sourceStats,
    );
    const candidateStats = await lstat(candidatePath);
    if (
      !candidateStats.isFile() ||
      candidateStats.isSymbolicLink() ||
      candidateStats.dev !== temporaryStats.dev ||
      candidateStats.ino !== temporaryStats.ino
    ) {
      throw fail(
        "Network catalog candidate changed while it was published",
      );
    }
    await rm(temporaryPath);
  } catch (error) {
    let cleanupFailed = false;
    try {
      await handle?.close();
    } catch {
      cleanupFailed = true;
    }
    if (published) {
      try {
        const candidateStats = await lstat(candidatePath);
        if (
          temporaryStats === undefined ||
          !candidateStats.isFile() ||
          candidateStats.isSymbolicLink() ||
          candidateStats.dev !== temporaryStats.dev ||
          candidateStats.ino !== temporaryStats.ino
        ) {
          cleanupFailed = true;
        } else {
          await rm(candidatePath);
        }
      } catch (cleanupError) {
        if (cleanupError?.code !== "ENOENT") {
          cleanupFailed = true;
        }
      }
    }
    try {
      await rm(temporaryPath, { force: true });
    } catch {
      cleanupFailed = true;
    }
    if (cleanupFailed) {
      throw fail("Network catalog candidate cleanup failed");
    }
    if (error instanceof SafeFeeMarketProbeError) {
      throw error;
    }
    throw fail("Network catalog candidate could not be written safely");
  }
}

export async function executeFeeMarketProbe(
  options,
  {
    fetchImplementation = fetch,
    nowImplementation = Date.now,
    proofKeyReader = readAppProofKey,
    catalogReader = readProbeCatalog,
    catalogWriter = writeCatalogCandidate,
  } = {},
) {
  const catalog = await catalogReader(options.catalogPath);
  if (options.outputPath !== undefined) {
    await assertCandidateDestinationAvailable(
      catalog.path,
      options.outputPath,
    );
  }
  const hasAlchemyRecords = catalog.records.some(
    (record) => endpointForRecord(record).isAlchemy,
  );
  if (
    options.outputPath !== undefined &&
    hasAlchemyRecords &&
    options.appProofKeyFile === undefined
  ) {
    throw fail(
      "--output requires Alchemy authorization for this catalog",
    );
  }

  const nowMilliseconds = nowImplementation();
  const checkedAt = checkedAtInstant(nowMilliseconds);
  let authorization = await acquireAlchemyAuthorization(options, {
    fetchImplementation,
    nowMilliseconds,
    proofKeyReader,
  });
  let outcomes;
  try {
    outcomes = await mapWithConcurrency(
      catalog.records,
      options.concurrency,
      (record) => probeCatalogRecordOutcome(record, {
        authorization,
        checkedAt,
        timeoutMs: options.timeoutMs,
        fetchImplementation,
      }),
    );
  } finally {
    authorization = undefined;
  }
  const results = outcomes.map((outcome) => outcome.report);

  if (options.outputPath !== undefined) {
    const outcomeByChainId = new Map(
      outcomes.map((outcome) => [outcome.report.chainId, outcome]),
    );
    let shouldWrite = false;
    const updatedRecords = catalog.records.map((record) => {
      const outcome = outcomeByChainId.get(record.chainId);
      if (outcome === undefined) {
        throw fail("Fee-market probe result is incomplete");
      }
      if (
        outcome.persistence === FEE_MARKET_HINT_PERSISTENCE.preserve
      ) {
        return record;
      }
      shouldWrite = true;
      return {
        ...record,
        feeMarketHint: {
          support: outcome.report.support,
          checkedAt: outcome.report.checkedAt,
          observedEndpoint: outcome.report.endpoint,
        },
      };
    });
    if (shouldWrite) {
      await catalogWriter(
        catalog.path,
        catalog.mode,
        updatedRecords,
        catalog.sourceBytes,
        catalog.sourceStats,
        options.outputPath,
      );
    }
  }
  return results;
}

export async function probeFeeMarketsMain(
  arguments_,
  {
    stdout = (message) => process.stdout.write(message),
    stderr = (message) => process.stderr.write(message),
    executor = executeFeeMarketProbe,
  } = {},
) {
  try {
    const options = parseProbeArguments(arguments_);
    if (options.help) {
      stdout(`${usage()}\n`);
      return 0;
    }
    const results = await executor(options);
    stdout(`${JSON.stringify(results, null, 2)}\n`);
    return 0;
  } catch (error) {
    const message = error instanceof SafeFeeMarketProbeError
      ? error.message
      : "Fee-market probe failed";
    stderr(`fee-market probe: ${message}\n`);
    return 1;
  }
}

if (
  process.argv[1] !== undefined &&
  pathToFileURL(resolve(process.argv[1])).href === import.meta.url
) {
  process.exitCode = await probeFeeMarketsMain(process.argv.slice(2));
}
