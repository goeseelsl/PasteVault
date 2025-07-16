import Foundation

/// Helper class for content type detection and analysis
class ContentHelper {
    
    /// Detect if text content appears to be code
    /// - Parameter text: The text to analyze
    /// - Returns: True if the text appears to contain code
    static func isCode(_ text: String) -> Bool {
        let codeKeywords = [
            "func", "var", "let", "if", "else", "return", "import", "struct", "class",
            "{", "}", ";", "def", "function", "const", "public", "private", "static",
            "void", "int", "string", "bool", "true", "false", "null", "undefined"
        ]
        
        let codePatterns = [
            "\\{.*\\}",  // Contains braces
            "\\bfunction\\b",  // Function keyword
            "\\bvar\\b",  // Variable declarations
            "\\blet\\b",  // Let declarations
            "\\bconst\\b",  // Const declarations
            "\\bimport\\b",  // Import statements
            "\\bclass\\b",  // Class declarations
            "\\bstruct\\b",  // Struct declarations
            "\\bdef\\b",  // Python def
            "\\bif\\b.*\\{", // If statements with braces
            "\\bfor\\b.*\\{", // For loops with braces
            "\\bwhile\\b.*\\{", // While loops with braces
            "\\w+\\(.*\\)\\s*\\{", // Function calls with braces
            "//.*", // Single line comments
            "/\\*.*\\*/", // Multi-line comments
            "#.*", // Hash comments
            "\\w+::\\w+", // Scope resolution
            "\\w+\\.\\w+\\(", // Method calls
            "\\bpublic\\b|\\bprivate\\b|\\bprotected\\b", // Access modifiers
        ]
        
        // Check for keywords
        for keyword in codeKeywords {
            if text.lowercased().contains(keyword.lowercased()) {
                return true
            }
        }
        
        // Check for patterns using regex
        for pattern in codePatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    /// Detect if text is a URL
    /// - Parameter text: The text to analyze
    /// - Returns: True if the text appears to be a URL
    static func isURL(_ text: String) -> Bool {
        return text.hasPrefix("http://") || 
               text.hasPrefix("https://") || 
               text.hasPrefix("www.") || 
               text.contains("://") || 
               text.hasPrefix("ftp://")
    }
    
    /// Detect if text is an email address
    /// - Parameter text: The text to analyze
    /// - Returns: True if the text appears to be an email
    static func isEmail(_ text: String) -> Bool {
        let emailPattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return text.range(of: emailPattern, options: .regularExpression) != nil
    }
    
    /// Detect if text is a number
    /// - Parameter text: The text to analyze
    /// - Returns: True if the text appears to be a number
    static func isNumber(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(trimmed) != nil || Int(trimmed) != nil
    }
    
    /// Get content type description for display
    /// - Parameter text: The text to analyze
    /// - Returns: A string describing the content type
    static func getContentType(_ text: String) -> String {
        if isURL(text) { return "URL" }
        if isEmail(text) { return "Email" }
        if isNumber(text) { return "Number" }
        if isCode(text) { return "Code" }
        return "Text"
    }
    
    /// Get appropriate emoji for content type
    /// - Parameter text: The text to analyze
    /// - Returns: An emoji representing the content type
    static func getContentEmoji(_ text: String) -> String {
        if isURL(text) { return "🔗" }
        if isEmail(text) { return "✉️" }
        if isNumber(text) { return "🔢" }
        if isCode(text) { return "💻" }
        return "📝"
    }
}
