import Foundation
import ServiceManagement

class LaunchAtLogin {
    static let shared = LaunchAtLogin()

    func setLaunchAtLogin(enabled: Bool) {
        let identifier = "com.clipboardmanager.app" as CFString
        SMLoginItemSetEnabled(identifier, enabled)
    }
}
