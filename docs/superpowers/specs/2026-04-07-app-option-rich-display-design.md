# App Option Rich Display Design

## Goal

Upgrade app-selection entry points so users can see app icon, display name, and bundle identifier in both:

- the `Default App` filter chooser
- the `Add Extension` default-app chooser

## Scope

### In Scope

- Replace the toolbar's plain-text default-app picker with a richer chooser
- Replace the `Add Extension` form's plain-text app picker with a richer chooser
- Reuse the existing app-list presentation style where possible
- Preserve existing filter behavior and add-extension submission behavior

### Out of Scope

- Changing how default-app filtering works
- Changing candidate-app grouping in the single-extension picker
- Changing batch app picker behavior
- Adding icon caching or list virtualization

## Problem

The current UI has two places that still rely on plain-text app selection:

- toolbar `Default App` filtering
- `Add Extension` app selection

This creates ambiguity when app names are similar and is visually inconsistent with the richer app picker already used elsewhere in the product.

## Product Direction

Whenever a user is choosing an app in this tool, the UI should make app identity legible without forcing the user to remember bundle identifiers.

The visual hierarchy should be:

- app icon
- app display name
- bundle identifier as secondary text

This keeps the UI readable for ordinary use while still surfacing the stable identifier when users need to disambiguate similar apps.

## Toolbar Filter Chooser

The existing toolbar `Picker` should be replaced with a button-driven chooser.

Behavior:

- the toolbar still shows a `Default App` control
- when no filter is active, it displays `All Apps`
- when a filter is active, it displays the selected app name
- clicking the control opens a chooser sheet

The chooser sheet should show:

- one explicit `All Apps` item at the top
- then one row per filterable app
- each app row shows icon, app name, and bundle identifier

Selecting an item applies the filter immediately and dismisses the sheet.

Canceling dismisses the sheet without changing the current filter.

## Add Extension App Chooser

The `Add Extension` form should replace the current inline `Picker` with a button-driven chooser.

Behavior:

- before a selection, the control reads `Choose an app`
- after a selection, the control reflects the chosen app
- clicking the control opens a chooser sheet
- app rows show icon, app name, and bundle identifier
- choosing an app updates the local form state only
- the add form is still submitted only when the user presses `Add`

Canceling the chooser should not reset the form.

## Reuse Strategy

The current `AppPickerSheet` already renders rich app rows.

This pass should extend or adapt that component rather than introducing another independent app-list renderer.

The toolbar chooser and add-extension chooser can share the same visual list pattern while differing in:

- title
- presence of an `All Apps` item
- selection callback behavior

## Architecture Changes

### RootView

Add responsibilities for:

- managing presentation of the toolbar filter chooser sheet
- feeding filter options into that chooser
- applying `All Apps` or one concrete app from the chooser result

### AddExtensionSheet

Add responsibilities for:

- managing presentation of an app chooser sheet
- storing the selected app locally until final form submission

### AppPickerSheet

Expand responsibilities for:

- optionally supporting a special leading item such as `All Apps`
- continuing to render app rows with icon, app name, and bundle identifier

## Testing Strategy

### Automated Tests

Add or update tests only where behavior changes are meaningful:

- add-extension submission still requires a selected app
- toolbar filter still updates the same filter state after chooser selection

No snapshot testing is required in this pass.

### Build Verification

Verify:

- `swift test`
- `swift build`

### Manual Validation

Validate in the running app:

1. open the toolbar `Default App` chooser and confirm app rows show icon, name, and bundle id
2. choose one app and confirm filtering still works
3. reopen the toolbar chooser and cancel it, confirming the current filter remains unchanged
4. open `Add Extension`, launch its app chooser, and confirm app rows show icon, name, and bundle id
5. choose an app, return to the form, and confirm the selection persists until `Add` or `Cancel`

## Acceptance Criteria

This pass is complete when:

- the toolbar filter chooser shows icon, app name, and bundle id
- the add-extension chooser shows icon, app name, and bundle id
- both choosers support cancel without unwanted side effects
- existing filter and add-extension flows still work
