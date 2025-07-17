<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" class="logo" width="120"/>

# Advanced Organization Window Feature Specification

## Overview

Replace the current collapsed folder area in the main sidebar with a dedicated **"Organize"** button that opens a comprehensive management window. This new window will serve as the central hub for advanced clipboard organization, filtering, and search capabilities.

## Main Interface Changes

### Sidebar Modification

- **Remove**: Current collapsed folder section
- **Add**: Single "Organize" button with folder icon
- **Button Style**: Subtle, integrated design matching sidebar aesthetics
- **Placement**: Below the main clipboard list, above settings


### Button Behavior

The organize button should open a new independent window for advanced clipboard management and organization.

## New Organization Window Specifications

### Window Properties

- **Size**: 1000x700 pixels (minimum), resizable
- **Title**: "Clipboard Organization"
- **Style**: Modern macOS window with toolbar
- **Behavior**: Independent window, can remain open while using main app


### Layout Structure

#### Left Panel: Filters \& Navigation (300px width)

**Content Type Filters:**

- 📄 **Text** - Plain text, rich text, code snippets
- 🔗 **URLs** - Web links, file paths
- 🖼️ **Images** - Screenshots, copied images
- 📁 **Files** - File references, attachments
- 🔢 **Numbers** - Numeric data, calculations
- 📧 **Emails** - Email content, addresses
- 🎨 **Colors** - Color codes, hex values

**Quick Filters:**

- ⭐ **Favorites** - Pinned items
- 📅 **Today** - Items from today
- 📆 **This Week** - Items from past 7 days
- 🔒 **Secure** - Password-protected items

**Folder Management:**

- 📂 **My Folders** (expandable tree)
    - Create new folder button (+)
    - Drag-and-drop folder reordering
    - Context menu for rename/delete


#### Right Panel: Content \& Search (700px width)

**Top Section: Advanced Search Bar**

- **Search Field**: Full-text search with suggestions
- **Filter Options**:
    - Date range picker
    - Source application filter
    - Content type selector
    - Size range (for images/files)
- **Search Operators**: Support for quotes, wildcards, exclusions

**Main Content Area**:

- **List View**: Detailed item display with columns
    - Preview thumbnail/icon
    - Content snippet (truncated)
    - Source application
    - Date/time
    - Folder assignment
    - Tags/labels
- **Grid View**: Visual thumbnail grid for images
- **Card View**: Expanded preview cards


## Detailed Feature Specifications

### Advanced Search Capabilities

#### Search Syntax Support

```
"exact phrase"          # Exact match
-exclude                # Exclude term
app:Safari             # Filter by source app
type:image             # Filter by content type
date:today             # Date-based search
folder:"Work Notes"    # Search within folder
```


#### Search Filters Panel

- **Date Range**: Calendar picker for from/to dates
- **Source Apps**: Checkboxes for installed applications
- **Content Types**: Multi-select content type filtering
- **Size Range**: Slider for file/image size filtering
- **Tags**: Tag-based filtering system


### Folder Management System

#### Folder Operations

- **Create Folder**:
    - Modal dialog with name input
    - Color coding options (8 preset colors)
    - Description field (optional)
    - Keyboard shortcut: Cmd+N
- **Edit Folder**:
    - Inline editing for folder names
    - Right-click context menu
    - Properties panel showing item count, creation date
- **Delete Folder**:
    - Confirmation dialog
    - Option to move items to "Uncategorized" or delete
    - Keyboard shortcut: Delete key


#### Folder Features

- **Drag \& Drop**: Items between folders
- **Nested Folders**: Up to 3 levels deep
- **Folder Icons**: Custom icons or emoji selection
- **Smart Folders**: Auto-populate based on rules
- **Folder Shortcuts**: Quick access via number keys


### Content Management

#### Item Actions

- **Multi-select**: Cmd+click, Shift+click support
- **Bulk Operations**:
    - Move to folder
    - Add tags
    - Export to file
    - Delete multiple items
- **Quick Actions**:
    - Pin/unpin toggle
    - Copy to clipboard
    - Edit content
    - Share via system share sheet


#### Content Preview

- **Rich Text Preview**: Formatted text display
- **Image Preview**: Thumbnail with zoom capability
- **Code Syntax Highlighting**: Language detection
- **URL Preview**: Favicon and page title
- **File Information**: Type, size, modification date


## UI Design Specifications

### Visual Hierarchy

- **Primary**: Search bar and content list
- **Secondary**: Filter panels and folder tree
- **Tertiary**: Status information and metadata


### Color Scheme

- **Background**: System background colors
- **Accent**: App theme color for highlights
- **Text**: High contrast system text colors
- **Borders**: Subtle separators using system colors


### Typography

- **Headers**: SF Pro Display, Medium, 16pt
- **Body**: SF Pro Text, Regular, 13pt
- **Monospace**: SF Mono for code content
- **Metadata**: System font, 11pt, secondary color


### Interactive Elements

- **Buttons**: Rounded rectangle style matching macOS
- **Icons**: SF Symbols where available
- **Hover States**: Subtle background color changes
- **Selection**: System selection color with rounded corners


## Technical Implementation Notes

### Data Management

- **Search Indexing**: Core Data with spotlight-style indexing
- **Folder Storage**: Hierarchical relationship model
- **Performance**: Lazy loading for large datasets
- **Sync**: CloudKit integration for cross-device folders


### Window Management

- **State Preservation**: Remember window size and position
- **Multi-window**: Allow multiple organization windows
- **Toolbar**: Customizable toolbar with common actions
- **Sidebar**: Collapsible left panel for more content space


### Accessibility

- **VoiceOver**: Full screen reader support
- **Keyboard Navigation**: Tab order and shortcuts
- **High Contrast**: Respect system accessibility settings
- **Text Size**: Dynamic type support


## User Experience Flow

### Opening Organization Window

1. User clicks "Organize" button in main sidebar
2. New window opens with default "All Items" view
3. Left panel shows content type filters and folder tree
4. Right panel displays searchable item list

### Creating a Folder

1. Click "+" button in folder section
2. Modal appears with folder name field
3. User enters name, selects color (optional)
4. Folder appears in tree, ready for item assignment

### Advanced Search

1. User enters search term in top search bar
2. Real-time filtering of results
3. Additional filters can be applied from left panel
4. Results update dynamically with each filter change

### Organizing Items

1. Select items using checkboxes or keyboard shortcuts
2. Drag to folder or use "Move to Folder" action
3. Items immediately reflect new organization
4. Changes sync across all app instances

This comprehensive organization window will transform your clipboard manager into a powerful content management system while maintaining the clean, efficient workflow users expect.

