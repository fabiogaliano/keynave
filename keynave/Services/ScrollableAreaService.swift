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
        kAXListRole as String
        // Removed: "AXWebArea" - causes massive over-detection in browsers (every iframe, frame, document)
        // Removed: "AXTextArea" - too generic, causes false positives
        // Web content is still scrollable via scroll bar detection in hasScrollBars()
    ]

    // Configuration constants
    private enum Config {
        static let minimumAreaSize: CGFloat = 100
        static let duplicateTolerance: CGFloat = 10
        static let nestedTolerance: CGFloat = 5
        static let nestedSizeThreshold: CGFloat = 0.7  // Only filter nested areas >70% parent size
        static let sameOriginTolerance: CGFloat = 2.0  // Strict tolerance for X-origin matching
    }

    // Area relationship detection
    private enum AreaRelationship {
        case duplicate
        case newNestedInExisting
        case existingNestedInNew
        case independent

        static func detect(_ newArea: CGRect, _ existingArea: CGRect) -> AreaRelationship {
            // Check for duplicate (within tolerance)
            if abs(newArea.origin.x - existingArea.origin.x) < Config.duplicateTolerance &&
               abs(newArea.origin.y - existingArea.origin.y) < Config.duplicateTolerance &&
               abs(newArea.width - existingArea.width) < Config.duplicateTolerance &&
               abs(newArea.height - existingArea.height) < Config.duplicateTolerance {
                return .duplicate
            }

            // Check if new area is nested inside existing
            if newArea.minX >= existingArea.minX - Config.nestedTolerance &&
               newArea.maxX <= existingArea.maxX + Config.nestedTolerance &&
               newArea.minY >= existingArea.minY - Config.nestedTolerance &&
               newArea.maxY <= existingArea.maxY + Config.nestedTolerance {

                // If they share the same X origin, they're the same scrollable (filter regardless of size)
                let sameXOrigin = abs(newArea.origin.x - existingArea.origin.x) < Config.sameOriginTolerance

                if sameXOrigin {
                    return .newNestedInExisting
                }

                // Otherwise, only filter if >70% the size (near-duplicate)
                let newAreaSize = newArea.width * newArea.height
                let existingAreaSize = existingArea.width * existingArea.height
                let sizeRatio = newAreaSize / existingAreaSize

                if sizeRatio > Config.nestedSizeThreshold {
                    return .newNestedInExisting
                }
            }

            // Check if existing area is nested inside new
            if existingArea.minX >= newArea.minX - Config.nestedTolerance &&
               existingArea.maxX <= newArea.maxX + Config.nestedTolerance &&
               existingArea.minY >= newArea.minY - Config.nestedTolerance &&
               existingArea.maxY <= newArea.maxY + Config.nestedTolerance {

                // If they share the same X origin, they're the same scrollable (filter regardless of size)
                let sameXOrigin = abs(newArea.origin.x - existingArea.origin.x) < Config.sameOriginTolerance

                if sameXOrigin {
                    return .existingNestedInNew
                }

                // Otherwise, only filter if >70% the size (near-duplicate)
                let newAreaSize = newArea.width * newArea.height
                let existingAreaSize = existingArea.width * existingArea.height
                let sizeRatio = existingAreaSize / newAreaSize

                if sizeRatio > Config.nestedSizeThreshold {
                    return .existingNestedInNew
                }
            }

            return .independent
        }
    }

    /// Centralized logic to determine if a new area should be added
    /// Returns true if should add, modifies areas array to remove nested ones
    private func shouldAddArea(_ newArea: ScrollableArea, to areas: inout [ScrollableArea]) -> Bool {
        var indicesToRemove: [Int] = []

        for (index, existing) in areas.enumerated() {
            let relationship = AreaRelationship.detect(newArea.frame, existing.frame)

            switch relationship {
            case .duplicate:
                return false // Skip duplicate

            case .newNestedInExisting:
                return false // Skip nested area

            case .existingNestedInNew:
                // Mark existing area for removal (keep larger new area)
                indicesToRemove.append(index)

            case .independent:
                // Check if they're vertically stacked sections (same X/width, different Y/height)
                if abs(newArea.frame.origin.x - existing.frame.origin.x) < Config.duplicateTolerance &&
                   abs(newArea.frame.width - existing.frame.width) < Config.duplicateTolerance &&
                   abs(newArea.frame.origin.y - existing.frame.origin.y) >= Config.duplicateTolerance {

                    // They're sections in the same vertical column - keep the larger one
                    let newSize = newArea.frame.width * newArea.frame.height
                    let existingSize = existing.frame.width * existing.frame.height

                    if newSize > existingSize {
                        // New area is larger, remove existing
                        indicesToRemove.append(index)
                        print("[DEBUG] REMOVING vertical section (new is larger): \(existing.frame)")
                    } else {
                        // Existing is larger, skip new
                        print("[DEBUG] SKIP vertical section (existing is larger): \(newArea.frame)")
                        return false
                    }
                }
                continue
            }
        }

        // Remove marked areas (in reverse order to maintain indices)
        for index in indicesToRemove.reversed() {
            print("[DEBUG] REMOVING nested: \(areas[index].frame)")
            areas.remove(at: index)
        }

        return true
    }

    func getScrollableAreas(onAreaFound: ((ScrollableArea) -> Void)? = nil, maxAreas: Int? = nil) -> [ScrollableArea] {
        let startTime = Date()
        var elementCount = 0

        guard let focusedApp = NSWorkspace.shared.frontmostApplication,
              let pid = focusedApp.processIdentifier as pid_t? else {
            return []
        }

        let appElement = AXUIElementCreateApplication(pid)
        var areas: [ScrollableArea] = []
        var shouldStop = false

        // Get all windows
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return []
        }

        // Process each window
        for (_, window) in windows.enumerated() {
            guard !shouldStop else { break }
            traverseElement(window, into: &areas, depth: 0, maxDepth: 10, elementCount: &elementCount, onAreaFound: onAreaFound, shouldStop: &shouldStop, maxAreas: maxAreas)
        }

        return areas
    }

    /// Fast focus detection - finds the focused scrollable area directly without needing full area list
    func findFocusedScrollableArea() -> ScrollableArea? {
        let startTime = Date()

        guard let focusedApp = NSWorkspace.shared.frontmostApplication,
              let pid = focusedApp.processIdentifier as pid_t? else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(pid)

        // Get the focused element
        var focusedElementRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElementRef) == .success,
              let focusedElement = focusedElementRef as! AXUIElement? else {
            print("[PERF] No focused element found")
            return nil
        }

        // Walk up the parent chain to find a scrollable container
        var currentElement: AXUIElement? = focusedElement
        var stepCount = 0

        while let element = currentElement {
            stepCount += 1

            // Check if this element is scrollable
            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
               let role = roleRef as? String,
               (scrollableRoles.contains(role) || hasScrollBars(element)) {

                // Create scrollable area from this element
                if let area = createScrollableArea(from: element),
                   area.frame.width > 100 && area.frame.height > 100 {
                    return area
                }
            }

            // Move to parent
            var parentRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parentRef) == .success,
               let parent = parentRef as! AXUIElement? {
                currentElement = parent
            } else {
                break
            }
        }

        return nil
    }

    /// Find the index of a scrollable area that contains the currently focused element
    func findFocusedScrollableAreaIndex(in areas: [ScrollableArea]) -> Int? {
        guard let focusedApp = NSWorkspace.shared.frontmostApplication,
              let pid = focusedApp.processIdentifier as pid_t? else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(pid)

        // Get the focused element
        var focusedElementRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElementRef) == .success,
              let focusedElement = focusedElementRef as! AXUIElement? else {
            return nil
        }

        // Walk up the parent chain to find a scrollable container
        var currentElement: AXUIElement? = focusedElement

        while let element = currentElement {
            // Check if this element is one of our scrollable areas
            if let index = findMatchingAreaIndex(element: element, in: areas) {
                return index
            }

            // Move to parent
            var parentRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parentRef) == .success,
               let parent = parentRef as! AXUIElement? {
                currentElement = parent
            } else {
                break
            }
        }

        return nil
    }

    /// Find the index of a scrollable area under the mouse cursor
    func findScrollableAreaUnderCursorIndex(in areas: [ScrollableArea]) -> Int? {
        // Get current mouse cursor position
        let cursorLocation = NSEvent.mouseLocation

        // Find which area contains the cursor
        for (index, area) in areas.enumerated() {
            if area.frame.contains(cursorLocation) {
                return index
            }
        }

        return nil
    }

    /// Helper to find if an AXUIElement matches one of our scrollable areas
    private func findMatchingAreaIndex(element: AXUIElement, in areas: [ScrollableArea]) -> Int? {
        guard let elementArea = createScrollableArea(from: element) else {
            return nil
        }

        // Find matching area by comparing frames
        for (index, area) in areas.enumerated() {
            if abs(area.frame.origin.x - elementArea.frame.origin.x) < 5 &&
               abs(area.frame.origin.y - elementArea.frame.origin.y) < 5 &&
               abs(area.frame.width - elementArea.frame.width) < 5 &&
               abs(area.frame.height - elementArea.frame.height) < 5 {
                return index
            }
        }

        return nil
    }

    private func traverseElement(
        _ element: AXUIElement,
        into areas: inout [ScrollableArea],
        depth: Int,
        maxDepth: Int,
        elementCount: inout Int,
        onAreaFound: ((ScrollableArea) -> Void)?,
        shouldStop: inout Bool,
        maxAreas: Int?
    ) {
        // Check if we should stop early
        if shouldStop {
            return
        }

        if let max = maxAreas, areas.count >= max {
            shouldStop = true
            return
        }

        elementCount += 1

        // Stop if we've reached max depth
        guard depth < maxDepth else {
            return
        }

        // Get role
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
              let role = roleRef as? String else {
            return
        }

        // Log web content traversal and check AXURL
        if role == "AXWebArea" {
            var urlRef: CFTypeRef?
            let urlResult = AXUIElementCopyAttributeValue(element, "AXURL" as CFString, &urlRef)
            if urlResult == .success, let url = urlRef as? String {
                print("[DEBUG-TRAVERSE] depth:\(depth) role:AXWebArea HAS_AXURL: \(url)")
            } else {
                print("[DEBUG-TRAVERSE] depth:\(depth) role:AXWebArea AXURL status:\(urlResult.rawValue)")
            }
        }

        // Check if element is scrollable (with validation for progressive discovery)
        let hasScrollableRole = scrollableRoles.contains(role)
        let hasEnabledScrollBars = hasScrollBars(element, validateEnabled: true, logDetails: false)

        // For progressive discovery, require either a scrollable role with enabled scrollbars, or just enabled scrollbars
        if hasScrollableRole || hasEnabledScrollBars {
            // If it has a scrollable role but no enabled scrollbars, check if it's web content
            if hasScrollableRole && !hasEnabledScrollBars {
                // Check if this is web content - web scrollables don't expose native scrollbar attributes
                let isWebContent = hasWebAncestor(element, logChain: false)

                if isWebContent {
                    // Web scrollables are accepted without native scrollbar validation
                    if let area = createScrollableArea(from: element) {
                        // Filter out off-screen or too small areas
                        if area.frame.width > Config.minimumAreaSize &&
                           area.frame.height > Config.minimumAreaSize &&
                           area.frame.origin.x >= 0 && area.frame.origin.y >= 0 {

                            // Use centralized area filtering logic
                            if shouldAddArea(area, to: &areas) {
                                print("[DEBUG] ADDED WEB: \(area.frame) role:\(role)")

                                areas.append(area)
                                onAreaFound?(area)

                                if let max = maxAreas, areas.count >= max {
                                    shouldStop = true
                                    return
                                }
                            } else {
                                print("[DEBUG] SKIP nested: \(area.frame) role:\(role)")
                            }
                        }
                    }
                } else {
                    // Native scrollable with no enabled scrollbars - reject it
                    if let area = createScrollableArea(from: element) {
                        // Check parent for debug logging
                        var parentRole: String? = nil
                        var parentRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parentRef) == .success,
                           let parent = parentRef as! AXUIElement?,
                           AXUIElementCopyAttributeValue(parent, kAXRoleAttribute as CFString, &roleRef) == .success,
                           let pRole = roleRef as? String {
                            parentRole = pRole
                        }

                        let parentInfo = parentRole.map { " parent:\($0)" } ?? ""
                        print("[DEBUG-REJECT] role:\(role) frame:\(area.frame)\(parentInfo) isWeb:false reason:no_enabled_scrollbars")
                    }
                }
            } else if let area = createScrollableArea(from: element) {
                // Filter out off-screen or too small areas
                if area.frame.width > Config.minimumAreaSize &&
                   area.frame.height > Config.minimumAreaSize &&
                   area.frame.origin.x >= 0 && area.frame.origin.y >= 0 {

                    // Use centralized area filtering logic
                    if shouldAddArea(area, to: &areas) {
                        let info = getElementInfo(element, logURL: false)
                        let webIndicator = info.hasURL ? " [WEB]" : ""
                        let parentInfo = info.parentRole.map { " parent:\($0)" } ?? ""
                        print("[DEBUG] ADDED: \(area.frame) role:\(role)\(webIndicator)\(parentInfo)")

                        areas.append(area)
                        onAreaFound?(area)

                        if let max = maxAreas, areas.count >= max {
                            shouldStop = true
                            return
                        }
                    } else {
                        print("[DEBUG] SKIP nested: \(area.frame) role:\(role)")
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
            guard !shouldStop else { return }
            traverseElement(child, into: &areas, depth: depth + 1, maxDepth: maxDepth, elementCount: &elementCount, onAreaFound: onAreaFound, shouldStop: &shouldStop, maxAreas: maxAreas)
        }
    }

    private func hasScrollBars(_ element: AXUIElement, validateEnabled: Bool = false, logDetails: Bool = false) -> Bool {
        // Check for vertical scroll bar
        var vScrollBarRef: CFTypeRef?
        let hasVScroll = AXUIElementCopyAttributeValue(element, "AXVerticalScrollBar" as CFString, &vScrollBarRef) == .success

        // Check for horizontal scroll bar
        var hScrollBarRef: CFTypeRef?
        let hasHScroll = AXUIElementCopyAttributeValue(element, "AXHorizontalScrollBar" as CFString, &hScrollBarRef) == .success

        if logDetails && (hasVScroll || hasHScroll) {
            print("[DEBUG-SCROLLBAR] Found scrollbars: V=\(hasVScroll) H=\(hasHScroll)")
        }

        // If validation is not requested, just check for presence
        if !validateEnabled {
            return hasVScroll || hasHScroll
        }

        // Validate that at least one scroll bar is actually enabled (has scrollable content)
        var isEnabled = false
        var vEnabledValue: Bool? = nil
        var hEnabledValue: Bool? = nil

        if hasVScroll, let vScrollBar = vScrollBarRef as! AXUIElement? {
            var enabledRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(vScrollBar, kAXEnabledAttribute as CFString, &enabledRef)
            if result == .success, let enabled = enabledRef as? Bool {
                vEnabledValue = enabled
                if enabled {
                    isEnabled = true
                }
            }
        }

        if !isEnabled && hasHScroll, let hScrollBar = hScrollBarRef as! AXUIElement? {
            var enabledRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(hScrollBar, kAXEnabledAttribute as CFString, &enabledRef)
            if result == .success, let enabled = enabledRef as? Bool {
                hEnabledValue = enabled
                if enabled {
                    isEnabled = true
                }
            }
        }

        if logDetails {
            print("[DEBUG-SCROLLBAR] AXEnabled values: V=\(vEnabledValue?.description ?? "nil") H=\(hEnabledValue?.description ?? "nil") → result=\(isEnabled)")
        }

        return isEnabled
    }

    private func hasWebAncestor(_ element: AXUIElement, logChain: Bool = false) -> Bool {
        var currentElement = element
        var chain: [String] = []
        let maxLevels = 10

        for _ in 0..<maxLevels {
            var roleRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(currentElement, kAXRoleAttribute as CFString, &roleRef) == .success,
                  let role = roleRef as? String else {
                break
            }

            chain.append(role)

            if role == "AXWebArea" {
                if logChain {
                    print("[DEBUG-PARENT-CHAIN] \(chain.joined(separator: " → ")) ✓ WEB")
                }
                return true
            }

            // Move to parent
            var parentRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(currentElement, kAXParentAttribute as CFString, &parentRef) == .success,
                  let parent = parentRef as! AXUIElement? else {
                break
            }

            currentElement = parent
        }

        if logChain && !chain.isEmpty {
            print("[DEBUG-PARENT-CHAIN] \(chain.joined(separator: " → ")) ✗ NOT WEB")
        }

        return false
    }

    private func getElementInfo(_ element: AXUIElement, logURL: Bool = false) -> (role: String, hasURL: Bool, parentRole: String?) {
        var role = "unknown"
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let roleStr = roleRef as? String {
            role = roleStr
        }

        var hasURL = false
        var urlRef: CFTypeRef?
        let urlResult = AXUIElementCopyAttributeValue(element, "AXURL" as CFString, &urlRef)
        if urlResult == .success {
            hasURL = true
            if logURL {
                print("[DEBUG-WEB] AXURL query SUCCESS on role:\(role)")
            }
        } else if logURL {
            print("[DEBUG-WEB] AXURL query FAILED on role:\(role) status:\(urlResult.rawValue)")
        }

        var parentRole: String? = nil
        var parentRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parentRef) == .success,
           let parent = parentRef as! AXUIElement?,
           AXUIElementCopyAttributeValue(parent, kAXRoleAttribute as CFString, &roleRef) == .success,
           let parentRoleStr = roleRef as? String {
            parentRole = parentRoleStr
        }

        return (role, hasURL, parentRole)
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
