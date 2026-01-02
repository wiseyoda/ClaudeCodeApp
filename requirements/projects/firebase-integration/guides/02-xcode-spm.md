# Xcode & Swift Package Manager Integration

Step-by-step guide for adding Firebase SDK to the Xcode project.

## Prerequisites

- Xcode 16.2 or later (required for Firebase 12.x)
- `GoogleService-Info.plist` downloaded from Firebase Console

---

## Adding Firebase SDK

### Step 1: Open Package Manager

1. Open `CodingBridge.xcodeproj` in Xcode
2. Go to **File → Add Package Dependencies...** (or **Add Packages...**)

### Step 2: Add Firebase Repository

In the search field, enter:
```
https://github.com/firebase/firebase-ios-sdk.git
```

### Step 3: Configure Version

- **Dependency Rule**: Up to Next Major Version
- **Version**: `12.7.0` (or latest)

Click **Add Package**

### Step 4: Select Libraries

When prompted, select these Firebase products:

| Library | Required | Purpose |
|---------|----------|---------|
| **FirebaseAnalytics** | Yes | Usage analytics, required by Crashlytics |
| **FirebaseCrashlytics** | Yes | Crash reporting |
| **FirebaseMessaging** | Yes | Push notifications (FCM) |
| **FirebaseRemoteConfig** | Yes | Feature flags |
| **FirebasePerformance** | Yes | Performance monitoring |

Click **Add Package**

Wait for Xcode to resolve and download dependencies (~1-2 minutes).

---

## Configuring Build Settings

### Add Linker Flag

Required for FirebaseAnalytics:

1. Select project in navigator
2. Select **CodingBridge** target
3. Go to **Build Settings** tab
4. Search for "Other Linker Flags"
5. Add: `-ObjC`

### Configure Debug Information

Required for Crashlytics symbolication:

1. In Build Settings, search for "Debug Information Format"
2. Set to **DWARF with dSYM File** for:
   - Debug
   - Release
   - Any other configurations

### Disable User Script Sandboxing (if needed)

If Crashlytics symbol upload fails:

1. Search for "User Script Sandboxing"
2. Set to **No**

---

## Adding GoogleService-Info.plist

### Step 1: Add to Project

1. In Finder, locate `GoogleService-Info.plist`
2. Drag into Xcode project navigator
3. Drop in the `CodingBridge` group (same level as `Info.plist`)

### Step 2: Configure Options

When prompted:
- [x] **Copy items if needed**
- [x] **Create folder references** (or groups)
- [x] **Add to targets: CodingBridge**

### Step 3: Verify

- File appears in project navigator
- File appears in **Build Phases → Copy Bundle Resources**

---

## Updating Info.plist

Add this key to disable swizzling (required for SwiftUI):

```xml
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

### Using Xcode UI

1. Select `Info.plist` in navigator
2. Right-click → Add Row
3. Key: `FirebaseAppDelegateProxyEnabled`
4. Type: Boolean
5. Value: NO

### Verify Background Modes

Ensure these exist (should already be present):

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

---

## Capabilities Setup

### Step 1: Open Capabilities

1. Select project in navigator
2. Select **CodingBridge** target
3. Go to **Signing & Capabilities** tab

### Step 2: Add Push Notifications

1. Click **+ Capability**
2. Search for "Push Notifications"
3. Double-click to add

### Step 3: Verify Background Modes

1. Find **Background Modes** capability
2. Ensure **Remote notifications** is checked

---

## Adding Crashlytics Build Phase

### Step 1: Create Run Script

1. Select project in navigator
2. Select **CodingBridge** target
3. Go to **Build Phases** tab
4. Click **+** → **New Run Script Phase**

### Step 2: Configure Script

- **Name**: `Upload Crashlytics Symbols`
- **Shell**: `/bin/sh` (default)
- **Script**:
```bash
"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
```

### Step 3: Add Input Files

Click **+** under Input Files and add:

```
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${PRODUCT_NAME}
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Info.plist
$(TARGET_BUILD_DIR)/$(INFOPLIST_PATH)
```

### Step 4: Position Script

**Critical**: Drag the run script phase to be the **LAST** build phase.

Order should be:
1. Dependencies
2. Compile Sources
3. Link Binary With Libraries
4. Copy Bundle Resources
5. **Upload Crashlytics Symbols** ← Last

---

## Verification Build

### Step 1: Clean Build

1. **Product → Clean Build Folder** (Shift+Cmd+K)
2. **File → Packages → Reset Package Caches**

### Step 2: Build

1. Select iOS Simulator or device
2. **Product → Build** (Cmd+B)

### Step 3: Check for Errors

Common issues:
- Missing `-ObjC` linker flag
- Wrong Swift version
- Package resolution failures

### Step 4: Verify Imports

In any Swift file, try:

```swift
import FirebaseCore
import FirebaseMessaging
import FirebaseCrashlytics
import FirebaseRemoteConfig
import FirebasePerformance
```

If imports succeed, SDK is properly configured.

---

## Package Versions

Current Firebase package structure (v12.7.0):

```
firebase-ios-sdk
├── FirebaseAnalytics
├── FirebaseCore
├── FirebaseCrashlytics
├── FirebaseInstallations
├── FirebaseMessaging
├── FirebasePerformance
├── FirebaseRemoteConfig
├── GoogleAppMeasurement
├── GoogleDataTransport
├── GoogleUtilities
├── PromisesObjC
└── nanopb
```

---

## Troubleshooting

### "No such module 'FirebaseCore'"
1. Clean build folder
2. Reset package caches
3. Close and reopen Xcode
4. Rebuild

### "Package resolution failed"
1. Check internet connection
2. Try VPN if network restricted
3. Update Xcode to latest version

### "Undefined symbols for architecture"
1. Verify `-ObjC` linker flag added
2. Check all targets have Firebase linked
3. Clean and rebuild

### Build takes very long
- Initial Firebase build can take 5-10 minutes
- Subsequent builds use cache
- Enable "Build Active Architecture Only" for Debug

### "GoogleService-Info.plist not found"
1. Verify file is in project navigator
2. Verify file is in Copy Bundle Resources build phase
3. Check file is not in a subfolder
4. Ensure filename is exactly `GoogleService-Info.plist`
