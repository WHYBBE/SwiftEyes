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

    var body: some View {
        Form {
            Section("外观") {
                HStack {
                    Text("眼睛大小")
                    Slider(value: $config.eyeRadius, in: 6...18, step: 1)
                    Text("\(Int(config.eyeRadius))").frame(width: 28)
                }
                HStack {
                    Text("瞳孔大小")
                    Slider(value: $config.pupilRadius, in: 2...10, step: 0.5)
                    Text("\(config.pupilRadius, specifier: "%.1f")").frame(width: 36)
                }
                HStack {
                    Text("眼距")
                    Slider(value: $config.eyeGap, in: 0...20, step: 1)
                    Text("\(Int(config.eyeGap))").frame(width: 28)
                }

                if config.pupilRadius >= config.eyeRadius - 1 {
                    Text("瞳孔太大，无法移动").foregroundColor(.orange).font(.caption)
                }
            }

            Section("通用") {
                Toggle("开机自启", isOn: $config.launchAtLogin)
                    .disabled(!config.isInAppBundle)
                if !config.isInAppBundle {
                    Text("需要 .app bundle 才能启用开机自启（请使用 Xcode 构建）")
                        .foregroundColor(.secondary).font(.caption)
                }
            }

            Section("终端应用") {
                Picker("选择终端", selection: $terminalPath) {
                    ForEach(commonTerminals, id: \.1) { name, path in
                        Text(name).tag(path)
                    }
                }

                TextField("终端路径", text: $terminalPath)
                    .textFieldStyle(.roundedBorder)

                Button("浏览...") {
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

            Section("快捷说明") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("左眼点击 → 在 Finder 当前路径打开终端")
                    Text("右眼点击 → 切换防睡眠模式（激活时高光变红）")
                    Text("左键按下 → 左眼眨眼，右键按下 → 右眼眨眼")
                    Text("右键 → 打开菜单")
                }
                .font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 400)
    }
}
