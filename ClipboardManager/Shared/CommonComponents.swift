import SwiftUI
import Carbon

// MARK: - Notification Names
extension Notification.Name {
    static let reloadHotkeys = Notification.Name("reloadHotkeys")
    static let applyTheme = Notification.Name("applyTheme")
    static let disableGlobalHotkeys = Notification.Name("disableGlobalHotkeys")
    static let enableGlobalHotkeys = Notification.Name("enableGlobalHotkeys")
}

// MARK: - Common UI Components
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                content
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    let description: String
    let icon: String
    let content: Content
    
    init(title: String, description: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.description = description
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            content
        }
        .padding(.vertical, 4)
    }
}

struct ModernButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [color, color.opacity(0.8)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}




