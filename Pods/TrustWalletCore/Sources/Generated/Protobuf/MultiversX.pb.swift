// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: MultiversX.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

// SPDX-License-Identifier: Apache-2.0
//
// Copyright © 2017 Trust Wallet.

import Foundation
import WalletCoreSwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of WalletCoreSwiftProtobuf.to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: WalletCoreSwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: WalletCoreSwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

/// Generic action. Using one of the more specific actions (e.g. transfers, see below) is recommended.
public struct TW_MultiversX_Proto_GenericAction {
  // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
  // methods supported on all messages.

  /// Accounts involved
  public var accounts: TW_MultiversX_Proto_Accounts {
    get {return _accounts ?? TW_MultiversX_Proto_Accounts()}
    set {_accounts = newValue}
  }
  /// Returns true if `accounts` has been explicitly set.
  public var hasAccounts: Bool {return self._accounts != nil}
  /// Clears the value of `accounts`. Subsequent reads from it will return its default value.
  public mutating func clearAccounts() {self._accounts = nil}

  /// amount
  public var value: String = String()

  /// additional data
  public var data: String = String()

  /// transaction version
  public var version: UInt32 = 0

  /// Generally speaking, the "options" field can be ignored (not set) by applications using TW Core.
  public var options: UInt32 = 0

  public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

  public init() {}

  fileprivate var _accounts: TW_MultiversX_Proto_Accounts? = nil
}

/// EGLD transfer (move balance).
public struct TW_MultiversX_Proto_EGLDTransfer {
  // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
  // methods supported on all messages.

  /// Accounts involved
  public var accounts: TW_MultiversX_Proto_Accounts {
    get {return _accounts ?? TW_MultiversX_Proto_Accounts()}
    set {_accounts = newValue}
  }
  /// Returns true if `accounts` has been explicitly set.
  public var hasAccounts: Bool {return self._accounts != nil}
  /// Clears the value of `accounts`. Subsequent reads from it will return its default value.
  public mutating func clearAccounts() {self._accounts = nil}

  /// Transfer amount (string)
  public var amount: String = String()

  public var data: String = String()

  /// transaction version, if empty, the default value will be used
  public var version: UInt32 = 0

  public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

  public init() {}

  fileprivate var _accounts: TW_MultiversX_Proto_Accounts? = nil
}

/// ESDT transfer (transfer regular ESDTs - fungible tokens).
public struct TW_MultiversX_Proto_ESDTTransfer {
  // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
  // methods supported on all messages.

  /// Accounts involved
  public var accounts: TW_MultiversX_Proto_Accounts {
    get {return _accounts ?? TW_MultiversX_Proto_Accounts()}
    set {_accounts = newValue}
  }
  /// Returns true if `accounts` has been explicitly set.
  public var hasAccounts: Bool {return self._accounts != nil}
  /// Clears the value of `accounts`. Subsequent reads from it will return its default value.
  public mutating func clearAccounts() {self._accounts = nil}

  /// Token ID
  public var tokenIdentifier: String = String()

  /// Transfer token amount (string)
  public var amount: String = String()

  /// transaction version, if empty, the default value will be used
  public var version: UInt32 = 0

  public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

  public init() {}

  fileprivate var _accounts: TW_MultiversX_Proto_Accounts? = nil
}

/// ESDTNFT transfer (transfer NFTs, SFTs and Meta ESDTs).
public struct TW_MultiversX_Proto_ESDTNFTTransfer {
  // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
  // methods supported on all messages.

  /// Accounts involved
  public var accounts: TW_MultiversX_Proto_Accounts {
    get {return _accounts ?? TW_MultiversX_Proto_Accounts()}
    set {_accounts = newValue}
  }
  /// Returns true if `accounts` has been explicitly set.
  public var hasAccounts: Bool {return self._accounts != nil}
  /// Clears the value of `accounts`. Subsequent reads from it will return its default value.
  public mutating func clearAccounts() {self._accounts = nil}

  /// tokens
  public var tokenCollection: String = String()

  /// nonce of the token
  public var tokenNonce: UInt64 = 0

  /// transfer amount
  public var amount: String = String()

  /// transaction version, if empty, the default value will be used
  public var version: UInt32 = 0

  public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

  public init() {}

  fileprivate var _accounts: TW_MultiversX_Proto_Accounts? = nil
}

/// Transaction sender & receiver etc.
public struct TW_MultiversX_Proto_Accounts {
  // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
  // methods supported on all messages.

  /// Nonce of the sender
  public var senderNonce: UInt64 = 0

  /// Sender address
  public var sender: String = String()

  /// Sender username
  public var senderUsername: String = String()

  /// Receiver address
  public var receiver: String = String()

  /// Receiver username
  public var receiverUsername: String = String()

  /// Guardian address
  public var guardian: String = String()

  /// Relayer address
  public var relayer: String = String()

  public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

  public init() {}
}

/// Input data necessary to create a signed transaction.
public struct TW_MultiversX_Proto_SigningInput {
  // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
  // methods supported on all messages.

  /// The secret private key used for signing (32 bytes).
  public var privateKey: Data = Data()

  /// Chain identifier, string
  public var chainID: String = String()

  /// Gas price
  public var gasPrice: UInt64 = 0

  /// Limit for the gas used
  public var gasLimit: UInt64 = 0

  /// transfer payload
  public var messageOneof: TW_MultiversX_Proto_SigningInput.OneOf_MessageOneof? = nil

  public var genericAction: TW_MultiversX_Proto_GenericAction {
    get {
      if case .genericAction(let v)? = messageOneof {return v}
      return TW_MultiversX_Proto_GenericAction()
    }
    set {messageOneof = .genericAction(newValue)}
  }

  public var egldTransfer: TW_MultiversX_Proto_EGLDTransfer {
    get {
      if case .egldTransfer(let v)? = messageOneof {return v}
      return TW_MultiversX_Proto_EGLDTransfer()
    }
    set {messageOneof = .egldTransfer(newValue)}
  }

  public var esdtTransfer: TW_MultiversX_Proto_ESDTTransfer {
    get {
      if case .esdtTransfer(let v)? = messageOneof {return v}
      return TW_MultiversX_Proto_ESDTTransfer()
    }
    set {messageOneof = .esdtTransfer(newValue)}
  }

  public var esdtnftTransfer: TW_MultiversX_Proto_ESDTNFTTransfer {
    get {
      if case .esdtnftTransfer(let v)? = messageOneof {return v}
      return TW_MultiversX_Proto_ESDTNFTTransfer()
    }
    set {messageOneof = .esdtnftTransfer(newValue)}
  }

  public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

  /// transfer payload
  public enum OneOf_MessageOneof: Equatable {
    case genericAction(TW_MultiversX_Proto_GenericAction)
    case egldTransfer(TW_MultiversX_Proto_EGLDTransfer)
    case esdtTransfer(TW_MultiversX_Proto_ESDTTransfer)
    case esdtnftTransfer(TW_MultiversX_Proto_ESDTNFTTransfer)

  #if !swift(>=4.1)
    public static func ==(lhs: TW_MultiversX_Proto_SigningInput.OneOf_MessageOneof, rhs: TW_MultiversX_Proto_SigningInput.OneOf_MessageOneof) -> Bool {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch (lhs, rhs) {
      case (.genericAction, .genericAction): return {
        guard case .genericAction(let l) = lhs, case .genericAction(let r) = rhs else { preconditionFailure() }
        return l == r
      }()
      case (.egldTransfer, .egldTransfer): return {
        guard case .egldTransfer(let l) = lhs, case .egldTransfer(let r) = rhs else { preconditionFailure() }
        return l == r
      }()
      case (.esdtTransfer, .esdtTransfer): return {
        guard case .esdtTransfer(let l) = lhs, case .esdtTransfer(let r) = rhs else { preconditionFailure() }
        return l == r
      }()
      case (.esdtnftTransfer, .esdtnftTransfer): return {
        guard case .esdtnftTransfer(let l) = lhs, case .esdtnftTransfer(let r) = rhs else { preconditionFailure() }
        return l == r
      }()
      default: return false
      }
    }
  #endif
  }

  public init() {}
}

/// Result containing the signed and encoded transaction.
public struct TW_MultiversX_Proto_SigningOutput {
  // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
  // methods supported on all messages.

  public var encoded: String = String()

  public var signature: String = String()

  /// error code, 0 is ok, other codes will be treated as errors
  public var error: TW_Common_Proto_SigningError = .ok

  /// error code description
  public var errorMessage: String = String()

  public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

  public init() {}
}

// MARK: - Code below here is support for the WalletCoreSwiftProtobuf.runtime.

fileprivate let _protobuf_package = "TW.MultiversX.Proto"

extension TW_MultiversX_Proto_GenericAction: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".GenericAction"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .same(proto: "accounts"),
    2: .same(proto: "value"),
    3: .same(proto: "data"),
    4: .same(proto: "version"),
    5: .same(proto: "options"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularMessageField(value: &self._accounts) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self.value) }()
      case 3: try { try decoder.decodeSingularStringField(value: &self.data) }()
      case 4: try { try decoder.decodeSingularUInt32Field(value: &self.version) }()
      case 5: try { try decoder.decodeSingularUInt32Field(value: &self.options) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._accounts {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
    } }()
    if !self.value.isEmpty {
      try visitor.visitSingularStringField(value: self.value, fieldNumber: 2)
    }
    if !self.data.isEmpty {
      try visitor.visitSingularStringField(value: self.data, fieldNumber: 3)
    }
    if self.version != 0 {
      try visitor.visitSingularUInt32Field(value: self.version, fieldNumber: 4)
    }
    if self.options != 0 {
      try visitor.visitSingularUInt32Field(value: self.options, fieldNumber: 5)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_MultiversX_Proto_GenericAction, rhs: TW_MultiversX_Proto_GenericAction) -> Bool {
    if lhs._accounts != rhs._accounts {return false}
    if lhs.value != rhs.value {return false}
    if lhs.data != rhs.data {return false}
    if lhs.version != rhs.version {return false}
    if lhs.options != rhs.options {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_MultiversX_Proto_EGLDTransfer: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".EGLDTransfer"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .same(proto: "accounts"),
    2: .same(proto: "amount"),
    3: .same(proto: "data"),
    4: .same(proto: "version"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularMessageField(value: &self._accounts) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self.amount) }()
      case 3: try { try decoder.decodeSingularStringField(value: &self.data) }()
      case 4: try { try decoder.decodeSingularUInt32Field(value: &self.version) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._accounts {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
    } }()
    if !self.amount.isEmpty {
      try visitor.visitSingularStringField(value: self.amount, fieldNumber: 2)
    }
    if !self.data.isEmpty {
      try visitor.visitSingularStringField(value: self.data, fieldNumber: 3)
    }
    if self.version != 0 {
      try visitor.visitSingularUInt32Field(value: self.version, fieldNumber: 4)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_MultiversX_Proto_EGLDTransfer, rhs: TW_MultiversX_Proto_EGLDTransfer) -> Bool {
    if lhs._accounts != rhs._accounts {return false}
    if lhs.amount != rhs.amount {return false}
    if lhs.data != rhs.data {return false}
    if lhs.version != rhs.version {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_MultiversX_Proto_ESDTTransfer: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".ESDTTransfer"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .same(proto: "accounts"),
    2: .standard(proto: "token_identifier"),
    3: .same(proto: "amount"),
    4: .same(proto: "version"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularMessageField(value: &self._accounts) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self.tokenIdentifier) }()
      case 3: try { try decoder.decodeSingularStringField(value: &self.amount) }()
      case 4: try { try decoder.decodeSingularUInt32Field(value: &self.version) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._accounts {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
    } }()
    if !self.tokenIdentifier.isEmpty {
      try visitor.visitSingularStringField(value: self.tokenIdentifier, fieldNumber: 2)
    }
    if !self.amount.isEmpty {
      try visitor.visitSingularStringField(value: self.amount, fieldNumber: 3)
    }
    if self.version != 0 {
      try visitor.visitSingularUInt32Field(value: self.version, fieldNumber: 4)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_MultiversX_Proto_ESDTTransfer, rhs: TW_MultiversX_Proto_ESDTTransfer) -> Bool {
    if lhs._accounts != rhs._accounts {return false}
    if lhs.tokenIdentifier != rhs.tokenIdentifier {return false}
    if lhs.amount != rhs.amount {return false}
    if lhs.version != rhs.version {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_MultiversX_Proto_ESDTNFTTransfer: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".ESDTNFTTransfer"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .same(proto: "accounts"),
    2: .standard(proto: "token_collection"),
    3: .standard(proto: "token_nonce"),
    4: .same(proto: "amount"),
    5: .same(proto: "version"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularMessageField(value: &self._accounts) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self.tokenCollection) }()
      case 3: try { try decoder.decodeSingularUInt64Field(value: &self.tokenNonce) }()
      case 4: try { try decoder.decodeSingularStringField(value: &self.amount) }()
      case 5: try { try decoder.decodeSingularUInt32Field(value: &self.version) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._accounts {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
    } }()
    if !self.tokenCollection.isEmpty {
      try visitor.visitSingularStringField(value: self.tokenCollection, fieldNumber: 2)
    }
    if self.tokenNonce != 0 {
      try visitor.visitSingularUInt64Field(value: self.tokenNonce, fieldNumber: 3)
    }
    if !self.amount.isEmpty {
      try visitor.visitSingularStringField(value: self.amount, fieldNumber: 4)
    }
    if self.version != 0 {
      try visitor.visitSingularUInt32Field(value: self.version, fieldNumber: 5)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_MultiversX_Proto_ESDTNFTTransfer, rhs: TW_MultiversX_Proto_ESDTNFTTransfer) -> Bool {
    if lhs._accounts != rhs._accounts {return false}
    if lhs.tokenCollection != rhs.tokenCollection {return false}
    if lhs.tokenNonce != rhs.tokenNonce {return false}
    if lhs.amount != rhs.amount {return false}
    if lhs.version != rhs.version {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_MultiversX_Proto_Accounts: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".Accounts"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .standard(proto: "sender_nonce"),
    2: .same(proto: "sender"),
    3: .standard(proto: "sender_username"),
    4: .same(proto: "receiver"),
    5: .standard(proto: "receiver_username"),
    6: .same(proto: "guardian"),
    7: .same(proto: "relayer"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularUInt64Field(value: &self.senderNonce) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self.sender) }()
      case 3: try { try decoder.decodeSingularStringField(value: &self.senderUsername) }()
      case 4: try { try decoder.decodeSingularStringField(value: &self.receiver) }()
      case 5: try { try decoder.decodeSingularStringField(value: &self.receiverUsername) }()
      case 6: try { try decoder.decodeSingularStringField(value: &self.guardian) }()
      case 7: try { try decoder.decodeSingularStringField(value: &self.relayer) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    if self.senderNonce != 0 {
      try visitor.visitSingularUInt64Field(value: self.senderNonce, fieldNumber: 1)
    }
    if !self.sender.isEmpty {
      try visitor.visitSingularStringField(value: self.sender, fieldNumber: 2)
    }
    if !self.senderUsername.isEmpty {
      try visitor.visitSingularStringField(value: self.senderUsername, fieldNumber: 3)
    }
    if !self.receiver.isEmpty {
      try visitor.visitSingularStringField(value: self.receiver, fieldNumber: 4)
    }
    if !self.receiverUsername.isEmpty {
      try visitor.visitSingularStringField(value: self.receiverUsername, fieldNumber: 5)
    }
    if !self.guardian.isEmpty {
      try visitor.visitSingularStringField(value: self.guardian, fieldNumber: 6)
    }
    if !self.relayer.isEmpty {
      try visitor.visitSingularStringField(value: self.relayer, fieldNumber: 7)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_MultiversX_Proto_Accounts, rhs: TW_MultiversX_Proto_Accounts) -> Bool {
    if lhs.senderNonce != rhs.senderNonce {return false}
    if lhs.sender != rhs.sender {return false}
    if lhs.senderUsername != rhs.senderUsername {return false}
    if lhs.receiver != rhs.receiver {return false}
    if lhs.receiverUsername != rhs.receiverUsername {return false}
    if lhs.guardian != rhs.guardian {return false}
    if lhs.relayer != rhs.relayer {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_MultiversX_Proto_SigningInput: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".SigningInput"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .standard(proto: "private_key"),
    2: .standard(proto: "chain_id"),
    3: .standard(proto: "gas_price"),
    4: .standard(proto: "gas_limit"),
    5: .standard(proto: "generic_action"),
    6: .standard(proto: "egld_transfer"),
    7: .standard(proto: "esdt_transfer"),
    8: .standard(proto: "esdtnft_transfer"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularBytesField(value: &self.privateKey) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self.chainID) }()
      case 3: try { try decoder.decodeSingularUInt64Field(value: &self.gasPrice) }()
      case 4: try { try decoder.decodeSingularUInt64Field(value: &self.gasLimit) }()
      case 5: try {
        var v: TW_MultiversX_Proto_GenericAction?
        var hadOneofValue = false
        if let current = self.messageOneof {
          hadOneofValue = true
          if case .genericAction(let m) = current {v = m}
        }
        try decoder.decodeSingularMessageField(value: &v)
        if let v = v {
          if hadOneofValue {try decoder.handleConflictingOneOf()}
          self.messageOneof = .genericAction(v)
        }
      }()
      case 6: try {
        var v: TW_MultiversX_Proto_EGLDTransfer?
        var hadOneofValue = false
        if let current = self.messageOneof {
          hadOneofValue = true
          if case .egldTransfer(let m) = current {v = m}
        }
        try decoder.decodeSingularMessageField(value: &v)
        if let v = v {
          if hadOneofValue {try decoder.handleConflictingOneOf()}
          self.messageOneof = .egldTransfer(v)
        }
      }()
      case 7: try {
        var v: TW_MultiversX_Proto_ESDTTransfer?
        var hadOneofValue = false
        if let current = self.messageOneof {
          hadOneofValue = true
          if case .esdtTransfer(let m) = current {v = m}
        }
        try decoder.decodeSingularMessageField(value: &v)
        if let v = v {
          if hadOneofValue {try decoder.handleConflictingOneOf()}
          self.messageOneof = .esdtTransfer(v)
        }
      }()
      case 8: try {
        var v: TW_MultiversX_Proto_ESDTNFTTransfer?
        var hadOneofValue = false
        if let current = self.messageOneof {
          hadOneofValue = true
          if case .esdtnftTransfer(let m) = current {v = m}
        }
        try decoder.decodeSingularMessageField(value: &v)
        if let v = v {
          if hadOneofValue {try decoder.handleConflictingOneOf()}
          self.messageOneof = .esdtnftTransfer(v)
        }
      }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    if !self.privateKey.isEmpty {
      try visitor.visitSingularBytesField(value: self.privateKey, fieldNumber: 1)
    }
    if !self.chainID.isEmpty {
      try visitor.visitSingularStringField(value: self.chainID, fieldNumber: 2)
    }
    if self.gasPrice != 0 {
      try visitor.visitSingularUInt64Field(value: self.gasPrice, fieldNumber: 3)
    }
    if self.gasLimit != 0 {
      try visitor.visitSingularUInt64Field(value: self.gasLimit, fieldNumber: 4)
    }
    switch self.messageOneof {
    case .genericAction?: try {
      guard case .genericAction(let v)? = self.messageOneof else { preconditionFailure() }
      try visitor.visitSingularMessageField(value: v, fieldNumber: 5)
    }()
    case .egldTransfer?: try {
      guard case .egldTransfer(let v)? = self.messageOneof else { preconditionFailure() }
      try visitor.visitSingularMessageField(value: v, fieldNumber: 6)
    }()
    case .esdtTransfer?: try {
      guard case .esdtTransfer(let v)? = self.messageOneof else { preconditionFailure() }
      try visitor.visitSingularMessageField(value: v, fieldNumber: 7)
    }()
    case .esdtnftTransfer?: try {
      guard case .esdtnftTransfer(let v)? = self.messageOneof else { preconditionFailure() }
      try visitor.visitSingularMessageField(value: v, fieldNumber: 8)
    }()
    case nil: break
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_MultiversX_Proto_SigningInput, rhs: TW_MultiversX_Proto_SigningInput) -> Bool {
    if lhs.privateKey != rhs.privateKey {return false}
    if lhs.chainID != rhs.chainID {return false}
    if lhs.gasPrice != rhs.gasPrice {return false}
    if lhs.gasLimit != rhs.gasLimit {return false}
    if lhs.messageOneof != rhs.messageOneof {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_MultiversX_Proto_SigningOutput: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".SigningOutput"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .same(proto: "encoded"),
    2: .same(proto: "signature"),
    3: .same(proto: "error"),
    4: .standard(proto: "error_message"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularStringField(value: &self.encoded) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self.signature) }()
      case 3: try { try decoder.decodeSingularEnumField(value: &self.error) }()
      case 4: try { try decoder.decodeSingularStringField(value: &self.errorMessage) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.encoded.isEmpty {
      try visitor.visitSingularStringField(value: self.encoded, fieldNumber: 1)
    }
    if !self.signature.isEmpty {
      try visitor.visitSingularStringField(value: self.signature, fieldNumber: 2)
    }
    if self.error != .ok {
      try visitor.visitSingularEnumField(value: self.error, fieldNumber: 3)
    }
    if !self.errorMessage.isEmpty {
      try visitor.visitSingularStringField(value: self.errorMessage, fieldNumber: 4)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_MultiversX_Proto_SigningOutput, rhs: TW_MultiversX_Proto_SigningOutput) -> Bool {
    if lhs.encoded != rhs.encoded {return false}
    if lhs.signature != rhs.signature {return false}
    if lhs.error != rhs.error {return false}
    if lhs.errorMessage != rhs.errorMessage {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
