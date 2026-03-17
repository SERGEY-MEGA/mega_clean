import Foundation
import AppKit

class StorageManager: ObservableObject {
    @Published var freeSpacePercentage: Double = 0.0
    @Published var isCleaning: Bool = false
    @Published var lastActionStatus: String? = nil
    
    private let fileManager = FileManager.default
    private var timer: Timer?
    
    init() {
        updateFreeSpace()
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateFreeSpace()
        }
    }
    
    func updateFreeSpace() {
        let path = NSHomeDirectory()
        do {
            let values = try fileManager.attributesOfFileSystem(forPath: path)
            if let freeSpace = values[.systemFreeSize] as? Int64,
               let totalSpace = values[.systemSize] as? Int64 {
                self.freeSpacePercentage = (Double(freeSpace) / Double(totalSpace)) * 100
            }
        } catch {
            print("Ошибка при получении данных о диске: \(error)")
        }
    }
    
    // MARK: - Cleaning

    func cleanAppCaches() {
        isCleaning = true
        lastActionStatus = "Очистка кэша приложений…"

        let cachesPath = NSString(string: "~/Library/Caches").expandingTildeInPath
        let excludePrefixes = [
            "com.apple.", // не трогаем apple caches (минимум рисков)
        ]

        DispatchQueue.global(qos: .userInitiated).async {
            let deletedBytes = self.removeItemsFiltered(
                at: cachesPath,
                shouldDelete: { itemName, _ in
                    for prefix in excludePrefixes where itemName.hasPrefix(prefix) { return false }
                    return true
                }
            )

            DispatchQueue.main.async {
                self.isCleaning = false
                self.lastActionStatus = "Кэш очищен: \(Self.formatBytes(deletedBytes))"
                self.updateFreeSpace()
                self.clearStatusAfterDelay()
            }
        }
    }

    func cleanSafeJunk() {
        isCleaning = true
        lastActionStatus = "Очистка мусора…"

        let logsPath = NSString(string: "~/Library/Logs").expandingTildeInPath
        let tmpPath = NSTemporaryDirectory()
        let cutoff = Date().addingTimeInterval(-14 * 24 * 60 * 60) // 14 дней

        DispatchQueue.global(qos: .userInitiated).async {
            var deleted: Int64 = 0

            deleted += self.removeFilesOlderThan(at: logsPath, cutoff: cutoff)
            deleted += self.removeItems(at: tmpPath, keepDirectory: true)

            DispatchQueue.main.async {
                self.isCleaning = false
                self.lastActionStatus = "Мусор очищен: \(Self.formatBytes(deleted))"
                self.updateFreeSpace()
                self.clearStatusAfterDelay()
            }
        }
    }
    
    func optimizeRAMSafely() {
        isCleaning = true
        lastActionStatus = "ОЗУ: безопасная оптимизация…"
        
        DispatchQueue.global(qos: .userInitiated).async {
            // На современных macOS принудительное "purge" часто бесполезно/недоступно.
            // Здесь делаем безопасный вариант: мягко чистим наши внутренние временные данные
            // и, если доступна утилита purge без sudo, пробуем её запустить.
            var didRunPurge = false
            var purgeOk = false

            if self.fileManager.isExecutableFile(atPath: "/usr/bin/purge") {
                didRunPurge = true
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/purge")
                task.arguments = []
                do {
                    try task.run()
                    task.waitUntilExit()
                    purgeOk = (task.terminationStatus == 0)
                } catch {
                    purgeOk = false
                }
            }
            
            DispatchQueue.main.async {
                self.isCleaning = false
                if didRunPurge {
                    self.lastActionStatus = purgeOk ? "ОЗУ: выполнено (purge)" : "ОЗУ: purge недоступен/ошибка"
                } else {
                    self.lastActionStatus = "ОЗУ: macOS управляет памятью автоматически"
                }
                self.clearStatusAfterDelay()
            }
        }
    }
    
    func emptyTrash() {
        isCleaning = true
        lastActionStatus = "Очистка корзины..."
        
        let trashPath = NSString(string: "~/.Trash").expandingTildeInPath
        
        DispatchQueue.global(qos: .userInitiated).async {
            let deleted = self.removeItems(at: trashPath, keepDirectory: true)
            
            DispatchQueue.main.async {
                self.isCleaning = false
                self.lastActionStatus = "Корзина очищена: \(Self.formatBytes(deleted))"
                self.updateFreeSpace()
                self.clearStatusAfterDelay()
            }
        }
    }
    
    func openMiniApp() {
        openApp(bundleIdentifier: "com.sergejmegeran.MegaCleanerMini", activate: false)
    }

    // MARK: - Filesystem helpers

    private func openApp(bundleIdentifier: String, activate: Bool) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = activate
        NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
    }

    @discardableResult
    private func removeItems(at path: String, keepDirectory: Bool = false) -> Int64 {
        do {
            let items = try fileManager.contentsOfDirectory(atPath: path)
            var deleted: Int64 = 0
            for item in items {
                let itemPath = (path as NSString).appendingPathComponent(item)
                deleted += Self.directorySize(atPath: itemPath)
                try fileManager.removeItem(atPath: itemPath)
            }
            if !keepDirectory {
                // We usually don't want to remove the parent if it's a specific folder like DerivedData or Trash
                // But for workspaceStorage/snapshots it's fine.
            }
            return deleted
        } catch {
            print("Не удалось удалить \(path): \(error)")
            return 0
        }
    }

    @discardableResult
    private func removeItemsFiltered(at path: String, shouldDelete: (String, String) -> Bool) -> Int64 {
        do {
            let items = try fileManager.contentsOfDirectory(atPath: path)
            var deleted: Int64 = 0
            for item in items {
                let itemPath = (path as NSString).appendingPathComponent(item)
                if shouldDelete(item, itemPath) {
                    deleted += Self.directorySize(atPath: itemPath)
                    try fileManager.removeItem(atPath: itemPath)
                }
            }
            return deleted
        } catch {
            print("Не удалось удалить \(path): \(error)")
            return 0
        }
    }

    private func removeFilesOlderThan(at path: String, cutoff: Date) -> Int64 {
        let url = URL(fileURLWithPath: path)
        guard let e = fileManager.enumerator(at: url, includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return 0
        }

        var deleted: Int64 = 0
        for case let fileURL as URL in e {
            do {
                let values = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey])
                if values.isDirectory == true { continue }
                if let m = values.contentModificationDate, m < cutoff {
                    let p = fileURL.path
                    deleted += Self.directorySize(atPath: p)
                    try fileManager.removeItem(at: fileURL)
                }
            } catch {
                continue
            }
        }
        return deleted
    }

    private static func directorySize(atPath path: String) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: path, isDirectory: &isDir) { return 0 }
        if !isDir.boolValue {
            if let attrs = try? fm.attributesOfItem(atPath: path), let size = attrs[.size] as? NSNumber {
                return size.int64Value
            }
            return 0
        }

        let url = URL(fileURLWithPath: path)
        guard let e = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in e {
            do {
                let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                if values.isDirectory == true { continue }
                if let s = values.fileSize {
                    total += Int64(s)
                }
            } catch {}
        }
        return total
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }
    
    private func clearStatusAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.lastActionStatus = nil
        }
    }
}
