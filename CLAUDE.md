# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

keynave is a macOS menu bar app providing keyboard-driven UI navigation similar to Homerow. It overlays clickable hints on UI elements, allowing users to click anywhere using keyboard shortcuts instead of the mouse.

## Build & Development

```bash
# Build from command line
xcodebuild -project keynave.xcodeproj -scheme keynave -configuration Debug build

# Run via Xcode
open keynave.xcodeproj
# Then Cmd+R to build and run
```

**Requirements:**
- macOS 14.0+ (uses modern SwiftUI APIs)
- Xcode 15+
- Accessibility permissions must be granted in System Settings > Privacy & Security > Accessibility

## Architecture

### Core Flow - Hint Mode
1. **Activation**: Global hotkey (default ⌘⇧Space, configurable) triggers `HintModeController.toggleHintMode()`
2. **Discovery**: `AccessibilityService` traverses the frontmost app's AX tree to find clickable elements
3. **Hint Assignment**: Elements receive alphabetic hints (A-Z for ≤26 elements, two-char combos otherwise)
4. **Overlay**: `HintOverlayWindow` renders hints as positioned labels over each element
5. **Input Processing**: Event tap intercepts keyboard input, filters hints by prefix matching
6. **Click Execution**: On hint match, `ClickService` posts CGEvents at element's center point

### Core Flow - Scroll Mode
1. **Activation**: Global hotkey (default ⌥E, configurable) triggers `ScrollModeController.toggleScrollMode()`
2. **Discovery**: `ScrollableAreaService` finds scrollable containers in frontmost app
3. **Hint Assignment**: Numbered hints (1, 2, 3...) assigned to each scrollable area
4. **Area Selection**: Type number or use arrow keys to select a scrollable area
5. **Scrolling**: Use hjkl keys (configurable) or arrow keys to scroll selected area
6. **Speed Control**: Hold Shift for dash speed (faster scrolling)
7. **Auto-deactivation**: Optional timer deactivates scroll mode after inactivity

### Key Components

**Services (singletons, @MainActor):**
- `HintModeController` - Orchestrates hint mode lifecycle, manages event tap for keyboard interception
- `ScrollModeController` - Orchestrates scroll mode lifecycle, handles area selection and scroll commands
- `AccessibilityService` - Queries macOS Accessibility API (AXUIElement) for clickable UI elements
- `ScrollableAreaService` - Discovers scrollable containers in the frontmost app
- `ClickService` - Posts CGEvent mouse clicks and scroll events at specified coordinates

**Models:**
- `UIElement` - Wrapper holding AXUIElement reference, screen frame, role, title, and assigned hint
- `ScrollableArea` - Wrapper for scrollable UI containers with frame and numbered hint

**Views:**
- `HintOverlayWindow` - Borderless, transparent NSWindow at screenSaver level displaying hint labels
- `ScrollOverlayWindow` - Overlay for scroll mode with numbered area indicators
- `PreferencesView` - SwiftUI Settings form for configuration
- `ShortcutRecorderView` - SwiftUI component for recording custom keyboard shortcuts with live preview

**App Infrastructure:**
- `keynaveApp` - SwiftUI App entry point with hidden window bridge for opening Settings
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
- Uses `@AppStorage` / `UserDefaults` for all preferences
- Defaults registered in `AppDelegate.applicationDidFinishLaunching()`

**Hotkey Coordination:**
- `Notification.Name.disableGlobalHotkeys` - Posted when shortcut recorder opens to prevent conflicts
- `Notification.Name.enableGlobalHotkeys` - Posted when shortcut recorder closes to re-register hotkeys
- Controllers listen for these notifications to temporarily unregister/re-register their hotkeys

### User Preferences

Stored in UserDefaults:

**Hint Mode:**
- `hintShortcutKeyCode` (Int): Virtual key code for hint mode activation (default: 49 = Space)
- `hintShortcutModifiers` (Int): Carbon modifier flags (default: cmdKey | shiftKey)
- `hintSize` (Double): Font size for hints (10-20pt)
- `hintColor` (String): "blue", "green", "orange", "purple"
- `continuousClickMode` (Bool): Stay in hint mode after clicking, refresh hints for continued clicking

**Scroll Mode:**
- `scrollShortcutKeyCode` (Int): Virtual key code for scroll mode activation (default: 14 = E)
- `scrollShortcutModifiers` (Int): Carbon modifier flags (default: optionKey)
- `scrollKeys` (String): Four characters for scroll directions, default "hjkl" (left, down, up, right)
- `scrollArrowMode` (String): "select" (arrows select areas) or "scroll" (arrows scroll)
- `scrollSpeed` (Double): Normal scroll speed multiplier (default: 5.0)
- `dashSpeed` (Double): Fast scroll speed when holding Shift (default: 9.0)
- `autoScrollDeactivation` (Bool): Auto-exit scroll mode after inactivity
- `scrollDeactivationDelay` (Double): Seconds before auto-deactivation (default: 5.0)
- `showScrollAreaNumbers` (Bool): Display numbered hints on scroll areas
- `scrollCommandsEnabled` (Bool): Enable/disable scroll mode entirely

## Key Technical Details

- Uses Carbon Event Manager for global hotkey registration (supports custom shortcuts)
- Event tap requires Accessibility permissions to intercept keyboard events
- Overlay windows use `.screenSaver` level to appear above all content
- Hints use monospaced system font for consistent sizing
- Backspace deletes last typed character, ESC cancels both hint and scroll modes
- Scroll mode uses CGEvent scroll wheel events with configurable speed multipliers
- ShortcutRecorderView uses NSEvent monitors to capture key combinations in real-time
- Carbon modifier constants (cmdKey, shiftKey, optionKey, controlKey) used for hotkey storage
