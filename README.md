# OpenWithGUI

OpenWithGUI is a macOS desktop app for inspecting and editing file extension default-app associations in one place.

Instead of going through Finder's `Get Info -> Open with -> Change All...` flow one extension at a time, OpenWithGUI gives you a table-first manager for the current system state.

[中文说明](README.zh-CN.md)

## Screenshot

![OpenWithGUI screenshot](docs/assets/openwithgui-screenshot.png)

## What It Does

- Lists extension-to-default-app associations in a single table.
- Shows the current default app, bundle ID, and status for each extension.
- Filters rows by default app and status.
- Searches by extension only, so results stay predictable.
- Supports multi-select, then assigns one app to all selected extensions in one action.
- Shows candidate apps for a single extension before changing it.
- Lets you add custom extensions and remove user-added ones.

## Current Scope

This first version focuses only on:

- `file extension -> default app`

It does not currently manage UTI / Uniform Type associations, folders, or URL schemes.

## Requirements

- macOS 14 or later
- Swift 6 toolchain / a recent Xcode that supports Swift 6

## Build And Run

Build the app bundle:

```bash
./scripts/package-macos-app.sh
```

Build a release bundle:

```bash
./scripts/package-macos-app.sh --release
```

Build and open it immediately:

```bash
./scripts/package-macos-app.sh --open
```

The generated app bundle will be placed at:

```text
dist/OpenWithGUI.app
```

## Project Structure

```text
Sources/OpenWithGUIApp    SwiftUI app, models, services, view models, views
Tests/OpenWithGUIAppTests Unit tests
scripts/                  Packaging helpers
docs/assets/              README assets
```

## Why This Exists

macOS makes default-app management tedious:

- You have to change associations one file type at a time.
- The system does not offer a central panel for reviewing everything.
- It is hard to see which app currently owns a given extension.
- Some apps register broad associations and leave behind confusing state.

OpenWithGUI is meant to make that state visible and editable without requiring users to memorize bundle IDs or click through repeated Finder dialogs.

## Acknowledgements

- linux.do
