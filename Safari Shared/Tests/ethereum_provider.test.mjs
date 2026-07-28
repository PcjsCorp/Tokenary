// ∅ 2026 lil org

import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const providerRequire = createRequire(
    new URL("../Inpage Provider/package.json", import.meta.url)
);
const { buildSync } = providerRequire("esbuild");
const providerSource = buildSync({
    bundle: true,
    entryPoints: [
        fileURLToPath(
            new URL("../Inpage Provider/ethereum.js", import.meta.url)
        ),
    ],
    format: "cjs",
    logLevel: "silent",
    platform: "browser",
    target: "safari15",
    write: false,
}).outputFiles[0].text;
const solanaProviderSource = buildSync({
    bundle: true,
    entryPoints: [
        fileURLToPath(
            new URL("../Inpage Provider/solana.js", import.meta.url)
        ),
    ],
    format: "cjs",
    logLevel: "silent",
    platform: "browser",
    target: "safari15",
    write: false,
}).outputFiles[0].text;
const idMappingSource = buildSync({
    bundle: true,
    entryPoints: [
        fileURLToPath(
            new URL("../Inpage Provider/id_mapping.js", import.meta.url)
        ),
    ],
    format: "cjs",
    logLevel: "silent",
    platform: "browser",
    target: "safari15",
    write: false,
}).outputFiles[0].text;

function normalized(value) {
    return JSON.parse(JSON.stringify(value));
}

function frozenClockGlobals() {
    return {
        Date: class FrozenDate {
            getTime() {
                return 1_750_000_000_000;
            }
        },
        Math: Object.assign(Object.create(Math), { random: () => 0.25 }),
    };
}

function makeFrozenClockIdMapping() {
    const context = vm.createContext({
        module: {
            exports: {},
        },
        ...frozenClockGlobals(),
    });
    new vm.Script(idMappingSource, {
        filename: "id-mapping.cjs",
    }).runInContext(context);
    return new context.module.exports();
}

function makeProviderFromSource(source, providerName, extraGlobals = {}) {
    const scheduledCallbacks = [];
    const disconnectCalls = [];
    const postedMessages = [];
    const context = vm.createContext({
        clearTimeout() {},
        console: {
            log() {},
        },
        module: {
            exports: {},
        },
        setTimeout(callback) {
            scheduledCallbacks.push(callback);
            return 1;
        },
        window: {
            bigwallet: {
                disconnect(...args) {
                    disconnectCalls.push(args);
                },
                postMessage(...args) {
                    postedMessages.push(args);
                },
            },
        },
        ...extraGlobals,
    });
    new vm.Script(source, {
        filename: `${providerName}-provider.cjs`,
    }).runInContext(context);
    const provider = new context.module.exports();
    context.window.bigwallet[providerName] = provider;
    provider.disconnectCalls = disconnectCalls;
    provider.postedMessages = postedMessages;
    provider.runScheduledCallbacks = () => {
        while (scheduledCallbacks.length > 0) {
            scheduledCallbacks.shift()();
        }
    };
    return provider;
}

function makeProvider(extraGlobals = {}) {
    return makeProviderFromSource(providerSource, "eth", extraGlobals);
}

function makeSolanaProvider(extraGlobals = {}) {
    return makeProviderFromSource(solanaProviderSource, "solana", extraGlobals);
}

function deliverError(provider, id, response) {
    let callbackError;
    let callbackResult = "not called";
    provider.idMapping.intIds.set(id, `original-${id}`);
    provider.callbacks.set(id, (error, result) => {
        callbackError = error;
        callbackResult = result;
    });
    provider.wrapResults.set(id, true);

    provider.processBigWalletResponse(id, response);

    assert.equal(callbackResult, null);
    assert.equal(provider.callbacks.has(id), false);
    assert.equal(provider.wrapResults.has(id), false);
    assert.equal(provider.idMapping.intIds.has(id), false);
    return callbackError;
}

function deliverSolanaError(
    provider,
    id,
    response,
    { onCallback, pendingRequest = {} } = {}
) {
    let callbackError;
    let callbackResult = "not called";
    provider.idMapping.intIds.set(id, `original-${id}`);
    provider.pendingRequests.set(id, pendingRequest);
    provider.callbacks.set(id, (error, result) => {
        callbackError = error;
        callbackResult = result;
        if (onCallback) {
            onCallback();
        }
    });

    provider.processBigWalletResponse(id, response);

    assert.equal(callbackResult, null);
    assert.equal(provider.callbacks.has(id), false);
    assert.equal(provider.pendingRequests.has(id), false);
    assert.equal(provider.idMapping.intIds.has(id), false);
    return callbackError;
}

test("preserves a native Ethereum response error code and message", () => {
    const provider = makeProvider();
    const error = deliverError(provider, 41, {
        error: "FeeTooLow: EffectivePriorityFeePerGas too low 0 < 1",
        errorCode: -32_000,
    });

    assert.equal(error.code, -32_000);
    assert.equal(
        error.message,
        "FeeTooLow: EffectivePriorityFeePerGas too low 0 < 1"
    );
    assert.equal(error.data, undefined);
});

test("preserves nested JSON-RPC error code, message, and data", () => {
    const provider = makeProvider();
    const error = deliverError(provider, 42, {
        error: {
            code: -32_000,
            data: {
                baseFeePerGas: "0x132",
                minimumPriorityFeePerGas: "0x1",
            },
            message: "transaction underpriced",
        },
        id: 42,
        jsonrpc: "2.0",
    });

    assert.equal(error.code, -32_000);
    assert.equal(error.message, "transaction underpriced");
    assert.deepEqual(
        JSON.parse(JSON.stringify(error.data)),
        {
            baseFeePerGas: "0x132",
            minimumPriorityFeePerGas: "0x1",
        }
    );
});

test("decodes native JSON-RPC error data", () => {
    const provider = makeProvider();
    const error = deliverError(provider, 48, {
        error: "transaction underpriced",
        errorCode: -32_000,
        errorDataJSON: JSON.stringify({
            baseFeePerGas: "0x132",
            minimumPriorityFeePerGas: "0x1",
        }),
    });

    assert.equal(error.code, -32_000);
    assert.equal(error.message, "transaction underpriced");
    assert.deepEqual(
        JSON.parse(JSON.stringify(error.data)),
        {
            baseFeePerGas: "0x132",
            minimumPriorityFeePerGas: "0x1",
        }
    );
});

test("ignores malformed native JSON-RPC error data", () => {
    const provider = makeProvider();
    const error = deliverError(provider, 49, {
        error: "transaction underpriced",
        errorCode: -32_000,
        errorDataJSON: "{not-json",
    });

    assert.equal(error.code, -32_000);
    assert.equal(error.message, "transaction underpriced");
    assert.equal(error.data, undefined);
});

test("preserves decoded JSON null as Ethereum error data", () => {
    const provider = makeProvider();
    const error = deliverError(provider, 64, {
        error: {
            code: -32_000,
            data: {
                reason: "embedded data",
            },
            message: "transaction failed",
        },
        errorDataJSON: "null",
    });

    assert.equal(error.code, -32_000);
    assert.equal(error.message, "transaction failed");
    assert.equal(error.data, null);
});

test("keeps the legacy string-only error fallback", () => {
    const provider = makeProvider();
    const error = deliverError(provider, 43, {
        error: "something went wrong",
    });

    assert.equal(error.code, undefined);
    assert.equal(error.message, "something went wrong");
    assert.equal(error.name, "Error");
});

test("preserves an explicit localized user-rejection code", () => {
    const provider = makeProvider();
    const error = deliverError(provider, 53, {
        error: "İşlem kullanıcı tarafından iptal edildi",
        errorCode: 4001,
    });

    assert.equal(error.code, 4001);
    assert.equal(error.message, "İşlem kullanıcı tarafından iptal edildi");
});

test("preserves an unrecognized-chain error code", () => {
    const provider = makeProvider();
    const error = deliverError(provider, 55, {
        error: "Unrecognized chain ID",
        errorCode: 4902,
    });

    assert.equal(error.code, 4902);
    assert.equal(error.message, "Unrecognized chain ID");
});

test("keeps the legacy English cancellation fallback", () => {
    const provider = makeProvider();
    const error = deliverError(provider, 54, {
        error: "canceled",
    });

    assert.equal(error.code, 4001);
    assert.equal(error.message, "canceled");
});

test("preserves an empty JSON-RPC error message", () => {
    const provider = makeProvider();
    const nestedError = deliverError(provider, 44, {
        error: {
            code: -32_000,
            data: {
                reason: "empty message is intentional",
            },
            message: "",
        },
    });
    const flatError = deliverError(provider, 45, {
        error: "",
        errorCode: -32_001,
    });

    assert.equal(nestedError.message, "");
    assert.equal(flatError.message, "");
});

test("Solana applies its fallback message and ignores embedded object data", () => {
    const provider = makeSolanaProvider();
    const nestedError = deliverSolanaError(provider, 65, {
        error: {
            code: -32_000,
            data: {
                reason: "must not reach the callback",
            },
            message: "",
        },
    });
    const flatError = deliverSolanaError(provider, 66, {
        error: "",
        errorCode: -32_001,
    });

    assert.equal(nestedError.code, -32_000);
    assert.equal(nestedError.message, "Big Wallet request failed");
    assert.equal(nestedError.data, undefined);
    assert.equal(flatError.code, -32_001);
    assert.equal(flatError.message, "Big Wallet request failed");
});

test("Solana prefers valid JSON data and preserves decoded null", () => {
    const provider = makeSolanaProvider();
    const decodedError = deliverSolanaError(provider, 67, {
        error: "transaction failed",
        errorCode: -32_000,
        errorDataJSON: JSON.stringify({
            instructionError: [0, "Custom"],
        }),
        errorSignature: "fallback-signature",
    });
    const nullError = deliverSolanaError(provider, 68, {
        error: "transaction failed",
        errorCode: -32_000,
        errorDataJSON: "null",
        errorSignature: "fallback-signature",
    });

    assert.deepEqual(
        JSON.parse(JSON.stringify(decodedError.data)),
        {
            instructionError: [0, "Custom"],
        }
    );
    assert.equal(nullError.data, null);
});

test("Solana falls through malformed JSON data to its signature", () => {
    const provider = makeSolanaProvider();
    const error = deliverSolanaError(provider, 69, {
        error: "transaction failed",
        errorCode: -32_000,
        errorDataJSON: "{not-json",
        errorSignature: "fallback-signature",
    });

    assert.deepEqual(
        JSON.parse(JSON.stringify(error.data)),
        {
            signature: "fallback-signature",
        }
    );
});

test("Solana disconnects before rejecting an unauthorized request", () => {
    const provider = makeSolanaProvider();
    const publicKey = "11111111111111111111111111111111";
    provider.processBigWalletResponse(0, {
        name: "didLoadLatestConfiguration",
        publicKey,
    });
    const events = [];
    provider.on("accountChanged", () => events.push("accountChanged"));
    provider.on("disconnect", () => events.push("disconnect"));
    provider.standardOn("change", () => events.push("standardChange"));

    const error = deliverSolanaError(provider, 70, {
        error: "Unauthorized",
        errorCode: 4100,
        errorPublicKey: publicKey,
    }, {
        onCallback() {
            events.push("callback");
        },
        pendingRequest: {
            publicKey,
        },
    });

    assert.equal(error.code, 4100);
    assert.equal(error.message, "Unauthorized");
    assert.equal(error.data, undefined);
    assert.equal(provider.isConnected, false);
    assert.equal(provider.publicKey, null);
    assert.deepEqual(events, [
        "accountChanged",
        "disconnect",
        "standardChange",
        "callback",
    ]);
});

test("cleans request mappings after a local provider rejection", () => {
    const provider = makeProvider();
    const payload = {
        id: 46,
        method: "eth_subscribe",
    };

    void provider._request(payload);

    assert.equal(provider.callbacks.has(payload.id), false);
    assert.equal(provider.wrapResults.has(payload.id), false);
    assert.equal(provider.idMapping.intIds.has(payload.id), false);
});

test("revokes Ethereum account access after disconnect storage succeeds", async () => {
    const provider = makeProvider();
    provider.didGetLatestConfiguration = true;
    provider.setAddress("0x0000000000000000000000000000000000000001");
    const events = [];
    provider.on("accountsChanged", accounts => {
        events.push(["accountsChanged", normalized(accounts)]);
    });
    provider.on("disconnect", () => {
        events.push(["disconnect"]);
    });
    const payload = {
        id: 73,
        method: "wallet_revokePermissions",
        params: [{
            eth_accounts: {},
        }],
    };

    const result = provider.request(payload);

    assert.deepEqual(provider.disconnectCalls, [["ethereum", 73]]);
    assert.equal(
        provider.address,
        "0x0000000000000000000000000000000000000001"
    );
    assert.deepEqual(events, []);

    provider.processBigWalletResponse(payload.id, {
        name: "revokePermissions",
        provider: "ethereum",
        result: null,
    });

    assert.equal(provider.address, "");
    assert.equal(provider.selectedAddress, "");
    assert.equal(provider.ready, false);
    assert.deepEqual(events, [["accountsChanged", []]]);

    provider.runScheduledCallbacks();
    assert.equal(await result, null);
    assert.equal(provider.callbacks.has(payload.id), false);
    assert.equal(provider.wrapResults.has(payload.id), false);
    assert.equal(provider.idMapping.intIds.has(payload.id), false);
    assert.equal(provider.pendingPermissionRevocations.has(payload.id), false);
});

test("does not emit a redundant account event when revoking without an account", async () => {
    const provider = makeProvider();
    provider.didGetLatestConfiguration = true;
    const events = [];
    provider.on("accountsChanged", accounts => {
        events.push(normalized(accounts));
    });
    const payload = {
        id: 74,
        method: "wallet_revokePermissions",
        params: [{
            eth_accounts: {},
        }],
    };

    const result = provider.request(payload);
    provider.processBigWalletResponse(payload.id, {
        name: "revokePermissions",
        provider: "ethereum",
        result: null,
    });
    provider.runScheduledCallbacks();

    assert.equal(await result, null);
    assert.deepEqual(events, []);
    assert.equal(provider.pendingPermissionRevocations.has(payload.id), false);
});

test("successful revocation wins over an intervening account update", async () => {
    const provider = makeProvider();
    provider.didGetLatestConfiguration = true;
    const address = "0x0000000000000000000000000000000000000001";
    provider.setAddress(address);
    const events = [];
    provider.on("accountsChanged", accounts => {
        events.push(normalized(accounts));
    });
    const payload = {
        id: 85,
        method: "wallet_revokePermissions",
        params: [{
            eth_accounts: {},
        }],
    };

    const result = provider.request(payload);
    provider.updateAccount("requestAccounts", [address], "0x1");
    provider.processBigWalletResponse(payload.id, {
        name: "revokePermissions",
        provider: "ethereum",
        result: null,
    });
    provider.runScheduledCallbacks();

    assert.equal(await result, null);
    assert.equal(provider.address, "");
    assert.equal(provider.selectedAddress, "");
    assert.equal(provider.ready, false);
    assert.deepEqual(events, [[]]);
    assert.equal(provider.pendingPermissionRevocations.has(payload.id), false);
});

test("rejects invalid Ethereum permission revocations locally", async () => {
    const invalidParameters = [
        undefined,
        null,
        [],
        [{}],
        [{ eth_accounts: {} }, { eth_accounts: {} }],
        [{ personal_sign: {} }],
        [{ eth_accounts: {}, personal_sign: {} }],
        [{ eth_accounts: null }],
        [{ eth_accounts: [] }],
    ];

    for (const [index, params] of invalidParameters.entries()) {
        const provider = makeProvider();
        provider.didGetLatestConfiguration = true;
        const payload = {
            id: 75 + index,
            method: "wallet_revokePermissions",
        };
        if (typeof params !== "undefined") {
            payload.params = params;
        }

        const result = provider.request(payload);
        provider.runScheduledCallbacks();

        await assert.rejects(
            result,
            error =>
                error.code === -32602 &&
                error.message === "Invalid parameters"
        );
        assert.deepEqual(provider.disconnectCalls, []);
        assert.equal(provider.callbacks.has(payload.id), false);
        assert.equal(provider.wrapResults.has(payload.id), false);
        assert.equal(provider.idMapping.intIds.has(payload.id), false);
        assert.equal(
            provider.pendingPermissionRevocations.has(payload.id),
            false
        );
    }
});

test("keeps Ethereum account access when disconnect storage fails", async () => {
    const provider = makeProvider();
    provider.didGetLatestConfiguration = true;
    const address = "0x0000000000000000000000000000000000000001";
    provider.setAddress(address);
    const events = [];
    provider.on("accountsChanged", accounts => {
        events.push(normalized(accounts));
    });
    const payload = {
        id: 84,
        method: "wallet_revokePermissions",
        params: [{
            eth_accounts: {},
        }],
    };

    const result = provider.request(payload);
    provider.processBigWalletResponse(payload.id, {
        name: "revokePermissions",
        provider: "ethereum",
        error: "Failed to revoke permissions",
        errorCode: -32603,
    });
    provider.runScheduledCallbacks();

    await assert.rejects(
        result,
        error =>
            error.code === -32603 &&
            error.message === "Failed to revoke permissions"
    );
    assert.equal(provider.address, address);
    assert.equal(provider.selectedAddress, address);
    assert.equal(provider.ready, true);
    assert.deepEqual(events, []);
    assert.equal(provider.pendingPermissionRevocations.has(payload.id), false);
});

test("fails closed locally when disconnect completion is indeterminate", async () => {
    const provider = makeProvider();
    provider.didGetLatestConfiguration = true;
    const address = "0x0000000000000000000000000000000000000001";
    provider.setAddress(address);
    const events = [];
    provider.on("accountsChanged", accounts => {
        events.push(normalized(accounts));
    });
    const payload = {
        id: 86,
        method: "wallet_revokePermissions",
        params: [{
            eth_accounts: {},
        }],
    };

    const result = provider.request(payload);
    provider.processBigWalletResponse(payload.id, {
        name: "revokePermissions",
        provider: "ethereum",
        error: "Failed to revoke permissions",
        errorCode: -32603,
        revokeLocally: true,
    });
    provider.runScheduledCallbacks();

    await assert.rejects(
        result,
        error =>
            error.code === -32603 &&
            error.message === "Failed to revoke permissions"
    );
    assert.equal(provider.address, "");
    assert.equal(provider.selectedAddress, "");
    assert.equal(provider.ready, false);
    assert.deepEqual(events, [[]]);
    assert.equal(provider.pendingPermissionRevocations.has(payload.id), false);
});

test("rejects missing, null, and empty transaction params locally", async () => {
    const invalidPayloads = [
        {
            id: 55,
            method: "eth_sendTransaction",
        },
        {
            id: 56,
            method: "eth_sendTransaction",
            params: null,
        },
        {
            id: 57,
            method: "eth_sendTransaction",
            params: [],
        },
    ];

    for (const payload of invalidPayloads) {
        const provider = makeProvider();
        provider.didGetLatestConfiguration = true;
        const result = provider._request(payload);

        assert.equal(provider.callbacks.has(payload.id), false);
        assert.equal(provider.wrapResults.has(payload.id), false);
        assert.equal(provider.idMapping.intIds.has(payload.id), false);

        provider.runScheduledCallbacks();
        await assert.rejects(
            result,
            (error) =>
                error.code === -32602 &&
                error.message === "Invalid parameters"
        );
        assert.equal(provider.postedMessages.length, 0);
    }
});

test("rejects non-object transaction values locally", async () => {
    const invalidTransactions = [
        null,
        "0xdeadbeef",
        1,
        true,
        [],
    ];

    for (const [index, transaction] of invalidTransactions.entries()) {
        const provider = makeProvider();
        provider.didGetLatestConfiguration = true;
        const payload = {
            id: 58 + index,
            method: "eth_sendTransaction",
            params: [transaction],
        };
        const result = provider._request(payload);

        assert.equal(provider.callbacks.has(payload.id), false);
        assert.equal(provider.wrapResults.has(payload.id), false);
        assert.equal(provider.idMapping.intIds.has(payload.id), false);

        provider.runScheduledCallbacks();
        await assert.rejects(
            result,
            (error) =>
                error.code === -32602 &&
                error.message === "Invalid parameters"
        );
        assert.equal(provider.postedMessages.length, 0);
    }
});

test("forwards a transaction object and ignores compatible extra params", async () => {
    const provider = makeProvider();
    provider.didGetLatestConfiguration = true;
    provider.setAddress("0x0000000000000000000000000000000000000001");
    const transaction = {
        from: "0x0000000000000000000000000000000000000001",
        to: "0x0000000000000000000000000000000000000002",
        value: "0x1",
    };
    const payload = {
        id: 63,
        method: "eth_sendTransaction",
        params: [transaction, { ignored: true }],
    };

    const result = provider._request(payload);
    assert.equal(provider.postedMessages.length, 1);
    const [handler, id, body, providerName] = provider.postedMessages[0];
    assert.equal(handler, "signTransaction");
    assert.equal(id, payload.id);
    assert.equal(providerName, "ethereum");
    assert.deepEqual(
        JSON.parse(JSON.stringify(body.object)),
        transaction
    );

    provider.processBigWalletResponse(payload.id, {
        result: "0xtransaction-hash",
    });
    provider.runScheduledCallbacks();

    assert.deepEqual(
        JSON.parse(JSON.stringify(await result)),
        {
            id: 63,
            jsonrpc: "2.0",
            result: "0xtransaction-hash",
        }
    );
    assert.equal(provider.callbacks.has(payload.id), false);
    assert.equal(provider.wrapResults.has(payload.id), false);
    assert.equal(provider.idMapping.intIds.has(payload.id), false);
});

test("preserves a zero JSON-RPC request ID through the request path", async () => {
    const provider = makeProvider();
    provider.didGetLatestConfiguration = true;
    const payload = {
        id: 0,
        method: "eth_chainId",
    };

    const result = provider._request(payload);
    provider.runScheduledCallbacks();

    const response = await result;
    assert.equal(payload.id, 0);
    assert.equal(response.id, 0);
    assert.equal(response.result, "0x1");
    assert.equal(provider.callbacks.has(0), false);
    assert.equal(provider.wrapResults.has(0), false);
    assert.equal(provider.idMapping.intIds.has(0), false);
});

test("remaps a non-finite JSON-RPC request ID", async () => {
    const provider = makeProvider();
    provider.didGetLatestConfiguration = true;
    const payload = {
        id: Number.NaN,
        method: "eth_chainId",
    };

    const result = provider._request(payload);
    provider.runScheduledCallbacks();

    const response = await result;
    assert.equal(Number.isFinite(payload.id), true);
    assert.equal(response.id, payload.id);
    assert.equal(response.result, "0x1");
    assert.equal(provider.callbacks.has(payload.id), false);
    assert.equal(provider.wrapResults.has(payload.id), false);
    assert.equal(provider.idMapping.intIds.has(payload.id), false);
});

test("de-batches sendAsync and maps reversed responses to their requests", async () => {
    const provider = makeProvider();
    const forwardedPayloads = [];
    provider.rpc.call = (payload) => {
        payload.jsonrpc = "2.0";
        forwardedPayloads.push(
            JSON.parse(JSON.stringify(payload))
        );
        return true;
    };
    const firstPayload = {
        id: 71,
        method: "eth_customFirst",
        params: [],
    };
    const secondPayload = {
        id: 72,
        method: "eth_customSecond",
        params: [],
    };
    const responsesPromise = new Promise((resolve, reject) => {
        provider.sendAsync(
            [firstPayload, secondPayload],
            (error, responses) => {
                if (error) {
                    reject(error);
                } else {
                    resolve(responses);
                }
            }
        );
    });

    assert.deepEqual(forwardedPayloads, [
        {
            id: 71,
            jsonrpc: "2.0",
            method: "eth_customFirst",
            params: [],
        },
        {
            id: 72,
            jsonrpc: "2.0",
            method: "eth_customSecond",
            params: [],
        },
    ]);

    provider.processBigWalletResponse(secondPayload.id, {
        result: "second",
    });
    provider.processBigWalletResponse(firstPayload.id, {
        result: "first",
    });
    provider.runScheduledCallbacks();

    assert.deepEqual(
        JSON.parse(JSON.stringify(await responsesPromise)),
        [
            {
                id: 71,
                jsonrpc: "2.0",
                result: "first",
            },
            {
                id: 72,
                jsonrpc: "2.0",
                result: "second",
            },
        ]
    );
    for (const id of [firstPayload.id, secondPayload.id]) {
        assert.equal(provider.callbacks.has(id), false);
        assert.equal(provider.wrapResults.has(id), false);
        assert.equal(provider.idMapping.intIds.has(id), false);
    }
});

test("preserves a zero Solana request ID through the request path", () => {
    const provider = makeSolanaProvider();
    const payload = {
        id: 0,
        method: "unsupported",
    };

    void provider.request(payload);

    assert.equal(payload.id, 0);
    assert.equal(provider.callbacks.has(0), false);
    assert.equal(provider.pendingRequests.has(0), false);
    assert.equal(provider.idMapping.intIds.has(0), false);
});

test("mints distinct request IDs under a frozen clock", () => {
    const mapping = makeFrozenClockIdMapping();
    const first = {};
    const second = { id: "dapp-string-id" };
    const third = {};

    mapping.tryFixId(first);
    mapping.tryFixId(second);
    mapping.tryFixId(third);
    const remapped = { id: first.id };
    mapping.tryFixId(remapped);

    const ids = [first.id, second.id, third.id, remapped.id];
    assert.equal(new Set(ids).size, 4);
    for (const id of ids) {
        assert.equal(typeof id, "number");
        assert.equal(Number.isFinite(id), true);
    }
    assert.equal(mapping.intIds.get(first.id), first.id);
    assert.equal(mapping.tryPopId(second.id), "dapp-string-id");
    assert.equal(mapping.tryPopId(remapped.id), first.id);
});

test("routes two ID-less requests minted in the same millisecond to their own promises", async () => {
    const provider = makeProvider(frozenClockGlobals());
    const forwardedPayloads = [];
    provider.rpc.call = (payload) => {
        forwardedPayloads.push(
            JSON.parse(JSON.stringify(payload))
        );
        return true;
    };

    const firstPromise = provider._request({
        method: "eth_customFirst",
        params: [],
    }, false);
    const secondPromise = provider._request({
        method: "eth_customSecond",
        params: [],
    }, false);

    assert.equal(forwardedPayloads.length, 2);
    assert.notEqual(forwardedPayloads[0].id, forwardedPayloads[1].id);
    assert.equal(provider.callbacks.size, 2);

    provider.processBigWalletResponse(forwardedPayloads[1].id, {
        result: "second",
    });
    provider.processBigWalletResponse(forwardedPayloads[0].id, {
        result: "first",
    });
    provider.runScheduledCallbacks();

    assert.equal(await firstPromise, "first");
    assert.equal(await secondPromise, "second");
    for (const payload of forwardedPayloads) {
        assert.equal(provider.callbacks.has(payload.id), false);
        assert.equal(provider.wrapResults.has(payload.id), false);
        assert.equal(provider.idMapping.intIds.has(payload.id), false);
    }
});

test("keeps distinct Solana pending requests minted in the same millisecond", () => {
    const provider = makeSolanaProvider(frozenClockGlobals());

    void provider.signMessage(new Uint8Array([1]));
    void provider.signMessage(new Uint8Array([2]));

    assert.equal(provider.pendingRequests.size, 2);
    assert.equal(provider.callbacks.size, 2);
    const ids = [...provider.pendingRequests.keys()];
    assert.notEqual(ids[0], ids[1]);
    for (const metadata of provider.pendingRequests.values()) {
        assert.equal(metadata.respondWithBuffer, true);
    }
});

test("a malformed queued request does not block later Ethereum payloads", async () => {
    const provider = makeProvider();
    const malformedPayload = {
        id: 50,
        method: "personal_sign",
        params: [],
    };
    const validPayload = {
        id: 51,
        method: "eth_chainId",
    };

    const malformedResult = provider._request(malformedPayload);
    const validResult = provider._request(validPayload);
    assert.equal(provider.pendingPayloads.length, 2);

    provider.processBigWalletResponse(52, {
        name: "didLoadLatestConfiguration",
    });
    provider.runScheduledCallbacks();

    await assert.rejects(malformedResult);
    assert.deepEqual(
        JSON.parse(JSON.stringify(await validResult)),
        {
            id: 51,
            jsonrpc: "2.0",
            result: "0x1",
        }
    );
    assert.equal(provider.pendingPayloads.length, 0);
    assert.equal(provider.callbacks.has(50), false);
    assert.equal(provider.callbacks.has(51), false);
    assert.equal(provider.wrapResults.has(50), false);
    assert.equal(provider.wrapResults.has(51), false);
    assert.equal(provider.idMapping.intIds.has(50), false);
    assert.equal(provider.idMapping.intIds.has(51), false);
});
