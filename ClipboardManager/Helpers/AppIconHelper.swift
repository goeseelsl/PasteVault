import Foundation
import AppKit

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
    
    private func getIconByAppName(_ appName: String) -> NSImage? {
        // Map common app names to their actual bundle identifiers
        let appNameMappings: [String: String] = [
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
