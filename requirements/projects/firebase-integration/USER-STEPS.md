# User Steps - Manual Actions Required

These are actions **you must perform personally** that cannot be automated. Complete these before Claude can implement the code.

---

## Step 1: Create Firebase Project

**Time:** ~5 minutes

### Instructions

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Create a project"** (or "Add project")
3. Enter project name: `CodingBridge` (or your preferred name)
4. Click **Continue**
5. **Google Analytics**: Enable it (required for Crashlytics)
   - Select or create a Google Analytics account
   - Accept terms
6. Click **Create project**
7. Wait for project creation (~30 seconds)
8. Click **Continue**

### Verification
- [ ] Firebase project created
- [ ] Google Analytics enabled for project

---

## Step 2: Register iOS App

**Time:** ~3 minutes

### Instructions

1. In Firebase Console, click the **iOS+ icon** on project overview
2. Enter your **Bundle ID**: **`com.level.CodingBridge`**
   - This is your confirmed bundle ID from Xcode
3. **App nickname**: `CodingBridge iOS` (optional)
4. **App Store ID**: Leave blank (add later when published)
5. Click **Register app**

### Verification
- [ ] iOS app registered with bundle ID: `com.level.CodingBridge`

---

## Step 3: Download GoogleService-Info.plist

**Time:** ~2 minutes

### Instructions

1. After registering, click **Download GoogleService-Info.plist**
2. Save the file (do not rename it)
3. **Important**: Keep this file secure - it contains API keys

### Where to Put It

```
/Users/ppatterson/dev/CodingBridge/CodingBridge/GoogleService-Info.plist
```

Place at the same level as `Info.plist` in the CodingBridge folder.

### Verification
- [ ] `GoogleService-Info.plist` downloaded
- [ ] File placed in `CodingBridge/` folder
- [ ] File added to `.gitignore` (do not commit to git!)

---

## Step 4: Create APNs Authentication Key

**Time:** ~5 minutes

### Why This Is Needed
Firebase Cloud Messaging (FCM) needs to communicate with Apple's Push Notification service (APNs). This key authorizes Firebase to send push notifications on your behalf.

### Instructions

1. Go to [Apple Developer Certificates](https://developer.apple.com/account/resources/authkeys/list)
2. Click the **+** button to create a new key
3. Enter **Key Name**: `CodingBridge FCM Key`
4. Check **Apple Push Notifications service (APNs)**
5. Click **Continue**
6. Click **Register**
7. **Download the key** (you can only download it once!)
   - File will be named like: `AuthKey_XXXXXXXXXX.p8`
8. **Note the Key ID** shown on the page (10-character ID)
9. **Note your Team ID** from [Membership page](https://developer.apple.com/account/#/membership)

### Store Securely
Save these somewhere safe (password manager, secure notes):
- [ ] APNs Key file (`.p8`)
- [ ] Key ID: `__________`
- [ ] Team ID: `__________`

---

## Step 5: Upload APNs Key to Firebase

**Time:** ~2 minutes

### Instructions

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click **gear icon** → **Project settings**
4. Go to **Cloud Messaging** tab
5. Scroll to **Apple app configuration**
6. Under **APNs Authentication Key**, click **Upload**
7. Upload your `.p8` file
8. Enter **Key ID** (from Step 4)
9. Enter **Team ID** (from Step 4)
10. Click **Upload**

### Verification
- [ ] APNs key uploaded successfully
- [ ] Key ID matches
- [ ] Team ID matches

---

## Step 6: Enable Xcode Capabilities

**Time:** ~2 minutes

### Instructions

1. Open `CodingBridge.xcodeproj` in Xcode
2. Select the **CodingBridge** target
3. Go to **Signing & Capabilities** tab
4. Verify these capabilities exist (add if missing):

#### Push Notifications
- Click **+ Capability**
- Search and add **Push Notifications**

#### Background Modes
- Should already exist
- Verify **Remote notifications** is checked

### Verification
- [ ] Push Notifications capability added
- [ ] Background Modes → Remote notifications checked

---

## Step 7: Configure Remote Config (Firebase Console)

**Time:** ~5 minutes

### Instructions

1. In Firebase Console, go to **Remote Config** (left sidebar)
2. Click **Create configuration** (or **Add parameter** if exists)
3. Add these initial parameters:

| Parameter key | Default value | Type |
|--------------|---------------|------|
| `feature_ssh_enabled` | `true` | Boolean |
| `feature_ideas_enabled` | `true` | Boolean |
| `max_message_history` | `50` | Number |
| `session_timeout_minutes` | `30` | Number |
| `api_timeout_seconds` | `30` | Number |

4. Click **Publish changes**

### Verification
- [ ] Remote Config parameters created
- [ ] Changes published

---

## Step 8: Test Push Notifications

**Time:** ~5 minutes (after code is implemented)

### Prerequisites
- Firebase integration code must be implemented
- App must be running on a **physical device** (not simulator)

### Instructions

1. Run the app on your iPhone
2. Accept notification permissions when prompted
3. Note the FCM token printed in Xcode console
4. In Firebase Console, go to **Cloud Messaging**
5. Click **Send your first message**
6. Enter test message title and body
7. Click **Send test message**
8. Paste the FCM token
9. Click **Test**

### Verification
- [ ] Test notification received on device
- [ ] Notification appears correctly

---

## Summary Checklist

### Firebase Console
- [ ] Project created
- [ ] iOS app registered
- [ ] GoogleService-Info.plist downloaded
- [ ] APNs key uploaded
- [ ] Remote Config parameters set

### Apple Developer
- [ ] APNs Authentication Key created
- [ ] Key ID noted
- [ ] Team ID noted

### Xcode
- [ ] GoogleService-Info.plist added to project
- [ ] Push Notifications capability enabled
- [ ] Background Modes configured

### Security
- [ ] GoogleService-Info.plist added to .gitignore
- [ ] APNs key (.p8) stored securely
- [ ] No credentials committed to git

---

## Troubleshooting

### "No matching provisioning profile"
1. Go to Xcode → Signing & Capabilities
2. Ensure "Automatically manage signing" is checked
3. Select your development team

### "APNs certificate/key not found"
1. Verify key uploaded in Firebase Console
2. Check Key ID and Team ID match exactly
3. Ensure `.p8` file is the original download

### "Push notifications not working in simulator"
Push notifications require a physical device. The simulator cannot receive push notifications.

### "GoogleService-Info.plist not found"
1. Ensure file is in the correct location
2. Ensure file is added to Xcode project (appears in Project Navigator)
3. Ensure target membership includes CodingBridge

---

## Next Steps

After completing all user steps:

1. Tell Claude: "I've completed the Firebase user steps"
2. Claude will implement the code changes
3. Test the integration on a physical device
