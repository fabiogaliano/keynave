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
    private var uiChangeObserver: NSObjectProtocol?
    private var isWaitingForUIChange = false
    private var refreshFallbackTask: Task<Void, Never>?

    // Thread-safe state for event tap callback
    private nonisolated(unsafe) static var isHintModeActive = false
    private nonisolated(unsafe) static var hintChars = "asdfhjkl"
    private nonisolated(unsafe) static var currentEventTap: CFMachPort?
    private nonisolated(unsafe) static var typedInput = ""
    private nonisolated(unsafe) static var pendingAction: (() -> Void)?
    private nonisolated(unsafe) static var textSearchEnabled = true
    private nonisolated(unsafe) static var minSearchChars = 2

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
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            guard let userData = userData, let event = event else { return OSStatus(eventNotHandledErr) }

            // Extract the hotkey ID from the event to check if this is our hotkey
            var pressedHotKeyID = EventHotKeyID()
            let err = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &pressedHotKeyID
            )

            guard err == noErr else { return OSStatus(eventNotHandledErr) }

            // Check if this is the hint mode hotkey (signature: "KNAV", id: 1)
            let expectedSignature = OSType("KNAV".utf8.reduce(0) { ($0 << 8) + OSType($1) })
            guard pressedHotKeyID.signature == expectedSignature && pressedHotKeyID.id == 1 else {
                return OSStatus(eventNotHandledErr) // Not our hotkey, let other handlers process
            }

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

        let startTime = CFAbsoluteTimeGetCurrent()

        // Get clickable elements (fast - only essential attributes)
        let elementsStartTime = CFAbsoluteTimeGetCurrent()
        elements = AccessibilityService.shared.getClickableElements()
        let elementsEndTime = CFAbsoluteTimeGetCurrent()
        print("⏱️ getClickableElements: \(String(format: "%.3f", elementsEndTime - elementsStartTime))s")

        guard !elements.isEmpty else {
            print("No clickable elements found")
            return
        }

        // Assign hints
        let hintsStartTime = CFAbsoluteTimeGetCurrent()
        assignHints()
        let hintsEndTime = CFAbsoluteTimeGetCurrent()
        print("⏱️ assignHints: \(String(format: "%.3f", hintsEndTime - hintsStartTime))s")

        // Show overlay with search bar
        let overlayStartTime = CFAbsoluteTimeGetCurrent()
        overlayWindow = HintOverlayWindow(elements: elements)
        overlayWindow?.show()
        let overlayEndTime = CFAbsoluteTimeGetCurrent()
        print("⏱️ createOverlay: \(String(format: "%.3f", overlayEndTime - overlayStartTime))s")

        // Update state before starting event tap
        isActive = true
        currentInput = ""
        HintModeController.isHintModeActive = true
        HintModeController.typedInput = ""
        HintModeController.textSearchEnabled = UserDefaults.standard.bool(forKey: "textSearchEnabled")
        HintModeController.minSearchChars = UserDefaults.standard.integer(forKey: "minSearchCharacters")

        // Start intercepting keyboard events
        startEventTap()

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        print("⏱️ TOTAL activateHintMode: \(String(format: "%.3f", totalTime))s with \(elements.count) elements")

        // Load text attributes in background for text search
        loadTextAttributesAsync()
    }

    private func loadTextAttributesAsync() {
        Task { @MainActor in
            let loadStartTime = CFAbsoluteTimeGetCurrent()
            AccessibilityService.shared.loadTextAttributes(for: &self.elements)
            let loadEndTime = CFAbsoluteTimeGetCurrent()
            print("⏱️ Background text attributes loaded: \(String(format: "%.3f", loadEndTime - loadStartTime))s")
        }
    }

    private func deactivateHintMode() {
        guard isActive else { return }

        print("Deactivating hint mode...")

        // Update static state first
        HintModeController.isHintModeActive = false
        HintModeController.typedInput = ""

        // Stop UI change observer
        stopUIChangeObserver()

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

    private func startUIChangeObserver() {
        // Remove existing observer if any
        stopUIChangeObserver()

        // Start accessibility observer
        AccessibilityService.shared.startObservingUIChanges()

        // Subscribe to UI change notifications
        uiChangeObserver = NotificationCenter.default.addObserver(
            forName: .accessibilityUIChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.handleUIChangeDetected()
            }
        }

        print("✅ UI change observer started")
    }

    private func stopUIChangeObserver() {
        // Cancel fallback task
        refreshFallbackTask?.cancel()
        refreshFallbackTask = nil

        // Remove notification observer
        if let observer = uiChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            uiChangeObserver = nil
        }

        // Stop accessibility observer
        AccessibilityService.shared.stopObservingUIChanges()
        isWaitingForUIChange = false

        print("🛑 UI change observer stopped")
    }

    private func handleUIChangeDetected() {
        guard isWaitingForUIChange && isActive else { return }

        print("🔄 UI change detected, refreshing hints...")
        isWaitingForUIChange = false

        // Cancel fallback task since we got the notification
        refreshFallbackTask?.cancel()
        refreshFallbackTask = nil

        // Perform the actual refresh
        performHintRefresh()
    }

    private func performHintRefresh() {
        guard isActive else { return }

        // Re-query clickable elements
        let newElements = AccessibilityService.shared.getClickableElements()

        guard !newElements.isEmpty else {
            print("No clickable elements found after refresh")
            deactivateHintMode()
            return
        }

        // Update elements and reassign hints
        self.elements = newElements
        self.assignHints()

        // Update the overlay window
        self.overlayWindow?.updateHints(with: self.elements)

        // Load text attributes for new elements (enables text search)
        self.loadTextAttributesAsync()

        print("✅ Hints refreshed with \(newElements.count) elements")
    }

    private func assignHints() {
        let hintCharacters = UserDefaults.standard.string(forKey: "hintCharacters") ?? "asdfhjkl"
        let chars = Array(hintCharacters)
        let count = elements.count

        // Update static hint chars for event tap filtering
        HintModeController.hintChars = hintCharacters

        // Generate hints based on element count
        // Always use 2-letter hints minimum, expand to 3-letter if needed
        var hints: [String] = []

        let twoCharCombos = chars.count * chars.count // e.g., 8 * 8 = 64

        if count <= twoCharCombos {
            // Two character hints (e.g., aa, as, ad, af, ah, aj, ak, al, sa, ss...)
            for i in 0..<count {
                let first = chars[i / chars.count]
                let second = chars[i % chars.count]
                hints.append("\(first)\(second)")
            }
        } else {
            // Three character hints (e.g., aaa, aas, aad...)
            for i in 0..<count {
                let first = chars[i / (chars.count * chars.count)]
                let second = chars[(i / chars.count) % chars.count]
                let third = chars[i % chars.count]
                hints.append("\(first)\(second)\(third)")
            }
        }

        // Assign to elements
        for i in 0..<elements.count {
            elements[i].hint = hints[i]
        }
    }

    private func startEventTap() {
        // Create event tap to intercept keyboard events
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

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
                let flags = event.flags

                // Option key press (keycode 58 or 61) - clear search
                if type == .flagsChanged && (keyCode == 58 || keyCode == 61) {
                    if flags.contains(.maskAlternate) {
                        // Option pressed - clear search
                        HintModeController.typedInput = ""
                        DispatchQueue.main.async {
                            HintModeController.sharedInstance?.clearSearch()
                        }
                    }
                    return Unmanaged.passRetained(event)
                }

                // Only process keyDown events from here
                guard type == .keyDown else {
                    return Unmanaged.passRetained(event)
                }

                // Escape key (keycode 53) - deactivate
                if keyCode == 53 {
                    DispatchQueue.main.async {
                        HintModeController.sharedInstance?.deactivateHintMode()
                    }
                    return nil // Consume the event
                }

                // Enter key (keycode 36) - handle actions
                if keyCode == 36 {
                    let hasControl = flags.contains(.maskControl)
                    DispatchQueue.main.async {
                        HintModeController.sharedInstance?.handleEnterKey(withControl: hasControl)
                    }
                    return nil // Consume the event
                }

                // Backspace (keycode 51)
                if keyCode == 51 {
                    if !HintModeController.typedInput.isEmpty {
                        HintModeController.typedInput.removeLast()
                        let input = HintModeController.typedInput
                        DispatchQueue.main.async {
                            HintModeController.sharedInstance?.processInput(input)
                        }
                    }
                    return nil // Consume the event
                }

                // Space key (keycode 49) - add to search
                if keyCode == 49 {
                    HintModeController.typedInput += " "
                    let input = HintModeController.typedInput
                    DispatchQueue.main.async {
                        HintModeController.sharedInstance?.processInput(input)
                    }
                    return nil // Consume the event
                }

                // Convert keycode to character
                guard let character = HintModeController.keyCodeToCharacter(keyCode) else {
                    return Unmanaged.passRetained(event) // Pass through non-character keys
                }

                let lowerChar = character.lowercased()

                // Accept all alphanumeric characters for text search
                guard lowerChar.count == 1, lowerChar.first?.isLetter == true || lowerChar.first?.isNumber == true else {
                    return Unmanaged.passRetained(event)
                }

                // Update typed input
                HintModeController.typedInput += lowerChar

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

        // Update search bar display
        overlayWindow?.updateSearchBar(text: input)

        // Check for exact hint match first
        if let matchedElement = elements.first(where: { $0.hint == input }) {
            // Update overlay to show the completed match with full highlighting
            overlayWindow?.filterHints(matching: input, textMatches: [])
            // Perform click
            performClick(on: matchedElement)
            // Immediately clear input state before handling post-click
            clearInputState()
            handlePostClick()
            return
        }

        // Check if input matches any hint prefixes
        let hintMatchingElements = elements.filter { $0.hint.hasPrefix(input) }

        if !hintMatchingElements.isEmpty {
            // Update overlay to show only matching hints
            overlayWindow?.filterHints(matching: input, textMatches: [])
            return
        }

        // If no hint matches, try text search (if enabled and input is long enough)
        if HintModeController.textSearchEnabled && input.count >= HintModeController.minSearchChars {
            let textMatches = searchElementsByText(input)

            if textMatches.count == 1 {
                // Single match - auto-click
                performClick(on: textMatches[0])
                // Immediately clear input state before handling post-click
                clearInputState()
                handlePostClick()
            } else if textMatches.isEmpty {
                // No text matches either, show "no matches" state
                overlayWindow?.filterHints(matching: "", textMatches: [])
                overlayWindow?.updateMatchCount(0)
            } else {
                // Multiple text matches - highlight them and show count
                overlayWindow?.filterHints(matching: "", textMatches: textMatches)
                overlayWindow?.updateMatchCount(textMatches.count)
            }
        } else {
            // Not enough characters for text search, reset display
            overlayWindow?.filterHints(matching: "", textMatches: [])
        }
    }

    private func clearInputState() {
        currentInput = ""
        HintModeController.typedInput = ""
        overlayWindow?.updateSearchBar(text: "")
        overlayWindow?.updateMatchCount(-1)
    }

    private func searchElementsByText(_ searchText: String) -> [UIElement] {
        let lowercasedSearch = searchText.lowercased()
        return elements.filter { element in
            element.searchableText.lowercased().contains(lowercasedSearch)
        }
    }

    private func handlePostClick() {
        let continuousMode = UserDefaults.standard.bool(forKey: "continuousClickMode")
        if continuousMode {
            refreshHints()
        } else {
            deactivateHintMode()
        }
    }

    private func clearSearch() {
        currentInput = ""
        overlayWindow?.updateSearchBar(text: "")
        overlayWindow?.filterHints(matching: "", textMatches: [])
        overlayWindow?.updateMatchCount(-1) // -1 means hide count
    }

    private func handleEnterKey(withControl: Bool) {
        // If we have text matches, click the first one
        if currentInput.count >= HintModeController.minSearchChars {
            let textMatches = searchElementsByText(currentInput)
            if let firstMatch = textMatches.first {
                if withControl {
                    performRightClick(on: firstMatch)
                } else {
                    performClick(on: firstMatch)
                }
                handlePostClick()
            }
        }
    }

    private func performRightClick(on element: UIElement) {
        let screenFrame = NSScreen.main?.frame ?? .zero
        let clickPoint = CGPoint(
            x: element.centerPoint.x,
            y: screenFrame.height - element.centerPoint.y
        )

        ClickService.shared.rightClick(at: clickPoint)
    }

    private func refreshHints() {
        print("Refreshing hints for continuous mode...")

        // Reset input state
        currentInput = ""
        HintModeController.typedInput = ""

        // Start observing for UI changes
        startUIChangeObserver()
        isWaitingForUIChange = true

        // Set up a fallback timeout in case no UI changes are detected
        // This handles cases where AX notifications don't fire (rare but possible)
        refreshFallbackTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(3))
                guard self.isWaitingForUIChange && self.isActive else { return }
                print("⚠️ No UI change detected, performing fallback refresh...")
                self.isWaitingForUIChange = false
                self.performHintRefresh()
            } catch {
                // Task was cancelled, which is fine
            }
        }

        print("⏳ Waiting for UI changes...")
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
