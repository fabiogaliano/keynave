//
//  ScrollOverlayWindow.swift
//  keynave
//
//  Transparent overlay window for displaying scroll area hints
//

import AppKit
import SwiftUI

@MainActor
class ScrollOverlayWindow: NSWindow {

    private var areas: [ScrollableArea]
    private var hintViews: [String: NSView] = [:]
    private var highlightView: NSView?
    private var selectedAreaIndex: Int = -1

    init(areas: [ScrollableArea]) {
        self.areas = areas

        let screenFrame = NSScreen.main?.frame ?? .zero

        super.init(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false

        setupViews()
    }

    override var canBecomeKey: Bool {
        return false
    }

    override var canBecomeMain: Bool {
        return false
    }

    private func setupViews() {
        let containerView = NSView(frame: self.frame)
        containerView.wantsLayer = true

        // Create highlight view (hidden initially)
        let highlight = NSView(frame: .zero)
        highlight.wantsLayer = true
        highlight.layer?.borderColor = NSColor.systemYellow.cgColor
        highlight.layer?.borderWidth = 3
        highlight.layer?.cornerRadius = 4
        highlight.isHidden = true
        containerView.addSubview(highlight)
        highlightView = highlight

        // Show hints only if setting is enabled
        let showNumbers = UserDefaults.standard.bool(forKey: "showScrollAreaNumbers")

        if showNumbers {
            for area in areas {
                let hintView = createHintLabel(for: area)
                containerView.addSubview(hintView)
                hintViews[area.hint] = hintView
            }
        }

        self.contentView = containerView
    }

    private func createHintLabel(for area: ScrollableArea) -> NSView {
        let label = NSTextField(labelWithString: area.hint)
        label.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        label.textColor = .white
        label.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.9)
        label.isBordered = false
        label.isBezeled = false
        label.drawsBackground = true
        label.alignment = .center
        label.wantsLayer = true
        label.layer?.cornerRadius = 4

        label.sizeToFit()

        // Add padding
        let padding: CGFloat = 6
        let width = label.frame.width + padding * 2
        let height = label.frame.height + padding

        // Position at top-right corner
        let x = area.frame.maxX - width - 8  // 8px from right edge
        let y = area.frame.minY + 8           // 8px from top edge

        label.frame = CGRect(x: x, y: y, width: width, height: height)

        return label
    }

    func show() {
        self.orderFrontRegardless()
    }

    /// Dynamically add a new scrollable area to the overlay
    func addArea(_ area: ScrollableArea) {
        // Add to areas array
        areas.append(area)

        // Only create hint view if setting is enabled
        let showNumbers = UserDefaults.standard.bool(forKey: "showScrollAreaNumbers")
        guard showNumbers else { return }

        // Create and add hint view
        let hintView = createHintLabel(for: area)
        contentView?.addSubview(hintView)
        hintViews[area.hint] = hintView

        // Preserve selection state (dim new hint if something is already selected)
        if selectedAreaIndex >= 0 {
            hintView.alphaValue = 0.3
        }
    }

    /// Remove an area from the overlay by its hint number
    func removeArea(withHint hint: String) {
        // Remove from areas array
        areas.removeAll { $0.hint == hint }

        // Remove hint view if it exists
        if let hintView = hintViews[hint] {
            hintView.removeFromSuperview()
            hintViews.removeValue(forKey: hint)
        }
    }

    /// Update hint number for an existing area (for resequencing)
    func updateHint(oldHint: String, newHint: String) {
        // Update in areas array
        if let index = areas.firstIndex(where: { $0.hint == oldHint }) {
            areas[index].hint = newHint
        }

        // Update hint view if it exists
        if let hintView = hintViews[oldHint] as? NSTextField {
            hintView.stringValue = newHint
            hintViews.removeValue(forKey: oldHint)
            hintViews[newHint] = hintView
        }
    }

    /// Update all areas (used after removing nested areas to refresh overlay)
    func updateAllAreas(_ newAreas: [ScrollableArea]) {
        // Clear existing hints
        hintViews.values.forEach { $0.removeFromSuperview() }
        hintViews.removeAll()

        // Update areas
        areas = newAreas

        // Recreate hints if enabled
        let showNumbers = UserDefaults.standard.bool(forKey: "showScrollAreaNumbers")
        guard showNumbers else { return }

        for area in areas {
            let hintView = createHintLabel(for: area)
            contentView?.addSubview(hintView)
            hintViews[area.hint] = hintView

            // Preserve selection state
            if selectedAreaIndex >= 0 && selectedAreaIndex < areas.count {
                let selectedArea = areas[selectedAreaIndex]
                if area.hint != selectedArea.hint {
                    hintView.alphaValue = 0.3
                }
            }
        }
    }

    override func close() {
        hintViews.removeAll()
        self.contentView?.subviews.forEach { $0.removeFromSuperview() }
        self.orderOut(nil)
        super.close()
    }

    func selectArea(at index: Int) {
        guard index >= 0 && index < areas.count else { return }

        selectedAreaIndex = index
        let area = areas[index]

        // Update highlight
        highlightView?.frame = area.frame
        highlightView?.isHidden = false

        // Dim non-selected hints
        for (hint, view) in hintViews {
            if hint == area.hint {
                view.alphaValue = 1.0
            } else {
                view.alphaValue = 0.3
            }
        }
    }

    func clearSelection() {
        selectedAreaIndex = -1
        highlightView?.isHidden = true

        // Reset all hints
        for (_, view) in hintViews {
            view.alphaValue = 1.0
        }
    }

    func filterHints(matching prefix: String) {
        for (hint, view) in hintViews {
            if prefix.isEmpty {
                view.isHidden = false
                (view as? NSTextField)?.textColor = .white
            } else if hint.hasPrefix(prefix) {
                view.isHidden = false
                highlightPrefix(in: view as? NSTextField, prefix: prefix, hint: hint)
            } else {
                view.isHidden = true
            }
        }
    }

    private func highlightPrefix(in textField: NSTextField?, prefix: String, hint: String) {
        guard let textField = textField else { return }

        let attributedString = NSMutableAttributedString(string: hint)

        // Matched portion in yellow
        attributedString.addAttribute(.foregroundColor, value: NSColor.yellow, range: NSRange(location: 0, length: prefix.count))

        // Remaining portion in white
        if prefix.count < hint.count {
            attributedString.addAttribute(.foregroundColor, value: NSColor.white, range: NSRange(location: prefix.count, length: hint.count - prefix.count))
        }

        textField.attributedStringValue = attributedString
    }
}
