# Pennyworth

A fast, keyboard-first local pennyworth for macOS. Search applications and files,
open web searches, evaluate calculations, and run a small set of system
commands.

No account, no telemetry, and no direct network requests. The only dependency
is the `KeyboardShortcuts` package (pinned to `1.10.0`; see `Package.resolved`).

## Build

Requirements:

- macOS 26.0 or later, Apple silicon
- Xcode 26.6 (Swift 6, strict concurrency)
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

Regenerate the project and build:

```sh
xcodegen generate
xcodebuild -project Pennyworth.xcodeproj -scheme Pennyworth -configuration Debug build
```

Run the unit tests:

```sh
xcodebuild -project Pennyworth.xcodeproj -scheme Pennyworth \
  -destination 'platform=macOS' test
```

The automated test run covers parser, ranking, fuzzy matching, calculator,
URL policy, and template validation (63 assertions in the judged corpus under
`PennyworthTests/`). UI tests require manually configured code signing and are
excluded from the default test action.

## Local release install

1. Build the Release configuration:

   ```sh
   xcodebuild -project Pennyworth.xcodeproj -scheme Pennyworth \
     -configuration Release -destination 'platform=macOS' build
   ```

2. Copy the app to `~/Applications`:

   ```sh
   APP=$(find "$HOME/Library/Developer/Xcode/DerivedData" \
     -path '*/Build/Products/Release/Pennyworth.app' | head -1)
   mkdir -p "$HOME/Applications"
   cp -R "$APP" "$HOME/Applications/"
   ```

3. Start the installed copy from `~/Applications/Pennyworth.app`.
4. Open Settings from the status bar and enable Launch at Login.

The app uses ad hoc signing (`Sign to Run Locally`). If macOS rejects the
signature after a build, open Login Items in System Settings and add the app
manually. After replacing an installed build, recheck `Launch at Login` in
Settings; unregister and register again if the status feels stale.

Application support data lives at:
`~/Library/Application Support/com.local.pennyworth/pennyworth.sqlite3`

## Shortcuts

| Key | Behavior |
| --- | --- |
| Option-Space (configurable) | Toggle the pennyworth |
| Up / Down | Change selection |
| Return | Run the primary action |
| Command-Return | Reveal the selection in Finder |
| Command-Y | Quick Look for a file |
| Command-C | Copy the selected path / URL / result |
| Right arrow at end | Open the action list |
| Left arrow | Return from the action list |
| Command-1 .. 9 | Run the result at that position |
| Escape | Clear the query, then close |

## Layout

```
Pennyworth/
  App/          application lifecycle
  PennyworthPanel/ panel UI, actions, Quick Look
  Search/       query parsing, coordinator, ranking
  Providers/    application, file, web, calculator, command providers
  Actions/      result actions and execution
  Persistence/  SQLite store, web searches, app settings
  Infrastructure/ hotkey, login item, icons, signposts
  Settings/     SwiftUI settings windows
PennyworthTests/  unit + judged corpus tests
PennyworthUITests/ UI smoke test
```