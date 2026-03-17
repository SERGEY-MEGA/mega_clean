import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover = NSPopover()
    var storageManager = StorageManager()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Setup popover
        popover.contentSize = NSSize(width: 250, height: 350)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuView(storageManager: storageManager))
        
        // Observe free space changes to update title
        storageManager.$freeSpacePercentage
            .receive(on: RunLoop.main)
            .sink { [weak self] percentage in
                self?.updateStatusItemTitle(percentage: percentage)
            }
            .store(in: &cancellables)
            
        updateStatusItemTitle(percentage: storageManager.freeSpacePercentage)
    }

    func updateStatusItemTitle(percentage: Double) {
        guard let button = statusItem?.button else { return }
        
        let titleString = "✨ \(Int(percentage))%"
        let color: NSColor
        
        if percentage > 20 {
            color = .systemGreen
        } else if percentage > 10 {
            color = .systemOrange
        } else {
            color = .systemRed
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: NSFont.systemFont(ofSize: 13, weight: .bold)
        ]
        
        button.attributedTitle = NSAttributedString(string: titleString, attributes: attributes)
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem?.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                // Bring app to front to ensure popover stays interactive
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
