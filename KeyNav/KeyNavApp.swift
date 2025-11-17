//
//  KeyNavApp.swift
//  KeyNav
//
//  Created by fábio on 17/11/2025.
//

import SwiftUI
import AppKit

@main
struct KeyNavApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Hidden window provides SwiftUI context for openSettings()
        Window("Hidden", id: "HiddenWindow") {
            SettingsOpenerView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)

        Settings {
            PreferencesView()
                .onDisappear {
                    NotificationCenter.default.post(name: .settingsWindowClosed, object: nil)
                }
        }
    }
}

// MARK: - Settings Opener View (Hidden SwiftUI Bridge)

struct SettingsOpenerView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequest)) { _ in
                Task { @MainActor in
                    // Temporarily show dock icon for proper window focus
                    NSApp.setActivationPolicy(.regular)
                    try? await Task.sleep(for: .milliseconds(100))

                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()

                    // Ensure window comes to front
                    try? await Task.sleep(for: .milliseconds(200))
                    if let settingsWindow = Self.findSettingsWindow() {
                        settingsWindow.makeKeyAndOrderFront(nil)
                        settingsWindow.orderFrontRegardless()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .settingsWindowClosed)) { _ in
                // Hide dock icon when settings closes
                NSApp.setActivationPolicy(.accessory)
            }
    }

    private static func findSettingsWindow() -> NSWindow? {
        NSApp.windows.first { window in
            window.identifier?.rawValue == "com.apple.SwiftUI.Settings" ||
            (window.isVisible && window.title.localizedCaseInsensitiveContains("settings"))
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openSettingsRequest = Notification.Name("openSettingsRequest")
    static let settingsWindowClosed = Notification.Name("settingsWindowClosed")
}

// MARK: - App Delegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hintModeController: HintModeController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register default values
        UserDefaults.standard.register(defaults: [
            "hintSize": 12.0,
            "hintColor": "blue"
        ])

        setupMenuBar()
        setupHintMode()
        checkAccessibilityPermissions()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyNav")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Activate Hints (⌘⇧Space)", action: #selector(activateHints), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit KeyNav", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func setupHintMode() {
        hintModeController = HintModeController()
        hintModeController?.registerGlobalHotkey()
    }

    private func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !trusted {
            print("Accessibility permissions not granted. Please enable in System Preferences.")
        }
    }

    @objc private func activateHints() {
        hintModeController?.toggleHintMode()
    }

    @objc private func openPreferences() {
        // Use NotificationCenter to trigger SwiftUI's openSettings()
        NotificationCenter.default.post(name: .openSettingsRequest, object: nil)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
