import Foundation
import Observation
import SwiftData

@Model
final class Visitor: Identifiable, Hashable {
    @Attribute(.unique) var id: UUID
    var firstName: String
    var lastName: String
    var company: String
    var visiting: String
    var carRegistration: String
    var blockedCar: Bool
    var pagerNumber: String?
    var badgeNumber: String
    var checkIn: Date
    var checkOut: Date?
    var wasAutoCheckedOut: Bool
    var wasPreRegistered: Bool = false

    init(id: UUID = UUID(), firstName: String, lastName: String, company: String, visiting: String, carRegistration: String, blockedCar: Bool = false, pagerNumber: String? = nil, badgeNumber: String = "", checkIn: Date = Date(), checkOut: Date? = nil, wasAutoCheckedOut: Bool = false, wasPreRegistered: Bool = false) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.company = company
        self.visiting = visiting
        self.carRegistration = carRegistration
        self.blockedCar = blockedCar
        self.pagerNumber = pagerNumber
        self.badgeNumber = badgeNumber
        self.checkIn = checkIn
        self.checkOut = checkOut
        self.wasAutoCheckedOut = wasAutoCheckedOut
        self.wasPreRegistered = wasPreRegistered
    }

    var isActive: Bool { checkOut == nil }
    var fullName: String { firstName + " " + lastName }

    static func == (lhs: Visitor, rhs: Visitor) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Model
final class PreRegisteredVisitor: Identifiable {
    @Attribute(.unique) var id: UUID
    var firstName: String
    var lastName: String
    var company: String
    var visiting: String
    var carRegistration: String
    var blockedCar: Bool
    var pagerNumber: String?
    var badgeNumber: String
    var createdAt: Date
    var visitDate: Date?

    init(
        id: UUID = UUID(),
        firstName: String,
        lastName: String,
        company: String,
        visiting: String,
        carRegistration: String = "",
        blockedCar: Bool = false,
        pagerNumber: String? = nil,
        badgeNumber: String = "",
        createdAt: Date = Date(),
        visitDate: Date? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.company = company
        self.visiting = visiting
        self.carRegistration = carRegistration
        self.blockedCar = blockedCar
        self.pagerNumber = pagerNumber
        self.badgeNumber = badgeNumber
        self.createdAt = createdAt
        self.visitDate = visitDate
    }

    var fullName: String { firstName + " " + lastName }
}

@Model
final class StaffPagerIssue: Identifiable {
    @Attribute(.unique) var id: UUID
    var firstName: String
    var lastName: String
    var carRegistration: String
    var pagerNumber: String
    var issuedAt: Date
    var returnedAt: Date?

    init(
        id: UUID = UUID(),
        firstName: String,
        lastName: String,
        carRegistration: String,
        pagerNumber: String,
        issuedAt: Date = Date(),
        returnedAt: Date? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.carRegistration = carRegistration
        self.pagerNumber = pagerNumber
        self.issuedAt = issuedAt
        self.returnedAt = returnedAt
    }

    var fullName: String { firstName + " " + lastName }
    var isActive: Bool { returnedAt == nil }
}

// MARK: - Structured error type

enum StoreError: LocalizedError {
    case validationFailed(String)
    case saveFailed(underlying: Error)
    case fetchFailed(underlying: Error)
    case importAccessDenied
    case importUnreadable
    case importEmpty
    case importMissingColumns
    case importMessage(String)

    var errorDescription: String? {
        switch self {
        case .validationFailed(let msg):
            return msg
        case .saveFailed(let e):
            return String(localized: "store.error.save_failed_prefix") + e.localizedDescription
        case .fetchFailed(let e):
            return String(localized: "store.error.fetch_failed_prefix") + e.localizedDescription
        case .importAccessDenied:
            return String(localized: "store.error.import_access_denied")
        case .importUnreadable:
            return String(localized: "store.error.import_unreadable")
        case .importEmpty:
            return String(localized: "store.error.import_empty")
        case .importMissingColumns:
            return String(localized: "store.error.import_missing_columns")
        case .importMessage(let msg):
            return msg
        }
    }
}

extension StoreError: Equatable {
    static func == (lhs: StoreError, rhs: StoreError) -> Bool {
        switch (lhs, rhs) {
        case (.validationFailed(let a), .validationFailed(let b)): return a == b
        case (.saveFailed(let a), .saveFailed(let b)): return a.localizedDescription == b.localizedDescription
        case (.fetchFailed(let a), .fetchFailed(let b)): return a.localizedDescription == b.localizedDescription
        case (.importAccessDenied, .importAccessDenied): return true
        case (.importUnreadable, .importUnreadable): return true
        case (.importEmpty, .importEmpty): return true
        case (.importMissingColumns, .importMissingColumns): return true
        case (.importMessage(let a), .importMessage(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - VisitorStore

@Observable
final class VisitorStore {
    var lastError: StoreError?

    // Derived state for sorting/searching; SwiftData is the source of truth.
    func signIn(_ context: ModelContext, firstName: String, lastName: String, company: String, visiting: String, carRegistration: String, blockedCar: Bool = false, pagerNumber: String? = nil, badgeNumber: String = "", wasPreRegistered: Bool = false, at date: Date = Date()) {
        lastError = nil
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCompany = company.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedVisiting = visiting.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPager = pagerNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBadge = badgeNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        // Guard against blank-after-trim values slipping through
        guard !trimmedFirst.isEmpty, !trimmedLast.isEmpty,
              !trimmedCompany.isEmpty, !trimmedVisiting.isEmpty else {
            lastError = .validationFailed(String(localized: "store.error.signin_required_fields"))
            return
        }

        let v = Visitor(firstName: trimmedFirst,
                        lastName: trimmedLast,
                        company: trimmedCompany,
                        visiting: trimmedVisiting,
                        carRegistration: carRegistration.trimmingCharacters(in: .whitespacesAndNewlines),
                        blockedCar: blockedCar,
                        pagerNumber: trimmedPager?.isEmpty == true ? nil : trimmedPager,
                        badgeNumber: trimmedBadge,
                        checkIn: date,
                        checkOut: nil,
                        wasAutoCheckedOut: false,
                        wasPreRegistered: wasPreRegistered)
        context.insert(v)
        do {
            try context.save()
        } catch {
            context.rollback()
            lastError = .saveFailed(underlying: error)
            print("SwiftData save error (signIn):", error)
        }
    }

    func checkOut(_ context: ModelContext, _ visitor: Visitor, at date: Date = Date()) {
        lastError = nil
        visitor.checkOut = date
        do {
            try context.save()
        } catch {
            context.rollback()
            lastError = .saveFailed(underlying: error)
            print("SwiftData save error (checkOut):", error)
        }
    }

    func deleteArchived(_ context: ModelContext, at offsets: IndexSet, from visitors: [Visitor]) {
        lastError = nil
        for index in offsets {
            context.delete(visitors[index])
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            lastError = .saveFailed(underlying: error)
            print("SwiftData save error (deleteArchived):", error)
        }
    }

    func issueStaffPager(_ context: ModelContext, firstName: String, lastName: String, carRegistration: String, pagerNumber: String, at date: Date = Date()) {
        lastError = nil
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCarRegistration = carRegistration.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let trimmedPager = pagerNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedFirst.isEmpty,
              !trimmedLast.isEmpty,
              !trimmedCarRegistration.isEmpty,
              !trimmedPager.isEmpty else {
            lastError = .validationFailed("First name, last name, car registration and pager number are required.")
            return
        }

        let issue = StaffPagerIssue(
            firstName: trimmedFirst,
            lastName: trimmedLast,
            carRegistration: trimmedCarRegistration,
            pagerNumber: trimmedPager,
            issuedAt: date
        )
        context.insert(issue)
        do {
            try context.save()
        } catch {
            context.rollback()
            lastError = .saveFailed(underlying: error)
            print("SwiftData save error (issueStaffPager):", error)
        }
    }

    func returnStaffPager(_ context: ModelContext, _ issue: StaffPagerIssue, at date: Date = Date()) {
        lastError = nil
        issue.returnedAt = date
        do {
            try context.save()
        } catch {
            context.rollback()
            lastError = .saveFailed(underlying: error)
            print("SwiftData save error (returnStaffPager):", error)
        }
    }

    func addPreRegisteredVisitor(_ context: ModelContext, firstName: String, lastName: String, company: String, visiting: String, badgeNumber: String, carRegistration: String = "", visitDate: Date? = nil) {
        lastError = nil
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCompany = company.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedVisiting = visiting.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBadge = badgeNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCarRegistration = carRegistration.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard !trimmedFirst.isEmpty,
              !trimmedLast.isEmpty,
              !trimmedCompany.isEmpty,
              !trimmedVisiting.isEmpty else {
            lastError = .validationFailed("First name, last name, company and visiting are required.")
            return
        }

        // Prevent duplicate badge allocation for the same visit date
        if let visitDate = visitDate {
            let normalizedBadge = trimmedBadge.lowercased()
            if !normalizedBadge.isEmpty {
                do {
                    let all = try context.fetch(FetchDescriptor<PreRegisteredVisitor>())
                    let conflict = all.contains { p in
                        let candidateDate = p.visitDate ?? p.createdAt
                        let pBadge = p.badgeNumber.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        return Calendar.current.isDate(candidateDate, inSameDayAs: visitDate) && pBadge == normalizedBadge
                    }
                    if conflict {
                        lastError = .validationFailed("That badge is already allocated for the selected visit date. Please choose a different badge number.")
                        return
                    }
                } catch {
                    lastError = .fetchFailed(underlying: error)
                    return
                }
                // Also prevent conflicts with active visitors for the same day
                do {
                    // Fetch active visitors (no checkOut date)
                    let active = try context.fetch(FetchDescriptor<Visitor>(predicate: #Predicate { $0.checkOut == nil }))
                    let conflictWithActive = active.contains { v in
                        let vBadge = v.badgeNumber.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        return vBadge == normalizedBadge && Calendar.current.isDate(v.checkIn, inSameDayAs: visitDate)
                    }
                    if conflictWithActive {
                        lastError = .validationFailed("That badge is already allocated for the selected visit date. Please choose a different badge number.")
                        return
                    }
                } catch {
                    lastError = .fetchFailed(underlying: error)
                    return
                }
            }
        }

        let visitor = PreRegisteredVisitor(
            firstName: trimmedFirst,
            lastName: trimmedLast,
            company: trimmedCompany,
            visiting: trimmedVisiting,
            carRegistration: trimmedCarRegistration,
            badgeNumber: trimmedBadge,
            visitDate: visitDate
        )
        context.insert(visitor)
        do {
            try context.save()
        } catch {
            context.rollback()
            lastError = .saveFailed(underlying: error)
            print("SwiftData save error (addPreRegisteredVisitor):", error)
        }
    }

    func deletePreRegisteredVisitor(_ context: ModelContext, _ visitor: PreRegisteredVisitor) {
        lastError = nil
        context.delete(visitor)
        do {
            try context.save()
        } catch {
            context.rollback()
            lastError = .saveFailed(underlying: error)
            print("SwiftData save error (deletePreRegisteredVisitor):", error)
        }
    }

    // MARK: - Backup export

    /// Builds the canonical 12-column backup CSV string for all visitors (includes Pre-Registered).
    func backupCSVString(from visitors: [Visitor]) -> String {
        var rows: [String] = [
            ["First Name","Last Name","Company","Visiting","Car Registration",
             "Blocked Car","Pager Number","Badge Number",
             "Date Signed In","Date Signed Out","Auto Logged Out","Pre-Registered"]
                .map(\.escapedAsCSVField)
                .joined(separator: ",")
        ]
        for v in visitors {
            let row: [String] = [
                v.firstName,
                v.lastName,
                v.company,
                v.visiting,
                v.carRegistration,
                v.blockedCar ? "Yes" : "No",
                v.pagerNumber ?? "",
                v.badgeNumber,
                DateFormatter.csvDateTime.string(from: v.checkIn),
                v.checkOut.map { DateFormatter.csvDateTime.string(from: $0) } ?? "",
                v.wasAutoCheckedOut ? "Yes" : "No",
                v.wasPreRegistered ? "Yes" : "No"
            ]
            rows.append(row.map(\.escapedAsCSVField).joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    // MARK: - CSV import

    /// Summarises the result of a CSV import operation.
    struct ImportSummary {
        let imported: Int
        let skipped: Int   // duplicates
        let failed: Int    // rows that couldn't be parsed
    }

    /// Parses a CSV file at `url` and inserts missing visitor records into `context`.
    /// Matches on firstName + lastName + checkIn to detect duplicates.
    /// Returns an `ImportSummary` — call `context.save()` to commit if desired.
    func previewImport(from url: URL, context: ModelContext) -> (summary: ImportSummary, pending: [Visitor]) {
        lastError = nil
        guard url.startAccessingSecurityScopedResource() else {
            lastError = .importAccessDenied
            return (ImportSummary(imported: 0, skipped: 0, failed: 0), [])
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
            lastError = .importUnreadable
            return (ImportSummary(imported: 0, skipped: 0, failed: 0), [])
        }

        // Parse records with quote-awareness so embedded newlines inside quoted
        // fields are preserved as part of a single CSV row.
        let records = parseCSVRecords(raw)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard records.count >= 2 else {
            lastError = .importEmpty
            return (ImportSummary(imported: 0, skipped: 0, failed: 0), [])
        }

        // Parse header row to build column-name → index map.
        let headers = parseCSVLine(records[0]).enumerated().map { index, value in
            var header = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if index == 0 {
                // Some CSV tools prepend UTF-8 BOM to the first header cell.
                header = stripUTF8BOM(from: header)
            }
            return header
        }
        func col(_ name: String) -> Int? { headers.firstIndex(of: name) }

        // Require at minimum the four identity columns.
        guard let iFirst = col("First Name"), let iLast = col("Last Name"),
              let iCheckIn = col("Date Signed In") ?? col("Check In") else {
            lastError = .importMissingColumns
            return (ImportSummary(imported: 0, skipped: 0, failed: 0), [])
        }

        // Optional columns resolved once to avoid repeated header scans per row.
        let iCompany = col("Company")
        let iVisiting = col("Visiting")
        let iCarRegistration = col("Car Registration")
        let iBlockedCar = col("Blocked Car")
        let iPagerNumber = col("Pager Number")
        let iBadgeNumber = col("Badge Number")
        let iCheckOut = col("Date Signed Out") ?? col("Check Out")
        let iAutoLoggedOut = col("Auto Logged Out")
        let iPreRegistered = col("Pre-Registered")

        // Note: duplicate key uses minute-precision timestamps to avoid precision mismatches.
        // Build a set of existing records for duplicate detection.
        let existingKey: Set<String>
        do {
            let all = try context.fetch(FetchDescriptor<Visitor>())
            existingKey = Set(all.map { dupKey($0.firstName, $0.lastName, $0.checkIn) })
        } catch {
            lastError = .importMessage(String(localized: "store.error.import_read_existing_failed"))
            return (ImportSummary(imported: 0, skipped: 0, failed: 0), [])
        }

        // Track keys seen during this import pass so duplicates inside the same CSV
        // are skipped (not just duplicates already persisted in the database).
        var seenKeys = existingKey

        var pending: [Visitor] = []
        var skipped = 0
        var failed = 0

        for record in records.dropFirst() {
            let fields = parseCSVLine(record)
            func field(_ idx: Int?) -> String {
                guard let i = idx, i < fields.count else { return "" }
                return fields[i].trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let firstName = field(iFirst)
            let lastName = field(iLast)
            let checkInStr = field(iCheckIn)

            guard !firstName.isEmpty, !lastName.isEmpty, !checkInStr.isEmpty else {
                failed += 1
                continue
            }

            guard let checkIn = DateFormatter.csvDateTime.date(from: checkInStr)
                              ?? DateFormatter.csvDateTimeAlt.date(from: checkInStr) else {
                failed += 1
                continue
            }

            // Duplicate check against both existing records and rows already parsed
            // in this same file.
            let key = dupKey(firstName, lastName, checkIn)
            if seenKeys.contains(key) {
                skipped += 1
                continue
            }

            // Optional / potentially missing columns get safe defaults.
            let company         = field(iCompany)
            let visiting        = field(iVisiting)
            let carReg          = field(iCarRegistration)
            let blockedCarStr   = field(iBlockedCar).lowercased()
            let blockedCar      = blockedCarStr == "yes" || blockedCarStr == "true" || blockedCarStr == "1"
            let pagerRaw        = field(iPagerNumber)
            let pagerNumber: String? = pagerRaw.isEmpty ? nil : pagerRaw
            let badgeNumber     = field(iBadgeNumber)
            let checkOutStr     = field(iCheckOut)
            let checkOut: Date? = checkOutStr.isEmpty ? nil
                : DateFormatter.csvDateTime.date(from: checkOutStr)
                  ?? DateFormatter.csvDateTimeAlt.date(from: checkOutStr)
            let autoStr         = field(iAutoLoggedOut).lowercased()
            let wasAuto         = autoStr == "yes" || autoStr == "true" || autoStr == "1"
            let preRegStr       = field(iPreRegistered).lowercased()
            let wasPreReg       = preRegStr == "yes" || preRegStr == "true" || preRegStr == "1"

            let visitor = Visitor(
                firstName: firstName,
                lastName: lastName,
                company: company,
                visiting: visiting,
                carRegistration: carReg,
                blockedCar: blockedCar,
                pagerNumber: pagerNumber,
                badgeNumber: badgeNumber,
                checkIn: checkIn,
                checkOut: checkOut,
                wasAutoCheckedOut: wasAuto,
                wasPreRegistered: wasPreReg
            )
            pending.append(visitor)
            seenKeys.insert(key)
        }

        return (ImportSummary(imported: pending.count, skipped: skipped, failed: failed), pending)
    }

    /// Commits the pending visitors from `previewImport` into `context` and saves.
    @discardableResult
    func commitImport(_ context: ModelContext, pending: [Visitor]) -> Bool {
        lastError = nil
        for v in pending { context.insert(v) }
        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            lastError = .saveFailed(underlying: error)
            print("SwiftData save error (commitImport):", error)
            return false
        }
    }

    // MARK: - Private CSV helpers

    private func stripUTF8BOM(from value: String) -> String {
        var result = value
        if result.hasPrefix("\u{FEFF}") {
            result.removeFirst()
        }
        return result
    }

    /// Splits raw CSV text into logical records while respecting quoted fields
    /// that may contain embedded newline characters.
    private func parseCSVRecords(_ raw: String) -> [String] {
        var records: [String] = []
        var current = ""
        var inQuotes = false
        var idx = raw.startIndex

        while idx < raw.endIndex {
            let ch = raw[idx]

            if ch == "\"" {
                if inQuotes {
                    let next = raw.index(after: idx)
                    if next < raw.endIndex, raw[next] == "\"" {
                        // Escaped quote ("") inside a quoted field.
                        current.append(ch)
                        current.append(raw[next])
                        idx = raw.index(after: next)
                        continue
                    }
                    inQuotes = false
                    current.append(ch)
                } else {
                    inQuotes = true
                    current.append(ch)
                }
            } else if (ch == "\n" || ch == "\r"), !inQuotes {
                if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    records.append(current)
                }
                current = ""

                // Consume CRLF as a single newline separator.
                if ch == "\r" {
                    let next = raw.index(after: idx)
                    if next < raw.endIndex, raw[next] == "\n" {
                        idx = next
                    }
                }
            } else {
                current.append(ch)
            }

            idx = raw.index(after: idx)
        }

        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            records.append(current)
        }

        return records
    }

    /// Normalize duplicate key to minute precision to avoid mismatches
    private func dupKey(_ first: String, _ last: String, _ date: Date) -> String {
        // Normalize to minute precision so CSV-rounded times and persisted times
        // (which may include seconds/subseconds) map to the same logical key.
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        // Force unwrap is safe here because the provided components are sufficient to form a date.
        let minute = cal.date(from: comps) ?? date
        let stamp = minute.timeIntervalSinceReferenceDate
        return "\(first.lowercased())|\(last.lowercased())|\(stamp)"
    }

    /// A minimal quote-aware CSV line parser that handles double-quoted fields
    /// (including escaped internal quotes "" and embedded newlines).
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var idx = line.startIndex

        while idx < line.endIndex {
            let ch = line[idx]
            if inQuotes {
                if ch == "\"" {
                    let next = line.index(after: idx)
                    if next < line.endIndex && line[next] == "\"" {
                        // Escaped quote ""
                        current.append("\"")
                        idx = line.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(ch)
                }
            } else {
                if ch == "\"" {
                    inQuotes = true
                } else if ch == "," {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(ch)
                }
            }
            idx = line.index(after: idx)
        }
        fields.append(current)
        return fields
    }

    // MARK: - Auto-checkout

    /// Checks out all visitors who signed in before today and have not yet signed out.
    /// Returns the number of visitors that were checked out.
    @discardableResult
    func autoCheckoutPreviousDay(_ context: ModelContext, at checkoutTime: Date = Date()) -> Int {
        lastError = nil
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: checkoutTime)
        let descriptor = FetchDescriptor<Visitor>(
            predicate: #Predicate { $0.checkOut == nil && $0.checkIn < startOfToday }
        )
        do {
            let results = try context.fetch(descriptor)
            if results.isEmpty { return 0 }
            for v in results {
                v.checkOut = checkoutTime
                v.wasAutoCheckedOut = true
            }
            try context.save()
            return results.count
        } catch {
            context.rollback()
            lastError = .fetchFailed(underlying: error)
            print("SwiftData fetch/save error (autoCheckout):", error)
            return 0
        }
    }

    /// Checks out all currently active visitors.
    /// Returns the number of visitors that were checked out.
    @discardableResult
    func autoCheckoutAllActive(_ context: ModelContext, at checkoutTime: Date = Date()) -> Int {
        lastError = nil
        let descriptor = FetchDescriptor<Visitor>(
            predicate: #Predicate { $0.checkOut == nil }
        )
        do {
            let results = try context.fetch(descriptor)
            if results.isEmpty { return 0 }
            for v in results {
                v.checkOut = checkoutTime
                v.wasAutoCheckedOut = true
            }
            try context.save()
            return results.count
        } catch {
            context.rollback()
            lastError = .fetchFailed(underlying: error)
            print("SwiftData fetch/save error (autoCheckoutAllActive):", error)
            return 0
        }
    }
}

