import SwiftUI
import AppKit

class EdgeWindow: NSPanel {
    enum Position {
        case left
        case right
        case top
        case bottom
    }
    
    private var position: Position
    private var widthOrHeight: CGFloat
    private var eventMonitor: Any?
    
    init(position: Position, widthOrHeight: CGFloat) {
        self.position = position
        self.widthOrHeight = widthOrHeight
        
        // Create with default frame, it will be positioned correctly later
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        
        self.isFloatingPanel = true
        self.level = .popUpMenu // Use popUpMenu level to ensure it appears above other windows
        self.backgroundColor = .clear
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.animationBehavior = .utilityWindow
        self.hasShadow = true
        self.isOpaque = false // Make the window non-opaque for better visual integration
        
        // Position the window
        self.positionOnScreen()
        
        // Setup event monitor to detect clicks outside the window
        setupEventMonitor()
    }
    
    func positionOnScreen() {
        guard let screen = NSScreen.main else { return }
        
        // Use the visible frame to account for menu bar and dock, but extend to full screen height for edge panels
        let visibleFrame = screen.visibleFrame
        let fullFrame = screen.frame
        var windowFrame: NSRect
        
        switch position {
        case .left:
            windowFrame = NSRect(
                x: fullFrame.minX,
                y: fullFrame.minY,
                width: widthOrHeight,
                height: fullFrame.height // Always use full screen height from top to bottom
            )
        case .right:
            windowFrame = NSRect(
                x: fullFrame.maxX - widthOrHeight,
                y: fullFrame.minY,
                width: widthOrHeight,
                height: fullFrame.height // Always use full screen height from top to bottom
            )
        case .top:
            windowFrame = NSRect(
                x: visibleFrame.minX,
                y: visibleFrame.maxY - widthOrHeight,
                width: visibleFrame.width,
                height: widthOrHeight
            )
        case .bottom:
            windowFrame = NSRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width,
                height: widthOrHeight
            )
        }
        
        // Debug: Print the calculated frame
        print("EdgeWindow positioning: \(position), calculated frame: \(windowFrame)")
        print("Screen full frame: \(fullFrame)")
        print("Screen visible frame: \(visibleFrame)")
        
        self.setFrame(windowFrame, display: true)
        
        // Debug: Print the actual frame after setting
        print("EdgeWindow actual frame after setting: \(self.frame)")
        print("EdgeWindow content view frame: \(self.contentView?.frame ?? .zero)")
    }
    
    func updatePosition(_ newPosition: Position) {
        self.position = newPosition
        self.positionOnScreen()
    }
    
    override func mouseDown(with event: NSEvent) {
        // Prevent window movement
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isVisible else { return }
            
            // Get the mouse location in screen coordinates
            let mouseLocation = NSEvent.mouseLocation
            
            // Check if the click is outside the window
            if !NSPointInRect(mouseLocation, self.frame) {
                // Close the window
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.closeEdgeWindow()
                }
            }
        }
    }
    
    deinit {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
}

extension EdgeWindow.Position {
    static func fromString(_ string: String) -> EdgeWindow.Position {
        switch string.lowercased() {
        case "left":
            return .left
        case "right":
            return .right
        case "top":
            return .top
        case "bottom":
            return .bottom
        default:
            return .right // Default to right
        }
    }
}
