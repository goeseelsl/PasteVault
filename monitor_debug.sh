#!/bin/bash

echo "🔍 Live ClipboardManager Debug Monitor"
echo "====================================="
echo ""
echo "This will show live debug output from ClipboardManager."
echo "After starting this monitor:"
echo "1. Launch ClipboardManager"
echo "2. Copy some text"
echo "3. Open ClipboardManager and try to paste with Enter"
echo "4. Watch for debug messages below"
echo ""
echo "Press Ctrl+C to stop monitoring"
echo ""
echo "Starting log stream..."
echo "======================"

# Monitor ClipboardManager process logs
log stream --process ClipboardManager --level debug
