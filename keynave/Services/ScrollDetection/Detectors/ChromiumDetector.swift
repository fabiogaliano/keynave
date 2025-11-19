//
//  ChromiumDetector.swift
//  keynave
//
//  Specialized detector for Chromium-based browsers (Chrome, Arc, Edge, Brave)
//  Optimizes detection of developer tools and web content
//

import Foundation
import AppKit

@MainActor
class ChromiumDetector: AppSpecificDetector {

    var supportedBundleIdentifiers: Set<String> {
        [
            "com.google.Chrome",
            "com.google.Chrome.beta",
            "com.google.Chrome.dev",
            "com.google.Chrome.canary",
            "company.thebrowser.Browser",  // Arc
            "com.microsoft.edgemac",       // Edge
            "com.microsoft.edgemac.Beta",
            "com.microsoft.edgemac.Dev",
            "com.microsoft.edgemac.Canary",
            "com.brave.Browser",           // Brave
            "com.brave.Browser.beta",
            "com.brave.Browser.dev",
            "com.brave.Browser.nightly"
        ]
    }

    var priority: Int { 100 } // High priority for early execution

    func detect(
        windows: [AXUIElement],
        appElement: AXUIElement,
        bundleIdentifier: String,
        onAreaFound: ((ScrollableArea) -> Void)?,
        maxAreas: Int?
    ) -> DetectionResult {

        var areas: [ScrollableArea] = []
        var foundDevTools = false

        // Fast DevTools Detection - Look for AXSplitGroup (indicates docked dev tools)
        for window in windows {
            if let devToolsAreas = detectDevTools(in: window) {
                areas.append(contentsOf: devToolsAreas)
                foundDevTools = true

                // Call progressive callback
                devToolsAreas.forEach { onAreaFound?($0) }

                // Stop if we hit maxAreas
                if let max = maxAreas, areas.count >= max {
                    return .customAreas(areas)
                }
            }
        }

        // If we found dev tools, return them but continue normal traversal
        // (to also get main viewport, sidebars, etc.)
        if foundDevTools {
            print("[ChromiumDetector] Found \(areas.count) DevTools panels")
            return .customAreasWithContinuation(areas)
        }

        // No dev tools detected, continue with normal detection
        return .continueNormal
    }

    /// Fast detection of Chromium DevTools panels
    /// Returns areas if DevTools detected, nil otherwise
    private func detectDevTools(in window: AXUIElement) -> [ScrollableArea]? {
        var areas: [ScrollableArea] = []

        // Get window children
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else {
            return nil
        }

        // Look for AXSplitGroup (indicates docked dev tools)
        for child in children {
            var roleRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef) == .success,
                  let role = roleRef as? String,
                  role == "AXSplitGroup" else {
                continue
            }

            // Found split group - this is the dev tools container
            // Now find large AXGroup elements inside (dev tools panels)
            findDevToolsPanels(in: child, depth: 0, maxDepth: 6, into: &areas)
        }

        return areas.isEmpty ? nil : areas
    }

    /// Find scrollable panels within DevTools split group
    private func findDevToolsPanels(in element: AXUIElement, depth: Int, maxDepth: Int, into areas: inout [ScrollableArea]) {
        guard depth < maxDepth else { return }

        // Get children
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else {
            return
        }

        for child in children {
            // Check role
            var roleRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef) == .success,
                  let role = roleRef as? String else {
                continue
            }

            // Look for large AXGroup elements (console, elements panel, network, sources)
            if role == "AXGroup" {
                if let area = createScrollableArea(from: child),
                   area.frame.width > 400 && area.frame.height > 400 {

                    // Check if it's web content (dev tools panels are rendered as web content)
                    if isWebContent(child) {
                        areas.append(area)
                    }
                }
            }

            // Recursively check children (dev tools has nested structure)
            findDevToolsPanels(in: child, depth: depth + 1, maxDepth: maxDepth, into: &areas)
        }
    }

    /// Check if element is web content by walking parent chain for AXWebArea
    private func isWebContent(_ element: AXUIElement) -> Bool {
        var currentElement = element
        let maxLevels = 10

        for _ in 0..<maxLevels {
            var roleRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(currentElement, kAXRoleAttribute as CFString, &roleRef) == .success,
                  let role = roleRef as? String else {
                break
            }

            if role == "AXWebArea" {
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

        return false
    }

    /// Create ScrollableArea from AXUIElement
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
