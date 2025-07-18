<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" class="logo" width="120"/>

# Pinned Items Feature Specification

## Overview

The Pinned Items feature allows users to "pin" specific clipboard items for quick, persistent access. Pinned items are displayed in a dedicated section at the bottom of the main sidebar. This section is dynamically visible only when at least one item is pinned. To maintain a clean UI, the pinned area is designed to visibly display up to 3 items at a time (e.g., in a horizontal or vertical layout), but it supports scrolling if more than 3 items are pinned, allowing users to access additional pinned content without overwhelming the interface. This encourages thoughtful pinning while providing flexibility for power users.

This feature builds on existing clipboard history by adding a layer of prioritization, similar to favorites in other productivity apps. It integrates seamlessly with the sidebar's design, ensuring it doesn't disrupt the main clipboard list.

## Key Requirements

- **Visibility**: The pinned section appears only if there are pinned items (hidden otherwise to avoid clutter).
- **Capacity and Display**:
    - Visibly shows up to 3 items without scrolling (e.g., in a compact row or stack).
    - If more than 3 items are pinned, the section becomes scrollable (horizontal or vertical) to reveal additional items.
    - No hard limit on total pinned items, but users should be encouraged to manage them (e.g., via a "Manage Pins" option).
- **Placement**: At the bottom of the sidebar, below the main clipboard history list.
- **Interactions**: Pinned items support quick actions like pasting, unpinning, or editing, similar to regular items.
- **Persistence**: Pinned status is saved across app sessions (e.g., via UserDefaults or Core Data).


## UI Design Specifications

- **Section Header**: A subtle label like "Pinned Items" with a pin icon (e.g., 📌 from SF Symbols). Use a thin separator line above it for visual distinction.
- **Item Display**:
    - Each pinned item shows a compact preview: source icon, truncated text/image thumbnail, and timestamp.
    - Layout: Horizontal carousel (scrollable left/right) or vertical stack (scrollable up/down) to fit up to 3 visible items.
    - If >3 items: Add subtle scroll indicators (e.g., arrows or a scrollbar) and enable gesture-based scrolling.
- **Styling**:
    - Background: Slightly differentiated (e.g., lighter shade of the sidebar background) for emphasis.
    - Highlight: Pinned items have a subtle glow or border (e.g., light blue accent) to indicate priority.
    - Empty State: Hidden entirely; no placeholder text.
- ** Responsiveness**: Section height adjusts dynamically (e.g., fixed height for 3 items, expands minimally for scrolling).
- **Accessibility**: Ensure VoiceOver reads "Pinned Items section" and describes scrollability; support keyboard navigation for scrolling.


## Implementation Details

Leverage macOS frameworks like SwiftUI or AppKit for the sidebar UI. Assume the sidebar uses a list-based view with sections.

### Data Model Enhancements

- Add a `isPinned` boolean property to the `ClipboardItem` model.
- Maintain a separate computed array for pinned items:

```swift
var pinnedItems: [ClipboardItem] {
    return allItems.filter { $0.isPinned }.sorted { $0.pinnedTimestamp > $1.pinnedTimestamp }  // Sort by pin time, newest first
}
```

- Store pinned status persistently (e.g., in Core Data or UserDefaults as a set of item IDs).


### UI Integration

#### For SwiftUI

- In the sidebar view, add a conditional section:

```swift
struct SidebarView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    
    var body: some View {
        VStack {
            // Main clipboard list here
            
            if !viewModel.pinnedItems.isEmpty {
                Section(header: Text("Pinned Items").font(.headline)) {
                    ScrollView(.horizontal, showsIndicators: false) {  // Horizontal scroll for carousel feel
                        HStack(spacing: 8) {
                            ForEach(viewModel.pinnedItems) { item in
                                PinnedItemView(item: item)
                                    .frame(width: 200)  // Fixed width for up to 3 visible (e.g., sidebar width ~600px)
                            }
                        }
                        .padding()
                    }
                    .frame(height: 100)  // Fixed height for compact display
                }
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

// Custom view for each pinned item
struct PinnedItemView: View {
    let item: ClipboardItem
    
    var body: some View {
        HStack {
            Image(systemName: item.sourceIcon)  // Or actual app icon
            Text(item.previewText)
            Spacer()
            Button(action: { unpinItem() }) {
                Image(systemName: "pin.slash")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))  // Light blue accent
        .onTapGesture { pasteItem(item) }
    }
}
```


#### For AppKit

- Use `NSCollectionView` for the pinned section in the sidebar's `NSViewController`.
- Dynamically add/remove the section view based on pinned count.
- In `viewDidLoad` or data update methods:

```swift
func updatePinnedSection() {
    if pinnedItems.isEmpty {
        pinnedSectionView.isHidden = true
        return
    }
    pinnedSectionView.isHidden = false
    // Reload collection view with pinnedItems
    collectionView.reloadData()
    // Configure for horizontal scrolling if >3 items
}
```


### Pinning Logic

- **Pin Action**: Triggered via context menu, button, or shortcut (e.g., Cmd+P on selected item).
    - Set `item.isPinned = true` and `item.pinnedTimestamp = Date()`.
    - Refresh the sidebar UI to show/update the pinned section.
- **Unpin Action**: Reverse the above; if no pinned items remain, hide the section.
- **Limit Enforcement**: No hard limit, but optionally add a warning toast if pinning >10 items: "You have many pinned items—consider managing them."


## User Flow

1. **Pinning an Item**:
    - User selects or right-clicks an item in the main list.
    - Chooses "Pin" from the menu.
    - Item is added to the pinned section (appears at bottom if hidden before).
    - If it's the 4th+ item, the section enables scrolling.
2. **Viewing/Interacting with Pinned Items**:
    - Open sidebar: Pinned section is visible at bottom if items exist.
    - Scroll if needed to see more than 3.
    - Click an item to paste it (sidebar auto-closes if configured).
    - Right-click for actions like unpin or edit.
3. **Unpinning**:
    - Right-click pinned item and select "Unpin".
    - Item removes from section; if last one, section hides.

## Edge Cases

- **No Pinned Items**: Section is completely hidden; no empty header or space wasted.
- **More Than 3 Pins**: Ensure smooth scrolling; test with 10+ items for performance.
- **Item Deletion**: If a pinned item is deleted from history, automatically remove from pinned section and hide if empty.
- **Duplicates**: Prevent pinning the same item multiple times (e.g., check by unique ID).
- **App Relaunch**: Reload pinned items from storage and show section accordingly.
- **Sidebar Resizing**: Ensure pinned section adapts (e.g., switches to vertical scroll if sidebar is narrow).
- **Accessibility Edge**: Handle screen readers announcing when the section appears/disappears dynamically.
- **Conflict with Other Features**: If integrating with folders, allow pinning from within folders; pinned items remain in history.


## Testing Guidelines

- **Basic Test**: Pin 1 item → Section appears with 1 item. Unpin → Section hides.
- **Capacity Test**: Pin 3 items → All visible without scroll. Pin 4th → Scrolling enabled.
- **Interaction Test**: Paste from pinned item → Works like regular items.
- **Persistence Test**: Pin items, close/reopen app → Section restores correctly.
- **Performance Test**: Pin 50 items → Scrolling remains responsive; no lag.

This feature enhances usability by providing quick access to important items while keeping the UI minimal and dynamic. If integrating with other features (e.g., search or sync), ensure pinned items are searchable and sync across devices.

