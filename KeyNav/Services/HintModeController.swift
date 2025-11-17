//
//  HintModeController.swift
//  KeyNav
//
//  Orchestrates hint mode activation and keyboard input
//

import Foundation
import AppKit
import Carbon

@MainActor
class HintModeController {

    private var overlayWindow: HintOverlayWindow?
    private var isActive = false
    private var currentInput = ""
    private var elements: [UIElement] = []
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hotKeyRef: EventHotKeyRef?

    private let hintCharacters = "ASDFGHJKLQWERTYUIOPZXCVBNM"

    // Thread-safe state for event tap callback
    private nonisolated(unsafe) static var isHintModeActive = false
    private nonisolated(unsafe) static var hintChars = "ASDFGHJKLQWERTYUIOPZXCVBNM"
    private nonisolated(unsafe) static var currentEventTap: CFMachPort?
    private nonisolated(unsafe) static var typedInput = ""
    private nonisolated(unsafe) static var pendingAction: (() -> Void)?

    // Static reference for C callback
    private static var sharedInstance: HintModeController?

    func registerGlobalHotkey() {
        HintModeController.sharedInstance = self

        // Listen for hotkey disable/enable notifications
        NotificationCenter.default.addObserver(
            forName: .disableGlobalHotkeys,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.unregisterHotkey()
        }

        NotificationCenter.default.addObserver(
            forName: .enableGlobalHotkeys,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.registerHotkeyInternal()
        }

        registerHotkeyInternal()
    }

    private func registerHotkeyInternal() {
        // Don't register if already registered
        guard hotKeyRef == nil else { return }

        let keyCode = UserDefaults.standard.integer(forKey: "hintShortcutKeyCode")
        let modifiers = UserDefaults.standard.integer(forKey: "hintShortcutModifiers")

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType("KNAV".utf8.reduce(0) { ($0 << 8) + OSType($1) })
        hotKeyID.id = 1

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        // Install event handler
        InstallEventHandler(GetApplicationEventTarget(), { (_, _, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let controller = Unmanaged<HintModeController>.fromOpaque(userData).takeUnretainedValue()

            Task { @MainActor in
                controller.toggleHintMode()
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)

        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    private func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    func toggleHintMode() {
        if isActive {
            deactivateHintMode()
        } else {
            activateHintMode()
        }
    }

    private func activateHintMode() {
        guard !isActive else { return }

        // Get clickable elements
        elements = AccessibilityService.shared.getClickableElements()

        guard !elements.isEmpty else {
            print("No clickable elements found")
            return
        }

        // Assign hints
        assignHints()

        // Show overlay
        overlayWindow = HintOverlayWindow(elements: elements)
        overlayWindow?.show()

        // Update state before starting event tap
        isActive = true
        currentInput = ""
        HintModeController.isHintModeActive = true
        HintModeController.typedInput = ""

        // Start intercepting keyboard events
        startEventTap()

        print("Hint mode activated with \(elements.count) elements")
    }

    private func deactivateHintMode() {
        guard isActive else { return }

        print("Deactivating hint mode...")

        // Update static state first
        HintModeController.isHintModeActive = false
        HintModeController.typedInput = ""

        // Stop event tap
        stopEventTap()

        // Close and remove window
        if let window = overlayWindow {
            print("Closing overlay window...")
            window.orderOut(nil)
            window.close()
        }
        overlayWindow = nil

        // Reset state
        elements = []
        isActive = false
        currentInput = ""

        print("Hint mode deactivated successfully")
    }

    private func assignHints() {
        let chars = Array(hintCharacters)
        let count = elements.count

        // Generate hints based on element count
        var hints: [String] = []

        if count <= chars.count {
            // Single character hints
            for i in 0..<count {
                hints.append(String(chars[i]))
            }
        } else {
            // Two character hints
            for i in 0..<count {
                let first = chars[i / chars.count]
                let second = chars[i % chars.count]
                hints.append("\(first)\(second)")
            }
        }

        // Assign to elements
        for i in 0..<elements.count {
            elements[i].hint = hints[i]
        }
    }

    private func startEventTap() {
        // Create event tap to intercept keyboard events
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }

                // Handle tap disabled by timeout - re-enable it
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = HintModeController.currentEventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passRetained(event)
                }

                guard HintModeController.isHintModeActive else {
                    return Unmanaged.passRetained(event)
                }

                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

                // Escape key (keycode 53) - schedule deactivation
                if keyCode == 53 {
                    DispatchQueue.main.async {
                        HintModeController.sharedInstance?.deactivateHintMode()
                    }
                    return nil // Consume the event
                }

                // Backspace (keycode 51)
                if keyCode == 51 {
                    if !HintModeController.typedInput.isEmpty {
                        HintModeController.typedInput.removeLast()
                        let input = HintModeController.typedInput
                        DispatchQueue.main.async {
                            HintModeController.sharedInstance?.currentInput = input
                            HintModeController.sharedInstance?.overlayWindow?.filterHints(matching: input)
                        }
                    }
                    return nil // Consume the event
                }

                // Convert keycode to character
                guard let character = HintModeController.keyCodeToCharacter(keyCode) else {
                    return Unmanaged.passRetained(event) // Pass through non-hint keys
                }

                let upperChar = character.uppercased()

                // Only accept hint characters
                guard upperChar.count == 1, HintModeController.hintChars.contains(upperChar) else {
                    return Unmanaged.passRetained(event)
                }

                // Update typed input
                HintModeController.typedInput += upperChar

                // Schedule UI update on main thread
                let input = HintModeController.typedInput
                DispatchQueue.main.async {
                    HintModeController.sharedInstance?.processInput(input)
                }

                return nil // Consume the event
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap = eventTap else {
            print("Failed to create event tap. Make sure Accessibility permissions are granted.")
            return
        }

        // Store in static for re-enabling
        HintModeController.currentEventTap = eventTap

        // Add to run loop
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        print("Event tap started")
    }

    private func stopEventTap() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        HintModeController.currentEventTap = nil

        print("Event tap stopped")
    }

    private func processInput(_ input: String) {
        guard isActive else { return }

        currentInput = input

        // Check for exact match
        if let matchedElement = elements.first(where: { $0.hint == input }) {
            // Perform click
            performClick(on: matchedElement)

            // Check if continuous mode is enabled
            let continuousMode = UserDefaults.standard.bool(forKey: "continuousClickMode")

            if continuousMode {
                // Refresh hints for continued clicking
                refreshHints()
            } else {
                // Deactivate as normal
                deactivateHintMode()
            }
            return
        }

        // Filter displayed hints
        let matchingElements = elements.filter { $0.hint.hasPrefix(input) }

        if matchingElements.isEmpty {
            // No matches, reset
            currentInput = ""
            HintModeController.typedInput = ""
            overlayWindow?.filterHints(matching: "")
        } else {
            // Update overlay to show only matching hints
            overlayWindow?.filterHints(matching: input)
        }
    }

    private func refreshHints() {
        print("Refreshing hints for continuous mode...")

        // Reset input state
        currentInput = ""
        HintModeController.typedInput = ""

        // Wait for UI to update after click
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))

            guard self.isActive else { return }

            // Re-query clickable elements
            let newElements = AccessibilityService.shared.getClickableElements()

            guard !newElements.isEmpty else {
                print("No clickable elements found after refresh")
                self.deactivateHintMode()
                return
            }

            // Update elements and reassign hints
            self.elements = newElements
            self.assignHints()

            // Update the overlay window
            self.overlayWindow?.updateHints(with: self.elements)

            print("Hints refreshed with \(newElements.count) elements")
        }
    }

    nonisolated private static func keyCodeToCharacter(_ keyCode: Int64) -> String? {
        // Map common keycodes to characters
        let keyMap: [Int64: String] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
            8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
            16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 37: "l",
            38: "j", 40: "k", 41: ";", 43: ",", 45: "n", 46: "m"
        ]

        return keyMap[keyCode]
    }

    private func performClick(on element: UIElement) {
        // Convert to screen coordinates for CGEvent (uses bottom-left origin)
        let screenFrame = NSScreen.main?.frame ?? .zero
        let clickPoint = CGPoint(
            x: element.centerPoint.x,
            y: screenFrame.height - element.centerPoint.y
        )

        ClickService.shared.click(at: clickPoint)
    }
}
