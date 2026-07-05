import SwiftUI

struct SettingsView: View {
    @ObservedObject var config = EyesConfig.shared
    @AppStorage("terminalPath") var terminalPath: String = "/System/Applications/Utilities/Terminal.app"

    private let commonTerminals = [
        ("Terminal", "/System/Applications/Utilities/Terminal.app"),
        ("iTerm", "/Applications/iTerm.app"),
        ("Alacritty", "/Applications/Alacritty.app"),
        ("Warp", "/Applications/Warp.app"),
        ("Kitty", "/Applications/kitty.app"),
        ("Hyper", "/Applications/Hyper.app"),
    ]

    private var l: String { config.language }

    var body: some View {
        Form {
            Section(L10n.tr("appearance")) {
                sliderRow(L10n.tr("eye_size"), value: $config.eyeRadius, range: 6...18, step: 1, display: { Text("\(Int(config.eyeRadius))") }, default: 11)
                sliderRow(L10n.tr("pupil_size"), value: $config.pupilRadius, range: 2...10, step: 0.5, display: { Text("\(config.pupilRadius, specifier: "%.1f")") }, default: 5)
                sliderRow(L10n.tr("eye_gap"), value: $config.eyeGap, range: 0...20, step: 1, display: { Text("\(Int(config.eyeGap))") }, default: 6)

                if config.pupilRadius >= config.eyeRadius - 1 {
                    Text(L10n.tr("pupil_too_large")).foregroundColor(.orange).font(.caption)
                }
            }

            Section(L10n.tr("general")) {
                Picker(L10n.tr("language"), selection: $config.language) {
                    Text("中文").tag("zh")
                    Text("English").tag("en")
                }
                Toggle(L10n.tr("launch_at_login"), isOn: $config.launchAtLogin)
                    .disabled(!config.isInAppBundle)
                if !config.isInAppBundle {
                    Text(L10n.tr("launch_at_login_hint"))
                        .foregroundColor(.secondary).font(.caption)
                }
                Picker(L10n.tr("sleep_mode"), selection: $config.sleepPersistMode) {
                    ForEach(SleepPersistMode.allCases, id: \.self) { mode in
                        Text(L10n.tr(mode.labelKey)).tag(mode)
                    }
                }
            }

            Section(L10n.tr("terminal_app")) {
                Picker(L10n.tr("select_terminal"), selection: $terminalPath) {
                    ForEach(commonTerminals, id: \.1) { name, path in
                        Text(name).tag(path)
                    }
                }

                TextField(L10n.tr("terminal_path"), text: $terminalPath)
                    .textFieldStyle(.roundedBorder)

                Button(L10n.tr("browse")) {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.application]
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.directoryURL = URL(fileURLWithPath: "/Applications")
                    if panel.runModal() == .OK, let url = panel.url {
                        terminalPath = url.path
                    }
                }
            }

            Section(L10n.tr("shortcuts")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.tr("shortcut_left_eye"))
                    Text(L10n.tr("shortcut_right_eye"))
                    Text(L10n.tr("shortcut_left_click"))
                    Text(L10n.tr("shortcut_right_click"))
                }
                .font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 420)
        .id(l)
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, display: @escaping () -> Text, default defaultValue: Double) -> some View {
        HStack(spacing: 8) {
            Text(label).frame(width: 60, alignment: .leading)
            Slider(value: value, in: range, step: step)
                .layoutPriority(1)
            display().frame(width: 36)
            Button(action: { value.wrappedValue = defaultValue }) {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .help(L10n.tr("reset"))
        }
    }
}
