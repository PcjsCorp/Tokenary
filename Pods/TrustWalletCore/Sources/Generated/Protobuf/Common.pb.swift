// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: Common.proto
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

/// Error codes, used in multiple blockchains.
public enum TW_Common_Proto_SigningError: WalletCoreSwiftProtobuf.Enum {
  public typealias RawValue = Int

  /// This is the OK case, with value=0
  case ok // = 0

  /// Chain-generic codes:
  /// Generic error (used if there is no suitable specific error is adequate)
  case errorGeneral // = 1

  /// Internal error, indicates some very unusual, unexpected case
  case errorInternal // = 2

  /// Chain-generic codes, input related:
  /// Low balance: the sender balance is not enough to cover the send and other auxiliary amount such as fee, deposit, or minimal balance.
  case errorLowBalance // = 3

  /// Requested amount is zero, send of 0 makes no sense
  case errorZeroAmountRequested // = 4

  /// One required key is missing (too few or wrong keys are provided)
  case errorMissingPrivateKey // = 5

  /// A private key provided is invalid (e.g. wrong size, usually should be 32 bytes)
  case errorInvalidPrivateKey // = 15

  /// A provided address (e.g. destination address) is invalid
  case errorInvalidAddress // = 16

  /// A provided input UTXO is invalid
  case errorInvalidUtxo // = 17

  /// The amount of an input UTXO is invalid
  case errorInvalidUtxoAmount // = 18

  /// Chain-generic, fee related:
  /// Wrong fee is given, probably it is too low to cover minimal fee for the transaction
  case errorWrongFee // = 6

  /// Chain-generic, signing related:
  /// General signing error
  case errorSigning // = 7

  /// Resulting transaction is too large
  /// [NEO] Transaction too big, fee in GAS needed or try send by parts
  case errorTxTooBig // = 8

  /// UTXO-chain specific, input related:
  /// No input UTXOs provided [BTC]
  case errorMissingInputUtxos // = 9

  /// Not enough non-dust input UTXOs to cover requested amount (dust UTXOs are filtered out) [BTC]
  case errorNotEnoughUtxos // = 10

  /// UTXO-chain specific, script related:
  /// [BTC] Missing required redeem script
  case errorScriptRedeem // = 11

  /// [BTC] Invalid required output script 
  case errorScriptOutput // = 12

  /// [BTC] Unrecognized witness program
  case errorScriptWitnessProgram // = 13

  /// Invalid memo, e.g. [XRP] Invalid tag
  case errorInvalidMemo // = 14

  /// Some input field cannot be parsed
  case errorInputParse // = 19

  /// Multi-input and multi-output transaction not supported
  case errorNoSupportN2N // = 20

  /// Incorrect count of signatures passed to compile
  case errorSignaturesCount // = 21

  /// Incorrect input parameter
  case errorInvalidParams // = 22

  /// Invalid input token amount
  case errorInvalidRequestedTokenAmount // = 23

  /// Operation not supported for the chain.
  case errorNotSupported // = 24

  /// Requested amount is too low (less dust).
  case errorDustAmountRequested // = 25
  case UNRECOGNIZED(Int)

  public init() {
    self = .ok
  }

  public init?(rawValue: Int) {
    switch rawValue {
    case 0: self = .ok
    case 1: self = .errorGeneral
    case 2: self = .errorInternal
    case 3: self = .errorLowBalance
    case 4: self = .errorZeroAmountRequested
    case 5: self = .errorMissingPrivateKey
    case 6: self = .errorWrongFee
    case 7: self = .errorSigning
    case 8: self = .errorTxTooBig
    case 9: self = .errorMissingInputUtxos
    case 10: self = .errorNotEnoughUtxos
    case 11: self = .errorScriptRedeem
    case 12: self = .errorScriptOutput
    case 13: self = .errorScriptWitnessProgram
    case 14: self = .errorInvalidMemo
    case 15: self = .errorInvalidPrivateKey
    case 16: self = .errorInvalidAddress
    case 17: self = .errorInvalidUtxo
    case 18: self = .errorInvalidUtxoAmount
    case 19: self = .errorInputParse
    case 20: self = .errorNoSupportN2N
    case 21: self = .errorSignaturesCount
    case 22: self = .errorInvalidParams
    case 23: self = .errorInvalidRequestedTokenAmount
    case 24: self = .errorNotSupported
    case 25: self = .errorDustAmountRequested
    default: self = .UNRECOGNIZED(rawValue)
    }
  }

  public var rawValue: Int {
    switch self {
    case .ok: return 0
    case .errorGeneral: return 1
    case .errorInternal: return 2
    case .errorLowBalance: return 3
    case .errorZeroAmountRequested: return 4
    case .errorMissingPrivateKey: return 5
    case .errorWrongFee: return 6
    case .errorSigning: return 7
    case .errorTxTooBig: return 8
    case .errorMissingInputUtxos: return 9
    case .errorNotEnoughUtxos: return 10
    case .errorScriptRedeem: return 11
    case .errorScriptOutput: return 12
    case .errorScriptWitnessProgram: return 13
    case .errorInvalidMemo: return 14
    case .errorInvalidPrivateKey: return 15
    case .errorInvalidAddress: return 16
    case .errorInvalidUtxo: return 17
    case .errorInvalidUtxoAmount: return 18
    case .errorInputParse: return 19
    case .errorNoSupportN2N: return 20
    case .errorSignaturesCount: return 21
    case .errorInvalidParams: return 22
    case .errorInvalidRequestedTokenAmount: return 23
    case .errorNotSupported: return 24
    case .errorDustAmountRequested: return 25
    case .UNRECOGNIZED(let i): return i
    }
  }

}

#if swift(>=4.2)

extension TW_Common_Proto_SigningError: CaseIterable {
  // The compiler won't synthesize support with the UNRECOGNIZED case.
  public static var allCases: [TW_Common_Proto_SigningError] = [
    .ok,
    .errorGeneral,
    .errorInternal,
    .errorLowBalance,
    .errorZeroAmountRequested,
    .errorMissingPrivateKey,
    .errorInvalidPrivateKey,
    .errorInvalidAddress,
    .errorInvalidUtxo,
    .errorInvalidUtxoAmount,
    .errorWrongFee,
    .errorSigning,
    .errorTxTooBig,
    .errorMissingInputUtxos,
    .errorNotEnoughUtxos,
    .errorScriptRedeem,
    .errorScriptOutput,
    .errorScriptWitnessProgram,
    .errorInvalidMemo,
    .errorInputParse,
    .errorNoSupportN2N,
    .errorSignaturesCount,
    .errorInvalidParams,
    .errorInvalidRequestedTokenAmount,
    .errorNotSupported,
    .errorDustAmountRequested,
  ]
}

#endif  // swift(>=4.2)

// MARK: - Code below here is support for the WalletCoreSwiftProtobuf.runtime.

extension TW_Common_Proto_SigningError: WalletCoreSwiftProtobuf._ProtoNameProviding {
  public static let _protobuf_nameMap: WalletCoreSwiftProtobuf._NameMap = [
    0: .same(proto: "OK"),
    1: .same(proto: "Error_general"),
    2: .same(proto: "Error_internal"),
    3: .same(proto: "Error_low_balance"),
    4: .same(proto: "Error_zero_amount_requested"),
    5: .same(proto: "Error_missing_private_key"),
    6: .same(proto: "Error_wrong_fee"),
    7: .same(proto: "Error_signing"),
    8: .same(proto: "Error_tx_too_big"),
    9: .same(proto: "Error_missing_input_utxos"),
    10: .same(proto: "Error_not_enough_utxos"),
    11: .same(proto: "Error_script_redeem"),
    12: .same(proto: "Error_script_output"),
    13: .same(proto: "Error_script_witness_program"),
    14: .same(proto: "Error_invalid_memo"),
    15: .same(proto: "Error_invalid_private_key"),
    16: .same(proto: "Error_invalid_address"),
    17: .same(proto: "Error_invalid_utxo"),
    18: .same(proto: "Error_invalid_utxo_amount"),
    19: .same(proto: "Error_input_parse"),
    20: .same(proto: "Error_no_support_n2n"),
    21: .same(proto: "Error_signatures_count"),
    22: .same(proto: "Error_invalid_params"),
    23: .same(proto: "Error_invalid_requested_token_amount"),
    24: .same(proto: "Error_not_supported"),
    25: .same(proto: "Error_dust_amount_requested"),
  ]
}
