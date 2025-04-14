// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: Aeternity.proto
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

/// Input data necessary to create a signed transaction.
public struct TW_Aeternity_Proto_SigningInput {
  // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
  // methods supported on all messages.

  /// Address of the sender with "ak_" prefix
  public var fromAddress: String = String()

  /// Address of the recipient with "ak_" prefix
  public var toAddress: String = String()

  /// Amount (uint256, serialized big endian)
  public var amount: Data = Data()

  /// Fee amount (uint256, serialized big endian)
  public var fee: Data = Data()

  /// Message, optional
  public var payload: String = String()

  /// Time to live until block height
  public var ttl: UInt64 = 0

  /// Nonce (should be larger than in the last transaction of the account)
  public var nonce: UInt64 = 0

  /// The secret private key used for signing (32 bytes).
  public var privateKey: Data = Data()

  public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

  public init() {}
}

/// Result containing the signed and encoded transaction.
public struct TW_Aeternity_Proto_SigningOutput {
  // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
  // methods supported on all messages.

  /// Signed and encoded transaction bytes, Base64 with checksum
  public var encoded: String = String()

  /// Signature, Base58 with checksum
  public var signature: String = String()

  public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

  public init() {}
}

// MARK: - Code below here is support for the WalletCoreSwiftProtobuf.runtime.

fileprivate let _protobuf_package = "TW.Aeternity.Proto"

extension TW_Aeternity_Proto_SigningInput: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".SigningInput"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .standard(proto: "from_address"),
    2: .standard(proto: "to_address"),
    3: .same(proto: "amount"),
    4: .same(proto: "fee"),
    5: .same(proto: "payload"),
    6: .same(proto: "ttl"),
    7: .same(proto: "nonce"),
    8: .standard(proto: "private_key"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularStringField(value: &self.fromAddress) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self.toAddress) }()
      case 3: try { try decoder.decodeSingularBytesField(value: &self.amount) }()
      case 4: try { try decoder.decodeSingularBytesField(value: &self.fee) }()
      case 5: try { try decoder.decodeSingularStringField(value: &self.payload) }()
      case 6: try { try decoder.decodeSingularUInt64Field(value: &self.ttl) }()
      case 7: try { try decoder.decodeSingularUInt64Field(value: &self.nonce) }()
      case 8: try { try decoder.decodeSingularBytesField(value: &self.privateKey) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.fromAddress.isEmpty {
      try visitor.visitSingularStringField(value: self.fromAddress, fieldNumber: 1)
    }
    if !self.toAddress.isEmpty {
      try visitor.visitSingularStringField(value: self.toAddress, fieldNumber: 2)
    }
    if !self.amount.isEmpty {
      try visitor.visitSingularBytesField(value: self.amount, fieldNumber: 3)
    }
    if !self.fee.isEmpty {
      try visitor.visitSingularBytesField(value: self.fee, fieldNumber: 4)
    }
    if !self.payload.isEmpty {
      try visitor.visitSingularStringField(value: self.payload, fieldNumber: 5)
    }
    if self.ttl != 0 {
      try visitor.visitSingularUInt64Field(value: self.ttl, fieldNumber: 6)
    }
    if self.nonce != 0 {
      try visitor.visitSingularUInt64Field(value: self.nonce, fieldNumber: 7)
    }
    if !self.privateKey.isEmpty {
      try visitor.visitSingularBytesField(value: self.privateKey, fieldNumber: 8)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_Aeternity_Proto_SigningInput, rhs: TW_Aeternity_Proto_SigningInput) -> Bool {
    if lhs.fromAddress != rhs.fromAddress {return false}
    if lhs.toAddress != rhs.toAddress {return false}
    if lhs.amount != rhs.amount {return false}
    if lhs.fee != rhs.fee {return false}
    if lhs.payload != rhs.payload {return false}
    if lhs.ttl != rhs.ttl {return false}
    if lhs.nonce != rhs.nonce {return false}
    if lhs.privateKey != rhs.privateKey {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_Aeternity_Proto_SigningOutput: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".SigningOutput"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .same(proto: "encoded"),
    2: .same(proto: "signature"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularStringField(value: &self.encoded) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self.signature) }()
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
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_Aeternity_Proto_SigningOutput, rhs: TW_Aeternity_Proto_SigningOutput) -> Bool {
    if lhs.encoded != rhs.encoded {return false}
    if lhs.signature != rhs.signature {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
