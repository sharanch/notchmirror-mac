# NotchMirror

A macOS menu-bar app that turns your MacBook notch into a mirror — click the notch to see a front-camera view in a squircle card below it. Includes a clipboard history manager.

---

## Building & Installing

### Requirements
- Xcode 15+
- macOS 14+ (Sonoma) target device
- Apple Developer account (free tier is fine for personal use; paid required for notarization)

### Steps

1. Open `NotchMirror.xcodeproj` in Xcode.
2. In the Project navigator, select the **NotchMirror** target.
3. Under **Signing & Capabilities**, set your Team to your Apple ID.  
   Xcode will auto-update the bundle ID if needed.
4. **Run** (`⌘R`) to test on your Mac directly.

---

## Creating a Distributable DMG

### 1. Archive
In Xcode: **Product → Archive**  
Wait for the Organizer to open.

### 2. Export
In the Organizer:
- Click **Distribute App**
- Choose **Direct Distribution** (no App Store)
- Choose **Export** → save the `.app` somewhere, e.g. `~/Desktop/NotchMirror.app`

### 3. Create DMG
```bash
cd /path/to/NotchMirror   # this project folder
./create-dmg.sh ~/Desktop/NotchMirror.app
```
This produces `NotchMirror.dmg` in the current folder.  
Users double-click it → drag **NotchMirror** to **Applications** → done.

```bash
xcodebuild -project NotchMirror.xcodeproj -scheme NotchMirror \
  -configuration Debug -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="-" build

open ./build/Build/Products/Debug/NotchMirror.app
```

Get an app-specific password at: https://appleid.apple.com → Security → App-Specific Passwords

---

## Login Item (Launch at Login)

NotchMirror registers itself as a login item automatically on **first launch** using `SMAppService` (the modern macOS 13+ API). It will appear under:

> **System Settings → General → Login Items & Extensions → Allow in the Background**

To toggle it off, remove it there, or call `appDelegate.setLaunchAtLogin(false)` programmatically.

---

## Permissions

| Permission | Why |
|---|---|
| Camera | Front camera mirror view |
| Pasteboard | Clipboard history monitoring |

Both are declared in `Info.plist` and `NotchMirror.entitlements`.
