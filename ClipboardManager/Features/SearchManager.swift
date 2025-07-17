import Foundation
import SwiftUI

/// Advanced search functionality with fuzzy matching and filtering
class SearchManager: ObservableObject {
    @Published var searchText = ""
    @Published var selectedSearchType: SearchType = .all
    @Published var dateRange: DateRange = .all
    @Published var showAdvancedFilters = false
    
    enum SearchType: String, CaseIterable {
        case all = "All"
        case text = "Text"
        case images = "Images"
        case urls = "URLs"
        case code = "Code"
        case email = "Email"
        case numbers = "Numbers"
        
        var icon: String {
            switch self {
            case .all: return "magnifyingglass"
            case .text: return "doc.text"
            case .images: return "photo"
            case .urls: return "link"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .email: return "envelope"
            case .numbers: return "number"
            }
        }
    }
    
    enum DateRange: String, CaseIterable {
        case all = "All Time"
        case today = "Today"
        case yesterday = "Yesterday"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case custom = "Custom Range"
        
        var dateFilter: DateInterval? {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .all, .custom:
                return nil
            case .today:
                return DateInterval(start: calendar.startOfDay(for: now), end: now)
            case .yesterday:
                let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
                return DateInterval(start: calendar.startOfDay(for: yesterday), 
                                  end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: yesterday))!)
            case .thisWeek:
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)!.start
                return DateInterval(start: startOfWeek, end: now)
            case .thisMonth:
                let startOfMonth = calendar.dateInterval(of: .month, for: now)!.start
                return DateInterval(start: startOfMonth, end: now)
            }
        }
    }
    
    /// Perform fuzzy search on clipboard items
    func fuzzySearch(items: [ClipboardItem]) -> [ClipboardItem] {
        guard !searchText.isEmpty else { return items }
        
        let searchTerms = searchText.lowercased().components(separatedBy: " ")
        
        return items.compactMap { item in
            let score = calculateFuzzyScore(for: item, searchTerms: searchTerms)
            return score > 0 ? item : nil
        }.sorted { item1, item2 in
            let score1 = calculateFuzzyScore(for: item1, searchTerms: searchTerms)
            let score2 = calculateFuzzyScore(for: item2, searchTerms: searchTerms)
            return score1 > score2
        }
    }
    
    /// Calculate fuzzy matching score for an item
    private func calculateFuzzyScore(for item: ClipboardItem, searchTerms: [String]) -> Int {
        var score = 0
        let content = (item.content ?? "").lowercased()
        let sourceApp = (item.sourceApp ?? "").lowercased()
        let category = (item.category ?? "").lowercased()
        
        for term in searchTerms {
            // Exact matches get highest score
            if content.contains(term) {
                score += 10
            }
            if sourceApp.contains(term) {
                score += 8
            }
            if category.contains(term) {
                score += 6
            }
            
            // Partial matches get lower score
            if fuzzyMatch(text: content, pattern: term) {
                score += 3
            }
            if fuzzyMatch(text: sourceApp, pattern: term) {
                score += 2
            }
        }
        
        return score
    }
    
    /// Simple fuzzy matching algorithm
    private func fuzzyMatch(text: String, pattern: String) -> Bool {
        guard !pattern.isEmpty else { return true }
        
        var textIndex = text.startIndex
        var patternIndex = pattern.startIndex
        
        while textIndex < text.endIndex && patternIndex < pattern.endIndex {
            if text[textIndex].lowercased() == pattern[patternIndex].lowercased() {
                patternIndex = pattern.index(after: patternIndex)
            }
            textIndex = text.index(after: textIndex)
        }
        
        return patternIndex == pattern.endIndex
    }
    
    /// Filter items by type
    func filterByType(items: [ClipboardItem]) -> [ClipboardItem] {
        guard selectedSearchType != .all else { return items }
        
        return items.filter { item in
            switch selectedSearchType {
            case .all:
                return true
            case .text:
                return item.content != nil && item.imageData == nil
            case .images:
                return item.imageData != nil
            case .urls:
                return ContentHelper.isURL(item.content ?? "")
            case .code:
                return ContentHelper.isCode(item.content ?? "")
            case .email:
                return ContentHelper.isEmail(item.content ?? "")
            case .numbers:
                return ContentHelper.isNumber(item.content ?? "")
            }
        }
    }
    
    /// Filter items by date range
    func filterByDate(items: [ClipboardItem]) -> [ClipboardItem] {
        guard let dateFilter = dateRange.dateFilter else { return items }
        
        return items.filter { item in
            guard let createdAt = item.createdAt else { return false }
            return dateFilter.contains(createdAt)
        }
    }
}

/// Advanced search view component
struct AdvancedSearchView: View {
    @ObservedObject var searchManager: SearchManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Search type filter
            HStack {
                Text("Type:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Picker("Search Type", selection: $searchManager.selectedSearchType) {
                    ForEach(SearchManager.SearchType.allCases, id: \.self) { type in
                        HStack {
                            Image(systemName: type.icon)
                            Text(type.rawValue)
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: 120)
            }
            
            // Date range filter
            HStack {
                Text("Date:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Picker("Date Range", selection: $searchManager.dateRange) {
                    ForEach(SearchManager.DateRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: 120)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}
