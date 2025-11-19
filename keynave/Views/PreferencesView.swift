//
//  PreferencesView.swift
//  keynave
//
//  Settings UI
//

import SwiftUI
import Carbon

struct PreferencesView: View {
    // Click Mode Settings
    @AppStorage("hintShortcutKeyCode") private var hintShortcutKeyCode: Int = 49 // Space
    @AppStorage("hintShortcutModifiers") private var hintShortcutModifiers: Int = cmdKey | shiftKey
    @AppStorage("hintSize") private var hintSize: Double = 12
    @AppStorage("hintColor") private var hintColor: String = "blue"
    @AppStorage("continuousClickMode") private var continuousClickMode: Bool = false
    @AppStorage("autoHintDeactivation") private var autoHintDeactivation: Bool = true
    @AppStorage("hintDeactivationDelay") private var hintDeactivationDelay: Double = 5.0
    @AppStorage("hintCharacters") private var hintCharacters: String = "asdfhjkl"
    @AppStorage("textSearchEnabled") private var textSearchEnabled: Bool = true
    @AppStorage("minSearchCharacters") private var minSearchCharacters: Int = 2
    @AppStorage("manualRefreshTrigger") private var manualRefreshTrigger: String = "rr"

    // Appearance Settings
    @AppStorage("hintBackgroundHex") private var hintBackgroundHex: String = "#3B82F6"
    @AppStorage("hintBorderHex") private var hintBorderHex: String = "#3B82F6"
    @AppStorage("hintTextHex") private var hintTextHex: String = "#FFFFFF"
    @AppStorage("highlightTextHex") private var highlightTextHex: String = "#FFFF00"
    @AppStorage("hintBackgroundOpacity") private var hintBackgroundOpacity: Double = 0.3
    @AppStorage("hintBorderOpacity") private var hintBorderOpacity: Double = 0.6

    // Scroll Mode Settings
    @AppStorage("scrollShortcutKeyCode") private var scrollShortcutKeyCode: Int = 14 // E
    @AppStorage("scrollShortcutModifiers") private var scrollShortcutModifiers: Int = optionKey
    @AppStorage("scrollArrowMode") private var scrollArrowMode: String = "select"
    @AppStorage("showScrollAreaNumbers") private var showScrollAreaNumbers: Bool = true
    @AppStorage("scrollKeys") private var scrollKeys: String = "hjkl"
    @AppStorage("scrollCommandsEnabled") private var scrollCommandsEnabled: Bool = true
    @AppStorage("scrollSpeed") private var scrollSpeed: Double = 5.0
    @AppStorage("dashSpeed") private var dashSpeed: Double = 9.0
    @AppStorage("autoScrollDeactivation") private var autoScrollDeactivation: Bool = true
    @AppStorage("scrollDeactivationDelay") private var scrollDeactivationDelay: Double = 5.0

    var body: some View {
        TabView {
            clickingTab
                .tabItem {
                    Label("Clicking", systemImage: "cursorarrow.click")
                }

            scrollingTab
                .tabItem {
                    Label("Scrolling", systemImage: "arrow.up.arrow.down")
                }

            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
        }
        .frame(width: 500, height: 500)
        .padding()
    }

    private var clickingTab: some View {
        Form {
            Section("Hotkey") {
                HStack {
                    Text("Activate Hint Mode")
                    Spacer()
                    ShortcutRecorderView(
                        keyCode: $hintShortcutKeyCode,
                        modifiers: $hintShortcutModifiers
                    )
                }
                Text("ESC - Cancel | Option - Clear search | Ctrl+Enter - Right-click")
                    .foregroundStyle(.secondary)
            }

            Section("Hint Characters") {
                HStack {
                    HStack(spacing: 4) {
                        Text("Characters")
                        helpButton(text: "Characters used to generate hints. Default is home row keys (asdfhjkl). With 8 characters, you get 64 two-letter combinations.")
                    }
                    Spacer()
                    TextField("", text: $hintCharacters)
                        .frame(width: 120)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                }
                Text("Current: \(hintCharacters.count) chars = \(hintCharacters.count * hintCharacters.count) two-letter combos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Text Search") {
                HStack {
                    HStack(spacing: 4) {
                        Text("Enable text search")
                        helpButton(text: "Search UI elements by their text content. Type element names to find and click them.")
                    }
                    Spacer()
                    Toggle("", isOn: $textSearchEnabled)
                }

                if textSearchEnabled {
                    HStack {
                        HStack(spacing: 4) {
                            Text("Minimum characters")
                            helpButton(text: "Number of characters required before text search activates. Auto-clicks when exactly one match remains.")
                        }
                        Spacer()
                        Stepper("\(minSearchCharacters)", value: $minSearchCharacters, in: 1...5)
                            .frame(width: 80)
                    }
                }

                HStack {
                    HStack(spacing: 4) {
                        Text("Manual refresh trigger")
                        helpButton(text: "Type this text to manually refresh hints. Useful if UI changed but hints didn't update. Works in both normal and continuous mode.")
                    }
                    Spacer()
                    TextField("rr", text: $manualRefreshTrigger)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.top, 4)
            }

            Section("Behavior") {
                Toggle("Continuous Click Mode", isOn: $continuousClickMode)
                Text("When enabled, hint mode stays active after clicking. Continue clicking elements until you press ESC.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if continuousClickMode {
                    HStack {
                        HStack(spacing: 4) {
                            Text("Auto-deactivation")
                            helpButton(text: "Automatically exit continuous mode after a period of inactivity.")
                        }
                        Spacer()
                        Toggle("", isOn: $autoHintDeactivation)
                    }

                    if autoHintDeactivation {
                        HStack {
                            HStack(spacing: 4) {
                                Text("Deactivation delay")
                                helpButton(text: "How long to wait before automatically exiting continuous mode.")
                            }
                            Spacer()
                            Text("\(String(format: "%.1f", hintDeactivationDelay))s")
                                .monospacedDigit()
                                .frame(width: 50)
                        }
                        Slider(value: $hintDeactivationDelay, in: 5...30, step: 0.5)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var scrollingTab: some View {
        Form {
            Section("Scrolling") {
                HStack {
                    Text("Shortcut")
                    Spacer()
                    ShortcutRecorderView(
                        keyCode: $scrollShortcutKeyCode,
                        modifiers: $scrollShortcutModifiers
                    )
                }

                HStack {
                    HStack(spacing: 4) {
                        Text("Arrow keys")
                        helpButton(text: "Controls what arrow keys do in scroll mode. 'Select' switches between scroll areas, 'Scroll' scrolls the active area directly.")
                    }
                    Spacer()
                    Picker("", selection: $scrollArrowMode) {
                        Text("Select").tag("select")
                        Text("Scroll").tag("scroll")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }

                HStack {
                    HStack(spacing: 4) {
                        Text("Show scroll area numbers")
                        helpButton(text: "Display numbered hints over scrollable areas for quick selection.")
                    }
                    Spacer()
                    Toggle("", isOn: $showScrollAreaNumbers)
                }

                HStack {
                    HStack(spacing: 4) {
                        Text("Scroll keys")
                        helpButton(text: "Four keys for left/down/up/right scrolling. Default is hjkl (vim-style).")
                    }
                    Spacer()
                    TextField("", text: $scrollKeys)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                }

                HStack {
                    HStack(spacing: 4) {
                        Text("Scroll commands")
                        helpButton(text: "Enable keyboard-based scrolling using the configured scroll keys.")
                    }
                    Spacer()
                    Toggle("", isOn: $scrollCommandsEnabled)
                }
            }

            Section("Speed") {
                VStack(alignment: .leading) {
                    Text("Scroll speed")
                    HStack {
                        Image(systemName: "tortoise")
                            .foregroundStyle(.secondary)
                        Slider(value: $scrollSpeed, in: 1...10, step: 1)
                        Image(systemName: "hare")
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading) {
                    HStack(spacing: 4) {
                        Text("Dash speed")
                        helpButton(text: "Speed when holding Shift while scrolling for faster movement.")
                    }
                    HStack {
                        Image(systemName: "tortoise")
                            .foregroundStyle(.secondary)
                        Slider(value: $dashSpeed, in: 1...10, step: 1)
                        Image(systemName: "hare")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Deactivation") {
                HStack {
                    HStack(spacing: 4) {
                        Text("Automatic scroll deactivation")
                        helpButton(text: "Automatically exit scroll mode after a period of inactivity.")
                    }
                    Spacer()
                    Toggle("", isOn: $autoScrollDeactivation)
                }

                if autoScrollDeactivation {
                    HStack {
                        HStack(spacing: 4) {
                            Text("Deactivation delay")
                            helpButton(text: "How long to wait before automatically exiting scroll mode.")
                        }
                        Spacer()
                        Text("\(String(format: "%.1f", scrollDeactivationDelay))s")
                            .monospacedDigit()
                            .frame(width: 50)
                    }
                    Slider(value: $scrollDeactivationDelay, in: 1...30, step: 0.5)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var appearanceTab: some View {
        Form {
            Section("Live Preview") {
                HintPreviewView(
                    hintText: "AJ",
                    backgroundColor: Binding(
                        get: { Color(hex: hintBackgroundHex) },
                        set: { hintBackgroundHex = $0.toHex() }
                    ),
                    borderColor: Binding(
                        get: { Color(hex: hintBorderHex) },
                        set: { hintBorderHex = $0.toHex() }
                    ),
                    textColor: Binding(
                        get: { Color(hex: hintTextHex) },
                        set: { hintTextHex = $0.toHex() }
                    ),
                    highlightColor: Binding(
                        get: { Color(hex: highlightTextHex) },
                        set: { highlightTextHex = $0.toHex() }
                    ),
                    fontSize: $hintSize,
                    backgroundOpacity: $hintBackgroundOpacity,
                    borderOpacity: $hintBorderOpacity
                )
            }

            Section("Colors") {
                ColorPicker("Background Tint", selection: Binding(
                    get: { Color(hex: hintBackgroundHex) },
                    set: { hintBackgroundHex = $0.toHex() }
                ))

                ColorPicker("Border", selection: Binding(
                    get: { Color(hex: hintBorderHex) },
                    set: { hintBorderHex = $0.toHex() }
                ))

                ColorPicker("Text", selection: Binding(
                    get: { Color(hex: hintTextHex) },
                    set: { hintTextHex = $0.toHex() }
                ))

                ColorPicker("Highlight (Matched Letters)", selection: Binding(
                    get: { Color(hex: highlightTextHex) },
                    set: { highlightTextHex = $0.toHex() }
                ))
            }

            Section("Transparency") {
                VStack(alignment: .leading) {
                    Text("Background: \(Int(hintBackgroundOpacity * 100))%")
                    Slider(value: $hintBackgroundOpacity, in: 0...1, step: 0.05)
                }

                VStack(alignment: .leading) {
                    Text("Border: \(Int(hintBorderOpacity * 100))%")
                    Slider(value: $hintBorderOpacity, in: 0...1, step: 0.05)
                }
            }

            Section("Size") {
                Slider(value: $hintSize, in: 10...20, step: 1) {
                    Text("Hint Size: \(Int(hintSize))pt")
                }
            }

            Section {
                Button("Reset to Defaults") {
                    hintBackgroundHex = "#3B82F6"
                    hintBorderHex = "#3B82F6"
                    hintTextHex = "#FFFFFF"
                    highlightTextHex = "#FFFF00"
                    hintBackgroundOpacity = 0.3
                    hintBorderOpacity = 0.6
                    hintSize = 12
                }
            }
        }
        .formStyle(.grouped)
    }

    private var generalTab: some View {
        Form {
            Section("Permissions") {
                Button("Check Accessibility Permissions") {
                    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                    _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
                }
            }

            Section("About") {
                Text("keynave - Keyboard Navigation for macOS")
                    .font(.headline)
                Text("Version 1.0")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func helpButton(text: String) -> some View {
        HelpButton(helpText: text)
    }
}

struct HelpButton: View {
    let helpText: String
    @State private var showingPopover = false

    var body: some View {
        Button(action: {
            showingPopover.toggle()
        }) {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPopover, arrowEdge: .trailing) {
            Text(helpText)
                .font(.callout)
                .padding()
                .frame(width: 280, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct HintPreviewView: View {
    let hintText: String
    @Binding var backgroundColor: Color
    @Binding var borderColor: Color
    @Binding var textColor: Color
    @Binding var highlightColor: Color
    @Binding var fontSize: Double
    @Binding var backgroundOpacity: Double
    @Binding var borderOpacity: Double

    var body: some View {
        HStack {
            Spacer()
            // Glass container simulation
            ZStack {
                // Background blur simulation (using gradient)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))

                // Tint overlay
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundColor.opacity(backgroundOpacity))

                // Border
                RoundedRectangle(cornerRadius: 4)
                    .stroke(borderColor.opacity(borderOpacity), lineWidth: 1)

                // Text with first letter highlighted
                HStack(spacing: 0) {
                    // First letter (highlighted - as if user typed it)
                    Text(String(hintText.prefix(1)))
                        .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                        .foregroundColor(highlightColor)

                    // Remaining letters (normal text color)
                    if hintText.count > 1 {
                        Text(String(hintText.dropFirst()))
                            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                            .foregroundColor(textColor)
                    }
                }
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: -1)
            }
            .frame(width: CGFloat(hintText.count) * fontSize * 0.8 + 16, height: fontSize + 8)
            Spacer()
        }
        .frame(height: 80)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    PreferencesView()
}

// MARK: - Color Hex Conversion

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (no alpha)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 59, 130, 246) // Default blue
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String {
        guard let components = NSColor(self).usingColorSpace(.sRGB) else {
            return "#3B82F6"
        }
        let r = Int(components.redComponent * 255)
        let g = Int(components.greenComponent * 255)
        let b = Int(components.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (59, 130, 246) // Default blue
        }
        self.init(
            srgbRed: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: 1.0
        )
    }
}
