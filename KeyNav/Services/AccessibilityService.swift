//
//  AccessibilityService.swift
//  KeyNav
//
//  Queries UI elements via Accessibility APIs
//

import Foundation
import AppKit

@MainActor
class AccessibilityService {

    static let shared = AccessibilityService()

    private let clickableRoles: Set<String> = [
        kAXButtonRole as String,
        "AXLink",
        kAXTextFieldRole as String,
        kAXCheckBoxRole as String,
        kAXRadioButtonRole as String,
        kAXPopUpButtonRole as String,
        kAXMenuButtonRole as String,
        "AXTab",
        kAXMenuItemRole as String,
        kAXIncrementorRole as String,
        kAXComboBoxRole as String,
        kAXSliderRole as String,
        kAXColorWellRole as String,
        "AXCell",
        "AXStaticText"
    ]

    func getClickableElements() -> [UIElement] {
        guard let focusedApp = NSWorkspace.shared.frontmostApplication,
              let pid = focusedApp.processIdentifier as pid_t? else {
            return []
        }

        let appElement = AXUIElementCreateApplication(pid)
        var elements: [UIElement] = []

        // Get all windows
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return []
        }

        // Process each window
        for window in windows {
            traverseElement(window, into: &elements)
        }

        return elements
    }

    private func traverseElement(_ element: AXUIElement, into elements: inout [UIElement]) {
        // Get role
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
              let role = roleRef as? String else {
            return
        }

        // Check if element is clickable
        if clickableRoles.contains(role) {
            if let uiElement = createUIElement(from: element, role: role) {
                // Filter out off-screen or too small elements
                if uiElement.frame.width > 5 && uiElement.frame.height > 5 &&
                   uiElement.frame.origin.x >= 0 && uiElement.frame.origin.y >= 0 {
                    elements.append(uiElement)
                }
            }
        }

        // Traverse children
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else {
            return
        }

        for child in children {
            traverseElement(child, into: &elements)
        }
    }

    private func createUIElement(from axElement: AXUIElement, role: String) -> UIElement? {
        // Get position
        var positionRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axElement, kAXPositionAttribute as CFString, &positionRef) == .success else {
            return nil
        }

        var position = CGPoint.zero
        if !AXValueGetValue(positionRef as! AXValue, .cgPoint, &position) {
            return nil
        }

        // Get size
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axElement, kAXSizeAttribute as CFString, &sizeRef) == .success else {
            return nil
        }

        var size = CGSize.zero
        if !AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) {
            return nil
        }

        // Get title (optional)
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(axElement, kAXTitleAttribute as CFString, &titleRef)
        let title = titleRef as? String

        // Convert to screen coordinates (macOS uses bottom-left origin, we need top-left)
        let screenFrame = NSScreen.main?.frame ?? .zero
        let flippedY = screenFrame.height - position.y - size.height

        let frame = CGRect(x: position.x, y: flippedY, width: size.width, height: size.height)

        return UIElement(axElement: axElement, frame: frame, role: role, title: title)
    }
}
