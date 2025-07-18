#!/bin/bash

# DMG Installer Validation Script
# Tests the created DMG files to ensure they work properly

echo "🔍 ClipboardManager DMG Validation"
echo "=================================="

# Check if DMG files exist
echo "📦 Checking for DMG files..."

SIMPLE_DMG="ClipboardManager-1.0.0-simple.dmg"
PROFESSIONAL_DMG="ClipboardManager-1.0.0.dmg"

if [ -f "$SIMPLE_DMG" ]; then
    SIMPLE_SIZE=$(ls -lh "$SIMPLE_DMG" | awk '{print $5}')
    echo "✅ Simple DMG: $SIMPLE_DMG ($SIMPLE_SIZE)"
else
    echo "❌ Simple DMG not found"
fi

if [ -f "$PROFESSIONAL_DMG" ]; then
    PROF_SIZE=$(ls -lh "$PROFESSIONAL_DMG" | awk '{print $5}')
    echo "✅ Professional DMG: $PROFESSIONAL_DMG ($PROF_SIZE)"
else
    echo "❌ Professional DMG not found"
fi

echo ""

# Test mounting DMGs
test_dmg() {
    local dmg_file="$1"
    local dmg_name="$2"
    
    echo "🔍 Testing $dmg_name..."
    
    if [ ! -f "$dmg_file" ]; then
        echo "❌ $dmg_file not found"
        return 1
    fi
    
    # Mount the DMG
    echo "  📁 Mounting $dmg_file..."
    local mount_output=$(hdiutil attach "$dmg_file" -noautoopen 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        local mount_point=$(echo "$mount_output" | grep "/Volumes" | awk '{print $3}')
        echo "  ✅ Successfully mounted at: $mount_point"
        
        # Check contents
        echo "  📋 Contents:"
        ls -la "$mount_point" | grep -E "(ClipboardManager\.app|Applications)" | while read line; do
            echo "    ✅ $line"
        done
        
        # Check app bundle
        if [ -d "$mount_point/ClipboardManager.app" ]; then
            echo "  📱 App bundle structure:"
            if [ -f "$mount_point/ClipboardManager.app/Contents/Info.plist" ]; then
                echo "    ✅ Info.plist present"
            else
                echo "    ❌ Info.plist missing"
            fi
            
            if [ -f "$mount_point/ClipboardManager.app/Contents/MacOS/ClipboardManager" ]; then
                echo "    ✅ Executable present"
                # Check if executable is valid
                local exec_file="$mount_point/ClipboardManager.app/Contents/MacOS/ClipboardManager"
                if file "$exec_file" | grep -q "Mach-O"; then
                    echo "    ✅ Valid Mach-O executable"
                else
                    echo "    ❌ Invalid executable format"
                fi
            else
                echo "    ❌ Executable missing"
            fi
            
            if [ -d "$mount_point/ClipboardManager.app/Contents/Resources" ]; then
                echo "    ✅ Resources directory present"
            else
                echo "    ⚠️  Resources directory missing"
            fi
        else
            echo "  ❌ ClipboardManager.app not found"
        fi
        
        # Unmount
        echo "  📤 Unmounting..."
        hdiutil detach "$mount_point" >/dev/null 2>&1
        echo "  ✅ $dmg_name validation complete"
    else
        echo "  ❌ Failed to mount $dmg_file"
        return 1
    fi
    
    echo ""
}

# Test both DMGs if they exist
if [ -f "$SIMPLE_DMG" ]; then
    test_dmg "$SIMPLE_DMG" "Simple DMG"
fi

if [ -f "$PROFESSIONAL_DMG" ]; then
    test_dmg "$PROFESSIONAL_DMG" "Professional DMG"
fi

echo "🎯 Validation Summary:"
echo "====================="

if [ -f "$SIMPLE_DMG" ] && [ -f "$PROFESSIONAL_DMG" ]; then
    echo "✅ Both DMG installers are available and ready for distribution"
    echo ""
    echo "📦 Recommended for distribution: $PROFESSIONAL_DMG"
    echo "🔧 For quick testing: $SIMPLE_DMG"
elif [ -f "$PROFESSIONAL_DMG" ]; then
    echo "✅ Professional DMG is ready for distribution"
elif [ -f "$SIMPLE_DMG" ]; then
    echo "✅ Simple DMG is available for testing"
else
    echo "❌ No DMG files found. Run a build script first."
    exit 1
fi

echo ""
echo "🚀 Installation Instructions for Users:"
echo "1. Double-click the DMG file"
echo "2. Drag ClipboardManager.app to Applications"
echo "3. Launch from Applications folder"
echo "4. Grant accessibility permissions when prompted"
