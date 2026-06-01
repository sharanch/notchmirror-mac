# NotchMirror

A macOS menu-bar app that turns your MacBook notch into a mirror — click the notch to see a front-camera view in a squircle card below it. Includes a clipboard history manager.

---

## Building & Installing

### Requirements
- Xcode 15+
- macOS 14+ (Sonoma) target device (mba m2+ and mbp m2 pro and above)

### Steps to install

```bash
xcodebuild -project NotchMirror.xcodeproj -scheme NotchMirror \
  -configuration Debug -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="-" build

open ./build/Build/Products/Debug/NotchMirror.app

sudo cp -r ./build/Build/Products/Debug/NotchMirror.app /Applications/ ## moves to application so its an executable that can be launched using spotlight
```

---

## Login Item (Launch at Login)

System settings > login items > add NotchMirror 

---

## Permissions

| Permission | Why |
|---|---|
| Camera | Front camera mirror view |
| Pasteboard | Clipboard history monitoring |

Both are declared in `Info.plist` and `NotchMirror.entitlements`.
