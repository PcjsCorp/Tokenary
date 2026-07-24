// ∅ 2026 lil org

import UIKit
import SwiftUI

class ApproveTransactionViewController: UIViewController {
    
    private enum CellModel {
        case text(text: String, oneLine: Bool, pro: Bool)
        case textWithImage(text: String, extraText: String?, imageURL: String?, image: UIImage?)
        case gasPriceSlider
    }
    
    private struct CellLayout {
        let cellModels: [CellModel]
        let feeRows: Range<Int>
        let sliderIndex: Int?
    }

    private struct PresentedApprovalAlert {
        let token: TransactionApprovalAlertToken
        let controller: UIAlertController
    }
    
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.delegate = self
            tableView.dataSource = self
            tableView.registerReusableCell(type: MultilineLabelTableViewCell.self)
            tableView.registerReusableCell(type: ImageWithLabelTableViewCell.self)
            tableView.registerReusableCell(type: GasPriceSliderTableViewCell.self)
            let bottomOverlayHeight: CGFloat = 70
            tableView.contentInset.bottom += bottomOverlayHeight
            tableView.verticalScrollIndicatorInsets.bottom += bottomOverlayHeight
        }
    }
    
    private let ethereum = Ethereum.shared
    private let priceService = PriceService.shared
    private var gasSpeedConfiguration = GasSpeedConfiguration()
    private var sectionModels = [[CellModel]]()
    private var cellLayout: CellLayout?
    
    private var walletId: String!
    private var account: WalletAccount!
    private var chain: EthereumNetwork!
    private var completion: ((Transaction?) -> Void)!
    private var approvalCoordinator: TransactionApprovalCoordinator!
    private var approvalSnapshot: TransactionApprovalSnapshot!
    private var peerMeta: PeerMeta?
    private var balance: String?
    private var isGasSliderTracking = false
    private var gasSliderInteractionStartValue: Float?
    private var gasSliderInteractionDidMove = false
    private var needsTableReloadAfterGasSliderInteraction = false
    private var presentedApprovalAlert: PresentedApprovalAlert?
    private var pendingApprovalAlert: TransactionApprovalAlertIntent?
    private var isPresentingTransactionEditor = false
    private var isDismissingTransactionEditor = false
    private weak var transactionEditorController: UIViewController?
    private var isViewVisible = false

    private var transaction: Transaction {
        approvalSnapshot.transaction
    }
    
    @IBOutlet weak var okButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    static func with(transaction: Transaction, chain: EthereumNetwork, account: WalletAccount, walletId: String, peerMeta: PeerMeta?, completion: @escaping (Transaction?) -> Void) -> ApproveTransactionViewController {
        let new = instantiate(ApproveTransactionViewController.self, from: .main)
        new.walletId = walletId
        new.chain = chain
        new.completion = completion
        new.account = account
        new.peerMeta = peerMeta
        new.approvalCoordinator = TransactionApprovalCoordinator(
            transaction: transaction,
            network: chain,
            authenticationPolicy: .required
        )
        new.approvalSnapshot = new.approvalCoordinator.snapshot
        new.approvalCoordinator.onOutput = { [weak new] output in
            new?.handleApprovalOutput(output)
        }
        return new
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        okButton.setTitle(Strings.ok, for: .normal)
        cancelButton.setTitle(Strings.cancel, for: .normal)
        
        priceService.update()
        configureAdaptiveLargeTitle(Strings.sendTransaction, tableView: tableView)
        let editTransactionItem = UIBarButtonItem(
            image: Images.preferences,
            style: .plain,
            target: self,
            action: #selector(editTransactionButtonTapped)
        )
        editTransactionItem.accessibilityLabel = Strings.editFees
        editTransactionItem.tintColor = .tertiaryLabel
        navigationItem.rightBarButtonItem = editTransactionItem
        isModalInPresentation = true
        sectionModels = [[]]

        updateDisplayedTransactionInfo(initially: true)
        approvalCoordinator.startPreparation(forceGasCheck: false)
        updateSpeedConfigurationState()
        
        ethereum.getBalance(network: chain, address: account.address) { [weak self] balance in
            self?.balance = balance.eth(shortest: true) + " " + (self?.chain.symbol ?? "")
            self?.updateDisplayedTransactionInfo(initially: false)
        }
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return screenshotMode ? true : super.prefersHomeIndicatorAutoHidden
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateAdaptiveLargeTitleLayout(Strings.sendTransaction, tableView: tableView)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isViewVisible = true
        presentPendingApprovalAlertIfNeeded()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isViewVisible = false
    }
    
    @objc private func editTransactionButtonTapped() {
        guard let snapshot = approvalSnapshot else { return }
        guard snapshot.canEdit,
              transactionEditorController == nil,
              !isPresentingTransactionEditor,
              !isDismissingTransactionEditor else {
            return
        }
        let transaction = snapshot.transaction
        let editTransactionView = EditTransactionView(
            initialTransaction: transaction,
            chain: chain,
            suggestedNonce:
                snapshot.suggestedNonce ?? transaction.decimalNonceString,
            suggestedFee: snapshot.latestWalletSuggestedFee,
            completion: { [weak self] edits in
                guard let self else { return }
                guard let edits else {
                    self.dismissTransactionEditor()
                    return
                }
                let previousTransaction = self.transaction
                guard self.approvalCoordinator.apply(edits: edits) else {
                    self.dismissTransactionEditor()
                    return
                }
                self.gasSpeedConfiguration.commitAppliedEdits(
                    edits,
                    from: previousTransaction,
                    to: self.transaction
                )
                let finishEditing = { [weak self] in
                    guard let self else { return }
                    self.updateDisplayedTransactionInfo(initially: false)
                    self.updateSpeedConfigurationState()
                    self.approvalCoordinator.startPreparation(
                        forceGasCheck: true
                    )
                }
                self.dismissTransactionEditor(completion: finishEditing)
            }
        )
        let hostingController = UIHostingController(rootView: editTransactionView)
        hostingController.modalPresentationStyle = .popover
#if os(visionOS)
        hostingController.preferredContentSize = CGSize(width: 340, height: 500)
#else
        hostingController.preferredContentSize = CGSize(width: 340, height: 440)
#endif
        if let hostingController = hostingController.popoverPresentationController {
            hostingController.permittedArrowDirections = [.up]
            hostingController.barButtonItem = navigationItem.rightBarButtonItem
            hostingController.delegate = self
        }
        transactionEditorController = hostingController
        isPresentingTransactionEditor = true
        present(hostingController, animated: true) { [weak self] in
            guard let self else { return }
            self.isPresentingTransactionEditor = false
            self.presentPendingApprovalAlertIfNeeded()
        }
    }

    private func dismissTransactionEditor(
        completion: @escaping () -> Void = {}
    ) {
        guard let transactionEditorController else {
            completion()
            presentPendingApprovalAlertIfNeeded()
            return
        }

        isDismissingTransactionEditor = true
        transactionEditorController.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            self.transactionEditorController = nil
            self.isDismissingTransactionEditor = false
            completion()
            self.presentPendingApprovalAlertIfNeeded()
        }
    }
    
    private func handleApprovalOutput(
        _ output: TransactionApprovalOutput
    ) {
        switch output {
        case .snapshot(let snapshot):
            installApprovalSnapshot(snapshot)
        case .verifiedFeeEstimate(let estimate):
            installVerifiedFeeEstimate(estimate)
        case .authenticationRequest(let token):
            authenticate(token: token)
        case .alert(let intent):
            receiveApprovalAlert(intent)
        case .editorRequest:
            editTransactionButtonTapped()
        case .completion(let result):
            completeApproval(with: result)
        }
    }

    private func installApprovalSnapshot(
        _ snapshot: TransactionApprovalSnapshot
    ) {
        approvalSnapshot = snapshot
        reconcileApprovalAlertState()
        gasSpeedConfiguration.synchronizeSelectedSliderPosition(
            with: snapshot.transaction
        )
        updateDisplayedTransactionInfo(initially: false)
        updateSpeedConfigurationState()
    }

    private func installVerifiedFeeEstimate(
        _ estimate: GasService.Estimate
    ) {
        gasSpeedConfiguration.applyFetchedEstimate(estimate)
    }

    private func authenticate(
        token: TransactionApprovalRequestToken
    ) {
        LocalAuthentication.attempt(
            reason: Strings.sendTransaction,
            presentPasswordAlertFrom: self,
            passwordReason: Strings.sendTransaction
        ) { [weak self] succeeded in
            self?.approvalCoordinator.authenticationCompleted(
                token: token,
                succeeded: succeeded
            )
        }
    }

    private func completeApproval(with result: Transaction?) {
        pendingApprovalAlert = nil
        if let presentedApprovalAlert {
            self.presentedApprovalAlert = nil
            presentedApprovalAlert.controller.dismiss(animated: false)
        }
        isGasSliderTracking = false
        gasSliderInteractionStartValue = nil
        gasSliderInteractionDidMove = false
        needsTableReloadAfterGasSliderInteraction = false
        completion(result)
    }

    private func receiveApprovalAlert(
        _ intent: TransactionApprovalAlertIntent
    ) {
        guard approvalCoordinator.isCurrentAlert(intent.token) else {
            return
        }
        pendingApprovalAlert = intent
        presentPendingApprovalAlertIfNeeded()
    }

    private func reconcileApprovalAlertState() {
        if let pendingApprovalAlert,
           !approvalCoordinator.isCurrentAlert(
               pendingApprovalAlert.token
           ) {
            self.pendingApprovalAlert = nil
        }

        guard let presentedApprovalAlert,
              !approvalCoordinator.isCurrentAlert(
                presentedApprovalAlert.token
              ) else {
            return
        }
        let token = presentedApprovalAlert.token
        let controller = presentedApprovalAlert.controller
        controller.dismiss(
            animated: true
        ) { [weak self, weak controller] in
            guard let self,
                  let controller,
                  let currentAlert = self.presentedApprovalAlert,
                  currentAlert.controller === controller,
                  currentAlert.token == token else {
                return
            }
            self.presentedApprovalAlert = nil
            self.presentPendingApprovalAlertIfNeeded()
        }
    }

    private func presentPendingApprovalAlertIfNeeded() {
        guard isViewVisible,
              viewIfLoaded?.window != nil,
              transactionEditorController == nil,
              !isPresentingTransactionEditor,
              !isDismissingTransactionEditor,
              presentedApprovalAlert == nil,
              let pendingApprovalAlert else {
            return
        }
        guard approvalCoordinator.isCurrentAlert(
            pendingApprovalAlert.token
        ) else {
            self.pendingApprovalAlert = nil
            return
        }
        self.pendingApprovalAlert = nil
        presentApprovalAlert(pendingApprovalAlert)
    }

    private func presentApprovalAlert(
        _ intent: TransactionApprovalAlertIntent
    ) {
        guard approvalCoordinator.isCurrentAlert(intent.token),
              presentedApprovalAlert == nil else {
            return
        }

        let presentation = intent.presentation
        let alert = UIAlertController(
            title: presentation.title,
            message: presentation.message,
            preferredStyle: .alert
        )
        for action in presentation.actions {
            let style: UIAlertAction.Style
            if case .cancel = action.action {
                style = .cancel
            } else {
                style = .default
            }
            alert.addAction(
                UIAlertAction(
                    title: action.title,
                    style: style
                ) { [weak self, weak alert] _ in
                    guard let alert else { return }
                    self?.dismissApprovalAlert(
                        alert,
                        intent: intent,
                        action: action.action
                    )
                }
            )
        }

        presentedApprovalAlert = PresentedApprovalAlert(
            token: intent.token,
            controller: alert
        )
        var presenter: UIViewController = self
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(alert, animated: true)
    }

    private func dismissApprovalAlert(
        _ alert: UIAlertController,
        intent: TransactionApprovalAlertIntent,
        action: TransactionApprovalAlertAction
    ) {
        guard let presentedApprovalAlert,
              presentedApprovalAlert.controller === alert,
              presentedApprovalAlert.token == intent.token else {
            return
        }
        alert.dismiss(animated: true) { [weak self, weak alert] in
            guard let self,
                  let alert,
                  let presentedApprovalAlert =
                    self.presentedApprovalAlert,
                  presentedApprovalAlert.controller === alert,
                  presentedApprovalAlert.token == intent.token else {
                return
            }
            self.presentedApprovalAlert = nil
            if self.approvalCoordinator.isCurrentAlert(intent.token) {
                self.approvalCoordinator.handleAlert(
                    token: intent.token,
                    action: action
                )
            }
            self.presentPendingApprovalAlertIfNeeded()
        }
    }
    
    private func makeCellLayout() -> CellLayout {
        var cellModels: [CellModel] = [
            .textWithImage(text: peerMeta?.name ?? Strings.unknownWebsite, extraText: nil, imageURL: peerMeta?.iconURLString, image: nil),
            .textWithImage(text: account.nameOrCroppedAddress(walletId: walletId), extraText: balance, imageURL: nil, image: account.image),
            .textWithImage(text: chain.name, extraText: nil, imageURL: nil, image: Images.network)
        ]
        
        let price = priceService.forNetwork(chain)
        if let value = transaction.valueWithSymbol(chain: chain, price: price, withLabel: true) {
            cellModels.append(.text(text: value, oneLine: false, pro: false))
        }
        
        let feeRowsStart = cellModels.count
        cellModels.append(contentsOf: feeCellModels(price: price))
        let feeRows = feeRowsStart..<cellModels.count
        
        let sliderIndex: Int?
        if chain.isEthMainnet {
            sliderIndex = cellModels.count
            cellModels.append(.gasPriceSlider)
        } else {
            sliderIndex = nil
        }
        
        if let diplayDataInterpretation = transaction.diplayDataInterpretation {
            cellModels.append(.text(text: diplayDataInterpretation, oneLine: false, pro: true))
        }
        
        return CellLayout(
            cellModels: cellModels,
            feeRows: feeRows,
            sliderIndex: sliderIndex
        )
    }
    
    private func updateDisplayedTransactionInfo(initially: Bool) {
        if !initially, isGasSliderTracking {
            needsTableReloadAfterGasSliderInteraction = true
            okButton.isEnabled = canApproveTransaction
            navigationItem.rightBarButtonItem?.isEnabled =
                canOpenTransactionEditor
            return
        }

        let newCellLayout = makeCellLayout()
        cellLayout = newCellLayout
        sectionModels[0] = newCellLayout.cellModels
        if !initially, tableView.numberOfSections > 0 {
            tableView.reloadData()
        }
        okButton.isEnabled = canApproveTransaction
        navigationItem.rightBarButtonItem?.isEnabled =
            canOpenTransactionEditor
    }

    private var canApproveTransaction: Bool {
        approvalSnapshot.canApprove
    }

    private var canOpenTransactionEditor: Bool {
        approvalSnapshot.canEdit
    }
    
    private func refreshFeeRows() {
        guard let cellLayout else { return }
        let price = priceService.forNetwork(chain)
        let feeModels = feeCellModels(price: price)
        guard feeModels.count == cellLayout.feeRows.count else {
            updateDisplayedTransactionInfo(initially: false)
            return
        }

        for (index, model) in zip(cellLayout.feeRows, feeModels) {
            sectionModels[0][index] = model
            updateVisibleTextCell(at: index, with: model)
        }
        
        if tableView.numberOfSections > 0 {
            UIView.performWithoutAnimation {
                tableView.beginUpdates()
                tableView.endUpdates()
            }
        }
        okButton.isEnabled = canApproveTransaction
        updateGasSliderCellIfNeeded()
    }

    private func feeCellModels(price: Double?) -> [CellModel] {
        transaction.feeSummaryLines(chain: chain, price: price).map {
            .text(text: $0, oneLine: false, pro: false)
        }
    }
    
    private func updateVisibleTextCell(at row: Int, with model: CellModel) {
        guard case let .text(text, oneLine, pro) = model,
              let cell = tableView.cellForRow(at: IndexPath(row: row, section: 0)) as? MultilineLabelTableViewCell else { return }
        cell.setup(text: text, largeFont: true, oneLine: oneLine, pro: pro)
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
        gasSpeedConfiguration.synchronizeSelectedSliderPosition(
            with: transaction
        )
        updateGasSliderValueIfNeeded()
    }
    
    private func updateGasSliderValueIfNeeded() {
        guard !isGasSliderTracking else { return }
        updateGasSliderCellIfNeeded()
    }

    private func updateGasSliderCellIfNeeded() {
        guard let sliderIndex = cellLayout?.sliderIndex,
              let cell = tableView.cellForRow(
                at: IndexPath(row: sliderIndex, section: 0)
              ) as? GasPriceSliderTableViewCell else {
            return
        }

        if isSpeedConfigurationEnabled {
            let value = gasSpeedConfiguration.sliderPosition(
                for: transaction
            )
            cell.update(
                // Never move the thumb under the user's finger; the
                // guarded end-of-drag update resyncs it.
                value: isGasSliderTracking ? nil : value,
                isEnabled: true,
                detail: speedDetail()
            )
        } else {
            cell.update(
                value: nil,
                isEnabled: false,
                detail: Strings.calculating.withEllipsis
            )
        }
    }

    private func speedDetail() -> String {
        let semanticName = gasSpeedConfiguration.semanticSpeed(
            for: transaction
        ).localizedName

        let priority = gasSpeedConfiguration.speedPriorityFeePerGas(
            for: transaction
        )
        guard let priority,
              let priorityText = Transaction.editableGwei(fromWei: priority)
        else {
            return semanticName
        }
        return "\(semanticName) • \(Strings.priorityFee): " +
            "\(priorityText) \(Strings.gwei)"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.main.async { [weak self] in
            self?.navigationController?.navigationBar.sizeToFit()
        }
    }
    
    @IBAction func okButtonTapped(_ sender: Any) {
        guard canApproveTransaction else {
            okButton.isEnabled = false
            return
        }
        approvalCoordinator.approve()
    }
    
    @IBAction func cancelButtonTapped(_ sender: Any) {
        approvalCoordinator.cancel()
    }
    
}

extension ApproveTransactionViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
    
}

extension ApproveTransactionViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sectionModels[indexPath.section][indexPath.row] {
        case let .text(text, oneLine, pro):
            let cell = tableView.dequeueReusableCellOfType(MultilineLabelTableViewCell.self, for: indexPath)
            cell.setup(text: text, largeFont: true, oneLine: oneLine, pro: pro)
            return cell
        case let .textWithImage(text: text, extraText: extraText, imageURL: imageURL, image: image):
            let cell = tableView.dequeueReusableCellOfType(ImageWithLabelTableViewCell.self, for: indexPath)
            cell.setup(text: text, extraText: extraText, imageURL: imageURL, image: image)
            return cell
        case .gasPriceSlider:
            let cell = tableView.dequeueReusableCellOfType(GasPriceSliderTableViewCell.self, for: indexPath)
            var value: Double?
            let isEnabled = isSpeedConfigurationEnabled
            if isEnabled {
                value = gasSpeedConfiguration.sliderPosition(
                    for: transaction
                )
            }
            cell.setup(
                value: value,
                isEnabled: isEnabled,
                detail: value == nil
                    ? Strings.calculating.withEllipsis
                    : speedDetail(),
                delegate: self
            )
            return cell
        }
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sectionModels[section].count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionModels.count
    }
    
}

extension ApproveTransactionViewController: GasPriceSliderDelegate {

    func sliderInteractionStarted(value: Double) {
        guard approvalSnapshot.allowsMutation,
              isSpeedConfigurationEnabled else {
            return
        }
        isGasSliderTracking = true
        gasSliderInteractionStartValue = Float(value)
        gasSliderInteractionDidMove = false
        gasSpeedConfiguration.markGasSliderInteraction()
        approvalCoordinator.beginSliderInteraction()
    }

    func sliderInteractionEnded() {
        isGasSliderTracking = false
        let didChangeFee =
            approvalCoordinator.endSliderInteraction()
        let didInstallPendingQuote =
            gasSpeedConfiguration.endGasSliderInteraction(
                didChangeFee: didChangeFee
            )
        gasSliderInteractionStartValue = nil
        gasSliderInteractionDidMove = false
        if needsTableReloadAfterGasSliderInteraction {
            needsTableReloadAfterGasSliderInteraction = false
            updateDisplayedTransactionInfo(initially: false)
        }
        if didInstallPendingQuote {
            updateSpeedConfigurationState()
        }
        updateGasSliderValueIfNeeded()
    }
    
    func sliderValueChanged(value: Double) {
        guard approvalSnapshot.allowsMutation,
              let gasInfo = gasSpeedConfiguration.info else {
            return
        }
        if isGasSliderTracking,
           !gasSliderInteractionDidMove,
           let startValue = gasSliderInteractionStartValue,
           abs(Float(value) - startValue) < 0.001 {
            return
        }
        gasSliderInteractionDidMove = true
        gasSpeedConfiguration.markGasSliderInteraction()
        let didChangeFee = approvalCoordinator.setFeeForSpeed(
            value: value,
            inRelationTo: gasInfo
        )
        gasSpeedConfiguration.recordSelectedSliderPosition(
            value,
            for: transaction
        )
        if didChangeFee {
            gasSpeedConfiguration.markGasSliderFeeChange()
        }
        refreshFeeRows()
        if !isGasSliderTracking {
            let didInstallPendingQuote =
                gasSpeedConfiguration.endGasSliderInteraction(
                didChangeFee: didChangeFee
            )
            if didInstallPendingQuote {
                updateSpeedConfigurationState()
            }
        }
    }
    
}

extension ApproveTransactionViewController: UIPopoverPresentationControllerDelegate {
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }

    func presentationControllerWillDismiss(
        _ presentationController: UIPresentationController
    ) {
        guard presentationController.presentedViewController ===
                transactionEditorController else {
            return
        }
        isDismissingTransactionEditor = true
    }

    func presentationControllerDidDismiss(
        _ presentationController: UIPresentationController
    ) {
        guard isDismissingTransactionEditor else { return }
        transactionEditorController = nil
        isDismissingTransactionEditor = false
        presentPendingApprovalAlertIfNeeded()
    }
    
}
