import Foundation

struct ProcessRow: Identifiable, Hashable {
    let id: Int
    let name: String
    let cpuPercent: Double
    let memoryMB: Double
}

final class SystemMonitorManager: ObservableObject {
    @Published var processes: [ProcessRow] = []
    @Published var cpuUser: Double = 0
    @Published var cpuSystem: Double = 0
    @Published var cpuIdle: Double = 0

    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        updateCPU()
        updateProcesses()
    }

    private func updateProcesses() {
        DispatchQueue.global(qos: .utility).async {
            let output = Self.run("/bin/ps", ["-axo", "pid=,pcpu=,rss=,comm="]) ?? ""
            var rows: [ProcessRow] = []

            for line in output.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }

                // pid pcpu rss comm(with spaces possible)
                // We parse first 3 numeric fields, remainder is command.
                let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
                if parts.count < 4 { continue }

                guard
                    let pid = Int(parts[0]),
                    let cpu = Double(parts[1]),
                    let rssKB = Double(parts[2])
                else { continue }

                let name = parts[3...].joined(separator: " ")
                let memMB = (rssKB / 1024.0)
                rows.append(ProcessRow(id: pid, name: name, cpuPercent: cpu, memoryMB: memMB))
            }

            rows.sort { a, b in
                if a.cpuPercent != b.cpuPercent { return a.cpuPercent > b.cpuPercent }
                return a.memoryMB > b.memoryMB
            }

            DispatchQueue.main.async {
                self.processes = Array(rows.prefix(60))
            }
        }
    }

    private func updateCPU() {
        DispatchQueue.global(qos: .utility).async {
            // Use top for a single snapshot.
            // Example: "CPU usage: 7.53% user, 18.12% sys, 74.35% idle"
            let output = Self.run("/usr/bin/top", ["-l", "1", "-n", "0"]) ?? ""
            guard let line = output.split(separator: "\n").first(where: { $0.contains("CPU usage:") }) else {
                return
            }

            let s = String(line)
            let parsed = Self.parseCPUUsageLine(s)
            DispatchQueue.main.async {
                if let parsed {
                    self.cpuUser = parsed.user
                    self.cpuSystem = parsed.sys
                    self.cpuIdle = parsed.idle
                }
            }
        }
    }

    private static func parseCPUUsageLine(_ line: String) -> (user: Double, sys: Double, idle: Double)? {
        // "CPU usage: 7.53% user, 18.12% sys, 74.35% idle"
        func extract(_ key: String) -> Double? {
            guard let range = line.range(of: key) else { return nil }
            let prefix = line[..<range.lowerBound]
            // take last "NN.NN%" before key (macOS 11 compatible)
            let s = String(prefix)
            guard let re = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)%"#, options: []) else {
                return nil
            }
            let ns = s as NSString
            let matches = re.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length))
            guard let last = matches.last, last.numberOfRanges >= 2 else { return nil }
            let num = ns.substring(with: last.range(at: 1))
            return Double(num)
        }

        guard
            let user = extract(" user"),
            let sys = extract(" sys"),
            let idle = extract(" idle")
        else { return nil }

        return (user, sys, idle)
    }

    private static func run(_ launchPath: String, _ arguments: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = arguments

        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()

        do {
            try p.run()
        } catch {
            return nil
        }

        p.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}

