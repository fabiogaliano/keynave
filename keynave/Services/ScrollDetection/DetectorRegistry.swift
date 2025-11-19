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

    /// Get app-specific refresh delays for continuous hint mode
    /// Returns nil if no custom delays configured (use defaults)
    func refreshDelays(for bundleIdentifier: String?) -> (optimistic: TimeInterval, fallback: TimeInterval)? {
        guard let bundleId = bundleIdentifier else { return nil }

        let detectors = detectorsForBundleId(bundleId)

        // Use first detector with custom delays (detectors are priority-sorted)
        for detector in detectors {
            if let optimistic = detector.optimisticRefreshDelay,
               let fallback = detector.fallbackRefreshDelay {
                return (optimistic, fallback)
            }
        }

        return nil
    }

    private func registerDefaultDetectors() {
        // Register Chromium detector
        register(ChromiumDetector())

        // Future detectors can be registered here:
        // register(SafariDetector())
        // register(VSCodeDetector())
    }
}
