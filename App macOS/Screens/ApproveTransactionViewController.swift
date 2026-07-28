// ∅ 2026 lil org

import Cocoa
import LocalAuthentication

class ApproveTransactionViewController: NSViewController {
    
    @IBOutlet weak var infoTextViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var speedContainerStackView: NSStackView!
    @IBOutlet weak var gweiLabel: NSTextField!
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet var metaTextView: NSTextView!
    @IBOutlet weak var okButton: NSButton!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var editTransactionButton: NSButton!
    @IBOutlet weak var speedSlider: NSSlider!
    @IBOutlet weak var slowSpeedLabel: NSTextField!
    @IBOutlet weak var fastSpeedLabel: NSTextField!
    @IBOutlet weak var peerNameLabel: NSTextField!
    @IBOutlet weak var peerLogoImageView: NSImageView! {
        didSet {
            peerLogoImageView.wantsLayer = true
            peerLogoImageView.layer?.backgroundColor = NSColor.systemGray.withAlphaComponent(0.5).cgColor
            peerLogoImageView.layer?.cornerRadius = 5
        }
    }
    
    private let agent = Agent.shared
    private let ethereum = Ethereum.shared
    private let priceService = PriceService.shared
    private var authenticationContext: LAContext?
    private var authenticationToken: TransactionApprovalRequestToken?
    private var gasSpeedConfiguration = GasSpeedConfiguration()
    private var coordinator: TransactionApprovalCoordinator!
    private var approvalSnapshot: TransactionApprovalSnapshot!
    private var chain: EthereumNetwork!
    private var completion: ((Transaction?) -> Void)!
    private var peerMeta: PeerMeta?
    private var account: WalletAccount!
    private var walletId: String!
    private var balance: String?
    private var displayedGasSliderValue: Double?
    private var gasSliderInteractionStartValue: Double?
    private var gasSliderInteractionDidMove = false
    private var presentedApprovalAlert: (
        alert: NSAlert,
        token: TransactionApprovalAlertToken
    )?
    private var pendingApprovalAlert: TransactionApprovalAlertIntent?
    private var isEndingTransactionEditorSheet = false
    private weak var transactionEditorWindow: NSWindow?
    private var transactionEditorDismissalCompletion: (() -> Void)?

    private var transaction: Transaction {
        approvalSnapshot.transaction
    }
    
    static func with(transaction: Transaction, chain: EthereumNetwork, account: WalletAccount, walletId: String, peerMeta: PeerMeta?, completion: @escaping (Transaction?) -> Void) -> ApproveTransactionViewController {
        let new = instantiate(ApproveTransactionViewController.self)
        new.walletId = walletId
        new.account = account
        new.chain = chain
        new.completion = completion
        new.peerMeta = peerMeta
        new.coordinator = TransactionApprovalCoordinator(
            transaction: transaction,
            network: chain,
            authenticationPolicy: .required
        )
        new.approvalSnapshot = new.coordinator.snapshot
        new.coordinator.onOutput = { [weak new] output in
            new?.handleApprovalOutput(output)
        }
        return new
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        okButton.title = Strings.ok
        cancelButton.title = Strings.cancel
        
        priceService.update { [weak self] in
            self?.updateTextView()
        }
        titleLabel.stringValue = Strings.sendTransaction
        speedSlider.isContinuous = true
        speedSlider.numberOfTickMarks = 4
        speedSlider.allowsTickMarkValuesOnly = false
        speedSlider.setAccessibilityLabel(Strings.transactionSpeed)
        speedSlider.setAccessibilityHelp(Strings.transactionSpeedHint)
        speedSlider.setAccessibilityIdentifier("transactionSpeedSlider")
        editTransactionButton.setAccessibilityLabel(Strings.editFees)
        editTransactionButton.setAccessibilityIdentifier(
            "editTransactionFeesButton"
        )
        editTransactionButton.toolTip = Strings.editFees
        gweiLabel.setAccessibilityIdentifier(
            "transactionSpeedDetail"
        )
        gweiLabel.maximumNumberOfLines = 2
        gweiLabel.preferredMaxLayoutWidth = gweiLabel.frame.width
        gweiLabel.cell?.usesSingleLineMode = false
        gweiLabel.cell?.wraps = true
        gweiLabel.cell?.lineBreakMode = .byWordWrapping
        gweiLabel.cell?.truncatesLastVisibleLine = true
        _ = speedSlider.sendAction(on: [.leftMouseDown, .leftMouseDragged, .leftMouseUp])
        setSpeedConfigurationViews(enabled: false)
        updateInterface()
        coordinator.startPreparation(forceGasCheck: false)
        
        ethereum.getBalance(network: chain, address: account.address) { [weak self] balance in
            self?.balance = balance.eth(shortest: true) + " " + (self?.chain.symbol ?? "")
            self?.updateTextView()
        }
        
        if let peer = peerMeta {
            peerNameLabel.stringValue = peer.name
            if let urlString = peer.iconURLString, let url = URL(string: urlString) {
                peerLogoImageView.setRemoteImage(with: url) { [weak peerLogoImageView] didLoad in
                    if didLoad {
                        peerLogoImageView?.layer?.backgroundColor = NSColor.clear.cgColor
                        peerLogoImageView?.layer?.cornerRadius = 0
                    }
                }
            }
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.delegate = self
        view.window?.makeFirstResponder(view)
        presentPendingApprovalAlertIfNeeded()
    }

    private func handleApprovalOutput(
        _ output: TransactionApprovalOutput
    ) {
        switch output {
        case .snapshot(let snapshot):
            approvalSnapshot = snapshot
            gasSpeedConfiguration.synchronizeSelectedSliderPosition(
                with: snapshot.transaction
            )
            updateInterface()
        case .verifiedFeeEstimate(let estimate):
            gasSpeedConfiguration.applyFetchedEstimate(estimate)
        case .authenticationRequest(let token):
            authenticate(token: token)
        case .alert(let intent):
            presentOrDeferApprovalAlert(intent)
        case .editorRequest:
            presentTransactionEditor()
        case .completion(let result):
            pendingApprovalAlert = nil
            presentedApprovalAlert = nil
            transactionEditorWindow = nil
            transactionEditorDismissalCompletion = nil
            isEndingTransactionEditorSheet = false
            resetGasSliderInteraction()
            completion(result)
        }
    }

    private func authenticate(
        token: TransactionApprovalRequestToken
    ) {
        cancelAuthentication()
        guard let window = view.window else {
            coordinator.authenticationCompleted(
                token: token,
                succeeded: false
            )
            coordinator.cancel()
            return
        }
        authenticationToken = token
        authenticationContext = agent.askAuthentication(
            on: window,
            getBackTo: self,
            browser: nil,
            onStart: false,
            reason: .sendTransaction,
            onWindowClose: { [weak self] in
                self?.cancelAuthentication()
                self?.coordinator.cancel()
            }
        ) { [weak self] succeeded in
            guard let self else { return }
            if authenticationToken == token {
                authenticationContext = nil
                authenticationToken = nil
            }
            coordinator.authenticationCompleted(
                token: token,
                succeeded: succeeded
            )
        }
    }

    private func cancelAuthentication() {
        authenticationToken = nil
        authenticationContext?.invalidate()
        authenticationContext = nil
    }

    private func presentOrDeferApprovalAlert(
        _ intent: TransactionApprovalAlertIntent
    ) {
        guard coordinator.isCurrentAlert(intent.token) else { return }
        guard presentedApprovalAlert == nil,
              transactionEditorWindow == nil,
              !isEndingTransactionEditorSheet,
              var window = view.window else {
            pendingApprovalAlert = intent
            return
        }

        pendingApprovalAlert = nil
        let alert = NSAlert()
        let presentation = intent.presentation
        alert.messageText = presentation.title
        alert.informativeText = presentation.message ?? ""
        for action in presentation.actions {
            alert.addButton(withTitle: action.title)
        }
        alert.alertStyle = .informational
        presentedApprovalAlert = (alert, intent.token)

        while let attachedSheet = window.attachedSheet {
            window = attachedSheet
        }
        alert.beginSheetModal(for: window) {
            [weak self, weak alert] response in
            guard let self, let alert,
                  self.presentedApprovalAlert?.alert === alert,
                  self.presentedApprovalAlert?.token == intent.token else {
                return
            }
            self.presentedApprovalAlert = nil
            guard self.coordinator.isCurrentAlert(intent.token) else {
                self.presentPendingApprovalAlertIfNeeded()
                return
            }
            let action: TransactionApprovalAlertAction
            if response == .alertFirstButtonReturn {
                action = presentation.primaryAction.action
            } else {
                action = presentation.secondaryAction?.action ?? .cancel
            }
            self.coordinator.handleAlert(
                token: intent.token,
                action: action
            )
            self.presentPendingApprovalAlertIfNeeded()
        }
    }

    private func presentPendingApprovalAlertIfNeeded() {
        guard approvalSnapshot.phase != .finished,
              presentedApprovalAlert == nil,
              transactionEditorWindow == nil,
              !isEndingTransactionEditorSheet,
              let pendingApprovalAlert else {
            return
        }
        self.pendingApprovalAlert = nil
        guard coordinator.isCurrentAlert(pendingApprovalAlert.token) else {
            return
        }
        presentOrDeferApprovalAlert(pendingApprovalAlert)
    }

    private func endTransactionEditorSheet(
        completion: @escaping () -> Void = {}
    ) {
        guard let window = view.window,
              let sheet = window.attachedSheet else {
            completion()
            presentPendingApprovalAlertIfNeeded()
            return
        }

        isEndingTransactionEditorSheet = true
        transactionEditorDismissalCompletion = completion
        window.endSheet(sheet)
    }
    
    private func updateInterface() {
        if !chain.isEthMainnet {
            speedContainerStackView.isHidden = true
            gweiLabel.isHidden = true
            infoTextViewBottomConstraint.constant = 30
        }
        
        okButton.isEnabled = approvalSnapshot.canApprove
        editTransactionButton.isEnabled = approvalSnapshot.canEdit
        updateSpeedConfigurationState()
        updateTextView()
        updateSpeedDetail()
    }

    private var canApproveTransaction: Bool {
        approvalSnapshot.canApprove
    }
    
    private var displayedMetaAndBalance = ("", "")
    private lazy var accountImageAttachmentString = NSAttributedString.accountImageAttachment(account: account)
    
    private func updateTextView() {
        let meta = approvalDescription(
            price: priceService.forNetwork(chain)
        )
        let balanceString = balance ?? ""
        guard displayedMetaAndBalance != (meta, balanceString) else { return }
        displayedMetaAndBalance = (meta, balanceString)
        
        let fullString = NSMutableAttributedString(attributedString: accountImageAttachmentString)
        fullString.insert(NSAttributedString(string: " ", attributes: [.font: NSFont.systemFont(ofSize: 5)]), at: 0)
        let addressString = NSAttributedString(string: " " + account.nameOrCroppedAddress(walletId: walletId),
                                               attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor])
        let balanceAttributedString = NSAttributedString(string: "\n" + balanceString + "\n\n",
                                               attributes: [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.tertiaryLabelColor])
        let metaString = NSAttributedString(string: meta,
                                            attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor])
        fullString.append(addressString)
        fullString.append(balanceAttributedString)
        fullString.append(metaString)
        metaTextView.textStorage?.setAttributedString(fullString)
    }

    private func approvalDescription(price: Double?) -> String {
        var result = ["🌐 " + chain.name]
        if let value = transaction.valueWithSymbol(
            chain: chain,
            price: price,
            withLabel: false
        ) {
            result.append(value)
        }

        result.append(
            contentsOf: transaction.feeSummaryLines(
                chain: chain,
                price: price
            )
        )

        if let interpretation = transaction.diplayDataInterpretation {
            result.append(interpretation)
        }
        return result.joined(separator: "\n\n")
    }
    
    private var isSpeedConfigurationEnabled: Bool {
        gasSpeedConfiguration.isSpeedSelectionAvailable(
            for: transaction,
            on: chain,
            allowsMutation: approvalSnapshot.allowsMutation
        )
    }

    private func updateSpeedConfigurationState() {
        guard chain.isEthMainnet else { return }
        if let priorityFee = gasSpeedConfiguration.speedPriorityFeePerGas(
            for: transaction
        ) {
            gasSpeedConfiguration.installTransactionFallback(
                feePerGas: priorityFee
            )
        }
        let isEnabled = isSpeedConfigurationEnabled
        setSpeedConfigurationViews(enabled: isEnabled)
        if isEnabled {
            updateGasSliderValueIfNeeded()
        }
    }

    private func updateGasSliderValueIfNeeded() {
        guard gasSliderInteractionStartValue == nil,
              isSpeedConfigurationEnabled,
              gasSpeedConfiguration.info != nil else { return }
        gasSpeedConfiguration.synchronizeSelectedSliderPosition(
            with: transaction
        )
        let sliderValue = gasSpeedConfiguration.sliderPosition(
            for: transaction
        )
        speedSlider.doubleValue = sliderValue
        displayedGasSliderValue = sliderValue
        updateSpeedDetail(value: sliderValue)
    }

    private func setSpeedConfigurationViews(enabled: Bool) {
        slowSpeedLabel.alphaValue = enabled ? 1 : 0.5
        fastSpeedLabel.alphaValue = enabled ? 1 : 0.5
        speedSlider.isEnabled = enabled
    }

    private func updateSpeedDetail(value: Double? = nil) {
        guard chain.isEthMainnet else { return }
        let detail: (visible: String, accessibility: String)
        if value != nil || gasSpeedConfiguration.info != nil {
            detail = speedDetail()
        } else {
            detail = (
                visible: Strings.calculating.withEllipsis,
                accessibility: Strings.calculating.withEllipsis
            )
        }
        gweiLabel.stringValue = detail.visible
        gweiLabel.toolTip = detail.accessibility
        speedSlider.setAccessibilityValueDescription(detail.accessibility)
    }

    private func speedDetail() -> (visible: String, accessibility: String) {
        let semanticName = gasSpeedConfiguration.semanticSpeed(
            for: transaction
        ).localizedName

        let priority = gasSpeedConfiguration.speedPriorityFeePerGas(
            for: transaction
        )
        guard let priority,
              let priorityText = Transaction.editableGwei(fromWei: priority)
        else {
            return (visible: semanticName, accessibility: semanticName)
        }
        let fee = "\(priorityText) \(Strings.gwei)"
        return (
            visible: "\(semanticName)\n\(fee)",
            accessibility: "\(semanticName) • \(Strings.priorityFee): \(fee)"
        )
    }
    
    @IBAction func editTransactionButtonTapped(_ sender: Any) {
        presentTransactionEditor()
    }

    private func presentTransactionEditor() {
        guard let snapshot = approvalSnapshot else { return }
        guard snapshot.canEdit,
              transactionEditorWindow == nil,
              !isEndingTransactionEditorSheet else {
            return
        }
        let editTransactionView = EditTransactionView(
            initialTransaction: snapshot.transaction,
            chain: chain,
            suggestedNonce:
                snapshot.suggestedNonce ??
                snapshot.transaction.decimalNonceString,
            suggestedFee: snapshot.latestWalletSuggestedFee,
            completion: { [weak self] edits in
                guard let self else { return }
                guard let edits else {
                    self.endTransactionEditorSheet()
                    return
                }
                guard self.approvalSnapshot.canEdit else {
                    self.endTransactionEditorSheet()
                    return
                }
                let previousTransaction =
                    self.approvalSnapshot.transaction
                guard self.coordinator.apply(edits: edits) else {
                    self.endTransactionEditorSheet()
                    return
                }
                let updatedTransaction =
                    self.approvalSnapshot.transaction
                self.gasSpeedConfiguration.commitAppliedEdits(
                    edits,
                    from: previousTransaction,
                    to: updatedTransaction
                )
                self.endTransactionEditorSheet { [weak self] in
                    guard let self,
                          self.approvalSnapshot.phase != .finished else {
                        return
                    }
                    self.updateInterface()
                    self.coordinator.startPreparation(
                        forceGasCheck: true
                    )
                }
            }
        )
        let editWindow = makeHostingWindow(content: editTransactionView)
        transactionEditorWindow = editWindow
        view.window?.beginSheet(editWindow)
    }
    
    @IBAction func sliderValueChanged(_ sender: NSSlider) {
        guard approvalSnapshot.allowsMutation,
              let gasInfo = gasSpeedConfiguration.info else {
            let didInstallPendingQuote =
                finishGasSliderInteraction(
                    cancelled: true
                )
            if didInstallPendingQuote {
                updateSpeedConfigurationState()
            } else {
                updateGasSliderValueIfNeeded()
            }
            return
        }
        gasSpeedConfiguration.markGasSliderInteraction()
        coordinator.beginSliderInteraction()

        let eventType = NSApp.currentEvent?.type
        if eventType == .leftMouseDown {
            let startValue = displayedGasSliderValue ?? sender.doubleValue
            gasSliderInteractionStartValue = startValue
            gasSliderInteractionDidMove =
                abs(sender.doubleValue - startValue) >= 0.001
            if gasSliderInteractionDidMove {
                applyGasSliderValue(
                    sender.doubleValue,
                    inRelationTo: gasInfo
                )
                updateInterface()
            }
            return
        }

        if eventType == .leftMouseDragged || eventType == .leftMouseUp {
            let startValue = gasSliderInteractionStartValue ?? displayedGasSliderValue ?? sender.doubleValue
            gasSliderInteractionStartValue = startValue
            if abs(sender.doubleValue - startValue) >= 0.001 {
                gasSliderInteractionDidMove = true
            }

            guard gasSliderInteractionDidMove else {
                if eventType == .leftMouseUp {
                    let didInstallPendingQuote =
                        finishGasSliderInteraction(
                            cancelled: false
                        )
                    if didInstallPendingQuote {
                        updateSpeedConfigurationState()
                    } else {
                        updateGasSliderValueIfNeeded()
                    }
                }
                return
            }

            applyGasSliderValue(sender.doubleValue, inRelationTo: gasInfo)
            if eventType == .leftMouseUp {
                finishGasSliderInteraction(
                    cancelled: false
                )
            }
            updateInterface()
            return
        }

        let semanticValue = semanticSliderValue(
            forAccessibilityOrKeyboardCandidate: sender.doubleValue
        )
        if let displayedGasSliderValue,
           abs(semanticValue - displayedGasSliderValue) < 0.001 {
            sender.doubleValue = displayedGasSliderValue
            finishGasSliderInteraction(
                cancelled: false
            )
            updateInterface()
            return
        }
        sender.doubleValue = semanticValue
        applyGasSliderValue(semanticValue, inRelationTo: gasInfo)
        finishGasSliderInteraction(
            cancelled: false
        )
        updateInterface()
    }

    @discardableResult
    private func applyGasSliderValue(
        _ value: Double,
        inRelationTo info: GasService.Info
    ) -> Bool {
        guard approvalSnapshot.allowsMutation else { return false }
        let didChangeFee = coordinator.setFeeForSpeed(
            value: value,
            inRelationTo: info
        )
        let updatedTransaction = approvalSnapshot.transaction
        gasSpeedConfiguration.recordSelectedSliderPosition(
            value,
            for: updatedTransaction
        )
        if didChangeFee {
            gasSpeedConfiguration.markGasSliderFeeChange()
        }
        return didChangeFee
    }

    @discardableResult
    private func finishGasSliderInteraction(
        cancelled: Bool
    ) -> Bool {
        let didChangeFee = coordinator.endSliderInteraction(
            cancelled: cancelled
        )
        let didInstallPendingQuote =
            gasSpeedConfiguration.endGasSliderInteraction(
                didChangeFee: !cancelled && didChangeFee
            )
        resetGasSliderInteraction()
        return didInstallPendingQuote
    }

    private func resetGasSliderInteraction() {
        gasSliderInteractionStartValue = nil
        gasSliderInteractionDidMove = false
    }

    private func semanticSliderValue(
        forAccessibilityOrKeyboardCandidate candidate: Double
    ) -> Double {
        let tierValues = GasSpeedConfiguration.semanticSliderPositions
        guard let current = displayedGasSliderValue else {
            return tierValues.min {
                abs($0 - candidate) < abs($1 - candidate)
            } ?? candidate
        }

        if candidate > current {
            return tierValues.first { $0 > current + 0.001 } ?? 100
        }
        if candidate < current {
            return tierValues.last { $0 < current - 0.001 } ?? 0
        }
        return current
    }

    @IBAction func actionButtonTapped(_ sender: Any) {
        guard canApproveTransaction else {
            okButton.isEnabled = false
            return
        }
        coordinator.approve()
    }
    
    @IBAction func cancelButtonTapped(_ sender: NSButton) {
        coordinator.cancel()
    }
    
}

extension ApproveTransactionViewController: NSWindowDelegate {

    func windowDidResignKey(_ notification: Notification) {
        guard gasSliderInteractionStartValue != nil else { return }
        guard approvalSnapshot.allowsMutation else {
            finishGasSliderInteraction(
                cancelled: true
            )
            updateInterface()
            return
        }
        finishGasSliderInteraction(
            cancelled: false
        )
        updateInterface()
    }

    func windowDidEndSheet(_ notification: Notification) {
        guard isEndingTransactionEditorSheet else {
            if transactionEditorWindow?.sheetParent == nil {
                transactionEditorWindow = nil
            }
            presentPendingApprovalAlertIfNeeded()
            return
        }

        isEndingTransactionEditorSheet = false
        transactionEditorWindow = nil
        let completion = transactionEditorDismissalCompletion
        transactionEditorDismissalCompletion = nil
        completion?()
        presentPendingApprovalAlertIfNeeded()
    }
    
    func windowWillClose(_ notification: Notification) {
        cancelAuthentication()
        coordinator.cancel()
        endAllSheets()
    }
    
}
