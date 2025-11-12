import Foundation

final class AutoCheckoutScheduler {
    private var timer: Timer?

    func scheduleDailyCheckout(atHour hour: Int = 7, minute: Int = 0, checkoutAction: @escaping () -> Void) {
        timer?.invalidate()
        let fireDate = nextFireDate(hour: hour, minute: minute)
        let interval = fireDate.timeIntervalSinceNow
        timer = Timer.scheduledTimer(withTimeInterval: max(1, interval), repeats: false) { [weak self] _ in
            checkoutAction()
            self?.scheduleDailyCheckout(atHour: hour, minute: minute, checkoutAction: checkoutAction)
        }
        RunLoop.main.add(timer!, forMode: .common)
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
        let todayAt = calendar.date(from: components) ?? now
        if todayAt > now {
            return todayAt
        }
        return calendar.date(byAdding: .day, value: 1, to: todayAt) ?? now.addingTimeInterval(86400)
    }
}
