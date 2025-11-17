//
//  ShortcutRecorderView.swift
//  KeyNav
//
//  SwiftUI view for recording keyboard shortcuts
//

import SwiftUI
import AppKit
import Carbon

struct ShortcutRecorderView: View {
    @Binding var keyCode: Int
    @Binding var modifiers: Int

    @State private var showingRecordSheet = false
    @State private var displayText = ""

    var body: some View {
        Button(action: {
            showingRecordSheet = true
        }) {
            Text(displayText)
                .frame(minWidth: 80)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .onAppear {
            updateDisplayText()
        }
        .sheet(isPresented: $showingRecordSheet) {
            ShortcutRecorderSheet(
                keyCode: $keyCode,
                modifiers: $modifiers,
                onConfirm: {
                    updateDisplayText()
                    showingRecordSheet = false
                },
                onCancel: {
                    showingRecordSheet = false
                }
            )
        }
    }

    private func updateDisplayText() {
        displayText = ShortcutRecorderView.formatShortcut(keyCode: keyCode, modifiers: modifiers)
    }

    static func formatShortcut(keyCode: Int, modifiers: Int) -> String {
        var result = ""

        // Add modifier symbols
        if modifiers & controlKey != 0 {
            result += "⌃"
        }
        if modifiers & optionKey != 0 {
            result += "⌥"
        }
        if modifiers & shiftKey != 0 {
            result += "⇧"
        }
        if modifiers & cmdKey != 0 {
            result += "⌘"
        }

        // Add key character
        result += keyCodeToString(keyCode)

        return result
    }

    static func keyCodeToString(_ keyCode: Int) -> String {
        let keyMap: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 40: "K", 41: ";", 43: ",", 45: "N", 46: "M",
            49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 53: "⎋",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]

        return keyMap[keyCode] ?? "?"
    }
}

struct ShortcutRecorderSheet: View {
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    var onConfirm: () -> Void
    var onCancel: () -> Void

    @State private var currentPreview = ""
    @State private var recordedKeyCode: Int = -1
    @State private var recordedModifiers: Int = 0
    @State private var hasValidShortcut = false
    @State private var keyDownMonitor: Any?
    @State private var flagsChangedMonitor: Any?

    var body: some View {
        VStack(spacing: 20) {
            Text("Record Shortcut")
                .font(.headline)

            VStack(spacing: 12) {
                Text(currentPreview.isEmpty ? "..." : currentPreview)
                    .font(.system(size: 36, weight: .medium, design: .rounded))
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)

                Text("Press your key combination")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)

            HStack {
                Button("Cancel") {
                    cleanup()
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Confirm") {
                    keyCode = recordedKeyCode
                    modifiers = recordedModifiers
                    cleanup()
                    onConfirm()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!hasValidShortcut)
            }
        }
        .padding(24)
        .frame(width: 320)
        .onAppear {
            startMonitoring()
        }
        .onDisappear {
            cleanup()
        }
    }

    private func startMonitoring() {
        // Notify controllers to temporarily disable their hotkeys
        NotificationCenter.default.post(name: .disableGlobalHotkeys, object: nil)

        // Monitor modifier key changes for real-time preview
        flagsChangedMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            updateModifierPreview(flags: event.modifierFlags)
            return event
        }

        // Monitor key presses
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Ignore modifier-only key codes
            let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            guard !modifierKeyCodes.contains(event.keyCode) else {
                return event
            }

            // Record the shortcut
            self.recordedKeyCode = Int(event.keyCode)
            self.recordedModifiers = self.carbonModifiersFromFlags(event.modifierFlags)
            self.hasValidShortcut = true
            self.updatePreview()

            return nil // Consume the event
        }
    }

    private func updateModifierPreview(flags: NSEvent.ModifierFlags) {
        // Only update preview if we haven't recorded a full shortcut yet
        if !hasValidShortcut {
            var preview = ""
            if flags.contains(.control) {
                preview += "⌃"
            }
            if flags.contains(.option) {
                preview += "⌥"
            }
            if flags.contains(.shift) {
                preview += "⇧"
            }
            if flags.contains(.command) {
                preview += "⌘"
            }
            currentPreview = preview
        }
    }

    private func updatePreview() {
        currentPreview = ShortcutRecorderView.formatShortcut(keyCode: recordedKeyCode, modifiers: recordedModifiers)
    }

    private func carbonModifiersFromFlags(_ flags: NSEvent.ModifierFlags) -> Int {
        var carbonModifiers = 0
        if flags.contains(.control) {
            carbonModifiers |= controlKey
        }
        if flags.contains(.option) {
            carbonModifiers |= optionKey
        }
        if flags.contains(.shift) {
            carbonModifiers |= shiftKey
        }
        if flags.contains(.command) {
            carbonModifiers |= cmdKey
        }
        return carbonModifiers
    }

    private func cleanup() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
        if let monitor = flagsChangedMonitor {
            NSEvent.removeMonitor(monitor)
            flagsChangedMonitor = nil
        }
        // Re-enable global hotkeys
        NotificationCenter.default.post(name: .enableGlobalHotkeys, object: nil)
    }
}
