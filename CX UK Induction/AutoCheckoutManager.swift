import Foundation

final class AutoCheckoutScheduler {
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.cemexuk.autocheckout.timer")
    private let stateLock = NSLock()
    private var scheduleToken = UUID()

    func scheduleDailyCheckout(atHour hour: Int = 5, minute: Int = 0, checkoutAction: @escaping () -> Void) {
        cancel()
        let token = UUID()
        stateLock.lock()
        scheduleToken = token
        stateLock.unlock()

        let fireDate = nextWeekdayFireDate(hour: hour, minute: minute)
        let interval = max(1, fireDate.timeIntervalSinceNow)

        let newTimer = DispatchSource.makeTimerSource(queue: queue)
        newTimer.schedule(deadline: .now() + interval, repeating: .never)
        newTimer.setEventHandler { [weak self] in
            guard let self else { return }
            self.stateLock.lock()
            let isCurrentSchedule = self.scheduleToken == token
            self.stateLock.unlock()
            guard isCurrentSchedule else { return }

            DispatchQueue.main.async {
                checkoutAction()
            }
            // One-shot timer; schedule again for the next weekday fire date.
            self.scheduleDailyCheckout(atHour: hour, minute: minute, checkoutAction: checkoutAction)
        }
        timer = newTimer
        newTimer.resume()
    }

    func cancel() {
        stateLock.lock()
        scheduleToken = UUID()
        stateLock.unlock()
        timer?.setEventHandler {}
        timer?.cancel()
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

        // Skip directly over weekends using a calendar calculation rather than
        // incrementing one day at a time.
        let weekday = calendar.component(.weekday, from: candidate)
        if weekday == 7 {
            // Saturday → advance 2 days to Monday
            candidate = calendar.date(byAdding: .day, value: 2, to: candidate) ?? candidate
        } else if weekday == 1 {
            // Sunday → advance 1 day to Monday
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }

        return candidate
    }
}
