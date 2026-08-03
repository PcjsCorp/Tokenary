// ∅ 2026 lil org

import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import vm from "node:vm";

const source = await readFile(
    new URL("../Resources/service_worker.js", import.meta.url),
    "utf8"
);

function deferred() {
    let resolve;
    let reject;
    const promise = new Promise((resolvePromise, rejectPromise) => {
        resolve = resolvePromise;
        reject = rejectPromise;
    });
    return { promise, reject, resolve };
}

function normalized(value) {
    return JSON.parse(JSON.stringify(value));
}

function makeHarness({ sendNativeMessage, storageGet, storageSet } = {}) {
    const nativeMessages = [];
    let runtimeListener;
    const browser = {
        runtime: {
            onMessage: {
                addListener(listener) {
                    runtimeListener = listener;
                },
            },
            sendNativeMessage(application, message) {
                nativeMessages.push({
                    application,
                    message: normalized(message),
                });
                if (sendNativeMessage) {
                    return sendNativeMessage(application, message);
                }
                return Promise.resolve();
            },
        },
        storage: {
            local: {
                get(key) {
                    if (storageGet) {
                        return storageGet(key);
                    }
                    return Promise.resolve({});
                },
                set(value) {
                    if (storageSet) {
                        return storageSet(value);
                    }
                    return Promise.resolve();
                },
            },
        },
        browserAction: {
            onClicked: {
                addListener() {},
            },
        },
        webNavigation: {
            onBeforeNavigate: {
                addListener() {},
            },
        },
        tabs: {
            executeScript() {
                return Promise.resolve();
            },
            getCurrent(callback) {
                callback(undefined);
            },
            sendMessage() {
                return Promise.resolve();
            },
            update() {
                return Promise.resolve();
            },
        },
    };
    class FixedDate extends Date {
        constructor(...arguments_) {
            if (arguments_.length === 0) {
                super(1_700_000_000_000);
            } else {
                super(...arguments_);
            }
        }

        static now() {
            return 1_700_000_000_000;
        }
    }
    const context = vm.createContext({
        browser,
        Date: FixedDate,
        Math: {
            floor: Math.floor,
            random: () => 0,
        },
    });
    new vm.Script(source, {
        filename: "service_worker.js",
    }).runInContext(context);

    return {
        context,
        evaluate(expression) {
            return new vm.Script(expression).runInContext(context);
        },
        nativeMessages,
        runtimeListener: () => runtimeListener,
    };
}

async function settlePromises() {
    for (let index = 0; index < 10; index += 1) {
        await Promise.resolve();
    }
}

function sendMessage(harness, request) {
    const responses = [];
    const keepsChannelOpen = harness.context.handleOnMessage(
        request,
        {},
        response => responses.push(response)
    );
    return { keepsChannelOpen, responses };
}

const rpcRequest = {
    body: "{\"id\":42,\"method\":\"eth_blockNumber\"}",
    chainId: "0x1",
    id: 42,
    subject: "rpc",
};

const rpcFailure = {
    error: "Failed to communicate with Big Wallet",
    errorCode: -32603,
    id: 42,
};

test("registers its production message listener", () => {
    const harness = makeHarness();

    assert.equal(harness.runtimeListener(), harness.context.handleOnMessage);
});

test("returns a correlated native RPC response", async () => {
    const harness = makeHarness({
        sendNativeMessage: () => Promise.resolve({
            id: 42,
            result: "0x2a",
        }),
    });
    const { keepsChannelOpen, responses } = sendMessage(harness, rpcRequest);
    await settlePromises();

    assert.equal(keepsChannelOpen, true);
    assert.deepEqual(normalized(responses), [{
        id: 42,
        result: "0x2a",
    }]);
    assert.deepEqual(harness.nativeMessages, [{
        application: "org.lil.wallet",
        message: rpcRequest,
    }]);
});

test("rejects missing or mismatched native RPC response IDs", async () => {
    for (const response of [
        { result: "0x2a" },
        { id: 99, result: "0x2a" },
    ]) {
        const harness = makeHarness({
            sendNativeMessage: () => Promise.resolve(response),
        });
        const { responses } = sendMessage(harness, rpcRequest);
        await settlePromises();

        assert.deepEqual(normalized(responses), [rpcFailure]);
    }
});

test("preserves a correlated native JSON-RPC error", async () => {
    const nativeError = {
        error: {
            code: -32_000,
            data: {
                minimumPriorityFeePerGas: "0x1",
            },
            message: "transaction underpriced",
        },
        id: 42,
        jsonrpc: "2.0",
    };
    const harness = makeHarness({
        sendNativeMessage: () => Promise.resolve(nativeError),
    });
    const { responses } = sendMessage(harness, rpcRequest);
    await settlePromises();

    assert.deepEqual(normalized(responses), [nativeError]);
});

test("returns a correlated error for an undefined native RPC response", async () => {
    const harness = makeHarness({
        sendNativeMessage: () => Promise.resolve(undefined),
    });
    const { responses } = sendMessage(harness, rpcRequest);
    await settlePromises();

    assert.deepEqual(normalized(responses), [rpcFailure]);
});

test("returns a correlated error for a malformed native RPC response", async () => {
    const harness = makeHarness({
        sendNativeMessage: () => Promise.resolve({ id: 42 }),
    });
    const { responses } = sendMessage(harness, rpcRequest);
    await settlePromises();

    assert.deepEqual(normalized(responses), [rpcFailure]);
});

test("returns a correlated error when a native RPC request rejects", async () => {
    const harness = makeHarness({
        sendNativeMessage: () => Promise.reject(new Error("unavailable")),
    });
    const { responses } = sendMessage(harness, rpcRequest);
    await settlePromises();

    assert.deepEqual(normalized(responses), [rpcFailure]);
});

test("returns a correlated error when a native RPC request throws", () => {
    const harness = makeHarness({
        sendNativeMessage: () => {
            throw new Error("unavailable");
        },
    });
    const { responses } = sendMessage(harness, rpcRequest);

    assert.deepEqual(normalized(responses), [rpcFailure]);
});

test("restores an Ethereum configuration without native prewarming", async () => {
    const host = "wallet.example";
    const configuration = {
        chainId: "0x1",
        provider: "ethereum",
        results: ["0x0000000000000000000000000000000000000042"],
    };
    const harness = makeHarness({
        storageGet: () => Promise.resolve({
            [host]: [configuration],
        }),
    });
    const { responses } = sendMessage(harness, {
        host,
        subject: "getLatestConfiguration",
    });
    await settlePromises();

    assert.deepEqual(normalized(responses), [{
        latestConfigurations: [configuration],
    }]);
    assert.deepEqual(harness.nativeMessages, []);
});

test("stores an Ethereum configuration without native prewarming", async () => {
    const host = "wallet.example";
    const configuration = {
        chainId: "0x1",
        provider: "ethereum",
        results: ["0x0000000000000000000000000000000000000042"],
    };
    const writes = [];
    const harness = makeHarness({
        storageSet: value => {
            writes.push(normalized(value));
            return Promise.resolve();
        },
    });

    harness.context.updateStoredConfigurationIfNeeded(host, {
        configurationToStore: configuration,
    });
    await settlePromises();

    assert.deepEqual(writes, [{
        [host]: [configuration],
    }]);
    assert.deepEqual(harness.nativeMessages, []);
});

test("waits for a queued configuration write before restoring it", async () => {
    const host = "wallet.example";
    const storageWrite = deferred();
    let storedConfiguration = [{
        chainId: "0x1",
        provider: "ethereum",
    }];
    let storageReadCount = 0;
    const harness = makeHarness({
        storageGet: () => {
            storageReadCount += 1;
            return Promise.resolve({
                [host]: storedConfiguration,
            });
        },
        storageSet: value => storageWrite.promise.then(() => {
            storedConfiguration = value[host];
        }),
    });

    harness.context.storeLatestConfiguration(host, [{
        chainId: "0x2",
        provider: "ethereum",
    }]);
    const { responses } = sendMessage(harness, {
        host,
        subject: "getLatestConfiguration",
    });
    await settlePromises();
    assert.equal(storageReadCount, 0);

    storageWrite.resolve();
    await settlePromises();

    assert.deepEqual(normalized(responses), [{
        latestConfigurations: [{
            chainId: "0x2",
            provider: "ethereum",
        }],
    }]);
    assert.deepEqual(harness.nativeMessages, []);
});

test("removes a settled configuration write queue", async () => {
    const storageWrite = deferred();
    const harness = makeHarness({
        storageSet: () => storageWrite.promise,
    });

    harness.context.storeLatestConfiguration("wallet.example", [{
        chainId: "0x1",
        provider: "ethereum",
    }]);
    await settlePromises();
    assert.equal(
        harness.evaluate("latestConfigurationWriteQueues.size"),
        1
    );

    storageWrite.resolve();
    await settlePromises();

    assert.equal(
        harness.evaluate("latestConfigurationWriteQueues.size"),
        0
    );
});

test("responds to a correlated disconnect after removing only its provider", async () => {
    const host = "wallet.example";
    const storageWrite = deferred();
    const storedConfigurations = {
        [host]: [
            { provider: "ethereum", chainId: "0x1" },
            { provider: "solana", publicKey: "solana-public-key" },
        ],
    };
    const writes = [];
    const harness = makeHarness({
        storageGet: key => Promise.resolve({
            [key]: storedConfigurations[key],
        }),
        storageSet: value => {
            writes.push(normalized(value));
            return storageWrite.promise;
        },
    });
    const { keepsChannelOpen, responses } = sendMessage(harness, {
        id: 73,
        subject: "disconnect",
        provider: "ethereum",
        host,
    });
    await settlePromises();

    assert.equal(keepsChannelOpen, true);
    assert.deepEqual(writes, [{
        [host]: [
            { provider: "solana", publicKey: "solana-public-key" },
        ],
    }]);
    assert.deepEqual(responses, []);

    storageWrite.resolve();
    await settlePromises();

    assert.deepEqual(normalized(responses), [{
        name: "revokePermissions",
        provider: "ethereum",
        result: null,
    }]);
});

test("returns an error when a correlated disconnect cannot be stored", async () => {
    const storageWrite = deferred();
    const harness = makeHarness({
        storageSet: () => storageWrite.promise,
    });
    const { responses } = sendMessage(harness, {
        id: 74,
        subject: "disconnect",
        provider: "ethereum",
        host: "wallet.example",
    });
    await settlePromises();

    storageWrite.reject(new Error("storage failed"));
    await settlePromises();

    assert.deepEqual(normalized(responses), [{
        name: "revokePermissions",
        provider: "ethereum",
        error: "Failed to revoke permissions",
        errorCode: -32603,
    }]);
});

test("does not overwrite configurations when a disconnect read fails", async () => {
    const writes = [];
    const harness = makeHarness({
        storageGet: () => Promise.reject(new Error("storage read failed")),
        storageSet: value => {
            writes.push(normalized(value));
            return Promise.resolve();
        },
    });
    const { responses } = sendMessage(harness, {
        id: 75,
        subject: "disconnect",
        provider: "ethereum",
        host: "wallet.example",
    });
    await settlePromises();

    assert.deepEqual(writes, []);
    assert.deepEqual(normalized(responses), [{
        name: "revokePermissions",
        provider: "ethereum",
        error: "Failed to revoke permissions",
        errorCode: -32603,
    }]);
});

test("preserves the empty response for an ID-less disconnect", async () => {
    const harness = makeHarness();
    const { responses } = sendMessage(harness, {
        subject: "disconnect",
        provider: "solana",
        host: "wallet.example",
    });
    await settlePromises();

    assert.deepEqual(responses, [undefined]);
});

test("removes only the matching Solana configuration for unauthorized responses", async () => {
    const host = "wallet.example";
    const matchingPublicKey = "matching-public-key";
    const storedConfigurations = {
        [host]: [
            { provider: "ethereum", chainId: "0x1" },
            { provider: "solana", publicKey: matchingPublicKey },
            { provider: "solana", publicKey: "another-public-key" },
        ],
    };
    const writes = [];
    const harness = makeHarness({
        storageGet: key => Promise.resolve({
            [key]: storedConfigurations[key],
        }),
        storageSet: value => {
            writes.push(normalized(value));
            return Promise.resolve();
        },
    });

    harness.context.updateStoredConfigurationIfNeeded(host, {
        configurationToStore: {
            provider: "solana",
            publicKey: "replacement-public-key",
        },
        error: "Unauthorized",
        errorCode: 4100,
        errorPublicKey: matchingPublicKey,
        provider: "solana",
    });
    await settlePromises();

    assert.deepEqual(writes, [{
        [host]: [
            { provider: "ethereum", chainId: "0x1" },
            { provider: "solana", publicKey: "another-public-key" },
        ],
    }]);
});
