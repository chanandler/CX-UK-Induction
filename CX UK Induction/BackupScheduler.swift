import Foundation

/// Fires a daily backup action at a fixed time every day (including weekends).
/// Mirrors the `AutoCheckoutScheduler` pattern but without weekday filtering.
final class BackupScheduler {
    private var timer: Timer?

    func scheduleDailyBackup(atHour hour: Int = 6, minute: Int = 0, action: @escaping () -> Void) {
        timer?.invalidate()
        let fireDate = nextFireDate(hour: hour, minute: minute)
        let interval = fireDate.timeIntervalSinceNow
        // scheduledTimer registers itself on the current run loop automatically.
        // On firing, reschedule for the next day.
        timer = Timer.scheduledTimer(withTimeInterval: max(1, interval), repeats: false) { [weak self] _ in
            action()
            self?.scheduleDailyBackup(atHour: hour, minute: minute, action: action)
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }

    private func nextFireDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard var candidate = calendar.date(from: components) else { return now }

        // If that time has already passed today, move to tomorrow.
        if candidate <= now {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }
}

// MARK: - Backup file management

extension BackupScheduler {

    /// The app's Documents directory URL.
    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Writes `csvString` to Documents as `visitor_backup_YYYY-MM-DD.csv`,
    /// then deletes backup files older than `keepDays` days.
    /// Returns the written file URL, or nil on failure.
    @discardableResult
    static func writeBackup(csvString: String, keepDays: Int = 30) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "visitor_backup_\(formatter.string(from: Date())).csv"
        let fileURL = documentsURL.appendingPathComponent(filename)

        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("BackupScheduler: failed to write backup – \(error)")
            return nil
        }

        // Prune backups older than keepDays.
        pruneOldBackups(keepDays: keepDays)
        return fileURL
    }

    /// Returns all backup file URLs sorted newest-first.
    static func existingBackups() -> [URL] {
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)) ?? []
        return items
            .filter { $0.lastPathComponent.hasPrefix("visitor_backup_") && $0.pathExtension == "csv" }
            .sorted { a, b in
                let dateA = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let dateB = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return dateA > dateB
            }
    }

    private static func pruneOldBackups(keepDays: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -keepDays, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for url in existingBackups() {
            // Parse the date from the filename so we don't need filesystem metadata.
            let name = url.deletingPathExtension().lastPathComponent // "visitor_backup_YYYY-MM-DD"
            let dateString = String(name.dropFirst("visitor_backup_".count))
            if let fileDate = formatter.date(from: dateString), fileDate < cutoff {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
