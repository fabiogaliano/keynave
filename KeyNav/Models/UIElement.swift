//
//  UIElement.swift
//  KeyNav
//
//  Wrapper for accessibility UI elements
//

import Foundation
import AppKit

struct UIElement: Identifiable {
    let id = UUID()
    let axElement: AXUIElement
    let frame: CGRect
    let role: String
    // Hash of nearest clickable ancestor (for deduplication)
    var clickableAncestorHash: Int? = nil
    // All text attributes loaded asynchronously after initial display
    var title: String?
    var label: String?
    var value: String?
    var elementDescription: String?
    var textAttributesLoaded: Bool = false
    var hint: String = ""

    var centerPoint: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    /// Combined searchable text from all text properties
    var searchableText: String {
        [title, label, value, elementDescription]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
