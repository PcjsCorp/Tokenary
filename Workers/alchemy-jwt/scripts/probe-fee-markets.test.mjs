import assert from "node:assert/strict";
import {
  chmod,
  mkdtemp,
  readdir,
  readFile,
  rename,
  rm,
  stat,
  symlink,
  writeFile,
} from "node:fs/promises";
import {
  tmpdir,
} from "node:os";
import {
  join,
  resolve,
} from "node:path";
import {
  fileURLToPath,
} from "node:url";
import {
  test,
} from "node:test";

import {
  SafeFeeMarketProbeError,
  classifyFeeMarketProbe,
  endpointForRecord,
  executeFeeMarketProbe,
  parseProbeArguments,
  probeCatalogRecord,
  probeFeeMarketsMain,
  readProbeCatalog,
} from "./probe-fee-markets.mjs";

const CHECKED_AT = "2026-07-23T00:00:00Z";
const PREVIOUS_CHECKED_AT = "2026-01-01T00:00:00Z";
const success = (result) => ({ kind: "success", result });
const failure = (reason, error) => ({ kind: "failure", reason, error });

function jsonRpcResponse(id, value) {
  return new Response(
    JSON.stringify({
      jsonrpc: "2.0",
      id,
      ...value,
    }),
    {
      status: 200,
      headers: { "Content-Type": "application/json" },
    },
  );
}

function successfulRPCFetch({
  expectedURL,
  expectedAuthorization,
  baseFeePerGas = "0x0",
}) {
  const expectedMethods = [
    "eth_chainId",
    "eth_getBlockByNumber",
    "eth_feeHistory",
  ];
  let methodIndex = 0;
  return async (url, init) => {
    assert.equal(url, expectedURL);
    if (expectedAuthorization === undefined) {
      assert.equal(init.headers.Authorization, undefined);
    } else {
      assert.equal(
        init.headers.Authorization,
        `Bearer ${expectedAuthorization}`,
      );
    }
    const request = JSON.parse(init.body);
    assert.equal(
      request.method,
      expectedMethods[methodIndex % expectedMethods.length],
    );
    methodIndex += 1;
    if (request.method === "eth_chainId") {
      return jsonRpcResponse(request.id, { result: "0x64" });
    }
    if (request.method === "eth_getBlockByNumber") {
      return jsonRpcResponse(request.id, {
        result: { number: "0x123", baseFeePerGas },
      });
    }
    assert.equal(request.method, "eth_feeHistory");
    assert.deepEqual(request.params, ["0x1", "0x123", []]);
    return jsonRpcResponse(request.id, {
      result: { baseFeePerGas: [baseFeePerGas, baseFeePerGas] },
    });
  };
}

function probeRecord({
  chainId = 100,
  fallbackRPCURL = "https://rpc.gnosis.example",
  support = "eip1559",
  checkedAt = PREVIOUS_CHECKED_AT,
  observedEndpoint = fallbackRPCURL,
} = {}) {
  return {
    chainId,
    fallbackRPCURL,
    feeMarketHint: {
      support,
      checkedAt,
      observedEndpoint,
    },
  };
}

function probeOptions(catalogPath, writesCandidate) {
  return {
    catalogPath,
    appProofKeyFile: undefined,
    expectedKid: undefined,
    concurrency: 2,
    timeoutMs: 1_000,
    outputPath: writesCandidate
      ? `${catalogPath}.candidate`
      : undefined,
  };
}

function catalogFixture(records) {
  return {
    path: "/fixture/NetworkCatalog.json",
    mode: 0o644,
    records,
    sourceBytes: new Uint8Array(),
  };
}

function rpcSequenceFetch({
  chainId = "0x64",
  latestBlock = { number: "0x123", baseFeePerGas: "0x1" },
  feeHistory = { result: { baseFeePerGas: ["0x1", "0x2"] } },
  failureMethod,
  failureResponse,
}) {
  return async (_url, init) => {
    const request = JSON.parse(init.body);
    if (
      request.method === failureMethod &&
      failureResponse !== undefined
    ) {
      return failureResponse(request, init);
    }
    if (request.method === "eth_chainId") {
      return jsonRpcResponse(request.id, { result: chainId });
    }
    if (request.method === "eth_getBlockByNumber") {
      return jsonRpcResponse(request.id, { result: latestBlock });
    }
    assert.equal(request.method, "eth_feeHistory");
    return jsonRpcResponse(request.id, feeHistory);
  };
}

test("classification requires agreeing block and fee-history signals", () => {
  assert.deepEqual(
    classifyFeeMarketProbe(100, {
      chainId: success("0x64"),
      latestBlock: success({ number: "0x1", baseFeePerGas: "0x0" }),
      feeHistory: success({ baseFeePerGas: ["0x0", "0x1"] }),
    }),
    { support: "eip1559", reason: "base-fee-and-history" },
  );
  assert.deepEqual(
    classifyFeeMarketProbe(100, {
      chainId: success("0x64"),
      latestBlock: success({ number: "0x1" }),
      feeHistory: failure("rpc-error", {
        code: -32_601,
        message: "Method not found",
      }),
    }),
    { support: "legacy", reason: "no-base-fee-and-no-history" },
  );
  assert.deepEqual(
    classifyFeeMarketProbe(100, {
      chainId: success("0x64"),
      latestBlock: success({ number: "0x1", baseFeePerGas: "0x0" }),
      feeHistory: failure("rpc-error", {
        code: -32_601,
        message: "Method not found",
      }),
    }),
    {
      support: "eip1559",
      reason: "base-fee-and-history-unsupported",
    },
  );
  assert.deepEqual(
    classifyFeeMarketProbe(100, {
      chainId: success("0x64"),
      latestBlock: success({ number: "0x1", baseFeePerGas: "0x00" }),
      feeHistory: success({ baseFeePerGas: ["0x0", "0x1"] }),
    }),
    { support: "eip1559", reason: "base-fee-and-history" },
  );
  assert.deepEqual(
    classifyFeeMarketProbe(100, {
      chainId: success("0X64"),
      latestBlock: success({ number: "0x01", baseFeePerGas: "0x1" }),
      feeHistory: success({ baseFeePerGas: ["0x1", "0x2"] }),
    }),
    { support: "eip1559", reason: "base-fee-and-history" },
  );

  const unknownFixtures = [
    {
      chainId: success("0x65"),
      latestBlock: success({ number: "0x1", baseFeePerGas: "0x1" }),
      feeHistory: success({ baseFeePerGas: ["0x1", "0x1"] }),
    },
    {
      chainId: success("0x64"),
      latestBlock: success({ number: "0x1", baseFeePerGas: "0xzz" }),
      feeHistory: success({ baseFeePerGas: ["0x0", "0x1"] }),
    },
    {
      chainId: success("0x64"),
      latestBlock: success({ number: "0x1", baseFeePerGas: null }),
      feeHistory: failure("rpc-error", {
        code: -32_601,
        message: "Method not found",
      }),
    },
    {
      chainId: success("0x64"),
      latestBlock: success({ number: "0x1" }),
      feeHistory: success({ baseFeePerGas: ["0x0", "0x1"] }),
    },
    {
      chainId: success("0x64"),
      latestBlock: success({ number: "0x1", baseFeePerGas: "0x1" }),
      feeHistory: failure("network-or-timeout"),
    },
    {
      chainId: success("0x64"),
      latestBlock: success({ number: "0x1", baseFeePerGas: "0x1" }),
      feeHistory: success({ baseFeePerGas: ["0x2", "0x3"] }),
    },
    {
      chainId: success("0x64"),
      latestBlock: success({ number: "0x1", baseFeePerGas: "0x1" }),
      feeHistory: success({
        baseFeePerGas: ["0x1", "0x2", "0x3"],
      }),
    },
    {
      chainId: success("0x64"),
      latestBlock: success({ baseFeePerGas: "0x1" }),
      feeHistory: success({ baseFeePerGas: ["0x1", "0x2"] }),
    },
    {
      chainId: success("0x64"),
      latestBlock: success({
        number: "0xzz",
        baseFeePerGas: "0x1",
      }),
      feeHistory: success({ baseFeePerGas: ["0x1", "0x2"] }),
    },
    {
      chainId: success("0x64"),
      latestBlock: success({
        number: `0x${"f".repeat(65)}`,
        baseFeePerGas: "0x1",
      }),
      feeHistory: success({ baseFeePerGas: ["0x1", "0x2"] }),
    },
    {
      chainId: success(`0x${"0".repeat(257)}`),
      latestBlock: success({ number: "0x1", baseFeePerGas: "0x1" }),
      feeHistory: success({ baseFeePerGas: ["0x1", "0x2"] }),
    },
  ];
  for (const fixture of unknownFixtures) {
    assert.equal(
      classifyFeeMarketProbe(100, fixture).support,
      "unknown",
    );
  }
});

test("probe never requests unanchored fee history", async () => {
  const methods = [];
  const result = await probeCatalogRecord(
    {
      chainId: 100,
      fallbackRPCURL: "https://rpc.gnosis.example",
    },
    {
      checkedAt: CHECKED_AT,
      fetchImplementation: async (_url, init) => {
        const request = JSON.parse(init.body);
        methods.push(request.method);
        if (request.method === "eth_chainId") {
          return jsonRpcResponse(request.id, { result: "0x64" });
        }
        if (request.method === "eth_getBlockByNumber") {
          return jsonRpcResponse(request.id, {
            result: { baseFeePerGas: "0x1" },
          });
        }
        assert.fail("eth_feeHistory must not be requested without a block number");
      },
    },
  );

  assert.equal(result.support, "unknown");
  assert.equal(result.reason, "latest-block-number-malformed");
  assert.deepEqual(methods, ["eth_chainId", "eth_getBlockByNumber"]);
});

test("probe authorizes only canonical Alchemy endpoints", async () => {
  const fallbackURL = "https://rpc.gnosis.example";
  const fallback = await probeCatalogRecord(
    {
      chainId: 100,
      fallbackRPCURL: fallbackURL,
    },
    {
      authorization: "must-not-leak",
      checkedAt: CHECKED_AT,
      fetchImplementation: successfulRPCFetch({
        expectedURL: fallbackURL,
        expectedAuthorization: undefined,
      }),
    },
  );
  assert.equal(fallback.support, "eip1559");

  const alchemyURL = "https://gnosis-mainnet.g.alchemy.com/v2";
  const alchemy = await probeCatalogRecord(
    {
      chainId: 100,
      alchemyNetwork: "gnosis-mainnet",
    },
    {
      authorization: "in-memory-token",
      checkedAt: CHECKED_AT,
      fetchImplementation: successfulRPCFetch({
        expectedURL: alchemyURL,
        expectedAuthorization: "in-memory-token",
      }),
    },
  );
  assert.equal(alchemy.support, "eip1559");
  assert.equal(alchemy.endpoint, alchemyURL);

  let unauthenticatedAlchemyCalls = 0;
  const unavailable = await probeCatalogRecord(
    {
      chainId: 100,
      alchemyNetwork: "gnosis-mainnet",
    },
    {
      authorization: undefined,
      checkedAt: CHECKED_AT,
      fetchImplementation: async () => {
        unauthenticatedAlchemyCalls += 1;
        throw new Error("must not be called");
      },
    },
  );
  assert.equal(unavailable.support, "unknown");
  assert.equal(unavailable.reason, "authorization-unavailable");
  assert.deepEqual(
    Object.keys(unavailable).sort(),
    ["chainId", "checkedAt", "endpoint", "reason", "support"],
  );
  assert.equal(unauthenticatedAlchemyCalls, 0);
});

test("catalog candidates are explicit and use complete probe results", async () => {
  const record = {
    chainId: 100,
    fallbackRPCURL: "https://rpc.gnosis.example",
    feeMarketHint: {
      support: "unknown",
      checkedAt: CHECKED_AT,
      observedEndpoint: "https://rpc.gnosis.example",
    },
  };
  const catalog = {
    path: "/fixture/NetworkCatalog.json",
    mode: 0o644,
    records: [record],
  };
  const common = {
    catalogPath: catalog.path,
    appProofKeyFile: undefined,
    expectedKid: undefined,
    concurrency: 1,
    timeoutMs: 1_000,
  };
  let writes = 0;
  const dependencies = {
    nowImplementation: () => Date.parse(CHECKED_AT),
    catalogReader: async () => catalog,
    catalogWriter: async () => {
      writes += 1;
    },
    fetchImplementation: successfulRPCFetch({
      expectedURL: record.fallbackRPCURL,
      expectedAuthorization: undefined,
    }),
  };

  const report = await executeFeeMarketProbe(
    { ...common, outputPath: undefined },
    dependencies,
  );
  assert.equal(report[0].support, "eip1559");
  assert.equal(writes, 0);

  let writtenRecords;
  await executeFeeMarketProbe(
    { ...common, outputPath: `${catalog.path}.candidate` },
    {
      ...dependencies,
      catalogWriter: async (path, mode, records) => {
        assert.equal(path, catalog.path);
        assert.equal(mode, catalog.mode);
        writtenRecords = records;
      },
    },
  );
  assert.deepEqual(writtenRecords[0].feeMarketHint, {
    support: "eip1559",
    checkedAt: CHECKED_AT,
    observedEndpoint: record.fallbackRPCURL,
  });
});

test("candidate preserves hints when chain identity evidence is unavailable", async () => {
  const record = probeRecord();
  const catalog = catalogFixture([record]);
  const previousHint = structuredClone(record.feeMarketHint);
  const failures = [
    {
      name: "network",
      response: async () => {
        throw new Error("network unavailable");
      },
    },
    {
      name: "timeout",
      timeoutMs: 1,
      response: async (_request, init) => new Promise(
        (_resolve, reject) => {
          const rejectForAbort = () => reject(
            new DOMException("request timed out", "AbortError"),
          );
          if (init.signal.aborted) {
            rejectForAbort();
          } else {
            init.signal.addEventListener("abort", rejectForAbort, {
              once: true,
            });
          }
        },
      ),
    },
    ...[401, 403, 408, 425, 429, 500, 599].map((status) => ({
      name: `http-${status}`,
      response: async () => new Response(null, { status }),
    })),
    {
      name: "malformed-json",
      response: async () => new Response("{", { status: 200 }),
    },
    {
      name: "malformed-response",
      response: async (request) => jsonRpcResponse(
        request.id + 1,
        { result: "0x64" },
      ),
    },
    {
      name: "rpc-error",
      response: async (request) => jsonRpcResponse(request.id, {
        error: {
          code: -32_000,
          message: "temporarily unavailable",
        },
      }),
    },
  ];

  for (const fixture of failures) {
    let writes = 0;
    const options = {
      ...probeOptions(catalog.path, true),
      timeoutMs: fixture.timeoutMs ?? 1_000,
    };
    const reports = await executeFeeMarketProbe(options, {
      nowImplementation: () => Date.parse(CHECKED_AT),
      catalogReader: async () => catalog,
      catalogWriter: async () => {
        writes += 1;
      },
      fetchImplementation: rpcSequenceFetch({
        failureMethod: "eth_chainId",
        failureResponse: fixture.response,
      }),
    });

    assert.equal(reports.length, 1, fixture.name);
    assert.deepEqual(
      Object.keys(reports[0]).sort(),
      ["chainId", "checkedAt", "endpoint", "reason", "support"],
      fixture.name,
    );
    assert.equal(reports[0].support, "unknown", fixture.name);
    assert.equal(
      reports[0].reason,
      "chain-id-unavailable",
      fixture.name,
    );
    assert.equal(reports[0].checkedAt, CHECKED_AT, fixture.name);
    assert.equal(writes, 0, fixture.name);
    assert.deepEqual(record.feeMarketHint, previousHint, fixture.name);
  }
});

test("candidate preserves hints when later RPC evidence is unavailable", async () => {
  const fixtures = [
    {
      name: "latest-block-http",
      failureMethod: "eth_getBlockByNumber",
      failureResponse: async () => new Response(null, { status: 429 }),
      reason: "latest-block-unavailable",
    },
    {
      name: "fee-history-http",
      failureMethod: "eth_feeHistory",
      failureResponse: async () => new Response(null, { status: 503 }),
      reason: "contradictory-or-incomplete",
    },
    {
      name: "fee-history-rpc-error",
      failureMethod: "eth_feeHistory",
      failureResponse: async (request) => jsonRpcResponse(request.id, {
        error: {
          code: -32_000,
          message: "temporarily unavailable",
        },
      }),
      reason: "contradictory-or-incomplete",
    },
  ];

  for (const fixture of fixtures) {
    const record = probeRecord();
    const catalog = catalogFixture([record]);
    const previousHint = structuredClone(record.feeMarketHint);
    let writes = 0;
    const reports = await executeFeeMarketProbe(
      probeOptions(catalog.path, true),
      {
        nowImplementation: () => Date.parse(CHECKED_AT),
        catalogReader: async () => catalog,
        catalogWriter: async () => {
          writes += 1;
        },
        fetchImplementation: rpcSequenceFetch(fixture),
      },
    );

    assert.equal(reports[0].support, "unknown", fixture.name);
    assert.equal(reports[0].reason, fixture.reason, fixture.name);
    assert.equal(writes, 0, fixture.name);
    assert.deepEqual(record.feeMarketHint, previousHint, fixture.name);
  }
});

test("candidate replaces hints after conclusive unknown observations", async () => {
  const fixtures = [
    {
      name: "chain-id-mismatch",
      fetchImplementation: rpcSequenceFetch({ chainId: "0x65" }),
      reason: "chain-id-mismatch",
    },
    {
      name: "malformed-block-number",
      fetchImplementation: rpcSequenceFetch({
        latestBlock: {
          number: "0xzz",
          baseFeePerGas: "0x1",
        },
      }),
      reason: "latest-block-number-malformed",
    },
    {
      name: "malformed-base-fee",
      fetchImplementation: rpcSequenceFetch({
        latestBlock: {
          number: "0x123",
          baseFeePerGas: "0xzz",
        },
      }),
      reason: "base-fee-malformed",
    },
    {
      name: "contradictory-base-fee",
      fetchImplementation: rpcSequenceFetch({
        feeHistory: {
          result: { baseFeePerGas: ["0x2", "0x3"] },
        },
      }),
      reason: "contradictory-base-fee",
    },
    {
      name: "malformed-fee-history",
      fetchImplementation: rpcSequenceFetch({
        feeHistory: {
          result: { baseFeePerGas: ["0x1"] },
        },
      }),
      reason: "contradictory-or-incomplete",
    },
  ];

  for (const fixture of fixtures) {
    const record = probeRecord();
    const catalog = catalogFixture([record]);
    let writes = 0;
    let writtenRecords;
    const reports = await executeFeeMarketProbe(
      probeOptions(catalog.path, true),
      {
        nowImplementation: () => Date.parse(CHECKED_AT),
        catalogReader: async () => catalog,
        catalogWriter: async (_path, _mode, records) => {
          writes += 1;
          writtenRecords = records;
        },
        fetchImplementation: fixture.fetchImplementation,
      },
    );

    assert.equal(reports[0].support, "unknown", fixture.name);
    assert.equal(reports[0].reason, fixture.reason, fixture.name);
    assert.equal(writes, 1, fixture.name);
    assert.deepEqual(writtenRecords[0].feeMarketHint, {
      support: "unknown",
      checkedAt: CHECKED_AT,
      observedEndpoint: record.fallbackRPCURL,
    }, fixture.name);
  }
});

test("fee-history method-not-found remains conclusive", async () => {
  const fixtures = [
    {
      name: "legacy",
      latestBlock: { number: "0x123" },
      support: "legacy",
    },
    {
      name: "eip1559",
      latestBlock: {
        number: "0x123",
        baseFeePerGas: "0x1",
      },
      support: "eip1559",
    },
  ];

  for (const fixture of fixtures) {
    const record = probeRecord({ support: "unknown" });
    const catalog = catalogFixture([record]);
    let writtenRecords;
    const reports = await executeFeeMarketProbe(
      probeOptions(catalog.path, true),
      {
        nowImplementation: () => Date.parse(CHECKED_AT),
        catalogReader: async () => catalog,
        catalogWriter: async (_path, _mode, records) => {
          writtenRecords = records;
        },
        fetchImplementation: rpcSequenceFetch({
          latestBlock: fixture.latestBlock,
          failureMethod: "eth_feeHistory",
          failureResponse: async (request) => jsonRpcResponse(
            request.id,
            {
              error: {
                code: -32_601,
                message: "Method not found",
              },
            },
          ),
        }),
      },
    );

    assert.equal(reports[0].support, fixture.support, fixture.name);
    assert.equal(
      writtenRecords[0].feeMarketHint.support,
      fixture.support,
      fixture.name,
    );
    assert.equal(
      writtenRecords[0].feeMarketHint.checkedAt,
      CHECKED_AT,
      fixture.name,
    );
  }
});

test("mixed candidates update conclusive records and preserve failures", async () => {
  const successfulURL = "https://rpc.gnosis.example";
  const unavailableURL = "https://rpc.unavailable.example";
  const successfulRecord = probeRecord({
    fallbackRPCURL: successfulURL,
    support: "unknown",
  });
  const unavailableRecord = probeRecord({
    chainId: 101,
    fallbackRPCURL: unavailableURL,
    support: "legacy",
  });
  const previousUnavailableHint = structuredClone(
    unavailableRecord.feeMarketHint,
  );
  const catalog = catalogFixture([
    successfulRecord,
    unavailableRecord,
  ]);
  let writes = 0;
  let writtenRecords;
  const reports = await executeFeeMarketProbe(
    probeOptions(catalog.path, true),
    {
      nowImplementation: () => Date.parse(CHECKED_AT),
      catalogReader: async () => catalog,
      catalogWriter: async (_path, _mode, records) => {
        writes += 1;
        writtenRecords = records;
      },
      fetchImplementation: async (url, init) => {
        if (url === unavailableURL) {
          return new Response(null, { status: 503 });
        }
        assert.equal(url, successfulURL);
        const request = JSON.parse(init.body);
        if (request.method === "eth_chainId") {
          return jsonRpcResponse(request.id, { result: "0x64" });
        }
        if (request.method === "eth_getBlockByNumber") {
          return jsonRpcResponse(request.id, {
            result: {
              number: "0x123",
              baseFeePerGas: "0x1",
            },
          });
        }
        assert.equal(request.method, "eth_feeHistory");
        return jsonRpcResponse(request.id, {
          result: { baseFeePerGas: ["0x1", "0x2"] },
        });
      },
    },
  );

  assert.equal(writes, 1);
  assert.equal(reports[0].support, "eip1559");
  assert.equal(reports[1].support, "unknown");
  assert.equal(reports[1].checkedAt, CHECKED_AT);
  assert.deepEqual(writtenRecords[0].feeMarketHint, {
    support: "eip1559",
    checkedAt: CHECKED_AT,
    observedEndpoint: successfulURL,
  });
  assert.deepEqual(
    writtenRecords[1].feeMarketHint,
    previousUnavailableHint,
  );
});

test("CLI JSON contains only public probe reports", async () => {
  const report = {
    chainId: 100,
    endpoint: "https://rpc.gnosis.example",
    support: "unknown",
    reason: "chain-id-unavailable",
    checkedAt: CHECKED_AT,
  };
  let stdout = "";
  let stderr = "";
  const exitCode = await probeFeeMarketsMain([], {
    executor: async () => [report],
    stdout: (message) => {
      stdout += message;
    },
    stderr: (message) => {
      stderr += message;
    },
  });

  assert.equal(exitCode, 0);
  assert.equal(stderr, "");
  assert.equal(stdout, `${JSON.stringify([report], null, 2)}\n`);
});

test("candidate repairs a mismatched observed endpoint without changing the source", async (context) => {
  const directory = await mkdtemp(
    join(tmpdir(), "fee-market-probe-mismatch-"),
  );
  context.after(async () => {
    await rm(directory, { recursive: true, force: true });
  });
  const catalogPath = join(directory, "NetworkCatalog.json");
  const candidatePath = join(directory, "NetworkCatalog.candidate.json");
  const record = {
    chainId: 100,
    fallbackRPCURL: "https://rpc.gnosis.example",
    feeMarketHint: {
      support: "unknown",
      checkedAt: CHECKED_AT,
      observedEndpoint: "https://previous-rpc.gnosis.example",
    },
  };
  await writeFile(
    catalogPath,
    `${JSON.stringify([{
      ...record,
      feeMarketHint: {
        ...record.feeMarketHint,
        observedEndpoint: "",
      },
    }], null, 2)}\n`,
    "utf8",
  );
  await assert.rejects(
    readProbeCatalog(catalogPath),
    SafeFeeMarketProbeError,
  );
  await writeFile(
    catalogPath,
    `${JSON.stringify([record], null, 2)}\n`,
    "utf8",
  );
  const originalText = await readFile(catalogPath, "utf8");

  const catalog = await readProbeCatalog(catalogPath);
  assert.equal(catalog.records.length, 1);
  assert.ok(catalog.sourceBytes instanceof Uint8Array);

  await executeFeeMarketProbe(
    {
      catalogPath,
      appProofKeyFile: undefined,
      expectedKid: undefined,
      concurrency: 1,
      timeoutMs: 1_000,
      outputPath: candidatePath,
    },
    {
      nowImplementation: () => Date.parse(CHECKED_AT),
      fetchImplementation: successfulRPCFetch({
        expectedURL: record.fallbackRPCURL,
        expectedAuthorization: undefined,
      }),
    },
  );

  assert.equal(await readFile(catalogPath, "utf8"), originalText);
  const updated = JSON.parse(await readFile(candidatePath, "utf8"));
  assert.deepEqual(updated[0].feeMarketHint, {
    support: "eip1559",
    checkedAt: CHECKED_AT,
    observedEndpoint: record.fallbackRPCURL,
  });
});

test("candidate creation preserves a catalog changed during probing", async (context) => {
  const directory = await mkdtemp(
    join(tmpdir(), "fee-market-probe-concurrent-"),
  );
  context.after(async () => {
    await rm(directory, { recursive: true, force: true });
  });
  const catalogPath = join(directory, "NetworkCatalog.json");
  const candidatePath = join(directory, "NetworkCatalog.candidate.json");
  const record = {
    chainId: 100,
    fallbackRPCURL: "https://rpc.gnosis.example",
    feeMarketHint: {
      support: "unknown",
      checkedAt: CHECKED_AT,
      observedEndpoint: "https://rpc.gnosis.example",
    },
  };
  const originalText = `${JSON.stringify([record], null, 2)}\n`;
  const concurrentlyEditedText = `${JSON.stringify([{
    ...record,
    concurrentMarker: true,
  }], null, 2)}\n`;
  await writeFile(catalogPath, originalText, "utf8");

  const successfulFetch = successfulRPCFetch({
    expectedURL: record.fallbackRPCURL,
    expectedAuthorization: undefined,
  });
  let didEdit = false;
  const fetchImplementation = async (url, init) => {
    if (!didEdit) {
      didEdit = true;
      await writeFile(catalogPath, concurrentlyEditedText, "utf8");
    }
    return successfulFetch(url, init);
  };

  await assert.rejects(
    executeFeeMarketProbe(
      {
        catalogPath,
        appProofKeyFile: undefined,
        expectedKid: undefined,
        concurrency: 1,
        timeoutMs: 1_000,
        outputPath: candidatePath,
      },
      {
        nowImplementation: () => Date.parse(CHECKED_AT),
        fetchImplementation,
      },
    ),
    (error) => {
      assert.ok(error instanceof SafeFeeMarketProbeError);
      assert.equal(
        error.message,
        "Network catalog changed while fee-market probe was running",
      );
      return true;
    },
  );
  assert.equal(
    await readFile(catalogPath, "utf8"),
    concurrentlyEditedText,
  );
  assert.deepEqual(
    await readdir(directory),
    ["NetworkCatalog.json"],
  );
});

test("candidate rejects a same-byte source replacement during probing", async (context) => {
  const directory = await mkdtemp(
    join(tmpdir(), "fee-market-probe-replaced-source-"),
  );
  context.after(async () => {
    await rm(directory, { recursive: true, force: true });
  });
  const catalogPath = join(directory, "NetworkCatalog.json");
  const candidatePath = join(directory, "NetworkCatalog.candidate.json");
  const replacementPath = join(directory, "replacement.json");
  const sourceText = `${JSON.stringify([probeRecord()], null, 2)}\n`;
  await writeFile(catalogPath, sourceText, "utf8");

  const successfulFetch = successfulRPCFetch({
    expectedURL: "https://rpc.gnosis.example",
    expectedAuthorization: undefined,
  });
  let didReplace = false;
  const fetchImplementation = async (url, init) => {
    if (!didReplace) {
      didReplace = true;
      await writeFile(replacementPath, sourceText, "utf8");
      await rename(replacementPath, catalogPath);
    }
    return successfulFetch(url, init);
  };

  await assert.rejects(
    executeFeeMarketProbe(
      {
        ...probeOptions(catalogPath, false),
        outputPath: candidatePath,
        concurrency: 1,
      },
      {
        nowImplementation: () => Date.parse(CHECKED_AT),
        fetchImplementation,
      },
    ),
    (error) => {
      assert.ok(error instanceof SafeFeeMarketProbeError);
      assert.equal(
        error.message,
        "Network catalog changed while fee-market probe was running",
      );
      return true;
    },
  );

  assert.equal(await readFile(catalogPath, "utf8"), sourceText);
  assert.deepEqual(await readdir(directory), ["NetworkCatalog.json"]);
});

test("candidate preserves the catalog permission mode", async (context) => {
  const directory = await mkdtemp(
    join(tmpdir(), "fee-market-probe-mode-"),
  );
  context.after(async () => {
    await rm(directory, { recursive: true, force: true });
  });
  const catalogPath = join(directory, "NetworkCatalog.json");
  const candidatePath = join(directory, "NetworkCatalog.candidate.json");
  const record = {
    chainId: 100,
    fallbackRPCURL: "https://rpc.gnosis.example",
    feeMarketHint: {
      support: "unknown",
      checkedAt: CHECKED_AT,
      observedEndpoint: "https://rpc.gnosis.example",
    },
  };
  await writeFile(
    catalogPath,
    `${JSON.stringify([record], null, 2)}\n`,
    "utf8",
  );
  await chmod(catalogPath, 0o664);

  await executeFeeMarketProbe(
    {
      catalogPath,
      appProofKeyFile: undefined,
      expectedKid: undefined,
      concurrency: 1,
      timeoutMs: 1_000,
      outputPath: candidatePath,
    },
    {
      nowImplementation: () => Date.parse(CHECKED_AT),
      fetchImplementation: successfulRPCFetch({
        expectedURL: record.fallbackRPCURL,
        expectedAuthorization: undefined,
      }),
    },
  );

  assert.equal((await stat(catalogPath)).mode & 0o777, 0o664);
  assert.equal((await stat(candidatePath)).mode & 0o777, 0o664);
});

test("candidate creation refuses an existing output and removes its temporary file", async (context) => {
  const directory = await mkdtemp(
    join(tmpdir(), "fee-market-probe-existing-output-"),
  );
  context.after(async () => {
    await rm(directory, { recursive: true, force: true });
  });
  const catalogPath = join(directory, "NetworkCatalog.json");
  const candidatePath = `${catalogPath}.candidate`;
  const sourceText = `${JSON.stringify([probeRecord()], null, 2)}\n`;
  const existingText = "keep this candidate\n";
  await writeFile(catalogPath, sourceText, "utf8");
  await writeFile(candidatePath, existingText, "utf8");

  await assert.rejects(
    executeFeeMarketProbe(
      {
        ...probeOptions(catalogPath, true),
        concurrency: 1,
      },
      {
        nowImplementation: () => Date.parse(CHECKED_AT),
        fetchImplementation: successfulRPCFetch({
          expectedURL: "https://rpc.gnosis.example",
          expectedAuthorization: undefined,
        }),
      },
    ),
    SafeFeeMarketProbeError,
  );

  assert.equal(await readFile(catalogPath, "utf8"), sourceText);
  assert.equal(await readFile(candidatePath, "utf8"), existingText);
  assert.deepEqual(
    (await readdir(directory)).sort(),
    ["NetworkCatalog.json", "NetworkCatalog.json.candidate"],
  );
});

test("candidate creation refuses a symlink output without changing its target", async (context) => {
  const directory = await mkdtemp(
    join(tmpdir(), "fee-market-probe-symlink-output-"),
  );
  context.after(async () => {
    await rm(directory, { recursive: true, force: true });
  });
  const catalogPath = join(directory, "NetworkCatalog.json");
  const candidatePath = `${catalogPath}.candidate`;
  const targetPath = join(directory, "protected.json");
  const sourceText = `${JSON.stringify([probeRecord()], null, 2)}\n`;
  const targetText = "protected\n";
  await writeFile(catalogPath, sourceText, "utf8");
  await writeFile(targetPath, targetText, "utf8");
  await symlink(targetPath, candidatePath);

  await assert.rejects(
    executeFeeMarketProbe(
      {
        ...probeOptions(catalogPath, true),
        concurrency: 1,
      },
      {
        nowImplementation: () => Date.parse(CHECKED_AT),
        fetchImplementation: successfulRPCFetch({
          expectedURL: "https://rpc.gnosis.example",
          expectedAuthorization: undefined,
        }),
      },
    ),
    SafeFeeMarketProbeError,
  );

  assert.equal(await readFile(catalogPath, "utf8"), sourceText);
  assert.equal(await readFile(targetPath, "utf8"), targetText);
  assert.deepEqual(
    (await readdir(directory)).sort(),
    [
      "NetworkCatalog.json",
      "NetworkCatalog.json.candidate",
      "protected.json",
    ],
  );
});

test("candidate output must differ from the source catalog", async (context) => {
  const directory = await mkdtemp(
    join(tmpdir(), "fee-market-probe-source-output-"),
  );
  context.after(async () => {
    await rm(directory, { recursive: true, force: true });
  });
  const catalogPath = join(directory, "NetworkCatalog.json");
  const sourceText = `${JSON.stringify([probeRecord()], null, 2)}\n`;
  await writeFile(catalogPath, sourceText, "utf8");

  await assert.rejects(
    executeFeeMarketProbe(
      {
        ...probeOptions(catalogPath, true),
        outputPath: catalogPath,
        concurrency: 1,
      },
      {
        nowImplementation: () => Date.parse(CHECKED_AT),
        fetchImplementation: successfulRPCFetch({
          expectedURL: "https://rpc.gnosis.example",
          expectedAuthorization: undefined,
        }),
      },
    ),
    (error) => {
      assert.ok(error instanceof SafeFeeMarketProbeError);
      assert.equal(
        error.message,
        "Catalog output must differ from the source catalog",
      );
      return true;
    },
  );

  assert.equal(await readFile(catalogPath, "utf8"), sourceText);
  assert.deepEqual(await readdir(directory), ["NetworkCatalog.json"]);
});

test("candidate creation refuses to classify Alchemy records without authorization", async () => {
  const catalog = {
    path: "/fixture/NetworkCatalog.json",
    mode: 0o644,
    records: [{
      chainId: 1,
      alchemyNetwork: "eth-mainnet",
      feeMarketHint: {
        support: "unknown",
        checkedAt: CHECKED_AT,
        observedEndpoint: "https://eth-mainnet.g.alchemy.com/v2",
      },
    }],
  };
  await assert.rejects(
    executeFeeMarketProbe(
      {
        catalogPath: catalog.path,
        appProofKeyFile: undefined,
        expectedKid: undefined,
        concurrency: 1,
        timeoutMs: 1_000,
        outputPath: "/fixture/NetworkCatalog.candidate.json",
      },
      { catalogReader: async () => catalog },
    ),
    SafeFeeMarketProbeError,
  );
});

test("CLI defaults to report-only and validates credential pairs", () => {
  const defaults = parseProbeArguments([]);
  assert.equal(defaults.outputPath, undefined);
  assert.equal(defaults.concurrency, 8);
  assert.equal(
    parseProbeArguments(["--timeout-ms", "120000"]).timeoutMs,
    120_000,
  );
  assert.throws(
    () => parseProbeArguments(["--timeout-ms", "120001"]),
    SafeFeeMarketProbeError,
  );
  assert.throws(
    () => parseProbeArguments(["--app-proof-key-file", "/tmp/key"]),
    SafeFeeMarketProbeError,
  );
  assert.throws(
    () => parseProbeArguments(["--expected-kid", "kid"]),
    SafeFeeMarketProbeError,
  );
  assert.equal(
    parseProbeArguments([
      "--output",
      "/tmp/NetworkCatalog.candidate.json",
      "--app-proof-key-file",
      "/tmp/key",
      "--expected-kid",
      "kid",
    ]).outputPath,
    "/tmp/NetworkCatalog.candidate.json",
  );
  assert.throws(
    () => parseProbeArguments(["--write"]),
    SafeFeeMarketProbeError,
  );
  assert.throws(
    () => parseProbeArguments([
      "--catalog",
      "/tmp/NetworkCatalog.json",
      "--output",
      "/tmp/./NetworkCatalog.json",
    ]),
    SafeFeeMarketProbeError,
  );
});

test("bundled catalog passes the probe schema without network access", async () => {
  const directory = resolve(
    fileURLToPath(new URL(".", import.meta.url)),
    "../../../Shared/Ethereum",
  );
  const catalog = await readProbeCatalog(
    resolve(directory, "NetworkCatalog.json"),
  );
  assert.equal(catalog.records.length, 184);
  assert.equal(
    catalog.records.find((record) => record.chainId === 1)
      ?.feeMarketHint.support,
    "eip1559",
  );
  assert.equal(
    catalog.records.find((record) => record.chainId === 100)
      ?.feeMarketHint.support,
    "eip1559",
  );
  for (const record of catalog.records) {
    assert.equal(
      record.feeMarketHint.observedEndpoint,
      endpointForRecord(record).url,
    );
  }
});
