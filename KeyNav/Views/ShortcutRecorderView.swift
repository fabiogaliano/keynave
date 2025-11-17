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

    @State private var isRecording = false
    @State private var displayText = ""

    var body: some View {
        Button(action: {
            startRecording()
        }) {
            Text(isRecording ? "Press keys..." : displayText)
                .frame(minWidth: 80)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .onAppear {
            updateDisplayText()
        }
    }

    private func startRecording() {
        isRecording = true

        // Notify controllers to temporarily disable their hotkeys
        NotificationCenter.default.post(name: .disableGlobalHotkeys, object: nil)

        // Use local event monitor to capture key events
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Ignore modifier-only presses
            guard event.keyCode != 56 && event.keyCode != 58 && event.keyCode != 59 && event.keyCode != 60 && event.keyCode != 61 && event.keyCode != 62 && event.keyCode != 63 else {
                return event
            }

            // Escape cancels
            if event.keyCode == 53 {
                self.cancelRecording()
                return nil
            }

            // Convert NSEvent modifiers to Carbon modifiers
            var carbonModifiers = 0
            if event.modifierFlags.contains(.control) {
                carbonModifiers |= controlKey
            }
            if event.modifierFlags.contains(.option) {
                carbonModifiers |= optionKey
            }
            if event.modifierFlags.contains(.shift) {
                carbonModifiers |= shiftKey
            }
            if event.modifierFlags.contains(.command) {
                carbonModifiers |= cmdKey
            }

            self.keyCode = Int(event.keyCode)
            self.modifiers = carbonModifiers
            self.finishRecording()

            return nil // Consume the event
        }

        // Store monitor for cleanup
        ShortcutRecorderView.activeMonitor = monitor
    }

    private func finishRecording() {
        isRecording = false
        updateDisplayText()
        cleanupMonitor()
        // Re-enable global hotkeys
        NotificationCenter.default.post(name: .enableGlobalHotkeys, object: nil)
    }

    private func cancelRecording() {
        isRecording = false
        cleanupMonitor()
        // Re-enable global hotkeys
        NotificationCenter.default.post(name: .enableGlobalHotkeys, object: nil)
    }

    private func cleanupMonitor() {
        if let monitor = ShortcutRecorderView.activeMonitor {
            NSEvent.removeMonitor(monitor)
            ShortcutRecorderView.activeMonitor = nil
        }
    }

    private static var activeMonitor: Any?

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

    private static func keyCodeToString(_ keyCode: Int) -> String {
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
