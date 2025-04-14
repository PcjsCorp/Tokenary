// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: Utxo.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

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

/// Bitcoin transaction out-point reference.
public struct TW_Utxo_Proto_OutPoint {
  // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
  // methods supported on all messages.

  /// The hash of the referenced transaction (network byte order, usually needs to be reversed).
  /// The referenced transaction ID in REVERSED order.
  public var hash: Data = Data()

  /// The position in the previous transactions output that this input references.
  public var vout: UInt32 = 0

  public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

  public init() {}
}

public struct TW_Utxo_Proto_TransactionInput {
  // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
  // methods supported on all messages.

  /// Reference to the previous transaction's output.
  public var outPoint: TW_Utxo_Proto_OutPoint {
    get {return _outPoint ?? TW_Utxo_Proto_OutPoint()}
    set {_outPoint = newValue}
  }
  /// Returns true if `outPoint` has been explicitly set.
  public var hasOutPoint: Bool {return self._outPoint != nil}
  /// Clears the value of `outPoint`. Subsequent reads from it will return its default value.
  public mutating func clearOutPoint() {self._outPoint = nil}

  /// The sequence number, used for timelocks, replace-by-fee, etc.
  public var sequence: UInt32 = 0

  /// The script for claiming the input (non-Segwit/non-Taproot).
  public var scriptSig: Data = Data()

  /// The script for claiming the input (Segit/Taproot).
  public var witnessItems: [Data] = []

  public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

  public init() {}

  fileprivate var _outPoint: TW_Utxo_Proto_OutPoint? = nil
}

public struct TW_Utxo_Proto_TransactionOutput {
  // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
  // methods supported on all messages.

  /// The condition for claiming the output.
  public var scriptPubkey: Data = Data()

  /// The amount of satoshis to spend.
  public var value: Int64 = 0

  public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

  public init() {}
}

public struct TW_Utxo_Proto_Transaction {
  // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
  // methods supported on all messages.

  /// The protocol version, is currently expected to be 1 or 2 (BIP68).
  public var version: UInt32 = 0

  /// Block height or timestamp indicating at what point transactions can be included in a block.
  /// Zero by default.
  public var lockTime: UInt32 = 0

  /// The transaction inputs.
  public var inputs: [TW_Utxo_Proto_TransactionInput] = []

  /// The transaction outputs.
  public var outputs: [TW_Utxo_Proto_TransactionOutput] = []

  public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

  public init() {}
}

// MARK: - Code below here is support for the WalletCoreSwiftProtobuf.runtime.

fileprivate let _protobuf_package = "TW.Utxo.Proto"

extension TW_Utxo_Proto_OutPoint: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".OutPoint"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .same(proto: "hash"),
    2: .same(proto: "vout"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularBytesField(value: &self.hash) }()
      case 2: try { try decoder.decodeSingularUInt32Field(value: &self.vout) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.hash.isEmpty {
      try visitor.visitSingularBytesField(value: self.hash, fieldNumber: 1)
    }
    if self.vout != 0 {
      try visitor.visitSingularUInt32Field(value: self.vout, fieldNumber: 2)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_Utxo_Proto_OutPoint, rhs: TW_Utxo_Proto_OutPoint) -> Bool {
    if lhs.hash != rhs.hash {return false}
    if lhs.vout != rhs.vout {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_Utxo_Proto_TransactionInput: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".TransactionInput"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .standard(proto: "out_point"),
    2: .same(proto: "sequence"),
    3: .standard(proto: "script_sig"),
    4: .standard(proto: "witness_items"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularMessageField(value: &self._outPoint) }()
      case 2: try { try decoder.decodeSingularUInt32Field(value: &self.sequence) }()
      case 3: try { try decoder.decodeSingularBytesField(value: &self.scriptSig) }()
      case 4: try { try decoder.decodeRepeatedBytesField(value: &self.witnessItems) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._outPoint {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
    } }()
    if self.sequence != 0 {
      try visitor.visitSingularUInt32Field(value: self.sequence, fieldNumber: 2)
    }
    if !self.scriptSig.isEmpty {
      try visitor.visitSingularBytesField(value: self.scriptSig, fieldNumber: 3)
    }
    if !self.witnessItems.isEmpty {
      try visitor.visitRepeatedBytesField(value: self.witnessItems, fieldNumber: 4)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_Utxo_Proto_TransactionInput, rhs: TW_Utxo_Proto_TransactionInput) -> Bool {
    if lhs._outPoint != rhs._outPoint {return false}
    if lhs.sequence != rhs.sequence {return false}
    if lhs.scriptSig != rhs.scriptSig {return false}
    if lhs.witnessItems != rhs.witnessItems {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_Utxo_Proto_TransactionOutput: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".TransactionOutput"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .standard(proto: "script_pubkey"),
    2: .same(proto: "value"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularBytesField(value: &self.scriptPubkey) }()
      case 2: try { try decoder.decodeSingularInt64Field(value: &self.value) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.scriptPubkey.isEmpty {
      try visitor.visitSingularBytesField(value: self.scriptPubkey, fieldNumber: 1)
    }
    if self.value != 0 {
      try visitor.visitSingularInt64Field(value: self.value, fieldNumber: 2)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_Utxo_Proto_TransactionOutput, rhs: TW_Utxo_Proto_TransactionOutput) -> Bool {
    if lhs.scriptPubkey != rhs.scriptPubkey {return false}
    if lhs.value != rhs.value {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_Utxo_Proto_Transaction: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".Transaction"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .same(proto: "version"),
    2: .standard(proto: "lock_time"),
    3: .same(proto: "inputs"),
    4: .same(proto: "outputs"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularUInt32Field(value: &self.version) }()
      case 2: try { try decoder.decodeSingularUInt32Field(value: &self.lockTime) }()
      case 3: try { try decoder.decodeRepeatedMessageField(value: &self.inputs) }()
      case 4: try { try decoder.decodeRepeatedMessageField(value: &self.outputs) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    if self.version != 0 {
      try visitor.visitSingularUInt32Field(value: self.version, fieldNumber: 1)
    }
    if self.lockTime != 0 {
      try visitor.visitSingularUInt32Field(value: self.lockTime, fieldNumber: 2)
    }
    if !self.inputs.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.inputs, fieldNumber: 3)
    }
    if !self.outputs.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.outputs, fieldNumber: 4)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_Utxo_Proto_Transaction, rhs: TW_Utxo_Proto_Transaction) -> Bool {
    if lhs.version != rhs.version {return false}
    if lhs.lockTime != rhs.lockTime {return false}
    if lhs.inputs != rhs.inputs {return false}
    if lhs.outputs != rhs.outputs {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
