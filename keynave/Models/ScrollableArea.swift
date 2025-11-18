//
//  ScrollableArea.swift
//  keynave
//
//  Wrapper for scrollable UI elements
//

import Foundation
import AppKit

struct ScrollableArea: Identifiable {
    let id = UUID()
    let axElement: AXUIElement
    let frame: CGRect
    var hint: String = ""

    var centerPoint: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
}
