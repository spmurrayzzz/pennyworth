# AGENTS.md

Guidance for coding agents working on this repository. Read this file
before you change code. It records the behaviors and constraints that
matter for continuing work on the app.

## What this is

A fast, keyboard-first local launcher for macOS in the style of Alfred.
The product name is "Pennyworth". It performs these tasks:

- Search applications and files
- Open web searches
- Evaluate calculations
- Run three fixed system commands

The core app is implemented and committed. The items that need human
validation are listed at the end of this file.

Three hard product constraints apply:

- Use no account, no telemetry, and no paid Apple Developer membership.
- Make no direct network requests. Web actions send the query to the
  shown site in the default browser (`NSWorkspace.open`).
- No deferred privacy permissions. The app must not
  request Accessibility, Input Monitoring, Contacts, Automation, Screen
  Recording, or Full Disk Access.

## Toolchain and build

- Use Xcode 26.6, Swift 6.3.3, and macOS 26 as the minimum target on
  Apple silicon.
- Enable strict concurrency everywhere. First-party warnings are treated
  as errors.
- xcodegen generates the project from `project.yml`. Regenerate the
  project after you add or remove files.
- `KeyboardShortcuts` is the only dependency. Keep it pinned to
  **1.10.0**. Do not "upgrade" it. The 3.0.1 tag does not exist upstream.

Commands:

```sh
xcodegen generate
xcodebuild -project Pennyworth.xcodeproj -scheme Pennyworth -destination 'platform=macOS' test
xcodebuild -project Pennyworth.xcodeproj -scheme Pennyworth -configuration Release -destination 'platform=macOS' build
```

`xcodebuild test` runs the unit tests only. `PennyworthUITests` is
excluded from the default test scheme. Ad hoc signing ("Sign to Run
Locally") breaks the UI test runner bundle. Keep that exclusion.

Local install for verification:

```sh
tmp="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
  -path '*/Build/Products/Release/Pennyworth.app' -print -quit)"
rm -rf "$HOME/Applications/Pennyworth.app" && cp -R "$tmp" "$HOME/Applications/"
open "$HOME/Applications/Pennyworth.app"
```

The app is ad hoc signed (no team). The install replaces the bundle. After
each reinstall, check the SMAppService registration in Settings.

## Architecture

AppKit implements the app. SwiftUI implements the settings windows. There
is no storyboard. There is no SwiftUI app shell.

```
Pennyworth/App/               lifecycle, AppController wiring, status item
Pennyworth/PennyworthPanel/   panel, results, actions, Quick Look
Pennyworth/Search/            query parsing, coordinator, ranking
Pennyworth/Providers/        application, file, web, calculator, command
Pennyworth/Actions/           action executor and catalog
Pennyworth/Persistence/        SQLite store, settings, web search registry
Pennyworth/Infrastructure/     hotkey, login item, icons, signposts
Pennyworth/Settings/           SwiftUI settings windows
PennyworthTests/               unit tests, judged corpus, regression tests
PennyworthUITests/             UI smoke test (not in test scheme)
```

### Entry point

Do not convert `PennyworthMain.main()` back to `@main` on the
AppDelegate. `@main` on `NSApplicationDelegate` does not wire the
delegate without a storyboard. The app calls `NSApplication.shared` in
`Pennyworth/App/Main.swift`, assigns the delegate, and runs.

### Wiring that has broken before

- Assign `SearchCoordinator.onResults` in AppController. If it stays
  unassigned, the query runs but no results reach the panel. Keep the
  coordinator callback test green.
- `applicationIndex.onCatalogChange` is unused. The coordinator does not
  query again when the catalog changes. Do not connect it without a
  debounce. Spotlight updates will flood the panel with searches.
- The settings window opens with the `--open-settings` launch argument.
  The panel can be forced open with `PENNYWORTH_SMOKE_PANEL=1`. Use
  these when the hotkey and the menu bar are not available.

## Behavior problems

### File search uses a dedicated thread

`FileMetadataService.start`/`stop`/`snapshot` forward to
`MetadataQueryHost`, which owns an NSMetadataQuery on its own thread with
its own run loop. Keep the query on that thread. NSMetadataQuery can
throw or stall indefinitely on a broken Spotlight configuration. On the
main thread, it freezes the panel.

Two rules apply:

1. Do not wrap a single subpredicate in an `AND` compound.
   `NSMetadataQuery` throws `NSInvalidArgumentException` when
   `setSearchScopes:` receives `NSAndPredicateType` with one
   subpredicate. `MetadataQueryHost.buildPredicate` returns the OR
   compound directly for one term. It builds an AND compound only across
   multiple terms.
2. `stop()` and `start()` call the query thread for every poll. Keep the
   poll loop's wakes cheap. The loop already sleeps about 55 ms between
   snapshots.

### Identity of files

- File identity is `volume UUID + document id` (stable across renames).
  If that identity is not available, use the standardized path.
  On macOS, `URLResourceValues.documentID` is nil. Take the id from the
  Spotlight attribute `kMDItemDocumentIdentifier`. Do not use
  `fileResourceIdentifier`. That value does not survive a restart.
- The screen saver command's fallback bundle id is
  `com.apple.ScreenSaver.Engine`. Do not use `com.apple.screensaver`.
- Selection events: record them for allowed actions only. Never record
  them for url or calculation rows. Deduplicate events within the same
  row, query, and action for 1.5 seconds.
- The learned ranking applies within a 28-day window and uses per-event
  exponential decay. A reset clears the table.

### Getting the hotkey and menu behavior right

- The panel's key monitor is a non-isolated AppKit callback. The handler
  extracts only the sendable components (the keyCode and the modifier
  flags) before it crosses into `MainActor.assumeIsolated`. Do not pass
  `NSEvent` into the isolated closure. The compiler rejects it under the
  `@Sending` closure of Swift 6 `assumeIsolated`.
- The status item looks correct on macOS 26, but on this dev machine
  Bartender 6 moves the item to "Always Hidden" in the layout editor.
  Also, the item's icon was visually identical to the Spotlight
  magnifier. The app uses a purple rounded-square glyph. When the user
  reports a missing menu bar icon, check Bartender's layout section
  first. Do not change the source code.
- The panel's icon is created in `StatusItemController.makeStatusIcon`.

### Notes for this specific machine

- Safari does not exist on this boot volume
  (`/System/Applications/Safari.app`). Do not use "safari" in tests. Use
  TextEdit or System Settings.
- Spotlight works (mdfind returns results). File search in the app was
  failing because of the shape of the predicate, not because of the index.
- In the window server list, a live status item from a peer does not show
  in CGWindowList on this OS (a system process hosts it). Therefore
  window-list checks cannot verify the presence of a status bar.

## Coding conventions

Follow the repository and the global AGENTS rules:

- Enable strict concurrency everywhere. Treat warnings in all targets as
  errors.
- Do not add comments unless you are asked.
- Keep the change small.
- Do not create new abstractions.
- Do not add tests unless they verify behavior, add regression checks, or
  fix a regression.

The product name is "Pennyworth". The bundle id is `com.local.pennyworth`.
Both are permanent. Do not rename them.

Commit with the conventional commit style. Write the subject in lowercase.

## Workflow after UI changes

After you change the UI, do these steps:

1. Regenerate the project.
2. Run the 74 unit tests.
3. Build the Release configuration.
4. Reinstall the app into `~/Applications`.
5. Let the user verify the change interactively.

The tests and a clean Release build are the ground truth for
automation. The panel, the menu bar, and the shortcut need direct
verification by the user.

## Outstanding human validation gates

No agent can close any of these gates. They require live use:

- Press the hotkey across apps. Option+Space may conflict with the
  system. Set a different chord in Settings if it does.
- Confirm login-item registration after a reboot through SMAppService
  (turn Launch at Login on and reboot).
- Complete a VoiceOver walkthrough of the whole flow.
- Measure the hotkey-to-visible p95 time and the first warm file-query
  batch.
- Use the app for one week in daily work with no release-blocking
  failure.