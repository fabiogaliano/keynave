//
//  ScrollableAreaService.swift
//  keynave
//
//  Queries UI elements via Accessibility APIs for scrollable areas
//

import Foundation
import AppKit

@MainActor
class ScrollableAreaService {

    static let shared = ScrollableAreaService()

    private let scrollableRoles: Set<String> = [
        "AXScrollArea",
        "AXScrollView",
        kAXTableRole as String,
        kAXOutlineRole as String,
        kAXListRole as String,
        "AXWebArea",
        "AXTextArea"
    ]

    func getScrollableAreas() -> [ScrollableArea] {
        guard let focusedApp = NSWorkspace.shared.frontmostApplication,
              let pid = focusedApp.processIdentifier as pid_t? else {
            return []
        }

        let appElement = AXUIElementCreateApplication(pid)
        var areas: [ScrollableArea] = []

        // Get all windows
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return []
        }

        // Process each window
        for window in windows {
            traverseElement(window, into: &areas)
        }

        return areas
    }

    private func traverseElement(_ element: AXUIElement, into areas: inout [ScrollableArea]) {
        // Get role
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
              let role = roleRef as? String else {
            return
        }

        // Check if element is scrollable
        if scrollableRoles.contains(role) || hasScrollBars(element) {
            if let area = createScrollableArea(from: element) {
                // Filter out off-screen or too small areas
                if area.frame.width > 50 && area.frame.height > 50 &&
                   area.frame.origin.x >= 0 && area.frame.origin.y >= 0 {
                    // Avoid duplicates by checking if we already have an area at this location
                    let isDuplicate = areas.contains { existing in
                        abs(existing.frame.origin.x - area.frame.origin.x) < 10 &&
                        abs(existing.frame.origin.y - area.frame.origin.y) < 10 &&
                        abs(existing.frame.width - area.frame.width) < 10 &&
                        abs(existing.frame.height - area.frame.height) < 10
                    }
                    if !isDuplicate {
                        areas.append(area)
                    }
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
            traverseElement(child, into: &areas)
        }
    }

    private func hasScrollBars(_ element: AXUIElement) -> Bool {
        // Check for vertical scroll bar
        var vScrollBarRef: CFTypeRef?
        let hasVScroll = AXUIElementCopyAttributeValue(element, "AXVerticalScrollBar" as CFString, &vScrollBarRef) == .success

        // Check for horizontal scroll bar
        var hScrollBarRef: CFTypeRef?
        let hasHScroll = AXUIElementCopyAttributeValue(element, "AXHorizontalScrollBar" as CFString, &hScrollBarRef) == .success

        return hasVScroll || hasHScroll
    }

    private func createScrollableArea(from axElement: AXUIElement) -> ScrollableArea? {
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

        // Convert to screen coordinates (macOS uses bottom-left origin, we need top-left)
        let screenFrame = NSScreen.main?.frame ?? .zero
        let flippedY = screenFrame.height - position.y - size.height

        let frame = CGRect(x: position.x, y: flippedY, width: size.width, height: size.height)

        return ScrollableArea(axElement: axElement, frame: frame)
    }
}
