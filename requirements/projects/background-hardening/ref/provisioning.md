# Provisioning

> Apple Developer Portal setup.

## Prerequisites

- Apple Developer Program membership ($99/year)
- Access to Apple Developer Portal

## App ID Configuration

1. Go to Certificates, Identifiers & Profiles
2. Select Identifiers → App IDs
3. Edit your App ID (com.codingbridge.CodingBridge)
4. Enable:
   - [x] Push Notifications
   - [x] App Groups

## App Group

1. Identifiers → App Groups → +
2. Description: CodingBridge Shared
3. Identifier: `group.com.codingbridge.shared`
4. Register

## APNs Key

1. Keys → +
2. Name: CodingBridge APNs
3. Enable: Apple Push Notifications service (APNs)
4. Continue → Register
5. **Download .p8 file** (only available once!)
6. Note the Key ID

## Info.plist Additions

```xml
<!-- Background task identifiers -->
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.codingbridge.task.continued-processing</string>
    <string>com.codingbridge.task.refresh</string>
</array>

<!-- Background modes -->
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
    <string>remote-notification</string>
</array>

<!-- URL scheme -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>codingbridge</string>
        </array>
    </dict>
</array>
```

## Entitlements - Main App

```xml
<!-- CodingBridge.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>

    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.codingbridge.shared</string>
    </array>
</dict>
</plist>
```

## Entitlements - Widget Extension

```xml
<!-- CodingBridgeWidgetsExtension.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.codingbridge.shared</string>
    </array>
</dict>
</plist>
```

## Xcode Setup

### Main App Target

1. Signing & Capabilities → +
2. Add:
   - Push Notifications
   - Background Modes (fetch, processing, remote notifications)
   - App Groups (select group.com.codingbridge.shared)

### Widget Extension Target

1. Signing & Capabilities → +
2. Add:
   - App Groups (select group.com.codingbridge.shared)

## Provisioning Profiles

After adding capabilities, provisioning profiles need regeneration:

1. Xcode → Preferences → Accounts → Download Manual Profiles
2. Or use Automatic Signing

## Checklist

- [ ] App Group created: `group.com.codingbridge.shared`
- [ ] Push Notifications capability added to App ID
- [ ] APNs key (.p8) downloaded and stored securely
- [ ] Key ID noted
- [ ] Team ID noted
- [ ] Background modes configured
- [ ] Entitlements files created
- [ ] Widget extension configured with App Group

---
**Index:** [../00-INDEX.md](../00-INDEX.md)
