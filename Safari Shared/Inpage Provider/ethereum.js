// ∅ 2025 lil org
// Rewrite of index.js from trust-web3-provider.

"use strict";

import RPCServer from "./rpc";
import ProviderRpcError from "./error";
import Utils from "./utils";
import IdMapping from "./id_mapping";
import { EventEmitter } from "events";
import isUtf8 from "isutf8";

class BigWalletEthereum extends EventEmitter {
    
    _metamask = {
        isUnlocked: () => {
            return new Promise((resolve) => {
                resolve(true);
            });
        },
    };
    
    constructor() {
        super();
        const config = {address: "", chainId: "0x1"};
        this.setConfig(config);
        this.idMapping = new IdMapping();
        this.callbacks = new Map();
        this.wrapResults = new Map();
        this.isMetaMask = true;
        this._isConnected = true;
        this._initialized = true;
        this._isUnlocked = true;
        this.isBigWallet = true;
        this.emitConnect(config.chainId);
        this.didEmitConnectAfterSubscription = false;
        this.didGetLatestConfiguration = false;
        this.pendingPayloads = [];
        
        const originalOn = this.on;
        this.on = (...args) => {
            if (args[0] == "connect") {
                setTimeout( function() {
                    if (!window.bigwallet.eth.didEmitConnectAfterSubscription) {
                        window.bigwallet.eth.emitConnect(window.bigwallet.eth.chainId);
                        window.bigwallet.eth.didEmitConnectAfterSubscription = true;
                    }
                }, 1);
            }
            return originalOn.apply(this, args);
        };
        
        setTimeout( function() { window.bigwallet.eth.emit("_initialized"); }, 1);
    }
    
    externalDisconnect() {
        this.setAddress("");
        window.bigwallet.eth.emit("disconnect");
        window.bigwallet.eth.emit("accountsChanged", []);
    }
    
    setAddress(address) {
        const lowerAddress = (address || "").toLowerCase();
        this.address = lowerAddress;
        this.selectedAddress = lowerAddress;
        this.ready = !!address;
    }
    
    updateAccount(eventName, addresses, chainId) {
        window.bigwallet.eth.setAddress(addresses[0]);
        
        if (eventName == "switchAccount") {
            window.bigwallet.eth.emit("accountsChanged", addresses);
        }
        
        if (window.bigwallet.eth.rpc.chainId != chainId) {
            this.rpc = new RPCServer(chainId);
        }
        
        if (window.bigwallet.eth.chainId != chainId) {
            window.bigwallet.eth.chainId = chainId;
            window.bigwallet.eth.networkVersion = this.net_version();
            if (eventName != "didLoadLatestConfiguration") {
                window.bigwallet.eth.emit("chainChanged", chainId);
                window.bigwallet.eth.emit("networkChanged", window.bigwallet.eth.net_version());
            }
        }
    }
    
    setConfig(config) {
        this.chainId = config.chainId;
        this.rpc = new RPCServer(config.chainId);
        this.setAddress(config.address);
        this.networkVersion = this.net_version();
    }
    
    request(payload) {
        var that = this;
        if (!(this instanceof BigWalletEthereum)) {
            that = window.bigwallet.eth;
        }
        return that._request(payload, false);
    }
    
    isConnected() {
        return true;
    }
    
    isUnlocked() {
        return Promise.resolve(true);
    }
    
    enable() {
        if (!window.bigwallet.eth.address) { // avoid double accounts request in uniswap
            return this.request({ method: "eth_requestAccounts", params: [] });
        } else {
            return this.request({ method: "eth_accounts", params: [] });
        }
    }
    
    send(payload, callback) {
        var that = this;
        if (!(this instanceof BigWalletEthereum)) {
            that = window.bigwallet.eth;
        }
        var requestPayload = {};
        if (typeof payload.method !== "undefined") {
            requestPayload.method = payload.method;
        } else {
            requestPayload.method = payload;
        }
        
        if (typeof payload.params !== "undefined") {
            requestPayload.params = payload.params;
        }

        if (typeof callback !== "undefined") {
            that.sendAsync(requestPayload, callback);
        } else {
            return that._request(requestPayload, false);
        }
    }
    
    sendAsync(payload, callback) {
        var that = this;
        if (!(this instanceof BigWalletEthereum)) {
            that = window.bigwallet.eth;
        }
        if (Array.isArray(payload)) {
            Promise.all(payload.map(that._request.bind(that)))
            .then((data) => callback(null, data))
            .catch((error) => callback(error, null));
        } else {
            that
            ._request(payload)
            .then((data) => callback(null, data))
            .catch((error) => callback(error, null));
        }
    }
    
    _request(payload, wrapResult = true) {
        this.idMapping.tryFixId(payload);
        return new Promise((resolve, reject) => {
            if (!payload.id) {
                payload.id = Utils.genId();
            }
            this.callbacks.set(payload.id, (error, data) => {
                // Some dapps do not get responses sent without a delay.
                // e.g., nftx.io does not start with a latest account if response is sent without a delay.
                setTimeout( function() {
                    if (error) {
                        reject(error);
                    } else {
                        resolve(data);
                    }
                }, 1);
            });
            this.wrapResults.set(payload.id, wrapResult);
            switch (payload.method) {
                case "eth_accounts":
                case "eth_coinbase":
                case "net_version":
                case "eth_chainId":
                case "eth_sign":
                case "personal_sign":
                case "personal_ecRecover":
                case "eth_signTypedData_v3":
                case "eth_signTypedData":
                case "eth_signTypedData_v4":
                case "eth_sendTransaction":
                case "eth_requestAccounts":
                case "wallet_addEthereumChain":
                case "wallet_switchEthereumChain":
                case "wallet_requestPermissions":
                case "wallet_getPermissions":
                    return this._processPayload(payload);
                case "eth_newFilter":
                case "eth_newBlockFilter":
                case "eth_newPendingTransactionFilter":
                case "eth_uninstallFilter":
                case "eth_subscribe":
                    throw new ProviderRpcError(4200, `big wallet does not support ${payload.method}`);
                default:
                    return this.rpc.call(payload);
            }
        });
    }
    
    _processPayload(payload) {
        if (!this.didGetLatestConfiguration) {
            this.pendingPayloads.push(payload);
            return;
        }
        
        switch (payload.method) {
            case "eth_accounts":
                return this.sendResponse(payload.id, this.eth_accounts());
            case "eth_coinbase":
                return this.sendResponse(payload.id, this.eth_coinbase());
            case "net_version":
                return this.sendResponse(payload.id, this.net_version());
            case "eth_chainId":
                return this.sendResponse(payload.id, this.eth_chainId());
            case "eth_sign":
                return this.eth_sign(payload);
            case "personal_sign":
                return this.personal_sign(payload);
            case "personal_ecRecover":
                return this.personal_ecRecover(payload);
            case "eth_signTypedData_v3":
                return this.eth_signTypedData(payload, false);
            case "eth_signTypedData":
            case "eth_signTypedData_v4":
                return this.eth_signTypedData(payload, true);
            case "eth_sendTransaction":
                return this.eth_sendTransaction(payload);
            case "eth_requestAccounts":
                if (!this.address) {
                    return this.eth_requestAccounts(payload);
                } else {
                    return this.sendResponse(payload.id, this.eth_accounts());
                }
            case "wallet_addEthereumChain":
                return this.wallet_addEthereumChain(payload);
            case "wallet_switchEthereumChain":
                return this.wallet_switchEthereumChain(payload);
            case "wallet_requestPermissions":
            case "wallet_getPermissions":
                const permissions = [{"parentCapability": "eth_accounts"}];
                return this.sendResponse(payload.id, permissions);
        }
    }
    
    emitConnect(chainId) {
        this.emit("connect", { chainId: chainId });
    }
    
    eth_accounts() {
        return this.address ? [this.address] : [];
    }
    
    eth_coinbase() {
        return this.address;
    }
    
    net_version() {
        return parseInt(this.chainId, 16).toString(10) || null;
    }
    
    eth_chainId() {
        return this.chainId;
    }
    
    eth_sign(payload) {
        const buffer = Utils.messageToBuffer(payload.params[1]);
        const hex = Utils.bufferToHex(buffer);
        if (isUtf8(buffer)) {
            this.postMessage("signPersonalMessage", payload.id, { data: hex });
        } else {
            this.postMessage("signMessage", payload.id, { data: hex });
        }
    }
    
    personal_sign(payload) {
        const message = payload.params[0];
        const buffer = Utils.messageToBuffer(message);
        if (buffer.length === 0) {
            const hex = Utils.bufferToHex(message);
            this.postMessage("signPersonalMessage", payload.id, { data: hex });
        } else {
            this.postMessage("signPersonalMessage", payload.id, { data: message });
        }
    }
    
    personal_ecRecover(payload) {
        this.postMessage("ecRecover", payload.id, {
        signature: payload.params[1],
        message: payload.params[0],
        });
    }
    
    eth_signTypedData(payload, useV4) {
        this.postMessage("signTypedMessage", payload.id, {
        raw: payload.params[1],
        });
    }
    
    eth_sendTransaction(payload) {
        this.postMessage("signTransaction", payload.id, payload.params[0]);
    }
    
    eth_requestAccounts(payload) {
        this.postMessage("requestAccounts", payload.id, {});
    }
    
    wallet_watchAsset(payload) {
        let options = payload.params.options;
        this.postMessage("watchAsset", payload.id, {
        type: payload.type,
        contract: options.address,
        symbol: options.symbol,
        decimals: options.decimals || 0,
        });
    }
    
    wallet_switchEthereumChain(payload) {
        if (this.chainId != payload.params[0].chainId) {
            this.postMessage("switchEthereumChain", payload.id, payload.params[0]);
        } else {
            this.sendResponse(payload.id, [this.address]);
        }
    }
    
    wallet_addEthereumChain(payload) {
        this.postMessage("addEthereumChain", payload.id, payload.params[0]);
    }
    
    processBigWalletResponse(id, response) {
        if (response.name == "didLoadLatestConfiguration") {
            this.didGetLatestConfiguration = true;
            if (response.chainId) {
                this.updateAccount(response.name, response.results, response.chainId);
            }
            
            for(let payload of this.pendingPayloads) {
                this._processPayload(payload);
            }
            
            this.pendingPayloads = [];
            return;
        }
        
        if ("result" in response) {
            this.sendResponse(id, response.result);
        } else if ("results" in response) {
            if (response.name == "switchEthereumChain" || response.name == "addEthereumChain") {
                // Calling it before sending response matters for some dapps
                this.updateAccount(response.name, response.results, response.chainId);
            }
            if (response.name != "switchAccount") {
                this.sendResponse(id, response.results);
            }
            if (response.name == "requestAccounts" || response.name == "switchAccount") {
                // Calling it after sending response matters for some dapps
                this.updateAccount(response.name, response.results, response.chainId);
            }
        } else if ("error" in response) {
            this.sendError(id, response.error);
        }
    }
    
    postMessage(handler, id, data) {
        if (this.ready || handler === "requestAccounts" || handler === "switchEthereumChain" || handler === "addEthereumChain") {
            let object = {
                object: data,
                address: this.address,
                chainId: this.chainId
            };
            window.bigwallet.postMessage(handler, id, object, "ethereum");
        } else {
            this.sendError(id, new ProviderRpcError(4100, "provider is not ready"));
        }
    }
    
    sendResponse(id, result) {
        let originId = this.idMapping.tryPopId(id) || id;
        let callback = this.callbacks.get(id);
        let wrapResult = this.wrapResults.get(id);
        let data = { jsonrpc: "2.0", id: originId };
        if (result !== null && result.result) {
            data.result = result.result;
        } else {
            data.result = result;
        }
        if (callback) {
            wrapResult ? callback(null, data) : callback(null, data.result);
            this.callbacks.delete(id);
            this.wrapResults.delete(id);
        } else {
            console.log(`callback id: ${id} not found`);
        }
    }
    
    sendError(id, error) {
        console.log(`<== ${id} sendError ${error}`);
        let callback = this.callbacks.get(id);
        if (callback) {
            callback(error instanceof Error ? error : new Error(error), null);
            this.callbacks.delete(id);
            this.wrapResults.delete(id);
        }
    }
}

module.exports = BigWalletEthereum;
