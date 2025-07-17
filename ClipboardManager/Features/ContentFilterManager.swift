import Foundation
import SwiftUI

/// Content filtering and ignored applications manager
class ContentFilterManager: ObservableObject {
    @Published var ignoredApps: Set<String> = []
    @Published var contentFilters: [ContentFilter] = []
    @Published var isDuplicateFilterEnabled = true
    @Published var isPasswordFilterEnabled = true
    @Published var minimumContentLength = 3
    
    private let ignoredAppsKey = "IgnoredApps"
    private let contentFiltersKey = "ContentFilters"
    
    init() {
        loadSettings()
        setupDefaultFilters()
    }
    
    /// Check if content should be ignored
    func shouldIgnoreContent(_ content: String?, from sourceApp: String?) -> Bool {
        // Check ignored apps
        if let app = sourceApp, ignoredApps.contains(app) {
            return true
        }
        
        // Check content filters
        guard let content = content else { return true }
        
        // Check minimum length
        if content.trimmingCharacters(in: .whitespacesAndNewlines).count < minimumContentLength {
            return true
        }
        
        // Check custom filters
        for filter in contentFilters where filter.isEnabled {
            if filter.matches(content) {
                return true
            }
        }
        
        return false
    }
    
    /// Check if content is duplicate
    func isDuplicate(_ content: String?, existingItems: [ClipboardItem]) -> Bool {
        guard isDuplicateFilterEnabled, let content = content else { return false }
        
        return existingItems.contains { $0.content == content }
    }
    
    /// Add app to ignored list
    func addIgnoredApp(_ bundleIdentifier: String) {
        ignoredApps.insert(bundleIdentifier)
        saveSettings()
    }
    
    /// Remove app from ignored list
    func removeIgnoredApp(_ bundleIdentifier: String) {
        ignoredApps.remove(bundleIdentifier)
        saveSettings()
    }
    
    /// Add content filter
    func addContentFilter(_ filter: ContentFilter) {
        contentFilters.append(filter)
        saveSettings()
    }
    
    /// Remove content filter
    func removeContentFilter(_ filter: ContentFilter) {
        contentFilters.removeAll { $0.id == filter.id }
        saveSettings()
    }
    
    /// Toggle filter enabled state
    func toggleFilter(_ filter: ContentFilter) {
        if let index = contentFilters.firstIndex(where: { $0.id == filter.id }) {
            contentFilters[index].isEnabled.toggle()
            saveSettings()
        }
    }
    
    private func setupDefaultFilters() {
        if contentFilters.isEmpty {
            contentFilters = [
                ContentFilter(
                    name: "Password-like",
                    description: "Filters content that looks like passwords",
                    type: .regex,
                    pattern: "^[A-Za-z0-9!@#$%^&*()_+\\-=\\[\\]{};':\"\\\\|,.<>\\/?]{8,}$",
                    isEnabled: isPasswordFilterEnabled
                ),
                ContentFilter(
                    name: "Credit Card Numbers",
                    description: "Filters content that looks like credit card numbers",
                    type: .regex,
                    pattern: "\\b(?:\\d[ -]*?){13,16}\\b",
                    isEnabled: true
                ),
                ContentFilter(
                    name: "SSN",
                    description: "Filters Social Security Numbers",
                    type: .regex,
                    pattern: "\\b\\d{3}-\\d{2}-\\d{4}\\b",
                    isEnabled: true
                ),
                ContentFilter(
                    name: "API Keys",
                    description: "Filters content that looks like API keys",
                    type: .regex,
                    pattern: "(?i)(api[_-]?key|token|secret)[\\s=:]+['\"]?[a-zA-Z0-9_-]{20,}['\"]?",
                    isEnabled: true
                ),
                ContentFilter(
                    name: "URLs with Tokens",
                    description: "Filters URLs containing authentication tokens",
                    type: .regex,
                    pattern: "https?://[^\\s]*[?&](token|key|secret|auth)=[^\\s&]*",
                    isEnabled: true
                )
            ]
        }
    }
    
    private func loadSettings() {
        if let ignoredAppsData = UserDefaults.standard.data(forKey: ignoredAppsKey),
           let ignoredAppsArray = try? JSONDecoder().decode([String].self, from: ignoredAppsData) {
            ignoredApps = Set(ignoredAppsArray)
        }
        
        if let filtersData = UserDefaults.standard.data(forKey: contentFiltersKey),
           let filters = try? JSONDecoder().decode([ContentFilter].self, from: filtersData) {
            contentFilters = filters
        }
        
        isDuplicateFilterEnabled = UserDefaults.standard.bool(forKey: "DuplicateFilterEnabled")
        isPasswordFilterEnabled = UserDefaults.standard.bool(forKey: "PasswordFilterEnabled")
        minimumContentLength = UserDefaults.standard.integer(forKey: "MinimumContentLength")
        
        if minimumContentLength == 0 {
            minimumContentLength = 3
        }
    }
    
    private func saveSettings() {
        let ignoredAppsArray = Array(ignoredApps)
        if let ignoredAppsData = try? JSONEncoder().encode(ignoredAppsArray) {
            UserDefaults.standard.set(ignoredAppsData, forKey: ignoredAppsKey)
        }
        
        if let filtersData = try? JSONEncoder().encode(contentFilters) {
            UserDefaults.standard.set(filtersData, forKey: contentFiltersKey)
        }
        
        UserDefaults.standard.set(isDuplicateFilterEnabled, forKey: "DuplicateFilterEnabled")
        UserDefaults.standard.set(isPasswordFilterEnabled, forKey: "PasswordFilterEnabled")
        UserDefaults.standard.set(minimumContentLength, forKey: "MinimumContentLength")
    }
}

/// Content filter model
struct ContentFilter: Identifiable, Codable {
    let id = UUID()
    let name: String
    let description: String
    let type: FilterType
    let pattern: String
    var isEnabled: Bool = true
    
    enum FilterType: String, Codable, CaseIterable {
        case regex = "Regular Expression"
        case contains = "Contains Text"
        case startsWith = "Starts With"
        case endsWith = "Ends With"
        case exact = "Exact Match"
        
        var icon: String {
            switch self {
            case .regex: return "text.magnifyingglass"
            case .contains: return "text.badge.checkmark"
            case .startsWith: return "text.alignleft"
            case .endsWith: return "text.alignright"
            case .exact: return "equal"
            }
        }
    }
    
    /// Check if content matches this filter
    func matches(_ content: String) -> Bool {
        switch type {
        case .regex:
            return content.range(of: pattern, options: .regularExpression) != nil
        case .contains:
            return content.localizedCaseInsensitiveContains(pattern)
        case .startsWith:
            return content.localizedCaseInsensitiveCompare(pattern) == .orderedSame || content.lowercased().hasPrefix(pattern.lowercased())
        case .endsWith:
            return content.localizedCaseInsensitiveCompare(pattern) == .orderedSame || content.lowercased().hasSuffix(pattern.lowercased())
        case .exact:
            return content.localizedCaseInsensitiveCompare(pattern) == .orderedSame
        }
    }
}

/// Content filtering settings view
struct ContentFilterSettingsView: View {
    @ObservedObject var filterManager: ContentFilterManager
    @State private var showingAddFilter = false
    @State private var newFilterName = ""
    @State private var newFilterDescription = ""
    @State private var newFilterType: ContentFilter.FilterType = .contains
    @State private var newFilterPattern = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Content Filtering")
                .font(.system(size: 18, weight: .semibold))
            
            // General settings
            VStack(alignment: .leading, spacing: 12) {
                Text("General Filters")
                    .font(.system(size: 14, weight: .medium))
                
                Toggle("Filter duplicate content", isOn: $filterManager.isDuplicateFilterEnabled)
                    .font(.system(size: 12))
                
                Toggle("Filter password-like content", isOn: $filterManager.isPasswordFilterEnabled)
                    .font(.system(size: 12))
                
                HStack {
                    Text("Minimum content length:")
                        .font(.system(size: 12))
                    Stepper(value: $filterManager.minimumContentLength, in: 1...20) {
                        Text("\(filterManager.minimumContentLength)")
                            .font(.system(size: 12))
                    }
                }
            }
            
            Divider()
            
            // Custom filters
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Custom Filters")
                        .font(.system(size: 14, weight: .medium))
                    
                    Spacer()
                    
                    Button("Add Filter") {
                        showingAddFilter = true
                    }
                    .font(.system(size: 11))
                }
                
                if filterManager.contentFilters.isEmpty {
                    Text("No custom filters")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filterManager.contentFilters) { filter in
                        ContentFilterRow(
                            filter: filter,
                            onToggle: { filterManager.toggleFilter(filter) },
                            onDelete: { filterManager.removeContentFilter(filter) }
                        )
                    }
                }
            }
            
            Divider()
            
            // Ignored apps
            IgnoredAppsSection(filterManager: filterManager)
        }
        .padding()
        .sheet(isPresented: $showingAddFilter) {
            AddContentFilterView(
                name: $newFilterName,
                description: $newFilterDescription,
                type: $newFilterType,
                pattern: $newFilterPattern,
                onSave: {
                    let filter = ContentFilter(
                        name: newFilterName,
                        description: newFilterDescription,
                        type: newFilterType,
                        pattern: newFilterPattern
                    )
                    filterManager.addContentFilter(filter)
                    
                    // Reset form
                    newFilterName = ""
                    newFilterDescription = ""
                    newFilterType = .contains
                    newFilterPattern = ""
                }
            )
        }
    }
}

/// Individual content filter row
struct ContentFilterRow: View {
    let filter: ContentFilter
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Toggle(isOn: .constant(filter.isEnabled)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(filter.name)
                        .font(.system(size: 12, weight: .medium))
                    Text(filter.description)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .onTapGesture {
                onToggle()
            }
            
            Spacer()
            
            Text(filter.type.rawValue)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                )
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

/// Add content filter dialog
struct AddContentFilterView: View {
    @Binding var name: String
    @Binding var description: String
    @Binding var type: ContentFilter.FilterType
    @Binding var pattern: String
    @Environment(\.presentationMode) var presentationMode
    let onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Add Content Filter")
                .font(.system(size: 16, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Name:")
                    .font(.system(size: 12, weight: .medium))
                TextField("Filter name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("Description:")
                    .font(.system(size: 12, weight: .medium))
                TextField("Filter description", text: $description)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("Type:")
                    .font(.system(size: 12, weight: .medium))
                Picker("Filter Type", selection: $type) {
                    ForEach(ContentFilter.FilterType.allCases, id: \.self) { filterType in
                        Text(filterType.rawValue).tag(filterType)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Text("Pattern:")
                    .font(.system(size: 12, weight: .medium))
                TextField("Filter pattern", text: $pattern)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if type == .regex {
                    Text("Use regular expression syntax")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                
                Button("Save") {
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(name.isEmpty || pattern.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

/// Ignored apps section
struct IgnoredAppsSection: View {
    @ObservedObject var filterManager: ContentFilterManager
    @State private var showingAppSelector = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ignored Applications")
                    .font(.system(size: 14, weight: .medium))
                
                Spacer()
                
                Button("Add App") {
                    showingAppSelector = true
                }
                .font(.system(size: 11))
            }
            
            if filterManager.ignoredApps.isEmpty {
                Text("No ignored applications")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(filterManager.ignoredApps), id: \.self) { appId in
                    IgnoredAppRow(
                        appId: appId,
                        onRemove: { filterManager.removeIgnoredApp(appId) }
                    )
                }
            }
        }
        .sheet(isPresented: $showingAppSelector) {
            AppSelectorView { selectedApp in
                filterManager.addIgnoredApp(selectedApp)
            }
        }
    }
}

/// Individual ignored app row
struct IgnoredAppRow: View {
    let appId: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            if let appIcon = AppIconHelper.shared.getAppIcon(for: appId) {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .cornerRadius(3)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(AppIconHelper.shared.getAppInfo(for: appId).name)
                    .font(.system(size: 12, weight: .medium))
                Text(appId)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

/// App selector view
struct AppSelectorView: View {
    @Environment(\.presentationMode) var presentationMode
    let onSelect: (String) -> Void
    
    @State private var runningApps: [NSRunningApplication] = []
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Select Application to Ignore")
                .font(.system(size: 16, weight: .semibold))
            
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(runningApps, id: \.bundleIdentifier) { app in
                        if let bundleId = app.bundleIdentifier {
                            HStack {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                        .cornerRadius(4)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.localizedName ?? "Unknown")
                                        .font(.system(size: 12, weight: .medium))
                                    Text(bundleId)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button("Select") {
                                    onSelect(bundleId)
                                    presentationMode.wrappedValue.dismiss()
                                }
                                .font(.system(size: 11))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(NSColor.controlBackgroundColor))
                            )
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
            
            Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            loadRunningApps()
        }
    }
    
    private func loadRunningApps() {
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.bundleIdentifier != nil && $0.localizedName != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
}
