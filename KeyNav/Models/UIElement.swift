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
    let title: String?
    var hint: String = ""

    var centerPoint: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
}
