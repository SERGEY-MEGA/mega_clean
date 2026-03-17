import SwiftUI

struct MainWindowView: View {
    @ObservedObject var storageManager: StorageManager
    @ObservedObject var monitor: SystemMonitorManager

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HStack(spacing: 0) {
                sidebar
                Divider()
                content
            }
        }
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
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

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Очистка")
                .font(.headline)
                .padding(.top, 12)

            ActionButton(
                title: "Кэш приложений",
                icon: "shippingbox.fill",
                color: .blue,
                action: storageManager.cleanAppCaches
            )

            ActionButton(
                title: "Мусор (логи/временные)",
                icon: "sparkles",
                color: .orange,
                action: storageManager.cleanSafeJunk
            )

            ActionButton(
                title: "Очистить Корзину",
                icon: "trash.fill",
                color: .red,
                action: storageManager.emptyTrash
            )

            ActionButton(
                title: "ОЗУ (безопасно)",
                icon: "memorychip",
                color: .green,
                action: storageManager.optimizeRAMSafely
            )

            Divider()
                .padding(.vertical, 6)

            Text("Инструменты")
                .font(.headline)

            Button {
                storageManager.openMiniApp()
            } label: {
                Label("Открыть мини-окно", systemImage: "sparkle.magnifyingglass")
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Spacer()

            if storageManager.isCleaning {
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.8)
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
        .padding(.horizontal, 14)
        .frame(width: 280)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Процессы (как в Мониторинге системы)")
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

            // SwiftUI Table доступен только macOS 12+, поэтому делаем “таблицу” через List (macOS 11+)
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

