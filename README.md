# keynave

A macOS menu bar application for keyboard-driven UI navigation. Click anywhere on your screen using keyboard shortcuts instead of the mouse.

## Overview

keynave displays alphabetic hints over clickable UI elements, allowing you to interact with any application without reaching for the mouse. Similar to Vimium for browsers, but for the entire macOS desktop.

## Features

### Hint Mode
- Overlay hints on all clickable elements in the frontmost app
- Type hint characters to click elements (e.g., "AJ" clicks the element labeled AJ)
- Two-character combinations for efficient navigation
- Text search: type element names to find and click them
- Continuous click mode for multiple clicks without reactivating
- Glass effect UI with customizable colors and transparency

### Scroll Mode
- Keyboard-based scrolling with vim-style keys (hjkl)
- Multiple scrollable area selection
- Configurable scroll speed and dash speed (Shift for faster)
- Auto-deactivation after inactivity

### Customization
- Configurable global hotkeys
- Custom hint characters (default: home row keys)
- Full color customization with live preview
- Adjustable hint size and transparency
- Arrow key behavior configuration

## Requirements

- macOS 14.0+
- Xcode 15+ (for building)
- Accessibility permissions

## Building

```bash
# Clone the repository
git clone <repository-url>
cd keynave

# Build from command line
xcodebuild -project keynave.xcodeproj -scheme keynave -configuration Debug build

# Or open in Xcode
open keynave.xcodeproj
# Press Cmd+R to build and run
```

## Setup

1. Launch keynave
2. Grant Accessibility permissions when prompted (System Settings > Privacy & Security > Accessibility)
3. The app appears in the menu bar

## Usage

### Default Shortcuts

| Action | Shortcut |
|--------|----------|
| Activate Hint Mode | Cmd + Shift + Space |
| Activate Scroll Mode | Option + E |
| Cancel/Exit | ESC |
| Clear search | Option (in hint mode) |
| Right-click | Ctrl + Enter (in hint mode) |

### Hint Mode Workflow

1. Press activation shortcut
2. Hints appear over clickable elements
3. Type the hint characters (e.g., "A", "AJ")
4. Element is clicked automatically
5. Mode deactivates (unless continuous mode is enabled)

Alternatively, type element text to search and auto-click when one match remains.

### Scroll Mode Workflow

1. Press activation shortcut
2. Numbered hints appear over scrollable areas
3. Select area by typing number or using arrow keys
4. Scroll with hjkl keys (or configured keys)
5. Hold Shift for faster scrolling
6. Press ESC to exit

## Configuration

Access preferences via the menu bar icon > Preferences, or use the standard Cmd+, shortcut.

### Tabs

- **Clicking**: Hotkey, hint characters, text search settings, continuous mode
- **Scrolling**: Hotkey, scroll keys, speed settings, auto-deactivation
- **Appearance**: Colors, transparency, hint size with live preview
- **General**: Accessibility permissions check

## Architecture

The application uses:
- SwiftUI for the settings interface
- AppKit for overlay windows and menu bar
- macOS Accessibility API for UI element discovery
- Carbon Event Manager for global hotkeys
- NSVisualEffectView for glass blur effects
- CGEvent for click and scroll simulation

## License

MIT License
