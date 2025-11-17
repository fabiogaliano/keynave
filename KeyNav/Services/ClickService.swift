//
//  ClickService.swift
//  KeyNav
//
//  Performs click actions via CGEvent
//

import Foundation
import AppKit

@MainActor
class ClickService {

    static let shared = ClickService()

    func click(at point: CGPoint) {
        let clickDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let clickUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)

        clickDown?.post(tap: .cghidEventTap)
        clickUp?.post(tap: .cghidEventTap)
    }

    func rightClick(at point: CGPoint) {
        let clickDown = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: point, mouseButton: .right)
        let clickUp = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: point, mouseButton: .right)

        clickDown?.post(tap: .cghidEventTap)
        clickUp?.post(tap: .cghidEventTap)
    }

    func doubleClick(at point: CGPoint) {
        for _ in 0..<2 {
            click(at: point)
        }
    }
}
