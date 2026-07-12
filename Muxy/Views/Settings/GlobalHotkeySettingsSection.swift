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

    private var triggerBinding: Binding<GlobalHotkeyTrigger> {
        Binding(
            get: { GlobalHotkeyTrigger(rawValue: triggerRaw) ?? GlobalHotkeyPreferences.defaultTrigger },
            set: { triggerRaw = $0.rawValue }
        )
    }

    private var intervalBinding: Binding<Double> {
        Binding(
            get: {
                GlobalHotkeyPreferences.clampedDoubleTapIntervalMilliseconds(doubleTapIntervalMilliseconds)
            },
            set: { newValue in
                doubleTapIntervalMilliseconds = GlobalHotkeyPreferences.clampedDoubleTapIntervalMilliseconds(newValue)
            }
        )
    }

    private var intervalLabel: String {
        "\(Int(intervalBinding.wrappedValue.rounded())) ms"
    }

    var body: some View {
        SettingsSection(
            "Global Hotkey",
            footer: "Modifier-only double taps use a dedicated event detector rather than standard app shortcut bindings. "
                + "When Toggle to Hide is off, the hotkey only shows the hotkey workspace."
        ) {
            SettingsToggleRow(label: "Enable Global Hotkey", isOn: $isEnabled)

            SettingsRow("Trigger") {
                Picker("", selection: triggerBinding) {
                    ForEach(GlobalHotkeyTrigger.allCases) { trigger in
                        Text(trigger.title).tag(trigger)
                    }
                }
                .labelsHidden()
                .frame(width: SettingsMetrics.controlWidth, alignment: .trailing)
                .disabled(!isEnabled)
            }

            SettingsRow("Double Tap Interval") {
                HStack(spacing: UIMetrics.spacing3) {
                    Slider(
                        value: intervalBinding,
                        in: GlobalHotkeyPreferences.minimumDoubleTapIntervalMilliseconds
                            ... GlobalHotkeyPreferences.maximumDoubleTapIntervalMilliseconds,
                        step: GlobalHotkeyPreferences.doubleTapIntervalStepMilliseconds
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
