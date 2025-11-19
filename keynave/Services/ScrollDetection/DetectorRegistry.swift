//
//  DetectorRegistry.swift
//  keynave
//
//  Registry for app-specific scrollable area detectors
//

import Foundation

@MainActor
class DetectorRegistry {
    static let shared = DetectorRegistry()

    private var detectors: [AppSpecificDetector] = []
    private var bundleIdToDetectors: [String: [AppSpecificDetector]] = [:]

    private init() {
        // Register all built-in detectors
        registerDefaultDetectors()
    }

    /// Register a new detector
    func register(_ detector: AppSpecificDetector) {
        detectors.append(detector)

        // Index by bundle ID for fast lookup
        for bundleId in detector.supportedBundleIdentifiers {
            bundleIdToDetectors[bundleId, default: []].append(detector)
        }

        // Sort detectors by priority (highest first)
        detectors.sort { $0.priority > $1.priority }
        for (bundleId, _) in bundleIdToDetectors {
            bundleIdToDetectors[bundleId]?.sort { $0.priority > $1.priority }
        }
    }

    /// Get detectors for a specific bundle identifier
    func detectorsForBundleId(_ bundleId: String) -> [AppSpecificDetector] {
        bundleIdToDetectors[bundleId] ?? []
    }

    /// Check if any detector handles this bundle ID
    func hasDetectorFor(_ bundleId: String) -> Bool {
        bundleIdToDetectors[bundleId] != nil
    }

    private func registerDefaultDetectors() {
        // Register Chromium detector
        register(ChromiumDetector())

        // Future detectors can be registered here:
        // register(SafariDetector())
        // register(VSCodeDetector())
    }
}
