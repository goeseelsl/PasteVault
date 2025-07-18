#!/usr/bin/env bash

# ClipboardManager Application Cleanup Script
# Removes unnecessary files while preserving important project files

set -e

echo "🧹 ClipboardManager Application Cleanup"
echo "========================================"

# Define files and directories to keep (important)
KEEP_FILES=(
    "build_professional_dmg.sh"
    "Package.swift"
    "Package.resolved"
    "ClipboardManager-1.0.2.dmg"  # Latest professional DMG
    "simple_dmg_builder.sh"       # Backup DMG builder
)

KEEP_DIRS=(
    "ClipboardManager"
    ".git"
    ".swiftpm"
    ".build"
)

echo "📋 Files and directories marked as IMPORTANT (will be kept):"
printf ' ✅ %s\n' "${KEEP_FILES[@]}"
printf ' ✅ %s/\n' "${KEEP_DIRS[@]}"
echo ""

# Remove old test DMG files
echo "🗑️  Removing old test DMG files..."
rm -f ClipboardManager-1.0.1-Test.dmg
rm -f ClipboardManager-1.0.2-Test.dmg
echo "   ✅ Removed old test DMG files"

# Remove markdown summary files (keeping only essential documentation)
echo "🗑️  Removing documentation/summary files..."
rm -f "Advanced Organization Window Feature Specification.md"
rm -f "CLEANUP_COMPLETE.md"
rm -f "CLOUDKIT_CRASH_FIX_SUMMARY.md"
rm -f "CLOUDKIT_CRASH_RESOLUTION.md"
rm -f "CLOUDKIT_SYNC_IMPLEMENTATION.md"
rm -f "CODE_QUALITY_REPORT.md"
rm -f "DATA_ENCRYPTION_IMPLEMENTATION.md"
rm -f "DMG_CREATION_SUMMARY.md"
rm -f "DMG_INSTALLER_GUIDE.md"
rm -f "ENHANCED_ICLOUD_SETTINGS_SUMMARY.md"
rm -f "FIXES_SUMMARY.md"
rm -f "IMAGE_FUNCTIONALITY_RESTORED.md"
rm -f "IMAGE_VISUALIZATION_FIX.md"
rm -f "ITEM_VISIBILITY_FIX.md"
rm -f "ITEM_VISIBILITY_FIX_SUMMARY.md"
rm -f "LAZY_KEYCHAIN_ACCESS_SUMMARY.md"
rm -f "OPTIONAL_ICLOUD_SYNC_SUMMARY.md"
rm -f "POST_FIX_QUALITY_REPORT.md"
rm -f "QUALITY_FIXES_SUMMARY.md"
rm -f "SIDEBAR_BACKGROUND_STYLING_ENHANCEMENT.md"
rm -f "SIDEBAR_CARD_BORDER_ENHANCEMENT.md"
rm -f "SIDEBAR_IMAGE_THUMBNAIL_ENHANCEMENT.md"
rm -f "SIDEBAR_IMAGE_VISIBILITY_FIX.md"
rm -f "SIDEBAR_OPEN_SCROLL_IMPLEMENTATION.md"
rm -f "SIDEBAR_SCROLL_AND_HIGHLIGHT_SUMMARY.md"
rm -f "SIDEBAR_SCROLL_FUNCTIONALITY_SUMMARY.md"
rm -f "SIDEBAR_SCROLL_HIGHLIGHT_FIX.md"
rm -f "SIDEBAR_SCROLL_RESET_FIX.md"
rm -f "SIDEBAR_SCROLL_RESET_IMPLEMENTATION.md"
rm -f "SOURCE_ICON_HOVER_FIX.md"
rm -f "WARNING_FIXES_SUMMARY.md"
echo "   ✅ Removed documentation files"

# Remove old/duplicate build scripts
echo "🗑️  Removing old build scripts..."
rm -f "build_dmg.sh"
rm -f "build_simple_dmg.sh"
rm -f "cleanup_project.sh"
rm -f "validate_dmg.sh"
echo "   ✅ Removed old build scripts"

# Remove test scripts
echo "🗑️  Removing test scripts..."
rm -f "create_test_image.swift"
rm -f "debug_sidebar_close.sh"
rm -f "debug_sidebar_enhanced.sh"
rm -f "final_sidebar_test.sh"
rm -f "test_comprehensive_keyboard_fix.sh"
rm -f "test_double_paste_fix.sh"
rm -f "test_fixes.sh"
rm -f "test_folder_filtering.sh"
rm -f "test_hotkey_fix.sh"
rm -f "test_image_clipboard.sh"
rm -f "test_image_copy.swift"
rm -f "test_keyboard_behavior.sh"
rm -f "test_keyboard_shortcut_after_paste.sh"
rm -f "test_keyboard_shortcut_fix.sh"
rm -f "test_keyboard_shortcut_fix_final.sh"
rm -f "test_keyboard_shortcuts.sh"
rm -f "test_sidebar_close_on_paste.sh"
rm -f "test_sidebar_hotkey_reload.sh"
rm -f "test_timing_fix.sh"
rm -f "test_window_fix.sh"
echo "   ✅ Removed test scripts"

# Remove documentation build artifacts
echo "🗑️  Removing documentation build artifacts..."
rm -rf "doc/"
echo "   ✅ Removed doc/ directory"

echo ""
echo "🎉 Cleanup completed successfully!"
echo ""
echo "📁 Remaining important files:"
echo "   • build_professional_dmg.sh (main DMG builder)"
echo "   • simple_dmg_builder.sh (backup DMG builder)"
echo "   • ClipboardManager-1.0.2.dmg (latest release)"
echo "   • Package.swift & Package.resolved (SPM configuration)"
echo "   • ClipboardManager/ (source code)"
echo "   • .git/ (version control)"
echo ""
echo "🚀 Project is now clean and ready for development!"
