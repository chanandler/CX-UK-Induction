import SwiftUI
import Charts

private enum AnalyticsRange: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        }
    }
}

struct AnalyticsDashboardView: View {
    let visitors: [Visitor]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRange: AnalyticsRange = .week

    private var metrics: AnalyticsMetrics {
        AnalyticsMetrics(visitors: visitors, now: Date(), calendar: .current, range: selectedRange)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Range", selection: $selectedRange) {
                        ForEach(AnalyticsRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)

                    summaryGrid

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trend (\(selectedRange.title))")
                            .font(.headline)
                        if metrics.trendPoints.isEmpty {
                            emptyState("No data for this period")
                        } else {
                            Chart(metrics.trendPoints) { item in
                                BarMark(
                                    x: .value("Period", item.label),
                                    y: .value("Visits", item.count)
                                )
                                .foregroundStyle(Color.cemexBlue.gradient)
                            }
                            .frame(height: 220)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Visitors by Hour")
                            .font(.headline)
                        Chart(metrics.hourlyCounts) { item in
                            BarMark(
                                x: .value("Hour", item.label),
                                y: .value("Visitors", item.count)
                            )
                            .foregroundStyle(Color.cemexBlue.gradient)
                        }
                        .frame(height: 220)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top Hosts / Departments")
                            .font(.headline)
                        if metrics.topDepartments.isEmpty {
                            emptyState("No host data yet")
                        } else {
                            Chart(metrics.topDepartments) { item in
                                BarMark(
                                    x: .value("Host", item.name),
                                    y: .value("Visits", item.count)
                                )
                                .foregroundStyle(.orange.gradient)
                            }
                            .frame(height: 220)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top Companies")
                            .font(.headline)
                        if metrics.topCompanies.isEmpty {
                            emptyState("No company data yet")
                        } else {
                            Chart(metrics.topCompanies) { item in
                                BarMark(
                                    x: .value("Company", item.name),
                                    y: .value("Visits", item.count)
                                )
                                .foregroundStyle(.green.gradient)
                            }
                            .frame(height: 220)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Busiest Day")
                            .font(.headline)
                        if let busiest = metrics.busiestWeekday {
                            HStack {
                                Text(busiest.name)
                                    .font(.title3.bold())
                                Spacer()
                                Text("\(busiest.count) visitors")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        } else {
                            emptyState("No visit records yet")
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var summaryGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            summaryCard("Visits", value: "\(metrics.totalInRange)", symbol: "person.2")
            summaryCard("Unique Visitors", value: "\(metrics.uniqueVisitors)", symbol: "person.crop.circle.badge.checkmark")
            summaryCard("Avg Visit", value: metrics.averageDurationText, symbol: "clock")
            summaryCard("Active Now", value: "\(metrics.activeNow)", symbol: "person.crop.circle.badge.exclamationmark")
            summaryCard("Repeat Visitors", value: "\(metrics.repeatVisitors)", symbol: "arrow.triangle.2.circlepath")
            summaryCard("Auto Check-out", value: metrics.autoCheckoutRateText, symbol: "moon.zzz")
        }
    }

    private func summaryCard(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
    }
}

private struct AnalyticsMetrics {
    struct HourCount: Identifiable {
        let hour: Int
        let label: String
        let count: Int
        var id: Int { hour }
    }

    struct NamedCount: Identifiable {
        let name: String
        let count: Int
        var id: String { name }
    }

    struct WeekdayCount: Identifiable {
        let weekday: Int
        let name: String
        let count: Int
        var id: Int { weekday }
    }

    struct TrendPoint: Identifiable {
        let label: String
        let count: Int
        var id: String { label }
    }

    let totalInRange: Int
    let uniqueVisitors: Int
    let repeatVisitors: Int
    let activeNow: Int
    let averageVisitDuration: TimeInterval?
    let autoCheckoutRateText: String
    let hourlyCounts: [HourCount]
    let trendPoints: [TrendPoint]
    let topDepartments: [NamedCount]
    let topCompanies: [NamedCount]
    let busiestWeekday: WeekdayCount?

    private static let shortWeekdaySymbols: [String] = {
        DateFormatter().shortWeekdaySymbols ?? []
    }()

    var averageDurationText: String {
        guard let averageVisitDuration else { return "N/A" }
        let minutes = Int(averageVisitDuration) / 60
        let hoursPart = minutes / 60
        let minutePart = minutes % 60
        if hoursPart > 0 {
            return "\(hoursPart)h \(minutePart)m"
        }
        return "\(minutePart)m"
    }

    init(visitors: [Visitor], now: Date, calendar: Calendar, range: AnalyticsRange) {
        let startDate: Date
        switch range {
        case .day:
            startDate = calendar.startOfDay(for: now)
        case .week:
            startDate = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        case .month:
            startDate = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
        }

        let filtered = visitors.filter { $0.checkIn >= startDate && $0.checkIn <= now }

        totalInRange = filtered.count

        let keys = filtered.map {
            "\($0.firstName.lowercased())|\($0.lastName.lowercased())|\($0.company.lowercased())"
        }
        uniqueVisitors = Set(keys).count

        var keyCounts: [String: Int] = [:]
        for key in keys { keyCounts[key, default: 0] += 1 }
        repeatVisitors = keyCounts.values.filter { $0 > 1 }.count

        activeNow = filtered.filter { $0.checkOut == nil }.count

        let completedDurations = filtered.compactMap { visitor -> TimeInterval? in
            guard let checkOut = visitor.checkOut else { return nil }
            let duration = checkOut.timeIntervalSince(visitor.checkIn)
            return duration >= 0 ? duration : nil
        }
        if !completedDurations.isEmpty {
            averageVisitDuration = completedDurations.reduce(0, +) / Double(completedDurations.count)
        } else {
            averageVisitDuration = nil
        }

        let completedInRange = filtered.filter { $0.checkOut != nil }
        if completedInRange.isEmpty {
            autoCheckoutRateText = "N/A"
        } else {
            let autoCount = completedInRange.filter { $0.wasAutoCheckedOut }.count
            let ratio = (Double(autoCount) / Double(completedInRange.count)) * 100
            autoCheckoutRateText = String(format: "%.0f%%", ratio)
        }

        var hourBuckets = Array(repeating: 0, count: 24)
        for visitor in filtered {
            let hour = calendar.component(.hour, from: visitor.checkIn)
            hourBuckets[hour] += 1
        }
        hourlyCounts = (0..<24).map { hour in
            HourCount(hour: hour, label: String(format: "%02d", hour), count: hourBuckets[hour])
        }

        topDepartments = Self.topCounts(from: filtered.map { $0.visiting }, emptyFallback: "Unspecified")
        topCompanies = Self.topCounts(from: filtered.map { $0.company }, emptyFallback: "Unspecified")

        var weekdayMap: [Int: Int] = [:]
        for visitor in filtered {
            let weekday = calendar.component(.weekday, from: visitor.checkIn)
            weekdayMap[weekday, default: 0] += 1
        }
        let orderedWeekdays = [2, 3, 4, 5, 6, 7, 1] // Mon...Sun
        let weekdayCounts: [WeekdayCount] = orderedWeekdays.map { weekday in
            let name = Self.shortWeekdaySymbols[safe: weekday - 1] ?? "Day"
            return WeekdayCount(weekday: weekday, name: name, count: weekdayMap[weekday, default: 0])
        }
        if let top = weekdayCounts.max(by: { $0.count < $1.count }), top.count > 0 {
            busiestWeekday = top
        } else {
            busiestWeekday = nil
        }

        trendPoints = Self.makeTrendPoints(filtered: filtered, now: now, calendar: calendar, range: range)
    }

    private static func topCounts(from values: [String], emptyFallback: String) -> [NamedCount] {
        var counts: [String: Int] = [:]
        for raw in values {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = trimmed.isEmpty ? emptyFallback : trimmed
            counts[key, default: 0] += 1
        }
        return counts
            .map { NamedCount(name: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.name < rhs.name }
                return lhs.count > rhs.count
            }
            .prefix(5)
            .map { $0 }
    }

    private static func makeTrendPoints(filtered: [Visitor], now: Date, calendar: Calendar, range: AnalyticsRange) -> [TrendPoint] {
        switch range {
        case .day:
            var hourBuckets = Array(repeating: 0, count: 24)
            for visitor in filtered {
                let hour = calendar.component(.hour, from: visitor.checkIn)
                hourBuckets[hour] += 1
            }
            return (0..<24).map { hour in
                TrendPoint(label: String(format: "%02d", hour), count: hourBuckets[hour])
            }

        case .week:
            let orderedWeekdays = [2, 3, 4, 5, 6, 7, 1]
            var weekdayMap: [Int: Int] = [:]
            for visitor in filtered {
                let weekday = calendar.component(.weekday, from: visitor.checkIn)
                weekdayMap[weekday, default: 0] += 1
            }
            return orderedWeekdays.map { weekday in
                let label = shortWeekdaySymbols[safe: weekday - 1] ?? "Day"
                return TrendPoint(label: label, count: weekdayMap[weekday, default: 0])
            }

        case .month:
            guard let monthInterval = calendar.dateInterval(of: .month, for: now) else { return [] }
            var dayMap: [Date: Int] = [:]
            for visitor in filtered {
                let day = calendar.startOfDay(for: visitor.checkIn)
                dayMap[day, default: 0] += 1
            }

            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "d MMM"

            var points: [TrendPoint] = []
            var current = monthInterval.start
            while current <= now {
                let label = dayFormatter.string(from: current)
                points.append(TrendPoint(label: label, count: dayMap[current, default: 0]))
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
            return points
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

#Preview {
    AnalyticsDashboardView(visitors: [
        Visitor(firstName: "Alex", lastName: "Smith", company: "ABC", visiting: "Operations", carRegistration: "AB12CDE", badgeNumber: "10", checkIn: Date(), checkOut: Date().addingTimeInterval(3600)),
        Visitor(firstName: "Jane", lastName: "Jones", company: "XYZ", visiting: "IT", carRegistration: "", badgeNumber: "11", checkIn: Date().addingTimeInterval(-7200), checkOut: Date())
    ])
    .environment(VisitorStore())
}
