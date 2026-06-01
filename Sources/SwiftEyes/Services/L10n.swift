import Foundation

enum L10n {
    static var lang: String { EyesConfig.shared.language }

    private static let table: [String: [String: String]] = [
        "zh": [
            "appearance": "外观",
            "eye_size": "眼睛大小",
            "pupil_size": "瞳孔大小",
            "eye_gap": "眼距",
            "pupil_too_large": "瞳孔太大，无法移动",
            "general": "通用",
            "launch_at_login": "开机自启",
            "launch_at_login_hint": "需要 .app bundle 才能启用开机自启（请使用 Xcode 构建）",
            "terminal_app": "终端应用",
            "select_terminal": "选择终端",
            "terminal_path": "终端路径",
            "browse": "浏览...",
            "shortcuts": "快捷说明",
            "shortcut_left_eye": "左眼点击 → 在 Finder 当前路径打开终端",
            "shortcut_right_eye": "右眼点击 → 切换防睡眠模式（激活时高光变红）",
            "shortcut_left_click": "左键按下 → 左眼眨眼，右键按下 → 右眼眨眼",
            "shortcut_right_click": "右键 → 打开菜单",
            "language": "语言",
            "menu_path_label": "当前路径: %@",
            "menu_copy_path": "复制路径",
            "menu_open_terminal": "在此打开终端",
            "menu_sleep_on": "防睡眠: 开启",
            "menu_sleep_off": "防睡眠: 关闭",
            "menu_settings": "设置...",
            "menu_refresh": "刷新位置",
            "menu_quit": "退出 SwiftEyes",
            "settings_title": "SwiftEyes 设置",
            "none": "无",
        ],
        "en": [
            "appearance": "Appearance",
            "eye_size": "Eye Size",
            "pupil_size": "Pupil Size",
            "eye_gap": "Eye Gap",
            "pupil_too_large": "Pupil too large to move",
            "general": "General",
            "launch_at_login": "Launch at Login",
            "launch_at_login_hint": "Requires .app bundle to enable launch at login (build with Xcode)",
            "terminal_app": "Terminal App",
            "select_terminal": "Select Terminal",
            "terminal_path": "Terminal Path",
            "browse": "Browse...",
            "shortcuts": "Shortcuts",
            "shortcut_left_eye": "Left eye click → Open terminal at Finder path",
            "shortcut_right_eye": "Right eye click → Toggle sleep prevention (red glow when active)",
            "shortcut_left_click": "Left-click → Left eye blinks, Right-click → Right eye blinks",
            "shortcut_right_click": "Right-click → Context menu",
            "language": "Language",
            "menu_path_label": "Current Path: %@",
            "menu_copy_path": "Copy Path",
            "menu_open_terminal": "Open Terminal Here",
            "menu_sleep_on": "Prevent Sleep: On",
            "menu_sleep_off": "Prevent Sleep: Off",
            "menu_settings": "Settings...",
            "menu_refresh": "Refresh Position",
            "menu_quit": "Quit SwiftEyes",
            "settings_title": "SwiftEyes Settings",
            "none": "None",
        ]
    ]

    static func tr(_ key: String) -> String {
        table[lang]?[key] ?? table["en"]?[key] ?? key
    }

    static func tr(_ key: String, _ args: CVarArg...) -> String {
        let fmt = tr(key)
        return String(format: fmt, arguments: args)
    }
}
