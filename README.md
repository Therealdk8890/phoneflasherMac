# PhoneFlasher Mac

macOS GUI tool to download ADB/Fastboot and flash images for Samsung, Pixel, LG, and OnePlus devices.

## What it does
- Downloads Google platform-tools (ADB/Fastboot) automatically
- Optional vendor tools downloads for Samsung/LG
- Flashes selected images via fastboot (boot, recovery, system, vendor)
- Provides quick device status checks (adb/fastboot)

## Requirements
- macOS 12+
- Python 3.10+ (Tkinter is included in standard Python installs)

## Run
```bash
python3 src/phoneflasher.py
```

or:
```bash
bash run.sh
```

## Build a macOS app (.app)
```bash
bash build.sh
```

The app will be at `dist/PhoneFlasherMac.app`.

## Build a DMG
```bash
bash build-dmg.sh
```

The DMG will be at `dist/PhoneFlasherMac.dmg`.

## Swift/Xcode Version
The SwiftUI Xcode project lives in `PhoneFlasherMacSwift/`.
Open `PhoneFlasherMacSwift/PhoneFlasherMacSwift.xcodeproj` in Xcode and build/run the `PhoneFlasherMac` target.

## Notes
- macOS does not require USB drivers for ADB/Fastboot.
- If a vendor changes a download URL, the app will open the official page as a fallback.
- Flashing can brick devices. Use firmware specific to your model and verify checksums.

## Folder layout
- `src/phoneflasher.py` - GUI app
- `src/tools/` - platform-tools extraction target
- `src/vendor/` - optional vendor downloads
- `src/downloads/` - cached downloads
- `PhoneFlasherMacSwift/` - SwiftUI Xcode project
