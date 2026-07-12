import AppKit
import CoreGraphics
import SwiftUI

@MainActor
private final class HotkeyWorkspaceModel {
    let appState: AppState
    let projectStore: ProjectStore
    let worktreeStore: WorktreeStore
    let projectGroupStore: ProjectGroupStore
    let remoteDeviceStore: RemoteDeviceStore
    let browserProfileStore: BrowserProfileStore
    let browserHistoryStore: BrowserHistoryStore

    init() {
        let environment = AppEnvironment.live
        let projectStore = ProjectStore(persistence: environment.projectPersistence)
        let worktreeStore = WorktreeStore(
            persistence: environment.worktreePersistence,
            projects: projectStore.projects
        )
        let remoteDeviceStore = RemoteDeviceStore(
            persistence: environment.remoteDevicePersistence
        )
        let browserProfileStore = BrowserProfileStore(
            persistence: environment.browserProfilePersistence
        )
        let browserHistoryStore = BrowserHistoryStore(
            persistence: environment.browserHistoryPersistence
        )
        let projectGroupStore = ProjectGroupStore(
            persistence: environment.projectGroupPersistence,
            remoteDeviceStore: remoteDeviceStore
        )
        let appState = AppState(
            selectionStore: UserDefaultsActiveProjectSelectionStore(
                projectKey: "muxy.hotkey.activeProjectID",
                worktreesKey: "muxy.hotkey.activeWorktreeIDs"
            ),
            terminalViews: environment.terminalViews,
            workspacePersistence: FileWorkspacePersistence(
                fileURL: MuxyFileStorage.fileURL(filename: "hotkey-workspaces.json")
            )
        )
        appState.restoreSelection(
            projects: projectStore.projects,
            worktrees: worktreeStore.worktrees,
            skippingProjectIDs: projectGroupStore.activeRemoteProjectIDs
        )

        self.appState = appState
        self.projectStore = projectStore
        self.worktreeStore = worktreeStore
        self.projectGroupStore = projectGroupStore
        self.remoteDeviceStore = remoteDeviceStore
        self.browserProfileStore = browserProfileStore
        self.browserHistoryStore = browserHistoryStore
    }

    func ensureWorkspaceReady() {
        if appState.activeProjectID == nil {
            _ = HomeProjectService.openHomeTab(
                appState: appState,
                worktreeStore: worktreeStore,
                projectGroupStore: projectGroupStore
            )
        }
        guard let projectID = appState.activeProjectID else { return }
        if !appState.hasTabs(for: projectID) {
            appState.createTab(projectID: projectID)
        }
    }
}

private final class HotkeyWorkspaceWindow: NSWindow {
    var suppressConfiguratorClose = true

    override func close() {
        if suppressConfiguratorClose {
            suppressConfiguratorClose = false
            return
        }
        super.close()
    }
}

@MainActor
final class HotkeyWindowController: NSObject, NSWindowDelegate {
    static let shared = HotkeyWindowController()

    private var window: HotkeyWorkspaceWindow?
    private var model: HotkeyWorkspaceModel?
    private var previousApplication: NSRunningApplication?
    private var fullScreenShortcutMonitor: Any?
    private var isFullScreenTransitioning = false
    private var pendingHideAfterFullScreenExit = false

    private(set) var isPresented = false

    private static let hotkeyCollectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces,
        .fullScreenAuxiliary,
        .transient,
        .ignoresCycle,
    ]

    private static let hotkeyWindowLevel = NSWindow.Level(
        rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) - 2
    )

    override private init() {
        super.init()
    }

    func prepareWhenMainWindowAvailable(remainingAttempts: Int = 20) {
        guard window == nil else { return }
        guard AppDelegate.mainAppWindow() != nil else {
            guard remainingAttempts > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.prepareWhenMainWindowAvailable(remainingAttempts: remainingAttempts - 1)
            }
            return
        }
        createWindow()
    }

    func toggle() {
        isPresented ? hide() : show()
    }

    func show() {
        if window == nil {
            prepareWhenMainWindowAvailable()
        }
        guard let window, let model else { return }

        model.ensureWorkspaceReady()
        capturePreviousApplication()
        pendingHideAfterFullScreenExit = false

        if !window.styleMask.contains(.fullScreen), !isFullScreenTransitioning {
            applyHotkeyPresentation(to: window)
            window.setFrame(hotkeyFrame(), display: true)
        }

        isPresented = true
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard isPresented, let window else { return }
        if window.styleMask.contains(.fullScreen) || isFullScreenTransitioning {
            pendingHideAfterFullScreenExit = true
            if window.styleMask.contains(.fullScreen), !isFullScreenTransitioning {
                window.toggleFullScreen(nil)
            }
            return
        }
        finishHide()
    }

    func toggleNativeFullScreen() {
        guard let window else { return }
        window.toggleFullScreen(nil)
    }

    private func createWindow() {
        guard window == nil else { return }

        let model = HotkeyWorkspaceModel()
        let window = HotkeyWorkspaceWindow(
            contentRect: hotkeyFrame(),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.identifier = ShortcutContext.hotkeyWindowIdentifier
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovable = false
        window.isMovableByWindowBackground = false
        applyHotkeyPresentation(to: window)
        installFullScreenShortcutMonitor(for: window)

        let rootView = MainWindow()
            .environment(model.appState)
            .environment(model.projectStore)
            .environment(model.worktreeStore)
            .environment(model.projectGroupStore)
            .environment(model.remoteDeviceStore)
            .environment(model.browserProfileStore)
            .environment(model.browserHistoryStore)
            .environment(SSHConnectionService.shared)
            .environment(GhosttyService.shared)
            .environment(MuxyConfig.shared)
            .environment(ThemeService.shared)
            .environment(ExtensionStore.shared)
            .environment(ExtensionSettingsStore.shared)
            .preferredColorScheme(MuxyTheme.colorScheme)

        window.contentViewController = NSHostingController(rootView: rootView)
        window.orderOut(nil)

        self.model = model
        self.window = window

        // MainWindow embeds WindowConfigurator, which assumes a single WindowGroup main window.
        // It will try to relabel this window as the main window and close it as a duplicate.
        // HotkeyWorkspaceWindow suppresses that one close; after the configurator pass, restore
        // the dedicated hotkey identity and apply the same native chrome without the quit hook.
        DispatchQueue.main.async { [weak self, weak window] in
            DispatchQueue.main.async {
                guard let self, let window else { return }
                self.finalizeWindowConfiguration(window)
            }
        }
    }

    private func finalizeWindowConfiguration(_ window: HotkeyWorkspaceWindow) {
        window.identifier = ShortcutContext.hotkeyWindowIdentifier
        window.suppressConfiguratorClose = false
        window.delegate = self
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.isMovable = false
        window.isMovableByWindowBackground = false
        WindowConfigurator.disableWindowTabbing(for: window)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = MuxyTheme.nsBg.cgColor
        WindowConfigurator.repositionTrafficLights(in: window)
        WindowConfigurator.hideTitlebarDecorationView(in: window)
        WindowConfigurator.neutralizeSafeAreaInsets(in: window)

        if let closeButton = window.standardWindowButton(.closeButton) {
            closeButton.target = self
            closeButton.action = #selector(handleCloseButton(_:))
        }
        applyHotkeyPresentation(to: window)
        window.orderOut(nil)
    }

    private func installFullScreenShortcutMonitor(for window: NSWindow) {
        guard fullScreenShortcutMonitor == nil else { return }
        fullScreenShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak window] event in
            guard let self,
                  let window,
                  window.isKeyWindow,
                  ShortcutContext.isHotkeyWindow(window),
                  KeyBindingStore.shared.combo(for: .toggleFullScreen).matches(event: event)
            else { return event }
            self.toggleNativeFullScreen()
            return nil
        }
    }

    private func applyHotkeyPresentation(to window: NSWindow) {
        window.collectionBehavior = Self.hotkeyCollectionBehavior
        window.level = Self.hotkeyWindowLevel
    }

    private func prepareForNativeFullScreen(_ window: NSWindow) {
        var behavior = window.collectionBehavior
        behavior.remove(.canJoinAllSpaces)
        behavior.remove(.fullScreenAuxiliary)
        behavior.remove(.transient)
        behavior.insert(.fullScreenPrimary)
        window.collectionBehavior = behavior
        window.level = .normal
    }

    private func capturePreviousApplication() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            previousApplication = nil
            return
        }
        previousApplication = frontmost
    }

    private func finishHide() {
        window?.orderOut(nil)
        isPresented = false
        pendingHideAfterFullScreenExit = false

        let applicationToRestore = previousApplication
        previousApplication = nil
        guard let applicationToRestore, !applicationToRestore.isTerminated else { return }
        DispatchQueue.main.async {
            applicationToRestore.activate(options: [.activateIgnoringOtherApps])
        }
    }

    private func hotkeyFrame() -> NSRect {
        let screen = screenUnderMouse() ?? NSScreen.main ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else {
            return NSRect(x: 120, y: 100, width: 1200, height: 800)
        }
        let width = min(visibleFrame.width, max(900, visibleFrame.width * 0.86))
        let height = min(visibleFrame.height, max(600, visibleFrame.height * 0.82))
        return NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func screenUnderMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }

    @objc
    private func handleCloseButton(_: Any?) {
        hide()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              ShortcutContext.isHotkeyWindow(window)
        else { return }
        isFullScreenTransitioning = true
        prepareForNativeFullScreen(window)
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              ShortcutContext.isHotkeyWindow(window)
        else { return }
        isFullScreenTransitioning = false
        NotificationCenter.default.post(
            name: .windowFullScreenDidChange,
            object: window,
            userInfo: ["isFullScreen": true]
        )
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              ShortcutContext.isHotkeyWindow(window)
        else { return }
        isFullScreenTransitioning = true
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              ShortcutContext.isHotkeyWindow(window)
        else { return }
        isFullScreenTransitioning = false
        applyHotkeyPresentation(to: window)
        NotificationCenter.default.post(
            name: .windowFullScreenDidChange,
            object: window,
            userInfo: ["isFullScreen": false]
        )
        if pendingHideAfterFullScreenExit {
            finishHide()
        } else if isPresented {
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
        }
    }

    deinit {
        if let fullScreenShortcutMonitor {
            NSEvent.removeMonitor(fullScreenShortcutMonitor)
        }
    }
}
