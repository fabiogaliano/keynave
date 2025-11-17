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

    enum ScrollDirection {
        case up, down, left, right
    }

    func scroll(at point: CGPoint, direction: ScrollDirection, speed: Double) {
        // Convert speed (1-10) to scroll delta
        let baseDelta = Int32(speed * 10)

        var deltaX: Int32 = 0
        var deltaY: Int32 = 0

        switch direction {
        case .up:
            deltaY = baseDelta
        case .down:
            deltaY = -baseDelta
        case .left:
            deltaX = baseDelta
        case .right:
            deltaX = -baseDelta
        }

        // Create scroll wheel event
        let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: deltaY,
            wheel2: deltaX,
            wheel3: 0
        )

        // Move cursor to scroll area center before scrolling
        let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)

        scrollEvent?.post(tap: .cghidEventTap)
    }
}

