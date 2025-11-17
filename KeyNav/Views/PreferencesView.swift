//
//  PreferencesView.swift
//  KeyNav
//
//  Settings UI
//

import SwiftUI

struct PreferencesView: View {
    @AppStorage("hintSize") private var hintSize: Double = 12
    @AppStorage("hintColor") private var hintColor: String = "blue"
    @AppStorage("continuousClickMode") private var continuousClickMode: Bool = false

    var body: some View {
        Form {
            Section("Hotkey") {
                Text("⌘⇧Space - Activate Hint Mode")
                    .foregroundStyle(.secondary)
                Text("ESC - Cancel Hint Mode")
                    .foregroundStyle(.secondary)
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
        .frame(width: 400, height: 400)
        .padding()
    }
}

#Preview {
    PreferencesView()
}
