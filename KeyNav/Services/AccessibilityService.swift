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

    // Roles that never contain clickable children - skip their subtrees
    private let skipSubtreeRoles: Set<String> = [
        kAXStaticTextRole as String,       // Text doesn't have clickable children
        kAXImageRole as String,            // Images rarely have clickable children
        "AXScrollBar",                     // Scroll bars themselves
        kAXValueIndicatorRole as String,   // Value indicators
        "AXBusyIndicator",                 // Loading spinners
        "AXProgressIndicator"              // Progress bars
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

        let screenFrame = NSScreen.main?.frame ?? .zero

        // Process each window with visibility clipping
        let traverseStartTime = CFAbsoluteTimeGetCurrent()
        for window in windows {
            // Get window frame for visibility clipping
            let windowBounds = getWindowBounds(window) ?? screenFrame
            let visibleBounds = windowBounds.intersection(screenFrame)

            traverseElementOptimized(window, clickableAncestor: nil, into: &elements, clipBounds: visibleBounds, screenFrame: screenFrame)
        }
        let traverseEndTime = CFAbsoluteTimeGetCurrent()
        print("  ⏱️ traverseElements: \(String(format: "%.3f", traverseEndTime - traverseStartTime))s (\(elements.count) raw elements)")

        // Deduplicate elements with the same frame (nested accessibility elements)
        let dedupeStartTime = CFAbsoluteTimeGetCurrent()
        let deduplicated = deduplicateElements(elements)
        let dedupeEndTime = CFAbsoluteTimeGetCurrent()
        print("  ⏱️ deduplicateElements: \(String(format: "%.3f", dedupeEndTime - dedupeStartTime))s (\(deduplicated.count) unique)")

        return deduplicated
    }

    private func getWindowBounds(_ window: AXUIElement) -> CGRect? {
        let attributes = [
            kAXPositionAttribute as CFString,
            kAXSizeAttribute as CFString
        ] as CFArray

        var values: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(window, attributes, [], &values) == .success,
              let valuesArray = values as? [Any],
              valuesArray.count == 2 else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        // Check CFTypeID to ensure it's actually an AXValue
        if let posRef = valuesArray[0] as CFTypeRef?,
           CFGetTypeID(posRef) == AXValueGetTypeID() {
            AXValueGetValue(posRef as! AXValue, .cgPoint, &position)
        }
        if let sizeRef = valuesArray[1] as CFTypeRef?,
           CFGetTypeID(sizeRef) == AXValueGetTypeID() {
            AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        }

        return CGRect(origin: position, size: size)
    }

    private func deduplicateElements(_ elements: [UIElement]) -> [UIElement] {
        // Filter out elements that have a clickable parent
        // If your parent is clickable, clicking the parent achieves the same result
        // So we only keep top-level clickable elements (those with no clickable ancestor)
        var unique: [UIElement] = []

        for element in elements {
            if element.clickableAncestorHash == nil {
                // No clickable parent - this is a top-level clickable, keep it
                unique.append(element)
            }
            // else: skip - parent is already clickable and in the list
        }

        return unique
    }

    private func traverseElementOptimized(_ element: AXUIElement, clickableAncestor: AXUIElement?, into elements: inout [UIElement], clipBounds: CGRect, screenFrame: CGRect) {
        // BATCH FETCH: Get role, position, size, children in ONE IPC call
        let attributes = [
            kAXRoleAttribute as CFString,
            kAXPositionAttribute as CFString,
            kAXSizeAttribute as CFString,
            kAXChildrenAttribute as CFString
        ] as CFArray

        var values: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(element, attributes, [], &values) == .success,
              let valuesArray = values as? [Any],
              valuesArray.count == 4 else {
            return
        }

        // Extract role
        guard let role = valuesArray[0] as? String else {
            return
        }

        // Extract position and size for visibility check
        var position = CGPoint.zero
        var size = CGSize.zero

        // Check CFTypeID to ensure it's actually an AXValue
        if let posRef = valuesArray[1] as CFTypeRef?,
           CFGetTypeID(posRef) == AXValueGetTypeID() {
            AXValueGetValue(posRef as! AXValue, .cgPoint, &position)
        } else {
            return // No position means we can't process this element
        }

        if let sizeRef = valuesArray[2] as CFTypeRef?,
           CFGetTypeID(sizeRef) == AXValueGetTypeID() {
            AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        } else {
            return // No size means we can't process this element
        }

        let elementFrame = CGRect(origin: position, size: size)

        // VISIBILITY CLIPPING: Skip entire subtree if element is off-screen
        if !elementFrame.intersects(clipBounds) {
            return // Early exit - don't traverse children
        }

        // Convert to screen coordinates (macOS uses bottom-left origin, we need top-left)
        let flippedY = screenFrame.height - position.y - size.height
        let frame = CGRect(x: position.x, y: flippedY, width: size.width, height: size.height)

        // Update clickable ancestor for children
        // If this element is clickable, it becomes the new ancestor for its children
        let newClickableAncestor: AXUIElement? = clickableRoles.contains(role) ? element : clickableAncestor

        // Check if element is clickable
        if clickableRoles.contains(role) {
            // Filter out too small elements
            if frame.width > 5 && frame.height > 5 &&
               frame.origin.x >= 0 && frame.origin.y >= 0 {
                var uiElement = UIElement(
                    axElement: element,
                    frame: frame,
                    role: role
                )
                // Store hash of clickable ancestor (if any) for deduplication
                uiElement.clickableAncestorHash = clickableAncestor.map { Int(CFHash($0)) }
                elements.append(uiElement)
            }
        }

        // SMART PRUNING: Skip subtrees for roles that never contain clickable children
        if skipSubtreeRoles.contains(role) {
            return // Don't traverse children of these roles
        }

        // Traverse children (already fetched in batch call)
        guard let children = valuesArray[3] as? [AXUIElement] else {
            return
        }

        // Use tighter clip bounds for children (intersection with current element)
        let childClipBounds = elementFrame.intersection(clipBounds)

        for child in children {
            traverseElementOptimized(child, clickableAncestor: newClickableAncestor, into: &elements, clipBounds: childClipBounds, screenFrame: screenFrame)
        }
    }

    /// Load all text attributes for elements (title, label, value, description)
    /// Called asynchronously after initial display
    func loadTextAttributes(for elements: inout [UIElement]) {
        for i in 0..<elements.count {
            guard !elements[i].textAttributesLoaded else { continue }

            let axElement = elements[i].axElement

            // Get title (optional)
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(axElement, kAXTitleAttribute as CFString, &titleRef)
            elements[i].title = titleRef as? String

            // Get label (optional) - accessibility label
            var labelRef: CFTypeRef?
            AXUIElementCopyAttributeValue(axElement, "AXLabel" as CFString, &labelRef)
            elements[i].label = labelRef as? String

            // Get value (optional) - for text fields, sliders, etc.
            var valueRef: CFTypeRef?
            AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &valueRef)
            elements[i].value = valueRef as? String

            // Get description (optional) - accessibility description
            var descriptionRef: CFTypeRef?
            AXUIElementCopyAttributeValue(axElement, kAXDescriptionAttribute as CFString, &descriptionRef)
            elements[i].elementDescription = descriptionRef as? String

            elements[i].textAttributesLoaded = true
        }
    }
}
