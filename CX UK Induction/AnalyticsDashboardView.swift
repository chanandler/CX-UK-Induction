import SwiftUI
import Charts

struct AnalyticsDashboardView: View {
    let visitors: [Visitor]
    @Environment(\.dismiss) private var dismiss

    private var metrics: AnalyticsMetrics {
        AnalyticsMetrics(visitors: visitors, now: Date(), calendar: .current)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryGrid

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
                        Text("Top Departments")
                            .font(.headline)
                        if metrics.topDepartments.isEmpty {
                            emptyState("No department data yet")
                        } else {
                            Chart(metrics.topDepartments) { item in
                                BarMark(
                                    x: .value("Department", item.department),
                                    y: .value("Visits", item.count)
                                )
                                .foregroundStyle(.orange.gradient)
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
            summaryCard("Today", value: "\(metrics.totalToday)", symbol: "calendar")
            summaryCard("This Week", value: "\(metrics.totalThisWeek)", symbol: "calendar.badge.clock")
            summaryCard("This Month", value: "\(metrics.totalThisMonth)", symbol: "calendar.circle")
            summaryCard("Avg Visit", value: metrics.averageDurationText, symbol: "clock")
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

    struct DepartmentCount: Identifiable {
        let department: String
        let count: Int
        var id: String { department }
    }

    struct WeekdayCount: Identifiable {
        let weekday: Int
        let name: String
        let count: Int
        var id: Int { weekday }
    }

    let totalToday: Int
    let totalThisWeek: Int
    let totalThisMonth: Int
    let averageVisitDuration: TimeInterval?
    let hourlyCounts: [HourCount]
    let topDepartments: [DepartmentCount]
    let busiestWeekday: WeekdayCount?

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

    init(visitors: [Visitor], now: Date, calendar: Calendar) {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday

        totalToday = visitors.filter { $0.checkIn >= startOfToday }.count
        totalThisWeek = visitors.filter { $0.checkIn >= startOfWeek }.count
        totalThisMonth = visitors.filter { $0.checkIn >= startOfMonth }.count

        let completedDurations = visitors.compactMap { visitor -> TimeInterval? in
            guard let checkOut = visitor.checkOut else { return nil }
            let duration = checkOut.timeIntervalSince(visitor.checkIn)
            return duration >= 0 ? duration : nil
        }
        if !completedDurations.isEmpty {
            averageVisitDuration = completedDurations.reduce(0, +) / Double(completedDurations.count)
        } else {
            averageVisitDuration = nil
        }

        var hourBuckets = Array(repeating: 0, count: 24)
        for visitor in visitors {
            let hour = calendar.component(.hour, from: visitor.checkIn)
            hourBuckets[hour] += 1
        }
        hourlyCounts = (0..<24).map { hour in
            HourCount(hour: hour, label: String(format: "%02d", hour), count: hourBuckets[hour])
        }

        var departmentMap: [String: Int] = [:]
        for visitor in visitors {
            let raw = visitor.visiting.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = raw.isEmpty ? "Unspecified" : raw
            departmentMap[key, default: 0] += 1
        }
        topDepartments = departmentMap
            .map { DepartmentCount(department: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.department < rhs.department }
                return lhs.count > rhs.count
            }
            .prefix(5)
            .map { $0 }

        let shortSymbols = DateFormatter().shortWeekdaySymbols ?? []
        var weekdayMap: [Int: Int] = [:]
        for visitor in visitors {
            let weekday = calendar.component(.weekday, from: visitor.checkIn)
            weekdayMap[weekday, default: 0] += 1
        }

        let orderedWeekdays = [2, 3, 4, 5, 6, 7, 1] // Mon...Sun
        let weekdayCounts: [WeekdayCount] = orderedWeekdays.map { weekday in
            let name = shortSymbols[safe: weekday - 1] ?? "Day"
            return WeekdayCount(weekday: weekday, name: name, count: weekdayMap[weekday, default: 0])
        }
        if let top = weekdayCounts.max(by: { $0.count < $1.count }), top.count > 0 {
            busiestWeekday = top
        } else {
            busiestWeekday = nil
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
