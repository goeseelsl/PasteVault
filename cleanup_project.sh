#!/bin/bash

# ClipboardManager Project Cleanup Script
echo "🧹 Cleaning up ClipboardManager project..."

cd /Users/lawrencegoeseels/Documents/AI/ClipboardManager

# Create backup before cleanup
echo "📦 Creating backup..."
cp -r . ../ClipboardManager_backup_$(date +%Y%m%d_%H%M%S)

echo "🗑️  Removing unnecessary files..."

# Remove all markdown documentation files (keeping only essential project files)
rm -f *.md
rm -f enhanced_paste_test_guide.md

# Remove all test scripts
rm -f *test*.sh
rm -f *test*.py
rm -f test_*.swift
rm -f troubleshoot_*.sh
rm -f demo_*.sh
rm -f debug_*.sh
rm -f ultimate_*.sh
rm -f final_*.sh
rm -f improved_*.sh
rm -f maccy_*.sh
rm -f keyboard_layout_*.sh
rm -f clipy_*.sh

# Remove build and debug scripts
rm -f build.sh
rm -f open_in_xcode.sh

# Remove backup files
rm -f Package.swift.bak
rm -f ClipboardManager/ContentView.swift.backup

# Remove documentation files in ClipboardManager directory
rm -f "ClipboardManager/Addressing Excessive Transparency in Your Clipboar.md"
rm -f "ClipboardManager/Detailed Feature Specifications for macOS Clipboar.md"

# Remove doc directory (generated documentation)
rm -rf doc/

# Remove any temporary or generated files
find . -name "*.tmp" -delete
find . -name "*.bak" -delete
find . -name "*~" -delete
find . -name ".DS_Store" -delete

echo "✅ Cleanup complete!"
echo ""
echo "📋 Remaining project structure:"
echo "├── Package.swift"
echo "├── Package.resolved"
echo "├── ClipboardManager/"
echo "│   ├── Source files (.swift)"
echo "│   ├── Components/"
echo "│   ├── Features/"
echo "│   ├── Helpers/"
echo "│   ├── Views/"
echo "│   ├── Services/"
echo "│   ├── Resources/"
echo "│   └── Info.plist"
echo "├── .build/ (build output)"
echo "├── .git/ (version control)"
echo "└── .swiftpm/ (package manager)"
echo ""
echo "🚀 Project is now clean and ready for development!"

# Verify project still builds
echo "🔍 Verifying project builds..."
swift build

if [ $? -eq 0 ]; then
    echo "✅ Project builds successfully after cleanup!"
else
    echo "❌ Build failed after cleanup - please check for missing files"
fi
