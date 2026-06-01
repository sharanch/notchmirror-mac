# NotchMirror

A macOS menu-bar app that turns your MacBook notch into a mirror — click the notch to see a front-camera view in a squircle card below it. Includes a clipboard history manager.

---

## Install (Download)

1. Go to the [Releases](../../releases) page and download the latest `NotchMirror-vX.X.X.dmg`
2. Open the DMG and drag **NotchMirror** to your Applications folder
3. Since the app is unsigned, macOS may block it on first launch. Run this once in Terminal:

```bash
xattr -cr /Applications/NotchMirror.app
```

4. Open NotchMirror from Applications or Spotlight

> **Why this is needed:** Apple requires a paid Developer account ($99/year) to notarize apps.
> Without notarization, macOS quarantines apps downloaded from the internet.
> The `xattr -cr` command removes that quarantine flag — it's safe to run.

---

## Login Item (Launch at Login)

System Settings → General → Login Items → add NotchMirror

---

## Permissions

| Permission | Why |
|---|---|
| Camera | Front camera mirror view |
| Pasteboard | Clipboard history monitoring |

Both are declared in `Info.plist` and `NotchMirror.entitlements`.

---

## Requirements

- macOS 14 Sonoma or later
- MacBook with notch (M2 Air and above, M2 Pro and above)

---

## Build from Source

### Requirements
- Xcode 15+

### Steps

```bash
xcodebuild -project NotchMirror.xcodeproj -scheme NotchMirror \
  -configuration Debug -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="-" build

open ./build/Build/Products/Debug/NotchMirror.app
```