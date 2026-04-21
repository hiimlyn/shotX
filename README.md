# ShotX

Native macOS menu bar screenshot prototype.

Requires macOS 15.2 or newer.

## Features

- Menu bar app using `NSStatusItem`.
- `Cmd+Shift+S` opens a drag-to-select overlay and captures the selected screen area.
- `PrtSc` is registered as the macOS `F13` key and captures the main display.
- Window capture remains available from the menu bar menu.
- Captures are copied to the clipboard and opened in a preview window.
- Preview window includes `Copy` and `Save` actions.
- Screen Recording permission check with a shortcut to System Settings.

## Development Signing

macOS Screen Recording permission is tied to the app's code signing identity. Debug builds use an ad-hoc signature with a stable designated requirement:

```text
identifier "com.lynx.shotx"
```

That keeps the signing requirement stable across code changes, instead of letting macOS key permission off a changing ad-hoc code hash.

For the smoothest loop, use a stable local app path:

```sh
./scripts/dev-build-run.sh
```

That installs and opens:

```text
~/Applications/ShotX-dev/ShotX.app
```

Grant Screen Recording permission once for that app. Rebuilds through the script should keep using the same identity and path.

## Build

```sh
xcodebuild -project ShotX.xcodeproj -scheme ShotX -configuration Debug -derivedDataPath /tmp/shotx-derived build
```

The built app is created at:

```text
/tmp/shotx-derived/Build/Products/Debug/ShotX.app
```

For normal local use, open `ShotX.xcodeproj` in Xcode, select the `ShotX` scheme, and run the app. The Debug target uses the same stable ad-hoc signing requirement.

For unsigned CI-style builds, keep using:

```sh
xcodebuild -project ShotX.xcodeproj -scheme ShotX -configuration Debug -derivedDataPath /tmp/shotx-derived CODE_SIGNING_ALLOWED=NO build
```

## Permission Notes

macOS Screen Recording permission is attached to the app identity and path. If you repeatedly run unsigned builds from changing DerivedData locations, System Settings can show permission as enabled while a fresh build still behaves like a new app. Prefer `./scripts/dev-build-run.sh` so the installed app path stays fixed.

If permission gets stuck during development, remove ShotX from Screen Recording in System Settings, quit the app, run it again, and grant permission when macOS asks.
