// ∅ 2026 lil org

import SwiftUI

struct EditTransactionView: View {

    private static let maximumExactGweiTextLength = 79

    private enum FeeMode: Equatable {
        case legacy
        case eip1559
    }

    private enum EIP1559FeeField {
        case priority
        case cap
    }

    private let chain: EthereumNetwork
    private let feeMode: FeeMode
    private let initialGasPriceText: String
    private let initialMaxPriorityFeeText: String
    private let initialMaxFeeText: String
    private let initialFeeProvenance: TransactionFeeProvenance
    private let initialNonce: UInt?
    private let initialNonceWasPresent: Bool
    private let initialNonceText: String
    private let gasLimit: BigUInt?
    private let currentBaseFeePerGas: BigUInt?
    private let nextBaseFeePerGas: BigUInt?
    private let suggestedNonce: String?
    private let suggestedFee: PreparedTransactionFee?
    private let completion: (Transaction.Edits?) -> Void

    @State private var gasPrice: String
    @State private var maxPriorityFee: String
    @State private var maxFee: String
    @State private var nonce: String
    @State private var workingFeeProvenance: TransactionFeeProvenance

    private var feeBasisBaseFeePerGas: BigUInt? {
        nextBaseFeePerGas ?? currentBaseFeePerGas
    }

    private var parsedGasPrice: BigUInt? {
        Self.exactWei(fromGwei: gasPrice)
    }

    private var parsedMaxPriorityFee: BigUInt? {
        Self.exactWei(fromGwei: maxPriorityFee)
    }

    private var parsedMaxFee: BigUInt? {
        Self.exactWei(fromGwei: maxFee)
    }

    private var legacyFeeIsValid: Bool {
        guard let parsedGasPrice else { return false }
        guard Transaction.isValidGasPrice(parsedGasPrice, on: chain) else {
            return false
        }
        guard let feeBasisBaseFeePerGas else { return true }
        return parsedGasPrice >= feeBasisBaseFeePerGas
    }

    private var eip1559FeeIsValid: Bool {
        guard let candidateFee,
              case .eip1559(_, let cap) = candidateFee else {
            return false
        }

        guard let feeBasisBaseFeePerGas else { return true }
        return cap >= feeBasisBaseFeePerGas
    }

    private var capWarning: String? {
        guard feeMode == .eip1559,
              let baseFee = feeBasisBaseFeePerGas,
              let priority = parsedMaxPriorityFee,
              let cap = parsedMaxFee,
              cap > baseFee,
              cap < baseFee + priority else {
            return nil
        }
        return Strings.feeCapReducesPriority + " " +
            validationBasisDescription(baseFee)
    }

    private var validationBasisWarning: String? {
        guard let baseFee = feeBasisBaseFeePerGas else { return nil }
        switch feeMode {
        case .legacy:
            guard let gasPrice = parsedGasPrice,
                  gasPrice < baseFee else { return nil }
        case .eip1559:
            guard let cap = parsedMaxFee,
                  cap < baseFee else { return nil }
        }
        return Strings.feeMustExceedValidationBaseFee + " " +
            validationBasisDescription(baseFee)
    }

    private var eip1559StructuralWarning: String? {
        guard feeMode == .eip1559 else { return nil }
        if let priority = parsedMaxPriorityFee,
           let cap = parsedMaxFee,
           cap < priority {
            return Strings.maxFeeMustCoverPriority
        }
        return nil
    }

    private var nonceIsValid: Bool {
        if nonce == initialNonceText {
            return !initialNonceWasPresent || initialNonce != nil
        }
        return UInt(nonce) != nil
    }

    private var canCommit: Bool {
        let feeIsValid = switch feeMode {
        case .legacy:
            legacyFeeIsValid
        case .eip1559:
            eip1559FeeIsValid
        }
        return feeIsValid &&
            maximumNetworkFeeFitsUInt256 &&
            nonceIsValid
    }

    private var candidateFee: PreparedTransactionFee? {
        switch feeMode {
        case .legacy:
            guard let gasPrice = parsedGasPrice else { return nil }
            let fee = PreparedTransactionFee.legacy(gasPrice: gasPrice)
            return fee.isStructurallyValid ? fee : nil
        case .eip1559:
            guard let priority = parsedMaxPriorityFee,
                  let cap = parsedMaxFee else {
                return nil
            }
            let fee = PreparedTransactionFee.eip1559(
                maxPriorityFeePerGas: priority,
                maxFeePerGas: cap
            )
            return fee.isStructurallyValid ? fee : nil
        }
    }

    private var maximumNetworkFeeFitsUInt256: Bool {
        guard let candidateFee else { return true }
        return Self.maximumNetworkFeeFitsUInt256(
            gasLimit: gasLimit,
            fee: candidateFee
        )
    }

    private var maximumNetworkFeeWarning: String? {
        guard candidateFee != nil,
              !maximumNetworkFeeFitsUInt256 else {
            return nil
        }
        return Strings.maximumNetworkFeeTooLarge
    }

    private var suggestedGasPriceText: String? {
        guard case .legacy(let gasPrice) = suggestedFee else { return nil }
        return Transaction.editableGwei(fromWei: gasPrice)
    }

    private var shouldOfferSuggestedLegacyFee: Bool {
        guard let suggestedGasPriceText else { return false }
        return suggestedGasPriceText != gasPrice ||
            workingFeeProvenance != automaticSuggestedFeeProvenance
    }

    private var suggestedEIP1559Texts: (priority: String, cap: String)? {
        guard case let .eip1559(priority, cap) = suggestedFee,
              let priorityText = Transaction.editableGwei(fromWei: priority),
              let capText = Transaction.editableGwei(fromWei: cap) else {
            return nil
        }
        return (priorityText, capText)
    }

    private var shouldOfferSuggestedEIP1559Fees: Bool {
        guard let suggested = suggestedEIP1559Texts else { return false }
        return suggested.priority != maxPriorityFee ||
            suggested.cap != maxFee ||
            workingFeeProvenance != automaticSuggestedFeeProvenance
    }

    private var automaticSuggestedFeeProvenance:
        TransactionFeeProvenance? {
        suggestedFee.map {
            TransactionFeeProvenance(source: .automatic, for: $0)
        }
    }

    init(
        initialTransaction: Transaction,
        chain: EthereumNetwork,
        suggestedNonce: String?,
        suggestedFee: PreparedTransactionFee?,
        completion: @escaping (Transaction.Edits?) -> Void
    ) {
        let feeMode: FeeMode = initialTransaction.usesEIP1559Fees
            ? .eip1559
            : .legacy
        let gasPrice = initialTransaction.editableGasPriceGwei ?? ""
        let maxPriorityFee = Transaction.editableGwei(
            fromWei: initialTransaction.maxPriorityFeePerGasValue
        ) ?? ""
        let maxFee = Transaction.editableGwei(
            fromWei: initialTransaction.maxFeePerGasValue
        ) ?? ""
        let nonce = initialTransaction.decimalNonceString ?? ""

        self.chain = chain
        self.feeMode = feeMode
        self.initialGasPriceText = gasPrice
        self.initialMaxPriorityFeeText = maxPriorityFee
        self.initialMaxFeeText = maxFee
        self.initialFeeProvenance = initialTransaction.feeProvenance
        self.initialNonce = initialTransaction.nonce.flatMap(UInt.init(hexString:))
        self.initialNonceWasPresent = initialTransaction.nonce != nil
        self.initialNonceText = nonce
        self.gasLimit = initialTransaction.gasLimitValue
        self.currentBaseFeePerGas = initialTransaction.currentBaseFeePerGas
        self.nextBaseFeePerGas = initialTransaction.nextBaseFeePerGas
        self.suggestedNonce = suggestedNonce
        self.suggestedFee = suggestedFee
        self.completion = completion
        self._gasPrice = State(initialValue: gasPrice)
        self._maxPriorityFee = State(initialValue: maxPriorityFee)
        self._maxFee = State(initialValue: maxFee)
        self._nonce = State(initialValue: nonce)
        self._workingFeeProvenance = State(
            initialValue: initialTransaction.feeProvenance
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    switch feeMode {
                    case .legacy:
                        legacyFeeEditor
                    case .eip1559:
                        eip1559FeeEditor
                    }
                    nonceEditor
                }
                .padding()
            }

            HStack {
                Button(Strings.cancel, action: cancel)
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.bordered)
                Button(Strings.ok, action: commit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCommit)
                    .buttonStyle(.borderedProminent)
            }
            .frame(minHeight: 44)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(minWidth: 300)
    }

    private var legacyFeeEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Strings.gasPrice).fontWeight(.medium)
                Spacer()
                if shouldOfferSuggestedLegacyFee {
                    Button(
                        Strings.useSuggestedFees,
                        action: resetGasPrice
                    )
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            TextField(
                Strings.customGasPrice,
                text: manuallyEditedLegacyFeeBinding
            )
                .textFieldStyle(.roundedBorder)
                .decimalInputKeyboard()
                .accessibilityIdentifier("transactionGasPriceField")
            Text(Strings.gwei)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let validationBasisWarning {
                validationWarning(validationBasisWarning)
            }
            if let maximumNetworkFeeWarning {
                validationWarning(
                    maximumNetworkFeeWarning,
                    identifier: "transactionMaximumNetworkFeeWarning"
                )
            }
        }
    }

    private var eip1559FeeEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(Strings.networkFees).fontWeight(.medium)
                Spacer()
                if shouldOfferSuggestedEIP1559Fees {
                    Button(
                        Strings.useSuggestedFees,
                        action: resetEIP1559Fees
                    )
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("useSuggestedTransactionFees")
                }
            }

            feeField(
                title: Strings.maxPriorityFee,
                placeholder: Strings.customMaxPriorityFee,
                text: manuallyEditedFeeBinding(
                    $maxPriorityFee,
                    field: .priority
                ),
                identifier: "transactionMaxPriorityFeeField"
            )
            feeField(
                title: Strings.maxFee,
                placeholder: Strings.customMaxFee,
                text: manuallyEditedFeeBinding(
                    $maxFee,
                    field: .cap
                ),
                identifier: "transactionMaxFeeField"
            )

            HStack {
                Text(Strings.currentBaseFee)
                Spacer()
                Text(baseFeeText(currentBaseFeePerGas))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .font(.caption)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("transactionCurrentBaseFee")

            if nextBaseFeePerGas != nil {
                HStack {
                    Text(Strings.nextBaseFeeValidation)
                    Spacer()
                    Text(baseFeeText(nextBaseFeePerGas))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .font(.caption)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("transactionValidationBaseFee")
            }

            if let capWarning {
                Text(capWarning)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("transactionFeeCapWarning")
            }
            if let eip1559StructuralWarning {
                validationWarning(eip1559StructuralWarning)
            }
            if let validationBasisWarning {
                validationWarning(validationBasisWarning)
            }
            if let maximumNetworkFeeWarning {
                validationWarning(
                    maximumNetworkFeeWarning,
                    identifier: "transactionMaximumNetworkFeeWarning"
                )
            }
        }
    }

    private func feeField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .decimalInputKeyboard()
                .accessibilityIdentifier(identifier)
            Text(Strings.gwei)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var nonceEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Strings.nonce).fontWeight(.medium)
                Spacer()
                if let suggestedNonce, suggestedNonce != nonce {
                    Button(
                        Strings.resetTo + " " + suggestedNonce,
                        action: resetNonce
                    )
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            TextField(Strings.customNonce, text: $nonce)
                .textFieldStyle(.roundedBorder)
                .numberInputKeyboard()
                .accessibilityIdentifier("transactionNonceField")
        }
    }

    private func baseFeeText(_ value: BigUInt?) -> String {
        guard let value,
              let gwei = Transaction.editableGwei(fromWei: value)
        else {
            return Strings.calculating.withEllipsis
        }
        return "\(gwei) \(Strings.gwei)"
    }

    private func validationBasisDescription(_ value: BigUInt) -> String {
        let label = nextBaseFeePerGas == nil
            ? Strings.currentBaseFee
            : Strings.nextBaseFeeValidation
        return "\(label): \(baseFeeText(value))"
    }

    private func validationWarning(
        _ message: String,
        identifier: String = "transactionFeeValidationWarning"
    ) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(identifier)
    }

    private func resetGasPrice() {
        guard let suggestedGasPriceText,
              let automaticSuggestedFeeProvenance else { return }
        gasPrice = suggestedGasPriceText
        workingFeeProvenance = automaticSuggestedFeeProvenance
    }

    private func resetEIP1559Fees() {
        guard let suggested = suggestedEIP1559Texts,
              let automaticSuggestedFeeProvenance else { return }
        maxPriorityFee = suggested.priority
        maxFee = suggested.cap
        workingFeeProvenance = automaticSuggestedFeeProvenance
    }

    private func resetNonce() {
        guard let suggestedNonce else { return }
        nonce = suggestedNonce
    }

    private func cancel() {
        completion(nil)
    }

    private func commit() {
        guard canCommit else { return }

        let feeChanged: Bool
        switch feeMode {
        case .legacy:
            feeChanged = gasPrice != initialGasPriceText
        case .eip1559:
            feeChanged =
                maxPriorityFee != initialMaxPriorityFeeText ||
                maxFee != initialMaxFeeText
        }

        let nonceEdit = nonce == initialNonceText ? nil : UInt(nonce)
        let provenanceChanged =
            workingFeeProvenance != initialFeeProvenance
        guard (feeChanged || provenanceChanged),
              let candidateFee else {
            completion(Transaction.Edits(nonce: nonceEdit))
            return
        }

        completion(
            Transaction.Edits(
                preparedFee: candidateFee,
                source: workingFeeProvenance.dominantSource(
                    for: candidateFee
                ),
                replacementFeeProvenance: workingFeeProvenance,
                restoresSuggestedFee:
                    candidateFee == suggestedFee &&
                    workingFeeProvenance ==
                        automaticSuggestedFeeProvenance,
                nonce: nonceEdit
            )
        )
    }

    private func manuallyEditedFeeBinding(
        _ binding: Binding<String>,
        field: EIP1559FeeField
    ) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue },
            set: { value in
                if workingFeeProvenance.maxPriorityFeePerGas == .slider ||
                    workingFeeProvenance.maxFeePerGas == .slider {
                    workingFeeProvenance =
                        TransactionFeeProvenance(
                            maxPriorityFeePerGas: .manual,
                            maxFeePerGas: .manual
                        )
                } else {
                    switch field {
                    case .priority:
                        workingFeeProvenance.maxPriorityFeePerGas =
                            .manual
                    case .cap:
                        workingFeeProvenance.maxFeePerGas = .manual
                    }
                }
                binding.wrappedValue = value
            }
        )
    }

    private var manuallyEditedLegacyFeeBinding: Binding<String> {
        Binding(
            get: { gasPrice },
            set: { value in
                workingFeeProvenance =
                    TransactionFeeProvenance(gasPrice: .manual)
                gasPrice = value
            }
        )
    }

    private static func exactWei(fromGwei rawText: String) -> BigUInt? {
        let text = rawText.replacingOccurrences(of: ",", with: ".")
        guard !text.isEmpty,
              text.utf8.count <= maximumExactGweiTextLength else {
            return nil
        }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2,
              parts.allSatisfy({ part in
                  part.unicodeScalars.allSatisfy {
                      (48...57).contains($0.value)
                  }
              }),
              parts.contains(where: { !$0.isEmpty }),
              parts.count < 2 || parts[1].count <= 9 else {
            return nil
        }
        return Transaction.feeWei(fromGwei: text)
    }

    static func maximumNetworkFeeFitsUInt256(
        gasLimit: BigUInt?,
        fee: PreparedTransactionFee
    ) -> Bool {
        guard let gasLimit else { return true }
        return fee.maximumNetworkFee(gasLimit: gasLimit) != nil
    }
}

private extension View {

    func decimalInputKeyboard() -> some View {
#if canImport(UIKit)
        return keyboardType(.decimalPad)
#else
        return self
#endif
    }

    func numberInputKeyboard() -> some View {
#if canImport(UIKit)
        return keyboardType(.numberPad)
#else
        return self
#endif
    }

}
