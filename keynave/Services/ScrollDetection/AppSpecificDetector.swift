//
//  AppSpecificDetector.swift
//  keynave
//
//  Protocol for app-specific scrollable area detection
//

import Foundation
import AppKit

/// Result from app-specific detection
struct DetectionResult {
    let areas: [ScrollableArea]
    let shouldContinueNormalTraversal: Bool

    /// No custom areas found, continue with normal detection
    static var continueNormal: DetectionResult {
        DetectionResult(areas: [], shouldContinueNormalTraversal: true)
    }

    /// Custom areas found, skip normal traversal
    static func customAreas(_ areas: [ScrollableArea]) -> DetectionResult {
        DetectionResult(areas: areas, shouldContinueNormalTraversal: false)
    }

    /// Custom areas found, but also continue normal traversal
    static func customAreasWithContinuation(_ areas: [ScrollableArea]) -> DetectionResult {
        DetectionResult(areas: areas, shouldContinueNormalTraversal: true)
    }
}

/// Protocol for app-specific scrollable area detectors
@MainActor
protocol AppSpecificDetector {
    /// Bundle identifiers this detector handles (e.g., "com.google.Chrome")
    var supportedBundleIdentifiers: Set<String> { get }

    /// Priority for detector execution (higher = runs first, default = 0)
    var priority: Int { get }

    /// Detect scrollable areas for supported apps
    /// - Parameters:
    ///   - windows: AX windows from the app
    ///   - appElement: Root AX application element
    ///   - bundleIdentifier: Bundle ID of frontmost app
    ///   - onAreaFound: Progressive callback for each area found
    ///   - maxAreas: Optional limit on number of areas to find
    /// - Returns: Detection result indicating areas found and whether to continue normal traversal
    func detect(
        windows: [AXUIElement],
        appElement: AXUIElement,
        bundleIdentifier: String,
        onAreaFound: ((ScrollableArea) -> Void)?,
        maxAreas: Int?
    ) -> DetectionResult

    /// Optional: App-specific refresh delay for continuous hint mode (optimistic attempt)
    /// Return nil to use default (50ms)
    var optimisticRefreshDelay: TimeInterval? { get }

    /// Optional: App-specific fallback refresh delay for continuous hint mode
    /// Return nil to use default (100ms additional)
    var fallbackRefreshDelay: TimeInterval? { get }
}

extension AppSpecificDetector {
    /// Default priority
    var priority: Int { 0 }

    /// Default: no custom refresh delays (use global defaults)
    var optimisticRefreshDelay: TimeInterval? { nil }
    var fallbackRefreshDelay: TimeInterval? { nil }
}
