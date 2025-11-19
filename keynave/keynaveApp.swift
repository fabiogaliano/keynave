//
//  keynaveApp.swift
//  keynave
//
//  Created by fábio on 17/11/2025.
//

import SwiftUI
import AppKit
import Carbon

@main
struct keynaveApp: App {
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
    @State private var windowObserver: NSObjectProtocol?

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequest)) { _ in
                Task { @MainActor in
                    // Temporarily show dock icon for proper window focus
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)

                    // Set up observer to detect when Settings window becomes key
                    windowObserver = NotificationCenter.default.addObserver(
                        forName: NSWindow.didBecomeKeyNotification,
                        object: nil,
                        queue: .main
                    ) { notification in
                        guard let window = notification.object as? NSWindow,
                              Self.isSettingsWindow(window) else { return }

                        // Settings window is now key, ensure it's focused
                        window.makeKeyAndOrderFront(nil)
                        window.orderFrontRegardless()

                        // Remove observer after handling
                        if let observer = windowObserver {
                            NotificationCenter.default.removeObserver(observer)
                            windowObserver = nil
                        }
                    }

                    openSettings()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .settingsWindowClosed)) { _ in
                // Hide dock icon when settings closes
                NSApp.setActivationPolicy(.accessory)

                // Clean up observer if still active
                if let observer = windowObserver {
                    NotificationCenter.default.removeObserver(observer)
                    windowObserver = nil
                }
            }
    }

    private static func isSettingsWindow(_ window: NSWindow) -> Bool {
        window.identifier?.rawValue == "com.apple.SwiftUI.Settings" ||
        (window.isVisible && window.title.localizedCaseInsensitiveContains("settings"))
    }

    private static func findSettingsWindow() -> NSWindow? {
        NSApp.windows.first { isSettingsWindow($0) }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openSettingsRequest = Notification.Name("openSettingsRequest")
    static let settingsWindowClosed = Notification.Name("settingsWindowClosed")
    static let disableGlobalHotkeys = Notification.Name("disableGlobalHotkeys")
    static let enableGlobalHotkeys = Notification.Name("enableGlobalHotkeys")
}

// MARK: - App Delegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hintModeController: HintModeController?
    private var scrollModeController: ScrollModeController?
    private var hintMenuItem: NSMenuItem?
    private var scrollMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register default values
        UserDefaults.standard.register(defaults: [
            "hintShortcutKeyCode": 49, // Space key
            "hintShortcutModifiers": cmdKey | shiftKey,
            "hintSize": 12.0,
            "hintColor": "blue",
            "continuousClickMode": false,
            "autoHintDeactivation": true,
            "hintDeactivationDelay": 5.0,
            "hintCharacters": "asdfhjkl", // Home row keys for hint generation
            "textSearchEnabled": true, // Enable text-based element search
            "minSearchCharacters": 2, // Minimum characters to trigger text search
            "hintBackgroundHex": "#3B82F6", // Blue background tint
            "hintBorderHex": "#3B82F6", // Blue border
            "hintTextHex": "#FFFFFF", // White text
            "highlightTextHex": "#FFFF00", // Yellow highlight
            "hintBackgroundOpacity": 0.3,
            "hintBorderOpacity": 0.6,
            "scrollShortcutKeyCode": 14, // E key
            "scrollShortcutModifiers": optionKey,
            "scrollArrowMode": "select",
            "showScrollAreaNumbers": true,
            "scrollKeys": "hjkl",
            "scrollCommandsEnabled": true,
            "scrollSpeed": 5.0,
            "dashSpeed": 9.0,
            "autoScrollDeactivation": true,
            "scrollDeactivationDelay": 5.0
        ])

        setupMenuBar()
        setupHintMode()
        setupScrollMode()
        checkAccessibilityPermissions()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "keynave")
        }

        let menu = NSMenu()

        hintMenuItem = NSMenuItem(title: formatHintMenuTitle(), action: #selector(activateHints), keyEquivalent: "")
        scrollMenuItem = NSMenuItem(title: formatScrollMenuTitle(), action: #selector(activateScroll), keyEquivalent: "")

        menu.addItem(hintMenuItem!)
        menu.addItem(scrollMenuItem!)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit keynave", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu

        // Listen for settings changes to update menu titles
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuTitles),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc private func updateMenuTitles() {
        hintMenuItem?.title = formatHintMenuTitle()
        scrollMenuItem?.title = formatScrollMenuTitle()
    }

    private func formatHintMenuTitle() -> String {
        let keyCode = UserDefaults.standard.integer(forKey: "hintShortcutKeyCode")
        let modifiers = UserDefaults.standard.integer(forKey: "hintShortcutModifiers")
        let shortcut = ShortcutRecorderView.formatShortcut(keyCode: keyCode, modifiers: modifiers)
        return "Activate Hints (\(shortcut))"
    }

    private func formatScrollMenuTitle() -> String {
        let keyCode = UserDefaults.standard.integer(forKey: "scrollShortcutKeyCode")
        let modifiers = UserDefaults.standard.integer(forKey: "scrollShortcutModifiers")
        let shortcut = ShortcutRecorderView.formatShortcut(keyCode: keyCode, modifiers: modifiers)
        return "Activate Scroll (\(shortcut))"
    }

    private func setupHintMode() {
        hintModeController = HintModeController()
        hintModeController?.registerGlobalHotkey()
    }

    private func setupScrollMode() {
        scrollModeController = ScrollModeController()
        scrollModeController?.registerGlobalHotkey()
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

    @objc private func activateScroll() {
        scrollModeController?.toggleScrollMode()
    }

    @objc private func openPreferences() {
        // Use NotificationCenter to trigger SwiftUI's openSettings()
        NotificationCenter.default.post(name: .openSettingsRequest, object: nil)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
