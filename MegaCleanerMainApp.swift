import SwiftUI

@main
struct MegaCleanerMainApp: App {
    @StateObject private var storageManager = StorageManager()
    @StateObject private var monitor = SystemMonitorManager()

    var body: some Scene {
        WindowGroup("MegaCleaner") {
            MainWindowView(storageManager: storageManager, monitor: monitor)
                .frame(minWidth: 980, minHeight: 620)
        }
        .windowStyle(.titleBar)
    }
}

