import SwiftUI
import Charts

private enum AnalyticsRange: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return String(localized: "analytics.range.day")
        case .week: return String(localized: "analytics.range.week")
        case .month: return String(localized: "analytics.range.month")
        }
    }
}

private enum HeatmapMetric: String, CaseIterable, Identifiable {
    case visits
    case carVisitors
    case blockedCars
    case preRegistered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .visits:
            return "Visits"
        case .carVisitors:
            return "Car Visitors"
        case .blockedCars:
            return "Blocked Cars"
        case .preRegistered:
            return "Pre-registered"
        }
    }
}

struct AnalyticsDashboardView: View {
    let visitors: [Visitor]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRange: AnalyticsRange = .week
    @State private var anchorDate: Date = Date()
    @State private var shareItem: AnalyticsExportShareItem?
    @State private var showExportError = false
    @State private var selectedHeatmapMetric: HeatmapMetric = .visits

    private var metrics: AnalyticsMetrics {
        AnalyticsMetrics(
            visitors: visitors,
            now: Date(),
            calendar: .current,
            range: selectedRange,
            anchorDate: anchorDate
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker(String(localized: "analytics.range"), selection: $selectedRange) {
                        ForEach(AnalyticsRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)

                    DatePicker(
                        String(localized: "analytics.period_date"),
                        selection: $anchorDate,
                        in: ...Date(),
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)

                    Text(metrics.periodTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    summaryGrid

                    VStack(alignment: .leading, spacing: 8) {
                        // Metric selector buttons
                        HStack {
                            ForEach(HeatmapMetric.allCases) { metric in
                                Button(action: { selectedHeatmapMetric = metric }) {
                                    Text(metric.title)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(selectedHeatmapMetric == metric ? Color.cemexBlue.opacity(0.15) : Color(.systemGray6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8).stroke(selectedHeatmapMetric == metric ? Color.cemexBlue : Color.clear, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }

                        // Heatmap
                        let matrix = heatmapMatrix(for: selectedHeatmapMetric)
                        let totalCount = matrix.reduce(0) { $0 + $1.count }
                        if totalCount == 0 {
                            emptyState("No data for selected metric in this period")
                        } else {
                            Chart(matrix, id: \.hour) { item in
                                RectangleMark(
                                    x: .value("Hour", item.labelX),
                                    y: .value("Day", item.labelY)
                                )
                                .foregroundStyle(by: .value("Count", item.count))
                            }
                            .chartForegroundStyleScale(range: Gradient(colors: [Color(.systemGray5), Color.cemexBlue]))
                            .frame(height: 220)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(String(localized: "analytics.trend")) (\(selectedRange.title))")
                            .font(.headline)
                        if metrics.trendPoints.isEmpty {
                            emptyState(String(localized: "analytics.empty.no_data_period"))
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
                        Text(String(localized: "analytics.visitors_by_hour"))
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
                        Text(String(localized: "analytics.top_hosts_departments"))
                            .font(.headline)
                        if metrics.topDepartments.isEmpty {
                            emptyState(String(localized: "analytics.empty.no_host_data"))
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
                        Text(String(localized: "analytics.top_companies"))
                            .font(.headline)
                        if metrics.topCompanies.isEmpty {
                            emptyState(String(localized: "analytics.empty.no_company_data"))
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
                        Text(String(localized: "analytics.busiest_day"))
                            .font(.headline)
                        if let busiest = metrics.busiestWeekday {
                            HStack {
                                Text(busiest.name)
                                    .font(.title3.bold())
                                Spacer()
                                Text(String(format: String(localized: "analytics.visitor_count_format"), busiest.count))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        } else {
                            emptyState(String(localized: "analytics.empty.no_visit_records"))
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "analytics.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Export Analytics CSV") {
                            if let url = exportAnalyticsCSV() {
                                shareItem = AnalyticsExportShareItem(url: url)
                            } else {
                                showExportError = true
                            }
                        }
                        Button("Export Printable Report") {
                            if let url = exportPrintableReport() {
                                shareItem = AnalyticsExportShareItem(url: url)
                            } else {
                                showExportError = true
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(item: $shareItem) { item in
                AnalyticsExportShareSheet(url: item.url, onDismiss: {
                    try? FileManager.default.removeItem(at: item.url)
                    shareItem = nil
                })
            }
            .alert(String(localized: "analytics.alert.export_failed.title"), isPresented: $showExportError) {
                Button(String(localized: "common.ok"), role: .cancel) { }
            } message: {
                Text(String(localized: "analytics.alert.export_failed.message"))
            }
        }
    }

    private func currentPeriodInterval() -> DateInterval {
        let now = Date()
        let calendar = Calendar.current
        let referenceDate = min(anchorDate, now)
        switch selectedRange {
        case .day:
            return calendar.dateInterval(of: .day, for: referenceDate)
                ?? DateInterval(start: calendar.startOfDay(for: referenceDate), duration: 24 * 60 * 60)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: referenceDate)
                ?? DateInterval(start: calendar.startOfDay(for: referenceDate), duration: 7 * 24 * 60 * 60)
        case .month:
            return calendar.dateInterval(of: .month, for: referenceDate)
                ?? DateInterval(start: calendar.startOfDay(for: referenceDate), duration: 31 * 24 * 60 * 60)
        }
    }

    private func heatmapMatrix(for metric: HeatmapMetric) -> [(weekday: Int, hour: Int, labelX: String, labelY: String, count: Int)] {
        let calendar = Calendar.current
        let now = Date()
        let periodInterval = currentPeriodInterval()
        let endDate = min(periodInterval.end, now)
        let filteredVisitors = visitors.filter { $0.checkIn >= periodInterval.start && $0.checkIn < endDate }

        // Helper: calendar weekday (Sun=1..Sat=7) to Monday-first index (Mon=0..Sun=6)
        let mondayFirstIndex: (Int) -> Int = { rawWeekday in
            // rawWeekday: 1=Sun, 2=Mon, ... 7=Sat
            return (rawWeekday + 5) % 7 // Mon(2)->0, Tue(3)->1, ..., Sun(1)->6
        }
        // Helper: localized short weekday symbol for Monday-first index
        // DateFormatter.shortWeekdaySymbols is always Sun..Sat (0..6). We want Mon..Sun.
        let shortSymbols = DateFormatter().shortWeekdaySymbols ?? [] // Sun, Mon, Tue, Wed, Thu, Fri, Sat
        let labelForMondayIndex: (Int) -> String = { index in
            // index: 0..6 (Mon..Sun) → symbolIndex: 0..6 (Sun..Sat)
            // Monday (0) should map to Mon which is at index 1 in Sun..Sat array.
            // So symbolIndex = (index + 1) % 7
            let symbolIndex = (index + 1) % 7
            return shortSymbols[safe: symbolIndex] ?? "Day"
        }

        var counts = Array(repeating: Array(repeating: 0, count: 24), count: 7)

        for visitor in filteredVisitors {
            let hour = calendar.component(.hour, from: visitor.checkIn)
            let rawWeekday = calendar.component(.weekday, from: visitor.checkIn) // 1=Sun .. 7=Sat
            let w = mondayFirstIndex(rawWeekday) // 0..6 Mon..Sun

            switch metric {
            case .visits:
                counts[w][hour] += 1
            case .carVisitors:
                if !visitor.carRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    counts[w][hour] += 1
                }
            case .blockedCars:
                if visitor.blockedCar {
                    counts[w][hour] += 1
                }
            case .preRegistered:
                if visitor.wasPreRegistered {
                    counts[w][hour] += 1
                }
            }
        }

        var result: [(weekday: Int, hour: Int, labelX: String, labelY: String, count: Int)] = []
        for w in 0..<7 { // Monday-first order: 0 = Monday, ..., 6 = Sunday
            let labelY = labelForMondayIndex(w)
            for hour in 0..<24 {
                let c = counts[w][hour]
                let labelX = String(format: "%02d", hour)
                // Use weekday = w+1 for id consistency (Monday=1..Sunday=7)
                result.append((weekday: w + 1, hour: hour, labelX: labelX, labelY: labelY, count: c))
            }
        }
        return result
    }

    private var summaryGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            summaryCard(String(localized: "analytics.card.visits"), value: "\(metrics.totalInRange)", symbol: "person.2")
            summaryCard(String(localized: "analytics.card.unique_visitors"), value: "\(metrics.uniqueVisitors)", symbol: "person.crop.circle.badge.checkmark")
            summaryCard(String(localized: "analytics.card.avg_visit"), value: metrics.averageDurationText, symbol: "clock")
            summaryCard(String(localized: "analytics.card.active_now"), value: "\(metrics.activeNow)", symbol: "person.crop.circle.badge.exclamationmark")
            summaryCard(String(localized: "analytics.card.repeat_visitors"), value: "\(metrics.repeatVisitors)", symbol: "arrow.triangle.2.circlepath")
            summaryCard(String(localized: "analytics.card.auto_checkout"), value: metrics.autoCheckoutRateText, symbol: "moon.zzz")
            summaryCard(String(localized: "analytics.card.pre_registered"), value: metrics.preRegisteredRateText, symbol: "person.text.rectangle")
            summaryCard(String(localized: "analytics.card.car_visitors"), value: metrics.carVisitorRateText, symbol: "car.fill")
            summaryCard(String(localized: "analytics.card.blocked_car"), value: metrics.blockedCarRateText, symbol: "car.2.fill")
            summaryCard(String(localized: "analytics.card.same_day_checkout"), value: metrics.sameDayCheckoutRateText, symbol: "calendar.badge.checkmark")
            summaryCard(String(localized: "analytics.card.median_visit"), value: metrics.medianDurationText, symbol: "clock.badge.checkmark")
            summaryCard(String(localized: "analytics.card.avg_visits_per_day"), value: metrics.averageVisitsPerDayText, symbol: "chart.bar.doc.horizontal")
            summaryCard(String(localized: "analytics.card.peak_hour"), value: metrics.peakHourText, symbol: "sun.max")
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

    private func exportAnalyticsCSV() -> URL? {
        let rows: [[String]] = [
            ["Metric", "Value"],
            ["Range", selectedRange.title],
            ["Period", metrics.periodTitle],
            ["Visits", "\(metrics.totalInRange)"],
            ["Unique Visitors", "\(metrics.uniqueVisitors)"],
            ["Repeat Visitors", "\(metrics.repeatVisitors)"],
            ["Active Now", "\(metrics.activeNow)"],
            ["Average Visit", metrics.averageDurationText],
            ["Median Visit", metrics.medianDurationText],
            ["Auto Checkout Rate", metrics.autoCheckoutRateText],
            ["Pre-registered Rate", metrics.preRegisteredRateText],
            ["Car Visitor Rate", metrics.carVisitorRateText],
            ["Blocked Car Rate", metrics.blockedCarRateText],
            ["Same-day Checkout Rate", metrics.sameDayCheckoutRateText],
            ["Avg Visits / Day", metrics.averageVisitsPerDayText],
            ["Peak Hour", metrics.peakHourText]
        ]
        let csv = rows.map { $0.map(\.escapedAsCSVField).joined(separator: ",") }.joined(separator: "\n")
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("analytics_\(Int(Date().timeIntervalSince1970)).csv")
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private func exportPrintableReport() -> URL? {
        let html = """
        <html><head><meta charset="utf-8"><title>Analytics Report</title></head><body style="font-family:-apple-system,Helvetica,Arial;padding:24px;">
        <h1>Visitor Analytics Report</h1>
        <p><strong>Range:</strong> \(selectedRange.title)</p>
        <p><strong>Period:</strong> \(metrics.periodTitle)</p>
        <table border="1" cellspacing="0" cellpadding="8" style="border-collapse:collapse;">
        <tr><th align="left">Metric</th><th align="left">Value</th></tr>
        <tr><td>Visits</td><td>\(metrics.totalInRange)</td></tr>
        <tr><td>Unique Visitors</td><td>\(metrics.uniqueVisitors)</td></tr>
        <tr><td>Repeat Visitors</td><td>\(metrics.repeatVisitors)</td></tr>
        <tr><td>Active Now</td><td>\(metrics.activeNow)</td></tr>
        <tr><td>Average Visit</td><td>\(metrics.averageDurationText)</td></tr>
        <tr><td>Median Visit</td><td>\(metrics.medianDurationText)</td></tr>
        <tr><td>Auto Checkout Rate</td><td>\(metrics.autoCheckoutRateText)</td></tr>
        <tr><td>Pre-registered Rate</td><td>\(metrics.preRegisteredRateText)</td></tr>
        <tr><td>Car Visitor Rate</td><td>\(metrics.carVisitorRateText)</td></tr>
        <tr><td>Blocked Car Rate</td><td>\(metrics.blockedCarRateText)</td></tr>
        <tr><td>Same-day Checkout Rate</td><td>\(metrics.sameDayCheckoutRateText)</td></tr>
        <tr><td>Avg Visits / Day</td><td>\(metrics.averageVisitsPerDayText)</td></tr>
        <tr><td>Peak Hour</td><td>\(metrics.peakHourText)</td></tr>
        </table>
        </body></html>
        """
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("analytics_report_\(Int(Date().timeIntervalSince1970)).html")
            try html.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}

private struct AnalyticsExportShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct AnalyticsExportShareSheet: View, Identifiable {
    let url: URL
    var id: URL { url }
    var onDismiss: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var didRunDismiss = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(String(localized: "analytics.export.ready"))
                ShareLink(item: url) {
                    Label(String(localized: "analytics.export.share"), systemImage: "square.and.arrow.up")
                }
            }
            .padding()
            .navigationTitle(String(localized: "analytics.export.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.done")) {
                        runDismissIfNeeded()
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            runDismissIfNeeded()
        }
    }

    private func runDismissIfNeeded() {
        guard !didRunDismiss else { return }
        didRunDismiss = true
        onDismiss?()
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
    let preRegisteredRateText: String
    let carVisitorRateText: String
    let blockedCarRateText: String
    let sameDayCheckoutRateText: String
    let averageVisitsPerDayText: String
    let peakHourText: String
    let medianVisitDuration: TimeInterval?
    let hourlyCounts: [HourCount]
    let trendPoints: [TrendPoint]
    let topDepartments: [NamedCount]
    let topCompanies: [NamedCount]
    let busiestWeekday: WeekdayCount?
    let periodTitle: String

    private static let shortWeekdaySymbols: [String] = {
        DateFormatter().shortWeekdaySymbols ?? []
    }()

    var averageDurationText: String {
        guard let averageVisitDuration else { return "N/A" }
        return Self.durationText(from: averageVisitDuration)
    }

    var medianDurationText: String {
        guard let medianVisitDuration else { return "N/A" }
        return Self.durationText(from: medianVisitDuration)
    }

    private static func durationText(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let hoursPart = minutes / 60
        let minutePart = minutes % 60
        if hoursPart > 0 {
            return "\(hoursPart)h \(minutePart)m"
        }
        return "\(minutePart)m"
    }

    init(visitors: [Visitor], now: Date, calendar: Calendar, range: AnalyticsRange, anchorDate: Date) {
        let referenceDate = min(anchorDate, now)
        let periodInterval: DateInterval
        switch range {
        case .day:
            periodInterval = calendar.dateInterval(of: .day, for: referenceDate)
                ?? DateInterval(start: calendar.startOfDay(for: referenceDate), duration: 24 * 60 * 60)
        case .week:
            periodInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate)
                ?? DateInterval(start: calendar.startOfDay(for: referenceDate), duration: 7 * 24 * 60 * 60)
        case .month:
            periodInterval = calendar.dateInterval(of: .month, for: referenceDate)
                ?? DateInterval(start: calendar.startOfDay(for: referenceDate), duration: 31 * 24 * 60 * 60)
        }

        let endDate = min(periodInterval.end, now)
        let filtered = visitors.filter { $0.checkIn >= periodInterval.start && $0.checkIn < endDate }

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
            let sorted = completedDurations.sorted()
            let mid = sorted.count / 2
            if sorted.count % 2 == 0 {
                medianVisitDuration = (sorted[mid - 1] + sorted[mid]) / 2
            } else {
                medianVisitDuration = sorted[mid]
            }
        } else {
            averageVisitDuration = nil
            medianVisitDuration = nil
        }

        let completedInRange = filtered.filter { $0.checkOut != nil }
        if completedInRange.isEmpty {
            autoCheckoutRateText = "N/A"
        } else {
            let autoCount = completedInRange.filter { $0.wasAutoCheckedOut }.count
            let ratio = (Double(autoCount) / Double(completedInRange.count)) * 100
            autoCheckoutRateText = String(format: "%.0f%%", ratio)
        }

        if filtered.isEmpty {
            preRegisteredRateText = "N/A"
            carVisitorRateText = "N/A"
            blockedCarRateText = "N/A"
            sameDayCheckoutRateText = "N/A"
            averageVisitsPerDayText = "N/A"
            peakHourText = "N/A"
        } else {
            let preRegisteredCount = filtered.filter { $0.wasPreRegistered }.count
            let ratio = (Double(preRegisteredCount) / Double(filtered.count)) * 100
            preRegisteredRateText = "\(preRegisteredCount) (\(String(format: "%.0f%%", ratio)))"

            let carVisitors = filtered.filter { !$0.carRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
            carVisitorRateText = "\(carVisitors) (\(String(format: "%.0f%%", (Double(carVisitors) / Double(filtered.count)) * 100)))"

            let blockedCount = filtered.filter { $0.blockedCar }.count
            blockedCarRateText = "\(blockedCount) (\(String(format: "%.0f%%", (Double(blockedCount) / Double(filtered.count)) * 100)))"

            let sameDayCount = filtered.filter {
                guard let out = $0.checkOut else { return false }
                return calendar.isDate($0.checkIn, inSameDayAs: out)
            }.count
            sameDayCheckoutRateText = "\(sameDayCount) (\(String(format: "%.0f%%", (Double(sameDayCount) / Double(filtered.count)) * 100)))"

            let dayCount: Int
            switch range {
            case .day: dayCount = 1
            case .week: dayCount = 7
            case .month:
                dayCount = max(1, calendar.dateComponents([.day], from: periodInterval.start, to: endDate).day ?? 1)
            }
            averageVisitsPerDayText = String(format: "%.1f", Double(filtered.count) / Double(dayCount))

            var hourBuckets = Array(repeating: 0, count: 24)
            for visitor in filtered {
                hourBuckets[calendar.component(.hour, from: visitor.checkIn)] += 1
            }
            if let maxCount = hourBuckets.max(), let peakHour = hourBuckets.firstIndex(of: maxCount), maxCount > 0 {
                peakHourText = String(format: "%02d:00 (%d)", peakHour, maxCount)
            } else {
                peakHourText = "N/A"
            }
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

        trendPoints = Self.makeTrendPoints(
            filtered: filtered,
            endDate: endDate,
            calendar: calendar,
            range: range,
            intervalStart: periodInterval.start
        )

        let periodFormatter = DateFormatter()
        periodFormatter.dateStyle = .medium
        periodFormatter.timeStyle = .none
        let startText = periodFormatter.string(from: periodInterval.start)
        let endText = periodFormatter.string(from: endDate)
        periodTitle = "\(startText) - \(endText)"
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

    private static func makeTrendPoints(
        filtered: [Visitor],
        endDate: Date,
        calendar: Calendar,
        range: AnalyticsRange,
        intervalStart: Date
    ) -> [TrendPoint] {
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
                // shortWeekdaySymbols is Sun..Sat; weekday is 1..7 (Sun=1..Sat=7)
                // We want Monday-first labels, so compute Monday-first index and then offset by +1.
                let mondayFirstIndex = (weekday + 5) % 7 // Mon=0..Sun=6
                let symbolIndex = (mondayFirstIndex + 1) % 7 // Sun..Sat index
                let label = shortWeekdaySymbols[safe: symbolIndex] ?? "Day"
                return TrendPoint(label: label, count: weekdayMap[weekday, default: 0])
            }

        case .month:
            var dayMap: [Date: Int] = [:]
            for visitor in filtered {
                let day = calendar.startOfDay(for: visitor.checkIn)
                dayMap[day, default: 0] += 1
            }

            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "d MMM"

            var points: [TrendPoint] = []
            var current = intervalStart
            while current <= endDate {
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
