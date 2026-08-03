// ∅ 2026 lil org

import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import vm from "node:vm";

const source = await readFile(
    new URL("../Resources/content.js", import.meta.url),
    "utf8"
);

function normalized(value) {
    return JSON.parse(JSON.stringify(value));
}

function makeHarness(sendMessage, options = {}) {
    const injectedScripts = [];
    const postedMessages = [];
    const runtimeMessages = [];
    let reloadCount = 0;
    let messageListener;
    const scriptContainer = {
        children: [],
        insertBefore(script) {
            injectedScripts.push(script.textContent);
        },
        removeChild() {},
    };
    const document = {
        addEventListener() {},
        createElement() {
            return {
                setAttribute() {},
                textContent: "",
            };
        },
        doctype: {
            name: "html",
        },
        documentElement: {
            nodeName: "HTML",
        },
        head: scriptContainer,
        readyState: options.readyState || "loading",
    };
    const window = {
        addEventListener(name, listener) {
            if (name === "message") {
                messageListener = listener;
            }
        },
        document,
        location: {
            host: "wallet.example",
            pathname: options.pathname || "/fixture.pdf",
            reload() {
                reloadCount += 1;
            },
        },
        postMessage(message, target) {
            postedMessages.push({
                message: normalized(message),
                target,
            });
        },
    };
    const browser = {
        runtime: {
            onMessage: {
                addListener() {},
            },
            getURL() {
                return "safari-web-extension://wallet/inpage.js";
            },
            sendMessage(message) {
                runtimeMessages.push(normalized(message));
                return sendMessage(message);
            },
        },
    };
    class XMLHttpRequest {
        open() {}

        send() {
            this.responseText = "// provider fixture";
        }
    }
    const context = vm.createContext({
        browser,
        console: {
            error() {},
            log() {},
        },
        document,
        isMobile: false,
        Set,
        setTimeout,
        window,
        XMLHttpRequest,
    });
    new vm.Script(source, {
        filename: "content.js",
    }).runInContext(context);

    return {
        dispatchRPC(message) {
            messageListener({
                data: {
                    direction: "rpc",
                    message,
                },
                source: window,
            });
        },
        injectedScripts,
        postedMessages,
        get reloadCount() {
            return reloadCount;
        },
        runtimeMessages,
    };
}

async function settlePromises() {
    for (let index = 0; index < 10; index += 1) {
        await Promise.resolve();
    }
}

const expectedFailure = {
    direction: "rpc-back",
    errorCode: -32603,
    id: 42,
};

function assertFailureMessage(postedMessages) {
    assert.equal(postedMessages.length, 1);
    const posted = postedMessages[0];
    assert.equal(posted.target, "*");
    assert.equal(posted.message.direction, expectedFailure.direction);
    assert.equal(posted.message.id, expectedFailure.id);
    assert.equal(posted.message.response.id, expectedFailure.id);
    assert.equal(
        posted.message.response.error,
        "Failed to communicate with Big Wallet"
    );
    assert.equal(
        posted.message.response.errorCode,
        expectedFailure.errorCode
    );
}

test("injects into a completed page without reloading it", async () => {
    const harness = makeHarness(
        () => Promise.resolve({ latestConfigurations: [] }),
        {
            pathname: "/dapp",
            readyState: "complete",
        }
    );
    await settlePromises();

    assert.equal(harness.reloadCount, 0);
    assert.deepEqual(harness.injectedScripts, ["// provider fixture"]);
    assert.deepEqual(harness.runtimeMessages, [{
        confirm: false,
        host: "wallet.example",
        navigate: false,
        subject: "getLatestConfiguration",
    }]);
});

test("converts an undefined runtime RPC response into a correlated error", async () => {
    const harness = makeHarness(() => Promise.resolve(undefined));

    harness.dispatchRPC({
        id: 42,
        subject: "rpc",
    });
    await settlePromises();

    assertFailureMessage(harness.postedMessages);
});

test("converts a malformed runtime RPC response into a correlated error", async () => {
    const harness = makeHarness(() => Promise.resolve({ id: 42 }));

    harness.dispatchRPC({
        id: 42,
        subject: "rpc",
    });
    await settlePromises();

    assertFailureMessage(harness.postedMessages);
});

test("converts a rejected runtime RPC response into a correlated error", async () => {
    const harness = makeHarness(() => Promise.reject(new Error("unavailable")));

    harness.dispatchRPC({
        id: 42,
        subject: "rpc",
    });
    await settlePromises();

    assertFailureMessage(harness.postedMessages);
});

test("converts a thrown runtime RPC response into a correlated error", () => {
    const harness = makeHarness(() => {
        throw new Error("unavailable");
    });

    harness.dispatchRPC({
        id: 42,
        subject: "rpc",
    });

    assertFailureMessage(harness.postedMessages);
});

test("correlates a valid runtime RPC response to the original request", async () => {
    const harness = makeHarness(() => Promise.resolve({
        id: 42,
        result: "0x2a",
    }));

    harness.dispatchRPC({
        id: 42,
        subject: "rpc",
    });
    await settlePromises();

    assert.deepEqual(harness.postedMessages, [{
        message: {
            direction: "rpc-back",
            id: 42,
            response: {
                id: 42,
                result: "0x2a",
            },
        },
        target: "*",
    }]);
});

test("rejects a mismatched runtime RPC response ID", async () => {
    const harness = makeHarness(() => Promise.resolve({
        id: 99,
        result: "0x2a",
    }));

    harness.dispatchRPC({
        id: 42,
        subject: "rpc",
    });
    await settlePromises();

    assertFailureMessage(harness.postedMessages);
});
