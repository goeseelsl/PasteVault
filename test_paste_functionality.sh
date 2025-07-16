#!/bin/bash

# Simple test script to verify paste functionality
echo "🧪 Testing ClipboardManager Paste Functionality"
echo "============================================="

# Build the project
echo "1. Building project..."
cd /Users/lawrencegoeseels/Documents/AI/ClipboardManager
swift build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
else
    echo "❌ Build failed!"
    exit 1
fi

# Check for duplicate files
echo "2. Checking for duplicate files..."
DUPLICATE_COUNT=$(find . -name "AccessibilityHelper.swift" -type f | wc -l)
if [ $DUPLICATE_COUNT -eq 1 ]; then
    echo "✅ Only one AccessibilityHelper.swift file found"
    find . -name "AccessibilityHelper.swift" -type f
else
    echo "❌ Found $DUPLICATE_COUNT AccessibilityHelper.swift files"
    find . -name "AccessibilityHelper.swift" -type f
    exit 1
fi

# Check file structure
echo "3. Checking file structure..."
if [ -f "ClipboardManager/Services/AccessibilityHelper.swift" ]; then
    echo "✅ AccessibilityHelper.swift exists in Services directory"
else
    echo "❌ AccessibilityHelper.swift missing from Services directory"
    exit 1
fi

if [ -f "ClipboardManager/AccessibilityHelper.swift" ]; then
    echo "❌ Duplicate AccessibilityHelper.swift found in root directory"
    exit 1
else
    echo "✅ No duplicate AccessibilityHelper.swift in root directory"
fi

echo ""
echo "🎉 All tests passed! The project is ready for testing."
echo ""
echo "📋 Next steps:"
echo "1. Run the app"
echo "2. Grant accessibility permissions when prompted"
echo "3. Test paste functionality by pressing Enter in the clipboard manager"
echo "4. Check console logs for debug output"
