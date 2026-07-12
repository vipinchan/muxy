import AppKit
import SwiftUI

private struct HotkeyWorkspaceEnvironmentKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isHotkeyWorkspace: Bool {
        get { self[HotkeyWorkspaceEnvironmentKey.self] }
        set { self[HotkeyWorkspaceEnvironmentKey.self] = newValue }
    }
}

enum AppSidebarVibrancy {
    static let material = NSVisualEffectView.Material.sidebar
    static let blendingMode = NSVisualEffectView.BlendingMode.behindWindow
    static let state = NSVisualEffectView.State.active
    static let themeOverlayOpacity = 0.8
}

struct AppSidebarBackground: View {
    let style: AppBackgroundStyle
    let isFullScreen: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.isHotkeyWorkspace) private var isHotkeyWorkspace

    private var usesVibrancy: Bool {
        guard !isHotkeyWorkspace else { return false }
        return AppSidebarVibrancyPolicy.isActive(
            style: style,
            reduceTransparency: reduceTransparency,
            increaseContrast: colorSchemeContrast == .increased,
            isFullScreen: isFullScreen
        )
    }

    var body: some View {
        Group {
            if usesVibrancy {
                ZStack {
                    SidebarVisualEffectView()
                    MuxyTheme.bg.opacity(AppSidebarVibrancy.themeOverlayOpacity)
                }
            } else {
                MuxyTheme.bg
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct SidebarVisualEffectView: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSVisualEffectView {
        configured(NSVisualEffectView())
    }

    func updateNSView(_ view: NSVisualEffectView, context _: Context) {
        configured(view)
    }

    @discardableResult
    private func configured(_ view: NSVisualEffectView) -> NSVisualEffectView {
        view.material = AppSidebarVibrancy.material
        view.blendingMode = AppSidebarVibrancy.blendingMode
        view.state = AppSidebarVibrancy.state
        return view
    }
}
