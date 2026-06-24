import AppKit
import Foundation

struct Limit {
    let used: Int
    let windowMinutes: Int
    let resetsAt: Date?

    var remaining: Int { max(0, min(100, 100 - used)) }

    var label: String {
        if windowMinutes % 1440 == 0 { return "\(windowMinutes / 1440)d" }
        if windowMinutes % 60 == 0 { return "\(windowMinutes / 60)h" }
        return "\(windowMinutes)m"
    }
}

struct Snapshot {
    let timestamp: String
    let sourcePath: String
    let planType: String?
    let primary: Limit?
    let secondary: Limit?

    var limits: [Limit] { [primary, secondary].compactMap { $0 } }

    var title: String {
        let parts = limits.map { "\($0.label) \($0.remaining)%" }
        return parts.isEmpty ? "Codex --" : parts.joined(separator: "  ")
    }

    var worstRemaining: Int? {
        limits.map(\.remaining).min()
    }
}

final class StatusArt {
    private let font = NSFont.monospacedSystemFont(ofSize: 8.5, weight: .regular)
    private let timeFont = NSFont.monospacedDigitSystemFont(ofSize: 7, weight: .regular)
    private let textColor = NSColor.labelColor
    private let timeColor = NSColor.secondaryLabelColor
    private let mutedColor = NSColor.secondaryLabelColor.withAlphaComponent(0.35)
    private let barSize = NSSize(width: 3, height: 7)
    private let barGap: CGFloat = 1
    private let padding = NSSize(width: 2, height: 1)
    private let resetTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = .autoupdatingCurrent
        return formatter
    }()
    private let resetDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M'月'd'日'"
        formatter.timeZone = .autoupdatingCurrent
        return formatter
    }()

    func image(for snapshot: Snapshot?) -> NSImage {
        guard let snapshot else {
            return textImage("Codex --", color: .secondaryLabelColor)
        }
        return image(for: snapshot.limits)
    }

    private func image(for limits: [Limit]) -> NSImage {
        let rows = Array(limits.prefix(2))
        let widthForRows = rows.map { rowWidth(for: $0) }.max() ?? textWidth("Codex --")
        let width = widthForRows + padding.width * 2
        let height: CGFloat = 22
        let image = NSImage(size: NSSize(width: ceil(width), height: height))
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        for (index, limit) in rows.enumerated() {
            let y = index == 0 ? CGFloat(11) : CGFloat(0)
            draw(limit, at: CGPoint(x: padding.width, y: y))
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func rowWidth(for limit: Limit) -> CGFloat {
        let resetWidth = resetLabel(for: limit).map { timeTextWidth($0) + 4 } ?? 0
        return textWidth(limit.label) + 4 + barsWidth + 4 + textWidth("\(limit.remaining)%") + resetWidth
    }

    private var barsWidth: CGFloat {
        barSize.width * 5 + barGap * 4
    }

    private func draw(_ limit: Limit, at point: CGPoint) {
        let labelAttrs = attrs(color: textColor)
        let percentAttrs = attrs(color: textColor)
        var x = point.x

        limit.label.draw(at: CGPoint(x: x, y: point.y), withAttributes: labelAttrs)
        x += textWidth(limit.label) + 4

        let filled = max(0, min(5, Int(ceil(Double(limit.remaining) / 20.0))))
        for i in 0..<5 {
            let rect = NSRect(x: x + CGFloat(i) * (barSize.width + barGap), y: point.y + 2, width: barSize.width, height: barSize.height)
            let path = NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5)
            (i < filled ? color(for: limit.remaining) : mutedColor).setFill()
            path.fill()
        }
        x += barsWidth + 4

        "\(limit.remaining)%".draw(at: CGPoint(x: x, y: point.y), withAttributes: percentAttrs)
        x += textWidth("\(limit.remaining)%") + 4
        if let reset = resetLabel(for: limit) {
            reset.draw(at: CGPoint(x: x, y: point.y), withAttributes: timeAttrs(color: timeColor))
        }
    }

    private func textImage(_ text: String, color: NSColor) -> NSImage {
        let width = textWidth(text) + padding.width * 2
        let image = NSImage(size: NSSize(width: ceil(width), height: 22))
        image.lockFocus()
        text.draw(at: CGPoint(x: padding.width, y: padding.height + 1), withAttributes: attrs(color: color))
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func textWidth(_ text: String) -> CGFloat {
        (text as NSString).size(withAttributes: attrs(color: textColor)).width
    }

    private func timeTextWidth(_ text: String) -> CGFloat {
        (text as NSString).size(withAttributes: timeAttrs(color: timeColor)).width
    }

    private func attrs(color: NSColor) -> [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: color]
    }

    private func timeAttrs(color: NSColor) -> [NSAttributedString.Key: Any] {
        [.font: timeFont, .foregroundColor: color]
    }

    private func resetLabel(for limit: Limit) -> String? {
        guard let date = limit.resetsAt else { return nil }
        return limit.windowMinutes >= 1440
            ? resetDateFormatter.string(from: date)
            : resetTimeFormatter.string(from: date)
    }

    private func color(for remaining: Int) -> NSColor {
        if remaining > 60 { return .systemGreen }
        if remaining >= 20 { return .systemOrange }
        return .systemRed
    }
}

final class QuotaReader {
    private let sessionsRoot: URL
    private let maxFiles = 20
    private let tailBytes: UInt64 = 2 * 1024 * 1024

    init(sessionsRoot: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/sessions")) {
        self.sessionsRoot = sessionsRoot
    }

    func latest() -> Snapshot? {
        let files = recentLogFiles()
        var best: Snapshot?
        for file in files {
            guard let text = tailText(from: file) else { continue }
            for line in text.split(separator: "\n").reversed() {
                guard line.contains("\"token_count\""), line.contains("\"rate_limits\"") else { continue }
                guard let snapshot = parse(String(line), sourcePath: file.path) else { continue }
                if best == nil || snapshot.timestamp > best!.timestamp {
                    best = snapshot
                }
            }
        }
        return best
    }

    private func recentLogFiles() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [(URL, Date)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                values.isRegularFile == true
            else { continue }
            files.append((url, values.contentModificationDate ?? .distantPast))
        }
        return files.sorted { $0.1 > $1.1 }.prefix(maxFiles).map(\.0)
    }

    private func tailText(from file: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }

        guard let size = try? handle.seekToEnd() else { return nil }
        let offset = size > tailBytes ? size - tailBytes : 0
        do {
            try handle.seek(toOffset: offset)
            guard var data = try handle.readToEnd() else { return nil }
            if offset > 0, let newline = data.firstIndex(of: 10) {
                data.removeSubrange(0...newline)
            }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func parse(_ line: String, sourcePath: String) -> Snapshot? {
        guard
            let data = line.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let timestamp = object["timestamp"] as? String,
            let payload = object["payload"] as? [String: Any]
        else { return nil }

        let rateLimits = (payload["rate_limits"] as? [String: Any])
            ?? (object["rate_limits"] as? [String: Any])
        guard let rateLimits else { return nil }

        let primary = parseLimit(rateLimits["primary"] as? [String: Any])
        let secondary = parseLimit(rateLimits["secondary"] as? [String: Any])
        guard primary != nil || secondary != nil else { return nil }

        return Snapshot(
            timestamp: timestamp,
            sourcePath: sourcePath,
            planType: rateLimits["plan_type"] as? String,
            primary: primary,
            secondary: secondary
        )
    }

    private func parseLimit(_ object: [String: Any]?) -> Limit? {
        guard
            let object,
            let used = number(object["used_percent"]),
            let minutes = number(object["window_minutes"])
        else { return nil }

        let resetDate = number(object["resets_at"]).map { Date(timeIntervalSince1970: TimeInterval($0)) }
        return Limit(used: Int(used.rounded()), windowMinutes: Int(minutes.rounded()), resetsAt: resetDate)
    }

    private func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let reader = QuotaReader()
    private let art = StatusArt()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var timer: Timer?
    private var snapshot: Snapshot?
    private let resetFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        formatter.timeZone = .autoupdatingCurrent
        return formatter
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.imagePosition = .imageLeft
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.menu = makeMenu()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        snapshot = reader.latest()
        let image = art.image(for: snapshot)
        statusItem.length = min(image.size.width + 4, 72)
        statusItem.button?.image = image
        statusItem.button?.title = " "
        statusItem.button?.toolTip = snapshot?.title ?? "No Codex quota log found"
        statusItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        if let snapshot {
            menu.addItem(disabledItem(snapshot.title))
            if let planType = snapshot.planType {
                menu.addItem(disabledItem("Plan: \(planType)"))
            }
            addLimitItems(to: menu, name: "Primary", limit: snapshot.primary)
            addLimitItems(to: menu, name: "Secondary", limit: snapshot.secondary)
            menu.addItem(disabledItem("Updated: \(snapshot.timestamp)"))
            menu.addItem(disabledItem("Source: \(URL(fileURLWithPath: snapshot.sourcePath).lastPathComponent)"))
        } else {
            menu.addItem(disabledItem("No Codex quota log found"))
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshFromMenu), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Open Log Folder", action: #selector(openLogFolder), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        return menu
    }

    private func addLimitItems(to menu: NSMenu, name: String, limit: Limit?) {
        guard let limit else { return }
        var text = "\(name): \(limit.label) remaining \(limit.remaining)% (used \(limit.used)%)"
        if let resetsAt = limit.resetsAt {
            text += ", reset \(resetFormatter.string(from: resetsAt))"
        }
        menu.addItem(disabledItem(text))
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func refreshFromMenu() {
        refresh()
    }

    @objc private func openLogFolder() {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions")
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

func printOnce() -> Int32 {
    let resetFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = .autoupdatingCurrent
        return formatter
    }()

    guard let snapshot = QuotaReader().latest() else {
        print("No Codex quota log found")
        return 1
    }
    print(snapshot.title)
    for limit in snapshot.limits {
        let reset = limit.resetsAt.map { ", reset \(resetFormatter.string(from: $0))" } ?? ""
        print("\(limit.label): remaining \(limit.remaining)%, used \(limit.used)%\(reset)")
    }
    print("updated: \(snapshot.timestamp)")
    print("source: \(snapshot.sourcePath)")
    return 0
}

if CommandLine.arguments.contains("--print-once") {
    exit(printOnce())
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
