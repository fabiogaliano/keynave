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

        // Position at element's top-left corner
        let x = element.frame.minX
        let y = element.frame.minY - height - 2

        label.frame = CGRect(x: x, y: y, width: width, height: height)

        return label
    }

    func show() {
        self.orderFrontRegardless()
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

        // Clear existing hints
        hintViews.removeAll()
        self.contentView?.subviews.forEach { $0.removeFromSuperview() }

        // Update elements
        self.elements = newElements

        // Recreate hints
        setupHintViews()

        // Force redraw
        self.contentView?.needsDisplay = true
        self.displayIfNeeded()

        print("Hints updated")
    }

    func filterHints(matching prefix: String) {
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
