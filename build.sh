#!/bin/bash
set -e

# Clean build directory
rm -rf .build

# Create build directories
mkdir -p .build/objects
mkdir -p .build/bin

# Swift compiler flags
SWIFTC="swiftc"
SWIFTFLAGS="-swift-version 5 -target arm64-apple-macosx12.0"
FRAMEWORKS="-framework AppKit -framework Foundation -framework CoreData -framework SwiftUI"

# Compile each Swift file
echo "Compiling Swift files..."
for file in ClipboardManager/*.swift ClipboardManager/*/*.swift; do
  echo "Compiling $file..."
  $SWIFTC $SWIFTFLAGS -c "$file" -o ".build/objects/$(basename "$file" .swift).o"
done

# Link all object files
echo "Linking..."
$SWIFTC $SWIFTFLAGS .build/objects/*.o $FRAMEWORKS -o .build/bin/ClipboardManager

echo "Build complete: .build/bin/ClipboardManager"
