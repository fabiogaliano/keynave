//
//  HintOverlayWindow.swift
//  KeyNav
//
//  Transparent overlay window for displaying hints
//

import AppKit
import SwiftUI

@MainActor
class HintOverlayWindow: NSWindow {

    private var elements: [UIElement]
    private var hintViews: [String: NSView] = [:]
    private var elementHighlights: [UUID: NSView] = [:]
    private var searchBarView: NSView?
    private var searchTextField: NSTextField?
    private var matchCountLabel: NSTextField?

    init(elements: [UIElement]) {
        self.elements = elements

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
        self.isReleasedWhenClosed = false // We manage lifecycle manually

        setupHintViews()
        setupSearchBar()
    }

    override var canBecomeKey: Bool {
        return false
    }

    override var canBecomeMain: Bool {
        return false
    }

    private func setupHintViews() {
        let containerView = NSView(frame: self.frame)
        containerView.wantsLayer = true

        for element in elements {
            let hintView = createHintLabel(for: element)
            containerView.addSubview(hintView)
            hintViews[element.hint] = hintView
        }

        self.contentView = containerView
    }

    private func createHintLabel(for element: UIElement) -> NSView {
        let label = NSTextField(labelWithString: element.hint)
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        label.textColor = .white
        label.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.9)
        label.isBordered = false
        label.isBezeled = false
        label.drawsBackground = true
        label.alignment = .center
        label.wantsLayer = true
        label.layer?.cornerRadius = 3

        label.sizeToFit()

        // Add padding
        let padding: CGFloat = 4
        let width = label.frame.width + padding * 2
        let height = label.frame.height + padding

        // Position hint overlapping the element (top-left corner, inside the element)
        // This is more visually clear than floating above
        let x = element.frame.minX
        let y = element.frame.maxY - height  // Place at top of element (maxY in flipped coords)

        label.frame = CGRect(x: x, y: y, width: width, height: height)

        return label
    }

    private func setupSearchBar() {
        let screenFrame = NSScreen.main?.frame ?? .zero

        // Create container view for search bar
        let containerWidth: CGFloat = 300
        let containerHeight: CGFloat = 40
        let containerX = (screenFrame.width - containerWidth) / 2
        let containerY: CGFloat = 80 // Near bottom of screen

        let container = NSView(frame: CGRect(x: containerX, y: containerY, width: containerWidth, height: containerHeight))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        container.layer?.cornerRadius = 10
        container.layer?.borderWidth = 2
        container.layer?.borderColor = NSColor.systemBlue.cgColor

        // Create search text field (display only)
        let textField = NSTextField(labelWithString: "")
        textField.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .medium)
        textField.textColor = .white
        textField.backgroundColor = .clear
        textField.isBordered = false
        textField.alignment = .center
        textField.frame = CGRect(x: 10, y: 8, width: containerWidth - 80, height: 24)
        textField.placeholderString = "Type to search..."
        textField.placeholderAttributedString = NSAttributedString(
            string: "Type to search...",
            attributes: [.foregroundColor: NSColor.gray, .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)]
        )

        // Create match count label
        let countLabel = NSTextField(labelWithString: "")
        countLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        countLabel.textColor = .systemYellow
        countLabel.backgroundColor = .clear
        countLabel.isBordered = false
        countLabel.alignment = .right
        countLabel.frame = CGRect(x: containerWidth - 70, y: 10, width: 60, height: 20)

        container.addSubview(textField)
        container.addSubview(countLabel)

        self.searchBarView = container
        self.searchTextField = textField
        self.matchCountLabel = countLabel

        self.contentView?.addSubview(container)
    }

    func show() {
        self.orderFrontRegardless()
    }

    func updateSearchBar(text: String) {
        searchTextField?.stringValue = text
        if text.isEmpty {
            searchBarView?.layer?.borderColor = NSColor.systemBlue.cgColor
        }
    }

    func updateMatchCount(_ count: Int) {
        if count == -1 {
            // Hide count
            matchCountLabel?.stringValue = ""
            searchBarView?.layer?.borderColor = NSColor.systemBlue.cgColor
        } else if count == 0 {
            matchCountLabel?.stringValue = "0"
            matchCountLabel?.textColor = .systemRed
            searchBarView?.layer?.borderColor = NSColor.systemRed.cgColor
        } else if count == 1 {
            matchCountLabel?.stringValue = "1"
            matchCountLabel?.textColor = .systemGreen
            searchBarView?.layer?.borderColor = NSColor.systemGreen.cgColor
        } else {
            matchCountLabel?.stringValue = "\(count)"
            matchCountLabel?.textColor = .systemYellow
            searchBarView?.layer?.borderColor = NSColor.systemYellow.cgColor
        }
    }

    override func close() {
        print("HintOverlayWindow closing...")
        // Clear all hint views
        hintViews.removeAll()
        self.contentView?.subviews.forEach { $0.removeFromSuperview() }
        self.orderOut(nil)
        super.close()
        print("HintOverlayWindow closed")
    }

    func updateHints(with newElements: [UIElement]) {
        print("Updating hints with \(newElements.count) elements...")

        // Clear existing hints but preserve search bar
        hintViews.removeAll()
        elementHighlights.removeAll()

        // Remove only hint views, not the search bar
        self.contentView?.subviews.forEach { view in
            if view !== searchBarView {
                view.removeFromSuperview()
            }
        }

        // Update elements
        self.elements = newElements

        // Recreate hint views (but not search bar)
        for element in elements {
            let hintView = createHintLabel(for: element)
            self.contentView?.addSubview(hintView)
            hintViews[element.hint] = hintView
        }

        // Reset search bar state
        updateSearchBar(text: "")
        updateMatchCount(-1)

        // Force redraw
        self.contentView?.needsDisplay = true
        self.displayIfNeeded()

        print("Hints updated")
    }

    func filterHints(matching prefix: String) {
        filterHints(matching: prefix, textMatches: [])
    }

    func filterHints(matching prefix: String, textMatches: [UIElement]) {
        // Clear existing highlights
        for (_, highlightView) in elementHighlights {
            highlightView.removeFromSuperview()
        }
        elementHighlights.removeAll()

        // If we have text matches, highlight those elements
        if !textMatches.isEmpty {
            for element in textMatches {
                let highlightView = createHighlightView(for: element)
                self.contentView?.addSubview(highlightView)
                elementHighlights[element.id] = highlightView
            }
            // Hide all hint labels when showing text matches
            for (_, view) in hintViews {
                view.isHidden = true
            }
        } else {
            // Filter hint labels by prefix
            for (hint, view) in hintViews {
                if prefix.isEmpty {
                    view.isHidden = false
                    (view as? NSTextField)?.textColor = .white
                } else if hint.hasPrefix(prefix) {
                    view.isHidden = false
                    // Highlight matched portion
                    highlightPrefix(in: view as? NSTextField, prefix: prefix, hint: hint)
                } else {
                    view.isHidden = true
                }
            }
        }
    }

    private func createHighlightView(for element: UIElement) -> NSView {
        let highlightView = NSView(frame: element.frame.insetBy(dx: -2, dy: -2))
        highlightView.wantsLayer = true
        highlightView.layer?.borderWidth = 3
        highlightView.layer?.borderColor = NSColor.systemGreen.cgColor
        highlightView.layer?.cornerRadius = 4
        highlightView.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.1).cgColor
        return highlightView
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
