// ∅ 2025 lil org

import Cocoa
import SafariServices
import LocalAuthentication
import WalletCore

class Agent: NSObject {
    
    enum ExternalRequest {
        case safari(SafariRequest)
    }
    
    static let shared = Agent()
    
    private let walletsManager = WalletsManager.shared
    
    private override init() { super.init() }
    private var statusBarItem: NSStatusItem!
    private lazy var hasPassword = Keychain.shared.password != nil
    private var didEnterPasswordOnStart = false
    
    private var didStartInitialLAEvaluation = false
    private var didCompleteInitialLAEvaluation = false
    private var initialExternalRequest: ExternalRequest?
    
    var statusBarButtonIsBlocked = false
    
    func start() {
        open()
        setupStatusBarItem()
    }
    
    func showInitialScreen(externalRequest: ExternalRequest?) {
        let isEvaluatingInitialLA = didStartInitialLAEvaluation && !didCompleteInitialLAEvaluation
        guard !isEvaluatingInitialLA else {
            if externalRequest != nil {
                initialExternalRequest = externalRequest
            }
            return
        }
        
        guard hasPassword else {
            let welcomeViewController = WelcomeViewController.new { [weak self] createdPassword in
                guard createdPassword else { return }
                self?.didEnterPasswordOnStart = true
                self?.didCompleteInitialLAEvaluation = true
                self?.hasPassword = true
                self?.showInitialScreen(externalRequest: externalRequest)
            }
            let windowController = Window.showNew(closeOthers: true)
            windowController.contentViewController = welcomeViewController
            return
        }
        
        guard didEnterPasswordOnStart else {
            askAuthentication(on: nil, browser: nil, onStart: true, reason: .start) { [weak self] success in
                if success {
                    self?.didEnterPasswordOnStart = true
                    self?.showInitialScreen(externalRequest: externalRequest)
                }
            }
            return
        }
        
        let request = externalRequest ?? initialExternalRequest
        initialExternalRequest = nil
        if let request = request {
            processExternalRequest(request)
        } else {
            let accountsList = instantiate(AccountsListViewController.self)
            let windowController = Window.showNew(closeOthers: accountsList.selectAccountAction == nil)
            windowController.contentViewController = accountsList
        }
    }
    
    func showApprove(windowController: NSWindowController, browser: Browser?, transaction: Transaction, account: Account, chain: EthereumNetwork, peerMeta: PeerMeta?, completion: @escaping (Transaction?) -> Void) {
        let window = windowController.window
        let approveViewController = ApproveTransactionViewController.with(transaction: transaction, chain: chain, account: account, peerMeta: peerMeta) { [weak self, weak window] transaction in
            if transaction != nil {
                self?.askAuthentication(on: window, browser: browser, onStart: false, reason: .sendTransaction) { success in
                    completion(success ? transaction : nil)
                }
            } else {
                completion(nil)
            }
        }
        windowController.contentViewController = approveViewController
    }
    
    func showApprove(windowController: NSWindowController, browser: Browser?, subject: ApprovalSubject, meta: String, account: Account, peerMeta: PeerMeta?, completion: @escaping (Bool) -> Void) {
        let window = windowController.window
        let approveViewController = ApproveViewController.with(subject: subject, meta: meta, account: account, peerMeta: peerMeta) { [weak self, weak window] result in
            if result {
                self?.askAuthentication(on: window, getBackTo: window?.contentViewController, browser: browser, onStart: false, reason: subject.asAuthenticationReason) { success in
                    completion(success)
                    (window?.contentViewController as? ApproveViewController)?.enableWaiting()
                }
            } else {
                completion(result)
            }
        }
        windowController.contentViewController = approveViewController
    }
    
    lazy private var statusBarMenu: NSMenu = {
        let menu = NSMenu(title: Strings.bigWallet)
        
        let showItem = NSMenuItem(title: Strings.showWallets, action: #selector(didSelectShowMenuItem), keyEquivalent: "")
        let safariItem = NSMenuItem(title: Strings.enableSafariExtension, action: #selector(enableSafariExtension), keyEquivalent: "")
        let mailItem = NSMenuItem(title: Strings.dropUsALine, action: #selector(didSelectMailMenuItem), keyEquivalent: "")
        let githubItem = NSMenuItem(title: Strings.viewOnGithub, action: #selector(didSelectGitHubMenuItem), keyEquivalent: "")
        let warpcastItem = NSMenuItem(title: Strings.viewOnWarpcast, action: #selector(didSelectWarpcastMenuItem), keyEquivalent: "")
        let zoraItem = NSMenuItem(title: Strings.viewOnZora, action: #selector(didSelectZoraMenuItem), keyEquivalent: "")
        let xItem = NSMenuItem(title: Strings.viewOnX, action: #selector(didSelectXMenuItem), keyEquivalent: "")
        let appStoreItem = NSMenuItem(title: Strings.rateOnTheAppStore, action: #selector(didSelectAppStoreMenuItem), keyEquivalent: "")
        let quitItem = NSMenuItem(title: Strings.quit, action: #selector(didSelectQuitMenuItem), keyEquivalent: "q")
        showItem.image = Images.zorb
        
        showItem.target = self
        safariItem.target = self
        githubItem.target = self
        warpcastItem.target = self
        zoraItem.target = self
        xItem.target = self
        appStoreItem.target = self
        mailItem.target = self
        quitItem.target = self
        
        menu.delegate = self
        menu.addItem(showItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(safariItem)
        menu.addItem(appStoreItem)
        if !Defaults.isHiddenFromMenuBar {
            menu.addItem(NSMenuItem.separator())
            let hideItem = NSMenuItem(title: Strings.hideFromMenuBar, action: #selector(didSelectHideItem), keyEquivalent: "")
            hideItem.target = self
            menu.addItem(hideItem)
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(warpcastItem)
        menu.addItem(githubItem)
        menu.addItem(zoraItem)
        menu.addItem(mailItem)
        menu.addItem(xItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)
        return menu
    }()
    
    @objc private func didSelectHideItem() {
        Defaults.isHiddenFromMenuBar = true
        statusBarItem.isVisible = false
        statusBarItem.button?.removeFromSuperview()
        statusBarItem.button?.window?.close()
    }
    
    @objc private func didSelectAppStoreMenuItem() {
        ReviewRequster.didClickAppStoreReviewButton()
    }
    
    @objc private func didSelectXMenuItem() {
        NSWorkspace.shared.open(URL.x)
    }
    
    @objc private func didSelectZoraMenuItem() {
        NSWorkspace.shared.open(URL.zora)
    }
    
    @objc private func didSelectWarpcastMenuItem() {
        NSWorkspace.shared.open(URL.warpcast)
    }
    
    @objc private func didSelectGitHubMenuItem() {
        NSWorkspace.shared.open(URL.github)
    }
    
    @objc func enableSafariExtension() {
        SFSafariApplication.showPreferencesForExtension(withIdentifier: Identifiers.safariExtensionBundle)
    }
    
    @objc private func didSelectMailMenuItem() {
        NSWorkspace.shared.open(URL.email)
    }
    
    @objc private func didSelectShowMenuItem() {
        open()
    }
    
    @objc private func didSelectQuitMenuItem() {
        NSApp.terminate(nil)
    }
    
    private func setupStatusBarItem() {
        if !Defaults.isHiddenFromMenuBar {
            let statusBar = NSStatusBar.system
            statusBarItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
            statusBarItem.button?.image = Images.statusBarIcon
            statusBarItem.button?.target = self
            statusBarItem.button?.action = #selector(statusBarButtonClicked(sender:))
            statusBarItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
            statusBarItem.isVisible = true
        }
    }
    
    @objc private func statusBarButtonClicked(sender: NSStatusBarButton) {
        guard !statusBarButtonIsBlocked, let event = NSApp.currentEvent, event.type == .rightMouseUp || event.type == .leftMouseUp else { return }
        
        statusBarItem.menu = statusBarMenu
        statusBarItem.button?.performClick(nil)
    }
    
    func open() {
        showInitialScreen(externalRequest: .none)
    }
    
    func askAuthentication(on: NSWindow?, getBackTo: NSViewController? = nil, browser: Browser?, onStart: Bool, reason: AuthenticationReason, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
        let canDoLocalAuthentication = context.canEvaluatePolicy(policy, error: &error)
        
        func showPasswordScreen() {
            let window = on ?? Window.showNew(closeOthers: onStart).window
            let passwordViewController = PasswordViewController.with(mode: .enter, reason: reason) { [weak window] success in
                if let getBackTo = getBackTo {
                    window?.contentViewController = getBackTo
                } else if let browser = browser {
                    Window.closeWindowAndActivateNext(idToClose: window?.windowNumber, specificBrowser: browser)
                } else {
                    Window.closeWindow(idToClose: window?.windowNumber)
                }
                completion(success)
            }
            window?.contentViewController = passwordViewController
        }
        
        if canDoLocalAuthentication {
            context.localizedCancelTitle = Strings.cancel
            didStartInitialLAEvaluation = true
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason.title) { [weak self] success, _ in
                DispatchQueue.main.async {
                    self?.didCompleteInitialLAEvaluation = true
                    if !success, onStart, self?.didEnterPasswordOnStart == false {
                        showPasswordScreen()
                    }
                    completion(success)
                }
            }
        } else {
            showPasswordScreen()
        }
    }

    private func processExternalRequest(_ request: ExternalRequest) {
        var windowNumber: Int?
        let action: DappRequestAction
        
        switch request {
        case .safari(let safariRequest):
            action = DappRequestProcessor.processSafariRequest(safariRequest) { _ in
                Window.closeWindowAndActivateNext(idToClose: windowNumber, specificBrowser: .safari)
            }
        }
        
        switch action {
        case .none:
            break
        case .selectAccount(let accountAction), .switchAccount(let accountAction):
            let closeOtherWindows: Bool
            if case .selectAccount = action {
                closeOtherWindows = false
            } else {
                closeOtherWindows = true
            }
            
            let windowController = Window.showNew(closeOthers: closeOtherWindows)
            windowNumber = windowController.window?.windowNumber
            let accountsList = instantiate(AccountsListViewController.self)
            accountsList.selectAccountAction = accountAction
            windowController.contentViewController = accountsList
        case .approveMessage(let action):
            let windowController = Window.showNew(closeOthers: false)
            windowNumber = windowController.window?.windowNumber
            showApprove(windowController: windowController, browser: .safari, subject: action.subject, meta: action.meta, account: action.account, peerMeta: action.peerMeta, completion: action.completion)
        case .approveTransaction(let action):
            let windowController = Window.showNew(closeOthers: false)
            windowNumber = windowController.window?.windowNumber
            showApprove(windowController: windowController, browser: .safari, transaction: action.transaction, account: action.account, chain: action.chain, peerMeta: action.peerMeta, completion: action.completion)
        case .justShowApp:
            let windowController = Window.showNew(closeOthers: true)
            windowNumber = windowController.window?.windowNumber
            let accountsList = instantiate(AccountsListViewController.self)
            windowController.contentViewController = accountsList
        case let .showMessage(message, subtitle, completion):
            let alert = Alert()
            alert.messageText = message
            alert.informativeText = subtitle
            alert.alertStyle = .informational
            alert.addButton(withTitle: Strings.ok)
            _ = alert.runModal()
            completion?()
        }
    }
    
}

extension Agent: NSMenuDelegate {
    
    func menuDidClose(_ menu: NSMenu) {
        statusBarItem.menu = nil
    }
    
}
