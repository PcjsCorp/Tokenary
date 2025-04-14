// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: BabylonStaking.proto
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

/// Public key and corresponding signature.
public struct TW_BabylonStaking_Proto_PublicKeySignature {
  // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
  // methods supported on all messages.

  /// Public key bytes. Can be either compressed (33 bytes) or x-only (32 bytes).
  public var publicKey: Data = Data()

  /// Signature 64-length byte array.
  public var signature: Data = Data()

  public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

  public init() {}
}

public struct TW_BabylonStaking_Proto_StakingInfo {
  // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
  // methods supported on all messages.

  /// User's public key.
  public var stakerPublicKey: Data = Data()

  /// Finality provider's public key chosen by the user.
  public var finalityProviderPublicKey: Data = Data()

  /// Staking Output's lock time.
  /// Equal to `global_parameters.staking_time` when creating a Staking transaction.
  /// or `global_parameters.unbonding_time` when creating an Unbonding transaction.
  public var stakingTime: UInt32 = 0

  /// Retrieved from global_parameters.covenant_pks.
  /// Babylon nodes that can approve Unbonding tx or Slash the staked position when acting bad.
  public var covenantCommitteePublicKeys: [Data] = []

  /// Retrieved from global_parameters.covenant_quorum.
  /// Specifies the quorum required by the covenant committee for unbonding transactions to be confirmed.
  public var covenantQuorum: UInt32 = 0

  public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

  public init() {}
}

public struct TW_BabylonStaking_Proto_InputBuilder {
  // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
  // methods supported on all messages.

  public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

  /// Spend a Staking Output via timelock path (staking time expired).
  /// In other words, create a Withdraw transaction.
  public struct StakingTimelockPath {
    // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
    // methods supported on all messages.

    public var params: TW_BabylonStaking_Proto_StakingInfo {
      get {return _params ?? TW_BabylonStaking_Proto_StakingInfo()}
      set {_params = newValue}
    }
    /// Returns true if `params` has been explicitly set.
    public var hasParams: Bool {return self._params != nil}
    /// Clears the value of `params`. Subsequent reads from it will return its default value.
    public mutating func clearParams() {self._params = nil}

    public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

    public init() {}

    fileprivate var _params: TW_BabylonStaking_Proto_StakingInfo? = nil
  }

  /// Spend a Staking Output via unbonding path.
  /// In other words, create an Unbonding transaction.
  public struct StakingUnbondingPath {
    // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
    // methods supported on all messages.

    public var params: TW_BabylonStaking_Proto_StakingInfo {
      get {return _params ?? TW_BabylonStaking_Proto_StakingInfo()}
      set {_params = newValue}
    }
    /// Returns true if `params` has been explicitly set.
    public var hasParams: Bool {return self._params != nil}
    /// Clears the value of `params`. Subsequent reads from it will return its default value.
    public mutating func clearParams() {self._params = nil}

    /// Signatures signed by covenant committees.
    /// There can be less signatures than covenant public keys, but not less than `covenant_quorum`.
    public var covenantCommitteeSignatures: [TW_BabylonStaking_Proto_PublicKeySignature] = []

    public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

    public init() {}

    fileprivate var _params: TW_BabylonStaking_Proto_StakingInfo? = nil
  }

  /// Spend a Staking Output via slashing path.
  /// Slashing path is only used in [ExpressOfInterest](https://github.com/babylonlabs-io/babylon-proto-ts/blob/ef42d04959b326849fe8c9773ab23802573ad407/src/generated/babylon/btcstaking/v1/tx.ts#L61).
  /// In other words, generate an unsigned Slashing transaction, pre-sign the staker's signature only and share to Babylon PoS chain.
  public struct StakingSlashingPath {
    // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
    // methods supported on all messages.

    public var params: TW_BabylonStaking_Proto_StakingInfo {
      get {return _params ?? TW_BabylonStaking_Proto_StakingInfo()}
      set {_params = newValue}
    }
    /// Returns true if `params` has been explicitly set.
    public var hasParams: Bool {return self._params != nil}
    /// Clears the value of `params`. Subsequent reads from it will return its default value.
    public mutating func clearParams() {self._params = nil}

    /// Empty in most of the cases. Staker's signature can be calculated without the fp signature.
    public var finalityProviderSignature: TW_BabylonStaking_Proto_PublicKeySignature {
      get {return _finalityProviderSignature ?? TW_BabylonStaking_Proto_PublicKeySignature()}
      set {_finalityProviderSignature = newValue}
    }
    /// Returns true if `finalityProviderSignature` has been explicitly set.
    public var hasFinalityProviderSignature: Bool {return self._finalityProviderSignature != nil}
    /// Clears the value of `finalityProviderSignature`. Subsequent reads from it will return its default value.
    public mutating func clearFinalityProviderSignature() {self._finalityProviderSignature = nil}

    public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

    public init() {}

    fileprivate var _params: TW_BabylonStaking_Proto_StakingInfo? = nil
    fileprivate var _finalityProviderSignature: TW_BabylonStaking_Proto_PublicKeySignature? = nil
  }

  /// Spend an Unbonding Output via timelock path (unbonding time expired).
  /// In other words, create a Withdraw transaction spending an Unbonding transaction.
  public struct UnbondingTimelockPath {
    // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
    // methods supported on all messages.

    public var params: TW_BabylonStaking_Proto_StakingInfo {
      get {return _params ?? TW_BabylonStaking_Proto_StakingInfo()}
      set {_params = newValue}
    }
    /// Returns true if `params` has been explicitly set.
    public var hasParams: Bool {return self._params != nil}
    /// Clears the value of `params`. Subsequent reads from it will return its default value.
    public mutating func clearParams() {self._params = nil}

    public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

    public init() {}

    fileprivate var _params: TW_BabylonStaking_Proto_StakingInfo? = nil
  }

  /// Spend an Unbonding Output via slashing path.
  /// Slashing path is only used in [ExpressOfInterest](https://github.com/babylonlabs-io/babylon-proto-ts/blob/ef42d04959b326849fe8c9773ab23802573ad407/src/generated/babylon/btcstaking/v1/tx.ts#L61).
  /// In other words, generate an unsigned Slashing transaction, pre-sign the staker's signature only and share to Babylon PoS chain.
  public struct UnbondingSlashingPath {
    // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
    // methods supported on all messages.

    public var params: TW_BabylonStaking_Proto_StakingInfo {
      get {return _params ?? TW_BabylonStaking_Proto_StakingInfo()}
      set {_params = newValue}
    }
    /// Returns true if `params` has been explicitly set.
    public var hasParams: Bool {return self._params != nil}
    /// Clears the value of `params`. Subsequent reads from it will return its default value.
    public mutating func clearParams() {self._params = nil}

    /// Empty in most of the cases. Staker's signature can be calculated without the fp signature.
    public var finalityProviderSignature: TW_BabylonStaking_Proto_PublicKeySignature {
      get {return _finalityProviderSignature ?? TW_BabylonStaking_Proto_PublicKeySignature()}
      set {_finalityProviderSignature = newValue}
    }
    /// Returns true if `finalityProviderSignature` has been explicitly set.
    public var hasFinalityProviderSignature: Bool {return self._finalityProviderSignature != nil}
    /// Clears the value of `finalityProviderSignature`. Subsequent reads from it will return its default value.
    public mutating func clearFinalityProviderSignature() {self._finalityProviderSignature = nil}

    public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

    public init() {}

    fileprivate var _params: TW_BabylonStaking_Proto_StakingInfo? = nil
    fileprivate var _finalityProviderSignature: TW_BabylonStaking_Proto_PublicKeySignature? = nil
  }

  public init() {}
}

public struct TW_BabylonStaking_Proto_OutputBuilder {
  // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
  // methods supported on all messages.

  public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

  /// Create a Staking Output.
  public struct StakingOutput {
    // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
    // methods supported on all messages.

    public var params: TW_BabylonStaking_Proto_StakingInfo {
      get {return _params ?? TW_BabylonStaking_Proto_StakingInfo()}
      set {_params = newValue}
    }
    /// Returns true if `params` has been explicitly set.
    public var hasParams: Bool {return self._params != nil}
    /// Clears the value of `params`. Subsequent reads from it will return its default value.
    public mutating func clearParams() {self._params = nil}

    public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

    public init() {}

    fileprivate var _params: TW_BabylonStaking_Proto_StakingInfo? = nil
  }

  /// Create an Unbonding Output.
  public struct UnbondingOutput {
    // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
    // methods supported on all messages.

    public var params: TW_BabylonStaking_Proto_StakingInfo {
      get {return _params ?? TW_BabylonStaking_Proto_StakingInfo()}
      set {_params = newValue}
    }
    /// Returns true if `params` has been explicitly set.
    public var hasParams: Bool {return self._params != nil}
    /// Clears the value of `params`. Subsequent reads from it will return its default value.
    public mutating func clearParams() {self._params = nil}

    public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

    public init() {}

    fileprivate var _params: TW_BabylonStaking_Proto_StakingInfo? = nil
  }

  /// Creates an OP_RETURN output used to identify the staking transaction among other transactions in the Bitcoin ledger.
  public struct OpReturn {
    // WalletCoreSwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the WalletCoreSwiftProtobuf.library for
    // methods supported on all messages.

    /// Retrieved from global_parameters.Tag.
    public var tag: Data = Data()

    /// User's public key.
    public var stakerPublicKey: Data = Data()

    /// Finality provider's public key chosen by the user.
    public var finalityProviderPublicKey: Data = Data()

    /// global_parameters.min_staking_time <= staking_time <= global_parameters.max_staking_time.
    public var stakingTime: UInt32 = 0

    public var unknownFields = WalletCoreSwiftProtobuf.UnknownStorage()

    public init() {}
  }

  public init() {}
}

// MARK: - Code below here is support for the WalletCoreSwiftProtobuf.runtime.

fileprivate let _protobuf_package = "TW.BabylonStaking.Proto"

extension TW_BabylonStaking_Proto_PublicKeySignature: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".PublicKeySignature"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .standard(proto: "public_key"),
    2: .same(proto: "signature"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularBytesField(value: &self.publicKey) }()
      case 2: try { try decoder.decodeSingularBytesField(value: &self.signature) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.publicKey.isEmpty {
      try visitor.visitSingularBytesField(value: self.publicKey, fieldNumber: 1)
    }
    if !self.signature.isEmpty {
      try visitor.visitSingularBytesField(value: self.signature, fieldNumber: 2)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_BabylonStaking_Proto_PublicKeySignature, rhs: TW_BabylonStaking_Proto_PublicKeySignature) -> Bool {
    if lhs.publicKey != rhs.publicKey {return false}
    if lhs.signature != rhs.signature {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_BabylonStaking_Proto_StakingInfo: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".StakingInfo"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .standard(proto: "staker_public_key"),
    2: .standard(proto: "finality_provider_public_key"),
    3: .standard(proto: "staking_time"),
    4: .standard(proto: "covenant_committee_public_keys"),
    5: .standard(proto: "covenant_quorum"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularBytesField(value: &self.stakerPublicKey) }()
      case 2: try { try decoder.decodeSingularBytesField(value: &self.finalityProviderPublicKey) }()
      case 3: try { try decoder.decodeSingularUInt32Field(value: &self.stakingTime) }()
      case 4: try { try decoder.decodeRepeatedBytesField(value: &self.covenantCommitteePublicKeys) }()
      case 5: try { try decoder.decodeSingularUInt32Field(value: &self.covenantQuorum) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.stakerPublicKey.isEmpty {
      try visitor.visitSingularBytesField(value: self.stakerPublicKey, fieldNumber: 1)
    }
    if !self.finalityProviderPublicKey.isEmpty {
      try visitor.visitSingularBytesField(value: self.finalityProviderPublicKey, fieldNumber: 2)
    }
    if self.stakingTime != 0 {
      try visitor.visitSingularUInt32Field(value: self.stakingTime, fieldNumber: 3)
    }
    if !self.covenantCommitteePublicKeys.isEmpty {
      try visitor.visitRepeatedBytesField(value: self.covenantCommitteePublicKeys, fieldNumber: 4)
    }
    if self.covenantQuorum != 0 {
      try visitor.visitSingularUInt32Field(value: self.covenantQuorum, fieldNumber: 5)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_BabylonStaking_Proto_StakingInfo, rhs: TW_BabylonStaking_Proto_StakingInfo) -> Bool {
    if lhs.stakerPublicKey != rhs.stakerPublicKey {return false}
    if lhs.finalityProviderPublicKey != rhs.finalityProviderPublicKey {return false}
    if lhs.stakingTime != rhs.stakingTime {return false}
    if lhs.covenantCommitteePublicKeys != rhs.covenantCommitteePublicKeys {return false}
    if lhs.covenantQuorum != rhs.covenantQuorum {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_BabylonStaking_Proto_InputBuilder: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".InputBuilder"
  public static let _protobuf_nameMap = WalletCoreSwiftProtobuf._NameMap()

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let _ = try decoder.nextFieldNumber() {
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_BabylonStaking_Proto_InputBuilder, rhs: TW_BabylonStaking_Proto_InputBuilder) -> Bool {
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_BabylonStaking_Proto_InputBuilder.StakingTimelockPath: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = TW_BabylonStaking_Proto_InputBuilder.protoMessageName + ".StakingTimelockPath"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .same(proto: "params"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularMessageField(value: &self._params) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._params {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_BabylonStaking_Proto_InputBuilder.StakingTimelockPath, rhs: TW_BabylonStaking_Proto_InputBuilder.StakingTimelockPath) -> Bool {
    if lhs._params != rhs._params {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_BabylonStaking_Proto_InputBuilder.StakingUnbondingPath: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = TW_BabylonStaking_Proto_InputBuilder.protoMessageName + ".StakingUnbondingPath"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .same(proto: "params"),
    2: .standard(proto: "covenant_committee_signatures"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularMessageField(value: &self._params) }()
      case 2: try { try decoder.decodeRepeatedMessageField(value: &self.covenantCommitteeSignatures) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._params {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
    } }()
    if !self.covenantCommitteeSignatures.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.covenantCommitteeSignatures, fieldNumber: 2)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_BabylonStaking_Proto_InputBuilder.StakingUnbondingPath, rhs: TW_BabylonStaking_Proto_InputBuilder.StakingUnbondingPath) -> Bool {
    if lhs._params != rhs._params {return false}
    if lhs.covenantCommitteeSignatures != rhs.covenantCommitteeSignatures {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_BabylonStaking_Proto_InputBuilder.StakingSlashingPath: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = TW_BabylonStaking_Proto_InputBuilder.protoMessageName + ".StakingSlashingPath"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .same(proto: "params"),
    2: .standard(proto: "finality_provider_signature"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularMessageField(value: &self._params) }()
      case 2: try { try decoder.decodeSingularMessageField(value: &self._finalityProviderSignature) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._params {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
    } }()
    try { if let v = self._finalityProviderSignature {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 2)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_BabylonStaking_Proto_InputBuilder.StakingSlashingPath, rhs: TW_BabylonStaking_Proto_InputBuilder.StakingSlashingPath) -> Bool {
    if lhs._params != rhs._params {return false}
    if lhs._finalityProviderSignature != rhs._finalityProviderSignature {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_BabylonStaking_Proto_InputBuilder.UnbondingTimelockPath: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = TW_BabylonStaking_Proto_InputBuilder.protoMessageName + ".UnbondingTimelockPath"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .same(proto: "params"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularMessageField(value: &self._params) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._params {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_BabylonStaking_Proto_InputBuilder.UnbondingTimelockPath, rhs: TW_BabylonStaking_Proto_InputBuilder.UnbondingTimelockPath) -> Bool {
    if lhs._params != rhs._params {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_BabylonStaking_Proto_InputBuilder.UnbondingSlashingPath: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = TW_BabylonStaking_Proto_InputBuilder.protoMessageName + ".UnbondingSlashingPath"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .same(proto: "params"),
    2: .standard(proto: "finality_provider_signature"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularMessageField(value: &self._params) }()
      case 2: try { try decoder.decodeSingularMessageField(value: &self._finalityProviderSignature) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._params {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
    } }()
    try { if let v = self._finalityProviderSignature {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 2)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_BabylonStaking_Proto_InputBuilder.UnbondingSlashingPath, rhs: TW_BabylonStaking_Proto_InputBuilder.UnbondingSlashingPath) -> Bool {
    if lhs._params != rhs._params {return false}
    if lhs._finalityProviderSignature != rhs._finalityProviderSignature {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_BabylonStaking_Proto_OutputBuilder: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".OutputBuilder"
  public static let _protobuf_nameMap = WalletCoreSwiftProtobuf._NameMap()

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let _ = try decoder.nextFieldNumber() {
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_BabylonStaking_Proto_OutputBuilder, rhs: TW_BabylonStaking_Proto_OutputBuilder) -> Bool {
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_BabylonStaking_Proto_OutputBuilder.StakingOutput: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = TW_BabylonStaking_Proto_OutputBuilder.protoMessageName + ".StakingOutput"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .same(proto: "params"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularMessageField(value: &self._params) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._params {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_BabylonStaking_Proto_OutputBuilder.StakingOutput, rhs: TW_BabylonStaking_Proto_OutputBuilder.StakingOutput) -> Bool {
    if lhs._params != rhs._params {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_BabylonStaking_Proto_OutputBuilder.UnbondingOutput: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = TW_BabylonStaking_Proto_OutputBuilder.protoMessageName + ".UnbondingOutput"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .same(proto: "params"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularMessageField(value: &self._params) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._params {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_BabylonStaking_Proto_OutputBuilder.UnbondingOutput, rhs: TW_BabylonStaking_Proto_OutputBuilder.UnbondingOutput) -> Bool {
    if lhs._params != rhs._params {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension TW_BabylonStaking_Proto_OutputBuilder.OpReturn: WalletCoreSwiftProtobuf.Message, WalletCoreSwiftProtobuf._MessageImplementationBase, WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = TW_BabylonStaking_Proto_OutputBuilder.protoMessageName + ".OpReturn"
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    1: .same(proto: "tag"),
    2: .standard(proto: "staker_public_key"),
    3: .standard(proto: "finality_provider_public_key"),
    4: .standard(proto: "staking_time"),
  ]

  public mutating func decodeMessage<D: WalletCoreSwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularBytesField(value: &self.tag) }()
      case 2: try { try decoder.decodeSingularBytesField(value: &self.stakerPublicKey) }()
      case 3: try { try decoder.decodeSingularBytesField(value: &self.finalityProviderPublicKey) }()
      case 4: try { try decoder.decodeSingularUInt32Field(value: &self.stakingTime) }()
      default: break
      }
    }
  }

  public func traverse<V: WalletCoreSwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.tag.isEmpty {
      try visitor.visitSingularBytesField(value: self.tag, fieldNumber: 1)
    }
    if !self.stakerPublicKey.isEmpty {
      try visitor.visitSingularBytesField(value: self.stakerPublicKey, fieldNumber: 2)
    }
    if !self.finalityProviderPublicKey.isEmpty {
      try visitor.visitSingularBytesField(value: self.finalityProviderPublicKey, fieldNumber: 3)
    }
    if self.stakingTime != 0 {
      try visitor.visitSingularUInt32Field(value: self.stakingTime, fieldNumber: 4)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: TW_BabylonStaking_Proto_OutputBuilder.OpReturn, rhs: TW_BabylonStaking_Proto_OutputBuilder.OpReturn) -> Bool {
    if lhs.tag != rhs.tag {return false}
    if lhs.stakerPublicKey != rhs.stakerPublicKey {return false}
    if lhs.finalityProviderPublicKey != rhs.finalityProviderPublicKey {return false}
    if lhs.stakingTime != rhs.stakingTime {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
