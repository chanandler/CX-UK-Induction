import Foundation

final class AutoCheckoutScheduler {
    private var timer: Timer?

    func scheduleDailyCheckout(atHour hour: Int = 5, minute: Int = 0, checkoutAction: @escaping () -> Void) {
        timer?.invalidate()
        let fireDate = nextWeekdayFireDate(hour: hour, minute: minute)
        let interval = fireDate.timeIntervalSinceNow
        // scheduledTimer already registers itself on the current run loop — no RunLoop.add() needed.
        // On firing, reschedule for the next weekday without unbounded recursion.
        timer = Timer.scheduledTimer(withTimeInterval: max(1, interval), repeats: false) { [weak self] _ in
            checkoutAction()
            self?.scheduleDailyCheckout(atHour: hour, minute: minute, checkoutAction: checkoutAction)
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }

    // Returns the next weekday (Mon–Fri) occurrence of the given hour/minute.
    private func nextWeekdayFireDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard var candidate = calendar.date(from: components) else { return now }

        // If the time has already passed today, start checking from tomorrow.
        if candidate <= now {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }

        // Advance past any weekend days (Saturday = 7, Sunday = 1 in Gregorian).
        for _ in 0..<7 {
            let weekday = calendar.component(.weekday, from: candidate)
            if weekday != 1 && weekday != 7 { break }
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }

        return candidate
    }
}
