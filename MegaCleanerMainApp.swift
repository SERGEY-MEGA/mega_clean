import SwiftUI

@main
struct MegaCleanerMainApp: App {
    @StateObject private var storageManager = StorageManager()
    @StateObject private var monitor = SystemMonitorManager()
    @StateObject private var scan = CleanerScanManager()

    var body: some Scene {
        WindowGroup("MegaCleaner") {
            MainWindowView(storageManager: storageManager, monitor: monitor, scan: scan)
                .frame(minWidth: 980, minHeight: 620)
        }
        .windowStyle(.titleBar)
    }
}

