import SwiftUI

/// Search bar component for filtering clipboard items
struct SearchView: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            
            TextField("Search clipboard... (try: image, url, code, email, number)", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 12))
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.08))
        .cornerRadius(6)
    }
}
