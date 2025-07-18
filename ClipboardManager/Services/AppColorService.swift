import Foundation
import AppKit
import SwiftUI

/// Service for extracting and caching app icon colors for dynamic background tinting
class AppColorService: ObservableObject {
    static let shared = AppColorService()
    
    private var colorCache: [String: Color] = [:]
    private let cacheQueue = DispatchQueue(label: "app.color.cache", qos: .utility)
    
    /// Settings for color tinting
    @Published var isColorTintingEnabled = true
    @Published var tintOpacity: Double = 0.15
    
    private init() {
        loadSettings()
    }
    
    /// Get the tinted background color for a source app
    func getBackgroundColor(for sourceApp: String?) -> Color {
        guard isColorTintingEnabled, let sourceApp = sourceApp, !sourceApp.isEmpty else {
            return Color.clear
        }
        
        // Check cache first
        if let cachedColor = colorCache[sourceApp] {
            return cachedColor
        }
        
        // Extract color from app
        let extractedColor = extractAppColor(for: sourceApp)
        
        // Cache the result
        cacheQueue.async { [weak self] in
            self?.colorCache[sourceApp] = extractedColor
        }
        
        return extractedColor
    }
    
    /// Extract dominant color from app icon
    private func extractAppColor(for sourceApp: String) -> Color {
        // Try to get app by bundle identifier first
        if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: sourceApp) {
            return extractColorFromBundle(bundleURL)
        }
        
        // Try to find app by name
        if let appURL = NSWorkspace.shared.urlForApplication(toOpen: URL(fileURLWithPath: "/")) {
            let appName = sourceApp.lowercased()
            if appURL.lastPathComponent.lowercased().contains(appName) {
                return extractColorFromBundle(appURL)
            }
        }
        
        // Try common app mappings
        if let mappedColor = getKnownAppColor(for: sourceApp) {
            return mappedColor
        }
        
        // Fallback to neutral color
        return Color.gray.opacity(tintOpacity)
    }
    
    /// Extract color from app bundle
    private func extractColorFromBundle(_ bundleURL: URL) -> Color {
        guard let bundle = Bundle(url: bundleURL),
              let iconFile = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String else {
            return getDefaultColor()
        }
        
        // Try to load the icon
        let iconURL = bundle.url(forResource: iconFile, withExtension: nil) ??
                     bundle.url(forResource: iconFile, withExtension: "icns")
        
        if let iconURL = iconURL,
           let image = NSImage(contentsOf: iconURL) {
            return extractDominantColor(from: image)
        }
        
        return getDefaultColor()
    }
    
    /// Extract dominant color from NSImage
    private func extractDominantColor(from image: NSImage) -> Color {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return getDefaultColor()
        }
        
        // Resize image for faster processing
        let size = CGSize(width: 50, height: 50)
        guard let resizedImage = resizeImage(cgImage, to: size) else {
            return getDefaultColor()
        }
        
        // Sample pixels to find dominant color
        let dominantColor = findDominantColor(in: resizedImage)
        
        // Convert to light tint
        return createLightTint(from: dominantColor)
    }
    
    /// Resize CGImage for faster color analysis
    private func resizeImage(_ image: CGImage, to size: CGSize) -> CGImage? {
        let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        context?.draw(image, in: CGRect(origin: .zero, size: size))
        return context?.makeImage()
    }
    
    /// Find dominant color in image
    private func findDominantColor(in image: CGImage) -> NSColor {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8
        
        guard let data = CFDataCreateMutable(nil, width * height * bytesPerPixel),
              let context = CGContext(
                data: CFDataGetMutableBytePtr(data),
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return NSColor.gray
        }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let pixels = CFDataGetMutableBytePtr(data)!
        
        var red = 0, green = 0, blue = 0, count = 0
        
        // Sample every 4th pixel for performance
        for y in stride(from: 0, to: height, by: 4) {
            for x in stride(from: 0, to: width, by: 4) {
                let pixelIndex = (y * width + x) * bytesPerPixel
                let r = Int(pixels[pixelIndex])
                let g = Int(pixels[pixelIndex + 1])
                let b = Int(pixels[pixelIndex + 2])
                let a = Int(pixels[pixelIndex + 3])
                
                // Skip transparent pixels
                if a > 50 {
                    red += r
                    green += g
                    blue += b
                    count += 1
                }
            }
        }
        
        guard count > 0 else { return NSColor.gray }
        
        return NSColor(
            red: CGFloat(red) / CGFloat(count * 255),
            green: CGFloat(green) / CGFloat(count * 255),
            blue: CGFloat(blue) / CGFloat(count * 255),
            alpha: 1.0
        )
    }
    
    /// Convert NSColor to light tint SwiftUI Color
    private func createLightTint(from color: NSColor) -> Color {
        // Convert to HSB for easier manipulation
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Create a very light, desaturated version
        let lightColor = NSColor(
            hue: hue,
            saturation: saturation * 0.3, // Reduce saturation
            brightness: min(brightness + 0.4, 0.95), // Increase brightness
            alpha: 1.0
        )
        
        return Color(lightColor).opacity(tintOpacity)
    }
    
    /// Known app color mappings for common applications
    private func getKnownAppColor(for sourceApp: String) -> Color? {
        let appName = sourceApp.lowercased()
        
        switch appName {
        case let name where name.contains("visual studio code") || name.contains("vscode") || name.contains("code"):
            return Color.blue.opacity(tintOpacity)
        case let name where name.contains("safari"):
            return Color.blue.opacity(tintOpacity)
        case let name where name.contains("chrome"):
            return Color.red.opacity(tintOpacity)
        case let name where name.contains("firefox"):
            return Color.orange.opacity(tintOpacity)
        case let name where name.contains("mail"):
            return Color.orange.opacity(tintOpacity)
        case let name where name.contains("notes"):
            return Color.yellow.opacity(tintOpacity)
        case let name where name.contains("terminal"):
            return Color.black.opacity(tintOpacity)
        case let name where name.contains("finder"):
            return Color.blue.opacity(tintOpacity)
        case let name where name.contains("xcode"):
            return Color.blue.opacity(tintOpacity)
        case let name where name.contains("slack"):
            return Color.purple.opacity(tintOpacity)
        case let name where name.contains("discord"):
            return Color.indigo.opacity(tintOpacity)
        case let name where name.contains("photoshop"):
            return Color.blue.opacity(tintOpacity)
        case let name where name.contains("figma"):
            return Color.purple.opacity(tintOpacity)
        default:
            return nil
        }
    }
    
    /// Default fallback color
    private func getDefaultColor() -> Color {
        return Color.gray.opacity(tintOpacity)
    }
    
    /// Clear the color cache
    func clearCache() {
        cacheQueue.async { [weak self] in
            self?.colorCache.removeAll()
        }
    }
    
    /// Save settings to UserDefaults
    func saveSettings() {
        UserDefaults.standard.set(isColorTintingEnabled, forKey: "AppColorTinting.enabled")
        UserDefaults.standard.set(tintOpacity, forKey: "AppColorTinting.opacity")
    }
    
    /// Load settings from UserDefaults
    private func loadSettings() {
        isColorTintingEnabled = UserDefaults.standard.object(forKey: "AppColorTinting.enabled") as? Bool ?? true
        tintOpacity = UserDefaults.standard.object(forKey: "AppColorTinting.opacity") as? Double ?? 0.15
    }
}

// MARK: - Helper Extension for NSImage
extension NSImage {
    var cgImage: CGImage? {
        return self.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
