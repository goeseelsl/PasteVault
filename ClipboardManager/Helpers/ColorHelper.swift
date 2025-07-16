import SwiftUI

/// Helper for generating consistent colors based on strings
class ColorHelper {
    
    /// Generate a color based on a string hash
    /// - Parameter string: The string to generate a color for
    /// - Returns: A SwiftUI Color with consistent hue for the same string
    static func colorForString(_ string: String) -> Color {
        var hash: Int = 0
        
        for char in string.unicodeScalars {
            let charValue = Int(char.value)
            // Use safe arithmetic to prevent overflow
            hash = charValue &+ (hash &<< 5) &- hash
            // Keep hash in a reasonable range to prevent further overflow
            hash = hash & 0x7FFFFFFF
        }
        
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.7, brightness: 0.9)
    }
    
    /// Get a gradient color for content type
    /// - Parameter contentType: The type of content (URL, Code, Email, etc.)
    /// - Returns: A gradient suitable for the content type
    static func gradientForContentType(_ contentType: String) -> LinearGradient {
        switch contentType.lowercased() {
        case "url", "link":
            return LinearGradient(
                gradient: Gradient(colors: [.purple, .blue]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "code", "programming":
            return LinearGradient(
                gradient: Gradient(colors: [.green, .mint]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "email", "mail":
            return LinearGradient(
                gradient: Gradient(colors: [.red, .orange]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "number", "numeric":
            return LinearGradient(
                gradient: Gradient(colors: [.indigo, .purple]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                gradient: Gradient(colors: [.gray, .secondary]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
