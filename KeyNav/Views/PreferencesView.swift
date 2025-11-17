//
//  PreferencesView.swift
//  KeyNav
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
    @AppStorage("hintCharacters") private var hintCharacters: String = "asdfhjkl"
    @AppStorage("textSearchEnabled") private var textSearchEnabled: Bool = true
    @AppStorage("minSearchCharacters") private var minSearchCharacters: Int = 2

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
            }

            Section("Behavior") {
                Toggle("Continuous Click Mode", isOn: $continuousClickMode)
                Text("When enabled, hint mode stays active after clicking. Continue clicking elements until you press ESC.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                Slider(value: $hintSize, in: 10...20, step: 1) {
                    Text("Hint Size: \(Int(hintSize))pt")
                }

                Picker("Hint Color", selection: $hintColor) {
                    Text("Blue").tag("blue")
                    Text("Green").tag("green")
                    Text("Orange").tag("orange")
                    Text("Purple").tag("purple")
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

    private var generalTab: some View {
        Form {
            Section("Permissions") {
                Button("Check Accessibility Permissions") {
                    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                    _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
                }
            }

            Section("About") {
                Text("KeyNav - Keyboard Navigation for macOS")
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

#Preview {
    PreferencesView()
}
