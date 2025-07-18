# ClipboardManager DMG Installer Guide

## Overview
This guide explains how to create professional DMG installers for ClipboardManager and how users should install the application.

## 🛠️ **Building DMG Installers**

### **Option 1: Simple DMG (Recommended for quick builds)**
```bash
./build_simple_dmg.sh
```
- **Output**: `ClipboardManager-1.0.0-simple.dmg`
- **Size**: ~1.1MB
- **Features**: Basic app bundle with Applications link
- **Build Time**: ~30 seconds

### **Option 2: Professional DMG (Recommended for distribution)**
```bash
./build_professional_dmg.sh
```
- **Output**: `ClipboardManager-1.0.0.dmg`
- **Features**: 
  - Custom background image
  - Installation guide
  - Professional layout
  - Proper metadata
- **Build Time**: ~1 minute

### **Option 3: Full-Featured DMG (Advanced)**
```bash
./build_dmg.sh
```
- **Output**: `ClipboardManager-1.0.0.dmg`
- **Features**: 
  - Xcode integration when available
  - Advanced customization
  - Multiple fallback methods
  - Comprehensive error handling

## 📦 **DMG Contents**

### **Files Included:**
1. **ClipboardManager.app** - The main application bundle
2. **Applications** - Symbolic link to /Applications folder
3. **Installation Guide.rtf** - User installation instructions (professional DMG only)
4. **Background image** - Custom DMG appearance (professional DMG only)

### **App Bundle Structure:**
```
ClipboardManager.app/
├── Contents/
│   ├── MacOS/
│   │   └── ClipboardManager          # Executable binary
│   ├── Resources/
│   │   ├── Assets.xcassets          # App icons and assets
│   │   └── Preview Content/         # SwiftUI preview assets
│   ├── Info.plist                   # App metadata
│   └── ClipboardManager.entitlements # Security permissions
```

## 🚀 **Installation Instructions for Users**

### **Step 1: Download and Mount DMG**
1. Download the `ClipboardManager-1.0.0.dmg` file
2. Double-click the DMG file to mount it
3. A new window will open showing the installer contents

### **Step 2: Install Application**
1. Drag `ClipboardManager.app` to the `Applications` folder
2. Wait for the copy operation to complete
3. Eject the DMG by dragging it to Trash or right-clicking and selecting "Eject"

### **Step 3: First Launch**
1. Open **Applications** folder in Finder
2. Double-click **ClipboardManager** to launch
3. If you see a security warning:
   - Click "Cancel"
   - Go to **System Preferences** > **Security & Privacy**
   - Click "Open Anyway" next to the ClipboardManager warning
   - Click "Open" in the confirmation dialog

### **Step 4: Grant Permissions**
1. ClipboardManager will request **Accessibility** permissions
2. Click "Open System Preferences"
3. Click the lock icon and enter your password
4. Check the box next to **ClipboardManager**
5. Restart ClipboardManager if needed

## 🔧 **Technical Details**

### **System Requirements:**
- **macOS**: 12.0 (Monterey) or later
- **Architecture**: Universal (Intel + Apple Silicon)
- **RAM**: 8MB minimum
- **Storage**: 10MB free space

### **Permissions Required:**
- **Accessibility**: Monitor clipboard changes
- **Network**: iCloud sync (optional)
- **Keychain**: Store encryption keys securely

### **Security Features:**
- **Sandboxed**: Runs in secure app sandbox
- **Code Signed**: Digitally signed for security (when built with Xcode)
- **Encrypted Storage**: AES-256 encryption for all data
- **Keychain Integration**: Secure key management

## 🔍 **Troubleshooting**

### **Common Issues:**

#### **"App is damaged and can't be opened"**
- **Cause**: Quarantine attribute from download
- **Solution**: 
  ```bash
  xattr -c /Applications/ClipboardManager.app
  ```

#### **"App can't be opened because it's from an unidentified developer"**
- **Cause**: App not code signed with Apple Developer certificate
- **Solution**: 
  1. Right-click the app and select "Open"
  2. Click "Open" in the security dialog
  3. Or disable Gatekeeper temporarily:
     ```bash
     sudo spctl --master-disable
     ```

#### **Accessibility permissions not working**
- **Solution**: 
  1. Remove ClipboardManager from Accessibility list
  2. Re-add it and grant permissions
  3. Restart the application

#### **iCloud sync not available**
- **Cause**: App not properly signed for CloudKit
- **Solution**: This is expected when building from source
- **Note**: CloudKit requires Apple Developer Program membership

## 📋 **Build Requirements**

### **For Basic DMG:**
- macOS with Xcode Command Line Tools
- Swift 5.5+
- `hdiutil` (built into macOS)

### **For Professional DMG:**
- Above requirements plus:
- Python 3 with PIL (for custom backgrounds)
- ImageMagick (optional, for enhanced graphics)

### **For Distribution:**
- Apple Developer Program membership
- Code signing certificate
- Notarization for Gatekeeper compatibility

## 🎯 **Best Practices**

### **For Developers:**
1. **Test the DMG** on a clean system before distribution
2. **Code sign** the app with a valid certificate
3. **Notarize** the app for Gatekeeper compatibility
4. **Test installation** on both Intel and Apple Silicon Macs
5. **Verify permissions** work correctly after installation

### **For Users:**
1. **Download only** from trusted sources
2. **Verify the app** works before deleting the DMG
3. **Keep the DMG** as a backup for reinstallation
4. **Check permissions** if features don't work
5. **Update regularly** for security and feature improvements

## 📝 **Version History**

### **v1.0.0**
- Initial DMG installer release
- AES-256 encryption support
- CloudKit sync integration
- Professional installer experience

## 🔗 **Resources**

- **Source Code**: https://github.com/goeseelsl/PasteVault
- **Documentation**: See project README
- **Issues**: GitHub Issues page
- **Security**: Encrypted storage with Keychain integration

## 📄 **License**
ClipboardManager DMG installers include all necessary components for secure clipboard management. The application is distributed under the project's license terms.
