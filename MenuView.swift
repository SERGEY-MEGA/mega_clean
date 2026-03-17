import SwiftUI

struct MenuView: View {
    @ObservedObject var storageManager: StorageManager
    
    var body: some View {
        VStack(spacing: 16) {
            header
            
            Divider()
            
            VStack(spacing: 10) {
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
                    title: "ОЗУ (безопасно)",
                    icon: "memorychip",
                    color: .green,
                    action: storageManager.optimizeRAMSafely
                )
                
                ActionButton(
                    title: "Очистить Корзину",
                    icon: "trash.fill",
                    color: .red,
                    action: storageManager.emptyTrash
                )
            }
            
            if let status = storageManager.lastActionStatus {
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
            
            Divider()
            
            VStack(spacing: 8) {
                Button("Открыть большое приложение") {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.sergejmegeran.MegaCleaner") {
                        let config = NSWorkspace.OpenConfiguration()
                        config.activates = true
                        NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                
                Button("Закрыть мини-окно") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(width: 250)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("MegaCleaner")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Свободно: \(String(format: "%.1f", storageManager.freeSpacePercentage))%")
                    .font(.subheadline)
                    .foregroundColor(statusColor)
            }
            Spacer()
            if storageManager.isCleaning {
                ProgressView()
                    .scaleEffect(0.6)
            } else {
                Text("\(Int(storageManager.freeSpacePercentage))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(statusColor)
            }
        }
    }
    
    private var statusColor: Color {
        if storageManager.freeSpacePercentage > 20 {
            return .green
        } else if storageManager.freeSpacePercentage > 10 {
            return .orange
        } else {
            return .red
        }
    }
}
