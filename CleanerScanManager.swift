import Foundation

struct CleanerCategory: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let bytes: Int64
}

final class CleanerScanManager: ObservableObject {
    @Published var userFilesTotalBytes: Int64 = 0
    @Published var junkFilesTotalBytes: Int64 = 0
    @Published var categories: [CleanerCategory] = []
    @Published var isScanning: Bool = false

    private let fm = FileManager.default

    func refresh() {
        isScanning = true
        DispatchQueue.global(qos: .utility).async {
            let home = NSHomeDirectory()

            let downloads = "\(home)/Downloads"
            let desktop = "\(home)/Desktop"
            let screenshots = self.estimateScreenshotsBytes(at: desktop)

            let installers = "\(home)/Library/Caches/com.apple.appstore"
            let logs = "\(home)/Library/Logs"
            let tmp = NSTemporaryDirectory()

            let downloadsBytes = self.directorySize(atPath: downloads)
            let installersBytes = self.directorySize(atPath: installers)
            let logsBytes = self.directorySize(atPath: logs)
            let tmpBytes = self.directorySize(atPath: tmp)

            // Условно считаем:
            // - user files: downloads + screenshots (как “пользовательские файлы”)
            // - junk: logs + tmp + installers (как “мусорные файлы”)
            let userTotal = downloadsBytes + screenshots
            let junkTotal = logsBytes + tmpBytes + installersBytes

            let cats: [CleanerCategory] = [
                CleanerCategory(id: "largest", title: "Наибольшие", subtitle: "скоро", icon: "externaldrive.fill", bytes: 0),
                CleanerCategory(id: "downloads", title: "Загрузки", subtitle: "Downloads", icon: "arrow.down.circle.fill", bytes: downloadsBytes),
                CleanerCategory(id: "installers", title: "Файлы установки", subtitle: "App Store cache", icon: "shippingbox.fill", bytes: installersBytes),
                CleanerCategory(id: "screenshots", title: "Снимки экрана", subtitle: "Desktop", icon: "camera.fill", bytes: screenshots),
                CleanerCategory(id: "duplicates", title: "Дубликаты", subtitle: "скоро", icon: "square.on.square.fill", bytes: 0),
                CleanerCategory(id: "logs", title: "Логи", subtitle: "Library/Logs", icon: "doc.text.fill", bytes: logsBytes),
                CleanerCategory(id: "temp", title: "Временные", subtitle: "TMP", icon: "sparkles", bytes: tmpBytes),
            ]

            DispatchQueue.main.async {
                self.userFilesTotalBytes = userTotal
                self.junkFilesTotalBytes = junkTotal
                self.categories = cats
                self.isScanning = false
            }
        }
    }

    private func estimateScreenshotsBytes(at desktopPath: String) -> Int64 {
        guard let items = try? fm.contentsOfDirectory(atPath: desktopPath) else { return 0 }
        var total: Int64 = 0
        for item in items where item.lowercased().hasPrefix("снимок экрана") || item.lowercased().hasPrefix("screen shot") {
            let p = (desktopPath as NSString).appendingPathComponent(item)
            total += fileSize(atPath: p)
        }
        return total
    }

    private func fileSize(atPath path: String) -> Int64 {
        if let attrs = try? fm.attributesOfItem(atPath: path), let size = attrs[.size] as? NSNumber {
            return size.int64Value
        }
        return 0
    }

    private func directorySize(atPath path: String) -> Int64 {
        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: path, isDirectory: &isDir) { return 0 }
        if !isDir.boolValue { return fileSize(atPath: path) }

        let url = URL(fileURLWithPath: path)
        guard let e = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in e {
            do {
                let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                if values.isDirectory == true { continue }
                if let s = values.fileSize { total += Int64(s) }
            } catch {}
        }
        return total
    }
}

