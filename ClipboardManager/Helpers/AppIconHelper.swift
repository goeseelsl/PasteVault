import Foundation
import AppKit

/// App information structure
struct AppInfo {
    let name: String
    let bundleIdentifier: String
    let isRunning: Bool
    let lastUsed: Date?
    let icon: NSImage?
}

/// Helper class for retrieving and caching app icons
class AppIconHelper {
    static let shared = AppIconHelper()
    private var iconCache: [String: NSImage] = [:]
    
    private init() {}
    
    /// Get the app icon for a given app name or bundle identifier
    func getAppIcon(for appName: String) -> NSImage? {
        // Check cache first
        if let cachedIcon = iconCache[appName] {
            return cachedIcon
        }
        
        // Try to get icon by app name
        if let icon = getIconByAppName(appName) {
            iconCache[appName] = icon
            return icon
        }
        
        // Try to get icon by bundle identifier
        if let icon = getIconByBundleIdentifier(appName) {
            iconCache[appName] = icon
            return icon
        }
        
        // Return default icon if not found
        let defaultIcon = NSImage(systemSymbolName: "app.fill", accessibilityDescription: "App Icon") ?? NSImage()
        iconCache[appName] = defaultIcon
        return defaultIcon
    }
    
    /// Get app information for tooltips and interaction
    func getAppInfo(for appName: String) -> AppInfo {
        // Try to find running application first
        for app in NSWorkspace.shared.runningApplications {
            if app.localizedName == appName || app.bundleIdentifier == appName {
                return AppInfo(
                    name: app.localizedName ?? appName,
                    bundleIdentifier: app.bundleIdentifier ?? appName,
                    isRunning: true,
                    lastUsed: Date(),
                    icon: app.icon
                )
            }
        }
        
        // Check app name mappings
        if let bundleId = appNameMappings[appName] {
            return AppInfo(
                name: appName,
                bundleIdentifier: bundleId,
                isRunning: false,
                lastUsed: nil,
                icon: getIconByBundleIdentifier(bundleId)
            )
        }
        
        // Return generic info
        return AppInfo(
            name: appName,
            bundleIdentifier: appName,
            isRunning: false,
            lastUsed: nil,
            icon: getSystemIcon(for: appName)
        )
    }
    
    /// Launch app or bring to front
    func launchApp(bundleIdentifier: String) -> Bool {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return app.activate(options: [])
        }
        
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            do {
                try NSWorkspace.shared.launchApplication(at: appURL, options: [], configuration: [:])
                return true
            } catch {
                print("Failed to launch app: \(error)")
                return false
            }
        }
        
        return false
    }
    
    /// Deep link to app with content (if supported)
    func openInApp(bundleIdentifier: String, content: String) -> Bool {
        // Handle special cases for deep linking
        switch bundleIdentifier {
        case "com.apple.Safari":
            if ContentHelper.isURL(content) {
                if let url = URL(string: content) {
                    return NSWorkspace.shared.open(url)
                }
            }
        case "com.apple.Notes":
            // Create new note with content
            let noteURL = URL(string: "notes://new?content=\(content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
            return NSWorkspace.shared.open(noteURL)
        case "com.apple.mail":
            if ContentHelper.isEmail(content) {
                let mailURL = URL(string: "mailto:\(content)")!
                return NSWorkspace.shared.open(mailURL)
            }
        default:
            break
        }
        
        // Fallback to regular launch
        return launchApp(bundleIdentifier: bundleIdentifier)
    }
    
    private var appNameMappings: [String: String] {
        return [
            "Safari": "com.apple.Safari",
            "Chrome": "com.google.Chrome",
            "Firefox": "org.mozilla.firefox",
            "Notes": "com.apple.Notes",
            "Mail": "com.apple.mail",
            "Messages": "com.apple.MobileSMS",
            "Finder": "com.apple.finder",
            "TextEdit": "com.apple.TextEdit",
            "Pages": "com.apple.iWork.Pages",
            "Numbers": "com.apple.iWork.Numbers",
            "Keynote": "com.apple.iWork.Keynote",
            "Microsoft Word": "com.microsoft.Word",
            "Microsoft Excel": "com.microsoft.Excel",
            "Microsoft PowerPoint": "com.microsoft.PowerPoint",
            "Slack": "com.tinyspeck.slackmacgap",
            "Discord": "com.hnc.Discord",
            "Telegram": "ru.keepcoder.Telegram",
            "WhatsApp": "net.whatsapp.WhatsApp",
            "Xcode": "com.apple.dt.Xcode",
            "Terminal": "com.apple.Terminal",
            "Visual Studio Code": "com.microsoft.VSCode",
            "Sublime Text": "com.sublimetext.3",
            "Atom": "com.github.atom",
            "Photoshop": "com.adobe.Photoshop",
            "Illustrator": "com.adobe.illustrator",
            "Sketch": "com.bohemiancoding.sketch3",
            "Figma": "com.figma.Desktop"
        ]
    }
    
    private func getIconByAppName(_ appName: String) -> NSImage? {
        // Try direct mapping first
        if let bundleId = appNameMappings[appName] {
            return getIconByBundleIdentifier(bundleId)
        }
        
        // Try to find running application
        for app in NSWorkspace.shared.runningApplications {
            if app.localizedName == appName {
                return app.icon
            }
        }
        
        // Try to find installed application
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appName) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        
        return nil
    }
    
    private func getIconByBundleIdentifier(_ bundleIdentifier: String) -> NSImage? {
        // Try to get icon from running applications
        for app in NSWorkspace.shared.runningApplications {
            if app.bundleIdentifier == bundleIdentifier {
                return app.icon
            }
        }
        
        // Try to find installed application
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        
        return nil
    }
    
    /// Get a system icon for common app categories
    func getSystemIcon(for appName: String) -> NSImage? {
        let systemIconMappings: [String: String] = [
            "Safari": "safari",
            "Chrome": "globe",
            "Firefox": "globe",
            "Notes": "note.text",
            "Mail": "envelope",
            "Messages": "message",
            "Finder": "folder",
            "TextEdit": "doc.text",
            "Terminal": "terminal",
            "Xcode": "hammer",
            "Unknown": "app.fill"
        ]
        
        let iconName = systemIconMappings[appName] ?? "app.fill"
        return NSImage(systemSymbolName: iconName, accessibilityDescription: "\(appName) Icon")
    }
}
