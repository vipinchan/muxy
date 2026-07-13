import SwiftUI

struct GlobalHotkeySettingsSection: View {
    @AppStorage(GlobalHotkeyPreferences.enabledKey)
    private var isEnabled = GlobalHotkeyPreferences.defaultEnabled
    @AppStorage(GlobalHotkeyPreferences.triggerKey)
    private var triggerRaw = GlobalHotkeyPreferences.defaultTrigger.rawValue
    @AppStorage(GlobalHotkeyPreferences.doubleTapIntervalMillisecondsKey)
    private var doubleTapIntervalMilliseconds = GlobalHotkeyPreferences.defaultDoubleTapIntervalMilliseconds
    @AppStorage(GlobalHotkeyPreferences.toggleToHideKey)
    private var toggleToHide = GlobalHotkeyPreferences.defaultToggleToHide

    private var selectedTrigger: GlobalHotkeyTrigger {
        GlobalHotkeyTrigger(rawValue: triggerRaw) ?? GlobalHotkeyPreferences.defaultTrigger
    }

    private var intervalBinding: Binding<Double> {
        Binding(
            get: {
                GlobalHotkeyPreferences.clampedDoubleTapIntervalMilliseconds(doubleTapIntervalMilliseconds)
            },
            set: { newValue in
                let clampedValue = GlobalHotkeyPreferences.clampedDoubleTapIntervalMilliseconds(newValue)
                let step = GlobalHotkeyPreferences.doubleTapIntervalStepMilliseconds
                doubleTapIntervalMilliseconds = (clampedValue / step).rounded() * step
            }
        )
    }

    private var intervalLabel: String {
        "\(Int(intervalBinding.wrappedValue.rounded())) ms"
    }

    var body: some View {
        SettingsSection(
            "Global Hotkey",
            footer: "Double-tap the selected modifier to show the hotkey workspace. "
                + "Disable Toggle to Hide to make the hotkey show-only."
        ) {
            SettingsToggleRow(label: "Enable Global Hotkey", isOn: $isEnabled)

            SettingsRow("Trigger") {
                Menu {
                    ForEach(GlobalHotkeyTrigger.allCases) { trigger in
                        Button {
                            triggerRaw = trigger.rawValue
                        } label: {
                            if trigger == selectedTrigger {
                                Label(trigger.title, systemImage: "checkmark")
                            } else {
                                Text(trigger.title)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: UIMetrics.spacing2) {
                        Text(selectedTrigger.title)
                            .foregroundStyle(SettingsStyle.foreground)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(SettingsStyle.mutedForeground)
                    }
                    .font(.system(size: SettingsMetrics.labelFontSize))
                    .padding(.horizontal, 8)
                    .frame(width: SettingsMetrics.controlWidth, height: 26)
                    .background(SettingsStyle.surface, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(SettingsStyle.border, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(!isEnabled)
            }

            SettingsRow("Double Tap Interval") {
                HStack(spacing: UIMetrics.spacing3) {
                    Slider(
                        value: intervalBinding,
                        in: GlobalHotkeyPreferences.minimumDoubleTapIntervalMilliseconds
                            ... GlobalHotkeyPreferences.maximumDoubleTapIntervalMilliseconds
                    )
                    Text(intervalLabel)
                        .font(.system(size: SettingsMetrics.labelFontSize).monospacedDigit())
                        .foregroundStyle(SettingsStyle.mutedForeground)
                        .frame(width: 58, alignment: .trailing)
                }
                .frame(width: SettingsMetrics.controlWidth)
                .disabled(!isEnabled)
            }

            SettingsToggleRow(label: "Toggle to Hide", isOn: $toggleToHide)
                .disabled(!isEnabled)
        }
    }
}
