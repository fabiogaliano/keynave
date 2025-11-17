# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KeyNav is a macOS menu bar app providing keyboard-driven UI navigation similar to Homerow. It overlays clickable hints on UI elements, allowing users to click anywhere using keyboard shortcuts instead of the mouse.

## Build & Development

```bash
# Build from command line
xcodebuild -project KeyNav.xcodeproj -scheme KeyNav -configuration Debug build

# Run via Xcode
open KeyNav.xcodeproj
# Then Cmd+R to build and run
```

**Requirements:**
- macOS 14.0+ (uses modern SwiftUI APIs)
- Xcode 15+
- Accessibility permissions must be granted in System Settings > Privacy & Security > Accessibility

## Architecture

### Core Flow
1. **Activation**: Global hotkey (⌘⇧Space) triggers `HintModeController.toggleHintMode()`
2. **Discovery**: `AccessibilityService` traverses the frontmost app's AX tree to find clickable elements
3. **Hint Assignment**: Elements receive alphabetic hints (A-Z for ≤26 elements, two-char combos otherwise)
4. **Overlay**: `HintOverlayWindow` renders hints as positioned labels over each element
5. **Input Processing**: Event tap intercepts keyboard input, filters hints by prefix matching
6. **Click Execution**: On hint match, `ClickService` posts CGEvents at element's center point

### Key Components

**Services (singletons, @MainActor):**
- `HintModeController` - Orchestrates hint mode lifecycle, manages event tap for keyboard interception
- `AccessibilityService` - Queries macOS Accessibility API (AXUIElement) for clickable UI elements
- `ClickService` - Posts CGEvent mouse clicks at specified coordinates

**Models:**
- `UIElement` - Wrapper holding AXUIElement reference, screen frame, role, title, and assigned hint

**Views:**
- `HintOverlayWindow` - Borderless, transparent NSWindow at screenSaver level displaying hint labels
- `PreferencesView` - SwiftUI Settings form for configuration

**App Infrastructure:**
- `KeyNavApp` - SwiftUI App entry point with hidden window bridge for opening Settings
- `AppDelegate` - Sets up menu bar status item, initializes hint mode controller

### Important Patterns

**Coordinate Systems:**
- macOS Accessibility API uses bottom-left origin (Quartz coordinates)
- `AccessibilityService` flips Y to top-left for UI positioning
- `HintModeController.performClick()` flips back for CGEvent posting

**Event Tap Threading:**
- Callback runs on CF run loop, not main actor
- Static vars with `nonisolated(unsafe)` for thread-safe state sharing
- UI updates dispatched to main queue via `DispatchQueue.main.async`

**Settings Persistence:**
- Uses `@AppStorage` / `UserDefaults` for: `hintSize`, `hintColor`, `continuousClickMode`
- Defaults registered in `AppDelegate.applicationDidFinishLaunching()`

### User Preferences

Stored in UserDefaults:
- `hintSize` (Double): Font size for hints (10-20pt)
- `hintColor` (String): "blue", "green", "orange", "purple"
- `continuousClickMode` (Bool): Stay in hint mode after clicking, refresh hints for continued clicking

## Key Technical Details

- Uses Carbon Event Manager for global hotkey registration
- Event tap requires Accessibility permissions to intercept keyboard events
- Overlay window uses `.screenSaver` level to appear above all content
- Hints use monospaced system font for consistent sizing
- Backspace deletes last typed character, ESC cancels hint mode
