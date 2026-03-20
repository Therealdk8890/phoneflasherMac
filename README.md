# PhoneFlasher Mac

A polished, App Store-ready macOS app for downloading ADB/Fastboot and flashing firmware images on Samsung, Pixel, LG, and OnePlus devices.

## Features

### Free
- Download Google Platform Tools (ADB & Fastboot) with progress tracking
- Real-time device status monitoring (ADB & Fastboot)
- Device reboot controls (system, bootloader, fastboot)
- Searchable activity logs
- First-launch onboarding walkthrough

### Pro (In-App Purchase)
- Flash boot, recovery, system, and vendor images
- Download vendor tools (Samsung Smart Switch, LG Bridge, etc.)
- Export logs to file
- All future features included

## Requirements
- macOS 12+
- Xcode 14+ (for building the SwiftUI version)

## Build & Run (SwiftUI / Xcode)
1. Open `PhoneFlasherMacSwift/PhoneFlasherMacSwift.xcodeproj` in Xcode
2. Select the **PhoneFlasherMac** target
3. Build & Run (Cmd+R)

## Legacy Python Version

The original Tkinter prototype is still available:

```bash
python3 src/phoneflasher.py
```

Build scripts:
```bash
bash build.sh       # .app bundle
bash build-dmg.sh   # DMG installer
```

## Architecture (SwiftUI)

```
PhoneFlasherMacSwift/
  PhoneFlasherMacSwiftApp.swift   - App entry, window & menu configuration
  ContentView.swift               - Sidebar navigation shell
  SetupView.swift                 - Platform & vendor tool downloads
  FlashView.swift                 - Device status & image flashing
  LogsView.swift                  - Searchable, exportable log viewer
  OnboardingView.swift            - First-launch walkthrough
  PaywallView.swift               - Pro upgrade paywall (StoreKit 2)
  SettingsView.swift              - Preferences & about
  StoreKitManager.swift           - StoreKit 2 in-app purchase manager
  PhoneFlasherModel.swift         - Core model (downloads, device, flashing)
  PhoneFlasherMac.entitlements    - App sandbox & USB entitlements
  Info.plist                      - App metadata & App Store configuration
```

## App Store Notes
- **Bundle ID**: `com.danielkissel.PhoneFlasherMac`
- **Category**: Developer Tools
- **Sandbox**: Enabled with network client, USB, and user-selected file access
- **Monetization**: One-time Pro purchase via StoreKit 2
- **Encryption**: No non-exempt encryption (`ITSAppUsesNonExemptEncryption = NO`)
- Set your `DEVELOPMENT_TEAM` in the Xcode project before submitting

## Safety
- macOS does not require USB drivers for ADB/Fastboot
- Flashing can brick devices -- always use firmware specific to your model
- If a vendor download URL changes, the app opens the official page as a fallback
