import SwiftUI

struct MainWindowView: View {
    @ObservedObject var storageManager: StorageManager
    @ObservedObject var monitor: SystemMonitorManager
    @ObservedObject var scan: CleanerScanManager

    @State private var selectedSection: Section = .overview
    @State private var selectedTopTab: TopTab = .userFiles

    enum Section: String, CaseIterable, Identifiable {
        case overview = "Общие сведения"
        case largest = "Наибольшие"
        case downloads = "Загрузки"
        case installers = "Файлы установки"
        case screenshots = "Снимки экрана"
        case duplicates = "Дубликаты"
        case monitor = "Мониторинг"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .overview: return "info.circle.fill"
            case .largest: return "externaldrive.fill"
            case .downloads: return "arrow.down.circle.fill"
            case .installers: return "shippingbox.fill"
            case .screenshots: return "camera.fill"
            case .duplicates: return "square.on.square.fill"
            case .monitor: return "waveform.path.ecg"
            }
        }
    }

    enum TopTab: String, CaseIterable, Identifiable {
        case userFiles = "Пользовательские файлы"
        case junkFiles = "Мусорные файлы"
        var id: String { rawValue }
        var icon: String { self == .userFiles ? "square.grid.2x2.fill" : "trash.fill" }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HStack(spacing: 0) {
                leftNav
                Divider()
                mainArea
            }
        }
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
        .onAppear { scan.refresh() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MegaCleaner")
                    .font(.system(size: 22, weight: .bold))
                Text("Свободно: \(String(format: "%.1f", storageManager.freeSpacePercentage))%")
                    .font(.subheadline)
                    .foregroundColor(storageManager.freeSpacePercentage > 20 ? .green : (storageManager.freeSpacePercentage > 10 ? .orange : .red))
            }

            Spacer()

            HStack(spacing: 10) {
                MetricPill(title: "CPU user", value: "\(String(format: "%.1f", monitor.cpuUser))%")
                MetricPill(title: "CPU sys", value: "\(String(format: "%.1f", monitor.cpuSystem))%")
                MetricPill(title: "Idle", value: "\(String(format: "%.1f", monitor.cpuIdle))%")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var leftNav: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Бесплатные инструменты")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 12)

            ForEach(Section.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: section.icon)
                            .frame(width: 18)
                        Text(section.rawValue)
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        if let badge = sectionBadge(section) {
                            Text(badge)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(selectedSection == section ? Color.primary.opacity(0.08) : Color.clear)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }

            Divider().padding(.vertical, 6)

            Text("Очистка")
                .font(.caption)
                .foregroundColor(.secondary)

            ActionButton(title: "Кэш (осторожно)", icon: "shippingbox.fill", color: .blue, action: storageManager.cleanAppCaches)
            ActionButton(title: "Мусор (логи/временные)", icon: "sparkles", color: .orange, action: storageManager.cleanSafeJunk)
            ActionButton(title: "Очистить Корзину", icon: "trash.fill", color: .red, action: storageManager.emptyTrash)

            Divider().padding(.vertical, 6)

            Button {
                storageManager.openMiniApp()
            } label: {
                Label("Открыть мини-окно", systemImage: "menubar.rectangle")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Spacer()

            if storageManager.isCleaning {
                HStack(spacing: 10) {
                    ProgressView().scaleEffect(0.8)
                    Text(storageManager.lastActionStatus ?? "Работаю…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 10)
            } else if let status = storageManager.lastActionStatus {
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)
            }
        }
        .padding(.horizontal, 12)
        .frame(width: 260)
        .background(Color.primary.opacity(0.02))
    }

    private func sectionBadge(_ s: Section) -> String? {
        switch s {
        case .downloads:
            return formatBytes(scan.categories.first(where: { $0.id == "downloads" })?.bytes ?? 0)
        case .installers:
            return formatBytes(scan.categories.first(where: { $0.id == "installers" })?.bytes ?? 0)
        case .screenshots:
            return formatBytes(scan.categories.first(where: { $0.id == "screenshots" })?.bytes ?? 0)
        default:
            return nil
        }
    }

    private var mainArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch selectedSection {
            case .monitor:
                monitorView
            default:
                overviewView
            }
        }
    }

    private var overviewView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Picker("", selection: $selectedTopTab) {
                    ForEach(TopTab.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 520)

                Spacer()

                Button {
                    scan.refresh()
                } label: {
                    Label(scan.isScanning ? "Сканирую…" : "Обновить", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .disabled(scan.isScanning)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            VStack(alignment: .center, spacing: 18) {
                Text("Удаление ненужных пользовательских файлов")
                    .font(.system(size: 18, weight: .bold))
                    .padding(.top, 18)
                Text("Просмотрите и удалите файлы из соответствующей категории")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.fixed(160)), GridItem(.fixed(160)), GridItem(.fixed(160))], spacing: 18) {
                    ForEach(gridCategoriesForTab(selectedTopTab)) { c in
                        CategoryTile(category: c)
                    }
                }
                .padding(.top, 10)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.60))
        }
    }

    private func gridCategoriesForTab(_ tab: TopTab) -> [CleanerCategory] {
        let cats = scan.categories
        switch tab {
        case .userFiles:
            return cats.filter { ["largest", "downloads", "installers", "screenshots", "duplicates"].contains($0.id) }
        case .junkFiles:
            return cats.filter { ["temp", "logs", "installers"].contains($0.id) }
        }
    }

    private var monitorView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Мониторинг процессов")
                    .font(.headline)
                Spacer()
                Button {
                    monitor.refresh()
                } label: {
                    Label("Обновить", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            VStack(spacing: 0) {
                HStack {
                    Text("Имя").frame(maxWidth: .infinity, alignment: .leading)
                    Text("CPU %").frame(width: 70, alignment: .trailing)
                    Text("RAM").frame(width: 70, alignment: .trailing)
                    Text("PID").frame(width: 60, alignment: .trailing)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider()

                List(monitor.processes) { row in
                    HStack(spacing: 12) {
                        Text(row.name)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(String(format: "%.1f", row.cpuPercent))
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .frame(width: 70, alignment: .trailing)

                        Text(String(format: "%.0f MB", row.memoryMB))
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .frame(width: 70, alignment: .trailing)

                        Text("\(row.id)")
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset)
            }

            Spacer()
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }
}

private struct CategoryTile: View {
    let category: CleanerCategory

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 86, height: 86)
                Image(systemName: category.icon)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.blue)
            }
            Text(category.title)
                .font(.system(size: 14, weight: .semibold))
            Text(formatBytes(category.bytes))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 160, height: 160)
        .background(Color.white.opacity(0.70))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes <= 0 { return "—" }
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }
}

private struct MetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.06))
        .cornerRadius(10)
    }
}

