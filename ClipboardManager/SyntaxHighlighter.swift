import SwiftUI

struct SyntaxHighlighter {
    static func highlight(code: String) -> AttributedString {
        var attributedString = AttributedString(code)
        
        let keywords = ["func", "var", "let", "if", "else", "return", "import", "struct", "class", "public", "private", "internal"]
        
        for keyword in keywords {
            if let range = attributedString.range(of: keyword) {
                attributedString[range].foregroundColor = .blue
            }
        }
        
        // Highlight comments
        let commentRegex = try! NSRegularExpression(pattern: "//.*")
        let matches = commentRegex.matches(in: code, range: NSRange(code.startIndex..., in: code))
        
        for match in matches {
            if let range = Range(match.range, in: code) {
                if let attributedRange = attributedString.range(of: code[range]) {
                    attributedString[attributedRange].foregroundColor = .green
                }
            }
        }
        
        return attributedString
    }
}
