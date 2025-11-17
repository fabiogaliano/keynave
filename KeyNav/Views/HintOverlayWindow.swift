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
        // Get user preferences
        let hintSize = UserDefaults.standard.double(forKey: "hintSize")
        let fontSize = hintSize > 0 ? CGFloat(hintSize) : 12

        // Get custom colors from preferences
        let backgroundHex = UserDefaults.standard.string(forKey: "hintBackgroundHex") ?? "#3B82F6"
        let borderHex = UserDefaults.standard.string(forKey: "hintBorderHex") ?? "#3B82F6"
        let textHex = UserDefaults.standard.string(forKey: "hintTextHex") ?? "#FFFFFF"
        let backgroundOpacity = UserDefaults.standard.double(forKey: "hintBackgroundOpacity")
        let borderOpacity = UserDefaults.standard.double(forKey: "hintBorderOpacity")

        let backgroundColor = NSColor(hex: backgroundHex)
        let borderColor = NSColor(hex: borderHex)
        let textColor = NSColor(hex: textHex)
        let bgOpacity = backgroundOpacity > 0 ? CGFloat(backgroundOpacity) : 0.3
        let bdrOpacity = borderOpacity > 0 ? CGFloat(borderOpacity) : 0.6

        let label = NSTextField(labelWithString: element.hint)
        label.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
        label.textColor = textColor
        label.backgroundColor = .clear
        label.isBordered = false
        label.isBezeled = false
        label.drawsBackground = false
        label.alignment = .center
        label.wantsLayer = true
        // Add subtle shadow for better legibility
        label.shadow = {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
            shadow.shadowOffset = NSSize(width: 0, height: -1)
            shadow.shadowBlurRadius = 2
            return shadow
        }()

        label.sizeToFit()

        // Add padding
        let padding: CGFloat = 4
        let width = label.frame.width + padding * 2
        let height = label.frame.height + padding

        // Create glass container using NSVisualEffectView
        let glassContainer = NSVisualEffectView(frame: .zero)
        glassContainer.material = .hudWindow
        glassContainer.blendingMode = .behindWindow
        glassContainer.state = .active
        glassContainer.wantsLayer = true
        glassContainer.layer?.cornerRadius = 4
        glassContainer.layer?.masksToBounds = true
        glassContainer.layer?.borderWidth = 1
        glassContainer.layer?.borderColor = borderColor.withAlphaComponent(bdrOpacity).cgColor

        // Add subtle tint overlay for accent color
        let tintOverlay = NSView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        tintOverlay.wantsLayer = true
        tintOverlay.layer?.backgroundColor = backgroundColor.withAlphaComponent(bgOpacity).cgColor

        // Position label within container
        label.frame = CGRect(x: 0, y: 0, width: width, height: height)

        glassContainer.addSubview(tintOverlay)
        glassContainer.addSubview(label)

        // Position hint overlapping the element (top-left corner, inside the element)
        let x = element.frame.minX
        let y = element.frame.maxY - height  // Place at top of element (maxY in flipped coords)

        glassContainer.frame = CGRect(x: x, y: y, width: width, height: height)

        return glassContainer
    }

    private func setupSearchBar() {
        let screenFrame = NSScreen.main?.frame ?? .zero

        // Create container view for search bar
        let containerWidth: CGFloat = 300
        let containerHeight: CGFloat = 40
        let containerX = (screenFrame.width - containerWidth) / 2
        let containerY: CGFloat = 80 // Near bottom of screen

        // Create visual effect view for glass background
        let visualEffectView = NSVisualEffectView(frame: CGRect(x: containerX, y: containerY, width: containerWidth, height: containerHeight))
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 10
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 1.5
        visualEffectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor

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
            attributes: [.foregroundColor: NSColor.white.withAlphaComponent(0.5), .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)]
        )

        // Create match count label
        let countLabel = NSTextField(labelWithString: "")
        countLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        countLabel.textColor = .systemYellow
        countLabel.backgroundColor = .clear
        countLabel.isBordered = false
        countLabel.alignment = .right
        countLabel.frame = CGRect(x: containerWidth - 70, y: 10, width: 60, height: 20)

        visualEffectView.addSubview(textField)
        visualEffectView.addSubview(countLabel)

        self.searchBarView = visualEffectView
        self.searchTextField = textField
        self.matchCountLabel = countLabel

        self.contentView?.addSubview(visualEffectView)
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

        // Get custom text color from preferences
        let textHex = UserDefaults.standard.string(forKey: "hintTextHex") ?? "#FFFFFF"
        let textColor = NSColor(hex: textHex)

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
                    // Reset text color to custom color
                    if let textField = findTextField(in: view) {
                        textField.textColor = textColor
                    }
                } else if hint.hasPrefix(prefix) {
                    view.isHidden = false
                    // Highlight matched portion
                    if let textField = findTextField(in: view) {
                        highlightPrefix(in: textField, prefix: prefix, hint: hint)
                    }
                } else {
                    view.isHidden = true
                }
            }
        }
    }

    private func findTextField(in view: NSView) -> NSTextField? {
        // If it's already an NSTextField, return it
        if let textField = view as? NSTextField {
            return textField
        }
        // Otherwise search subviews (for glass container structure)
        for subview in view.subviews {
            if let textField = subview as? NSTextField {
                return textField
            }
        }
        return nil
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

        // Get custom colors from preferences
        let highlightHex = UserDefaults.standard.string(forKey: "highlightTextHex") ?? "#FFFF00"
        let textHex = UserDefaults.standard.string(forKey: "hintTextHex") ?? "#FFFFFF"
        let highlightColor = NSColor(hex: highlightHex)
        let textColor = NSColor(hex: textHex)

        let attributedString = NSMutableAttributedString(string: hint)

        // Matched portion in highlight color
        attributedString.addAttribute(.foregroundColor, value: highlightColor, range: NSRange(location: 0, length: prefix.count))

        // Remaining portion in text color
        if prefix.count < hint.count {
            attributedString.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: prefix.count, length: hint.count - prefix.count))
        }

        textField.attributedStringValue = attributedString
    }
}
