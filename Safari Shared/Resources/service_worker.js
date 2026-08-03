// ∅ 2026 lil org

function handleOnMessage(request, sender, sendResponse) {
    if (request.subject === "rpc") {
        sendRPCRequest(request, sendResponse);
    } else if (request.subject === "message-to-wallet") {
        browser.runtime.sendNativeMessage("org.lil.wallet", request.message).then(response => {
            if (typeof response !== "undefined") {
                sendResponse(response);
                updateStoredConfigurationIfNeeded(request.host, response);
            } else {
                if (!request.navigate) {
                    sendResponse();
                }
            }
        }).catch(() => {
            if (!request.navigate) {
                sendResponse();
            }
        });
        
        if (request.navigate) {
            mobileRedirectFor(request, sendResponse);
        }
    } else if (request.subject === "getResponse") {
        browser.runtime.sendNativeMessage("org.lil.wallet", request).then(response => {
            if (typeof response !== "undefined") {
                sendResponse(response);
                updateStoredConfigurationIfNeeded(request.host, response);
            } else { sendResponse(); }
        }).catch(() => { sendResponse(); });
    } else if (request.subject === "cancelRequest") {
        browser.runtime.sendNativeMessage("org.lil.wallet", request).then(() => {}).catch(() => {});
        sendResponse();
    } else if (request.subject === "getLatestConfiguration") {
        const host = request.host;
        const queuedWrite = latestConfigurationWriteQueues.get(host);
        const waitForWrite = queuedWrite ?
            queuedWrite.catch(() => {}) :
            Promise.resolve();
        waitForWrite.then(() => {
            return getLatestConfiguration(host);
        }).then(currentConfiguration => {
            sendResponse(currentConfiguration);
        }).catch(() => {
            sendResponse();
        });
    } else if (request.subject === "disconnect") {
        const provider = request.provider;
        const host = request.host;
        removeLatestConfiguration(host, provider).then(() => {
            sendDisconnectResponse(request, sendResponse, {
                result: null
            });
        }).catch(() => {
            sendDisconnectResponse(request, sendResponse, {
                error: "Failed to revoke permissions",
                errorCode: -32603
            });
        });
    } else {
        sendResponse();
    }
    return true;
}

function sendRPCRequest(request, sendResponse) {
    const sendFailure = () => {
        sendResponse(rpcFailureResponse(request.id));
    };
    let pendingRequest;
    try {
        pendingRequest = browser.runtime.sendNativeMessage(
            "org.lil.wallet",
            request
        );
    } catch (error) {
        sendFailure();
        return;
    }
    Promise.resolve(pendingRequest).then(response => {
        if (response &&
            typeof response === "object" &&
            !Array.isArray(response) &&
            response.id === request.id &&
            ("result" in response || "error" in response)) {
            sendResponse(response);
        } else {
            sendFailure();
        }
    }, sendFailure);
}

function rpcFailureResponse(id) {
    return {
        id: id,
        error: "Failed to communicate with Big Wallet",
        errorCode: -32603
    };
}

function sendDisconnectResponse(request, sendResponse, response) {
    if (typeof request.id === "undefined") {
        sendResponse();
        return;
    }
    sendResponse({
        name: "revokePermissions",
        provider: request.provider,
        ...response
    });
}

const latestConfigurationWriteQueues = new Map();

function storeLatestConfiguration(host, configuration) {
    if (Array.isArray(configuration)) {
        queueLatestConfigurationWrite(host, () => {
            return browser.storage.local.set({ [host]: latestConfigurationsArray(configuration) });
        });
    } else if (configuration && "provider" in configuration) {
        queueLatestConfigurationUpdate(host, latestArray => latestConfigurationsReplacing(latestArray, configuration));
    }
}

function latestConfigurationsReplacing(latestArray, configuration) {
    const updatedArray = latestArray.slice();
    for (var i = 0; i < updatedArray.length; i++) {
        if (updatedArray[i].provider == configuration.provider) {
            updatedArray[i] = configuration;
            return updatedArray;
        }
    }
    updatedArray.push(configuration);
    return updatedArray;
}

function removeLatestConfiguration(host, provider) {
    return queueLatestConfigurationUpdate(host, (latestArray) => {
        return latestArray.filter(configuration => configuration.provider != provider);
    });
}

function removeLatestSolanaConfigurationIfMatching(host, publicKey) {
    return queueLatestConfigurationUpdate(host, (latestArray) => {
        return latestArray.filter(configuration => {
            return configuration.provider != "solana" || configuration.publicKey !== publicKey;
        });
    });
}

function queueLatestConfigurationUpdate(host, update) {
    return queueLatestConfigurationWrite(host, async () => {
        const currentArray = await readLatestConfigurations(host);
        const updatedArray = latestConfigurationsArray(update(currentArray));
        await browser.storage.local.set({ [host]: updatedArray });
    });
}

function queueLatestConfigurationWrite(host, write) {
    const previousWrite = latestConfigurationWriteQueues.get(host) || Promise.resolve();
    const queuedWrite = previousWrite
        .catch(() => {})
        .then(write);

    latestConfigurationWriteQueues.set(host, queuedWrite);
    const clearQueueIfLatest = () => {
        if (latestConfigurationWriteQueues.get(host) === queuedWrite) {
            latestConfigurationWriteQueues.delete(host);
        }
    };
    queuedWrite.then(clearQueueIfLatest, clearQueueIfLatest);

    return queuedWrite;
}

function latestConfigurationsArray(latest) {
    if (Array.isArray(latest)) {
        return latest.slice();
    }
    if (latest && Array.isArray(latest.latestConfigurations)) {
        return latest.latestConfigurations.slice();
    }
    if (typeof latest !== "undefined" && latest && "provider" in latest) {
        return [latest];
    }
    return [];
}

function readLatestConfigurations(host) {
    return browser.storage.local.get(host).then(stored => {
        return latestConfigurationsArray(stored[host]);
    });
}

function getLatestConfiguration(host) {
    return readLatestConfigurations(host).then(latestConfigurations => {
        return { latestConfigurations };
    }).catch(() => {
        return { latestConfigurations: [] };
    });
}

function updateStoredConfigurationIfNeeded(host, response) {
    if (!host || !response || typeof response !== "object") {
        return;
    }

    if (response.errorCode === 4100 &&
        response.provider === "solana" &&
        typeof response.errorPublicKey === "string") {
        removeLatestSolanaConfigurationIfMatching(host, response.errorPublicKey);
    } else if ("configurationToStore" in response) {
        storeLatestConfiguration(host, response.configurationToStore);
    }
}

function onBeforeExtensionPageNavigation(details) {
    if (details.url.includes("lil.org/extension?query=")) {
        const queryStringIndex = details.url.indexOf("?query=") + 7;
        const encodedQuery = details.url.substring(queryStringIndex);
        browser.tabs.update(details.tabId, { url: "bigwallet://safari?request=" + encodedQuery });
    }
}

function justShowApp() {
    const id = genId();
    const showAppMessage = {name: "justShowApp", id: id, provider: "unknown", body: {}, host: ""};
    browser.runtime.sendNativeMessage("org.lil.wallet", showAppMessage).then(() => {}).catch(() => {});
}

function handleOnClick(tab) {
    const message = {didTapExtensionButton: true};
    browser.tabs.sendMessage(tab.id, message).then(response => {
        if (typeof response !== "undefined" && "host" in response) {
            getLatestConfiguration(response.host).then(currentConfiguration => {
                const switchAccountMessage = {name: "switchAccount", id: genId(), provider: "unknown", body: currentConfiguration};
                browser.tabs.sendMessage(tab.id, switchAccountMessage).then(() => {}).catch(() => {});
            });
        } else {
            justShowApp();
        }
    }).catch(() => {});
    
    if (tab.url == "" && tab.pendingUrl == "") {
        justShowApp();
    }
}


function mobileRedirectFor(request, sendResponse) {
    const query = encodeURIComponent(JSON.stringify(request.message));
    browser.tabs.getCurrent((tab) => {
        if (tab) {
            if (request.confirm) {
                const confirmationText = request.message.host + " | connect wallet";
                browser.tabs.executeScript(tab.id, {
                    code: `
                        var query = '` + query + `';
                        var confirmationText = '` + confirmationText + `';
                        var id = ` + request.message.id + `;
                        var provider = '` + request.message.provider + `';
                        if (confirm(confirmationText)) {
                            window.location.href = 'https://lil.org/extension?query=' + query;
                        } else {
                            const response = {subject: "notConfirmed", id: id, provider: provider};
                            window.postMessage(response, "*");
                        }
                    `
                });
            } else {
                browser.tabs.executeScript(tab.id, { code: 'window.location.href = `https://lil.org/extension?query=' + query + '`;' });
            }
            sendResponse();
        }
    });
}


function genId() {
    return new Date().getTime() + Math.floor(Math.random() * 1000);
}

function addListeners() {
    browser.runtime.onMessage.addListener(handleOnMessage);
    browser.browserAction.onClicked.addListener(handleOnClick);
    browser.webNavigation.onBeforeNavigate.addListener(onBeforeExtensionPageNavigation, {url: [{urlMatches : "https://(www\.)?lil\.org/extension"}]});
}

addListeners();
