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

    init(id: UUID = UUID(), firstName: String, lastName: String, company: String, visiting: String, carRegistration: String, blockedCar: Bool = false, pagerNumber: String? = nil, badgeNumber: String = "", checkIn: Date = Date(), checkOut: Date? = nil, wasAutoCheckedOut: Bool = false) {
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
        case .validationFailed(let msg):   return msg
        case .saveFailed(let e):           return "Save failed: \(e.localizedDescription)"
        case .fetchFailed(let e):          return "Fetch failed: \(e.localizedDescription)"
        case .importAccessDenied:          return "Import failed: could not access the selected file."
        case .importUnreadable:            return "Import failed: could not read file."
        case .importEmpty:                 return "Import failed: file appears empty."
        case .importMissingColumns:        return "Import failed: required columns (First Name, Last Name, Date Signed In) not found."
        case .importMessage(let msg):      return msg
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
    func signIn(_ context: ModelContext, firstName: String, lastName: String, company: String, visiting: String, carRegistration: String, blockedCar: Bool = false, pagerNumber: String? = nil, badgeNumber: String = "", at date: Date = Date()) {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCompany = company.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedVisiting = visiting.trimmingCharacters(in: .whitespacesAndNewlines)

        // Guard against blank-after-trim values slipping through
        guard !trimmedFirst.isEmpty, !trimmedLast.isEmpty,
              !trimmedCompany.isEmpty, !trimmedVisiting.isEmpty else {
            lastError = .validationFailed("Sign-in failed: required fields must not be blank.")
            return
        }

        let v = Visitor(firstName: trimmedFirst,
                        lastName: trimmedLast,
                        company: trimmedCompany,
                        visiting: trimmedVisiting,
                        carRegistration: carRegistration.trimmingCharacters(in: .whitespacesAndNewlines),
                        blockedCar: blockedCar,
                        pagerNumber: pagerNumber,
                        badgeNumber: badgeNumber,
                        checkIn: date,
                        checkOut: nil)
        context.insert(v)
        do {
            try context.save()
        } catch {
            lastError = .saveFailed(underlying: error)
            print("SwiftData save error (signIn):", error)
        }
    }

    func checkOut(_ context: ModelContext, _ visitor: Visitor, at date: Date = Date()) {
        visitor.checkOut = date
        do {
            try context.save()
        } catch {
            lastError = .saveFailed(underlying: error)
            print("SwiftData save error (checkOut):", error)
        }
    }

    func deleteArchived(_ context: ModelContext, at offsets: IndexSet, from visitors: [Visitor]) {
        for index in offsets {
            context.delete(visitors[index])
        }
        do {
            try context.save()
        } catch {
            lastError = .saveFailed(underlying: error)
            print("SwiftData save error (deleteArchived):", error)
        }
    }

    // MARK: - Backup export

    /// Builds the canonical 11-column backup CSV string for all visitors.
    func backupCSVString(from visitors: [Visitor]) -> String {
        var rows: [String] = [
            ["First Name","Last Name","Company","Visiting","Car Registration",
             "Blocked Car","Pager Number","Badge Number",
             "Date Signed In","Date Signed Out","Auto Logged Out"]
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
                v.wasAutoCheckedOut ? "Yes" : "No"
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
        guard url.startAccessingSecurityScopedResource() else {
            lastError = .importAccessDenied
            return (ImportSummary(imported: 0, skipped: 0, failed: 0), [])
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
            lastError = .importUnreadable
            return (ImportSummary(imported: 0, skipped: 0, failed: 0), [])
        }

        let lines = raw.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard lines.count >= 2 else {
            lastError = .importEmpty
            return (ImportSummary(imported: 0, skipped: 0, failed: 0), [])
        }

        // Parse header row to build column-name → index map.
        let headers = parseCSVLine(lines[0]).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        func col(_ name: String) -> Int? { headers.firstIndex(of: name) }

        // Require at minimum the four identity columns.
        guard let iFirst = col("First Name"), let iLast = col("Last Name"),
              let iCheckIn = col("Date Signed In") ?? col("Check In") else {
            lastError = .importMissingColumns
            return (ImportSummary(imported: 0, skipped: 0, failed: 0), [])
        }

        // Build a set of existing records for duplicate detection.
        let existingKey: Set<String>
        do {
            let all = try context.fetch(FetchDescriptor<Visitor>())
            existingKey = Set(all.map { dupKey($0.firstName, $0.lastName, $0.checkIn) })
        } catch {
            lastError = .importMessage("Import failed: could not read existing records.")
            return (ImportSummary(imported: 0, skipped: 0, failed: 0), [])
        }

        // Track keys seen during this import pass so duplicates inside the same CSV
        // are skipped (not just duplicates already persisted in the database).
        var seenKeys = existingKey

        var pending: [Visitor] = []
        var skipped = 0
        var failed = 0

        for line in lines.dropFirst() {
            let fields = parseCSVLine(line)
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
            let company         = field(col("Company"))
            let visiting        = field(col("Visiting"))
            let carReg          = field(col("Car Registration"))
            let blockedCarStr   = field(col("Blocked Car")).lowercased()
            let blockedCar      = blockedCarStr == "yes" || blockedCarStr == "true" || blockedCarStr == "1"
            let pagerRaw        = field(col("Pager Number"))
            let pagerNumber: String? = pagerRaw.isEmpty ? nil : pagerRaw
            let badgeNumber     = field(col("Badge Number"))
            let checkOutStr     = field(col("Date Signed Out") ?? col("Check Out"))
            let checkOut: Date? = checkOutStr.isEmpty ? nil
                : DateFormatter.csvDateTime.date(from: checkOutStr)
                  ?? DateFormatter.csvDateTimeAlt.date(from: checkOutStr)
            let autoStr         = field(col("Auto Logged Out")).lowercased()
            let wasAuto         = autoStr == "yes" || autoStr == "true" || autoStr == "1"

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
                wasAutoCheckedOut: wasAuto
            )
            pending.append(visitor)
            seenKeys.insert(key)
        }

        return (ImportSummary(imported: pending.count, skipped: skipped, failed: failed), pending)
    }

    /// Commits the pending visitors from `previewImport` into `context` and saves.
    @discardableResult
    func commitImport(_ context: ModelContext, pending: [Visitor]) -> Bool {
        for v in pending { context.insert(v) }
        do {
            try context.save()
            return true
        } catch {
            lastError = .saveFailed(underlying: error)
            print("SwiftData save error (commitImport):", error)
            return false
        }
    }

    // MARK: - Private CSV helpers

    private func dupKey(_ first: String, _ last: String, _ date: Date) -> String {
        "\(first.lowercased())|\(last.lowercased())|\(date.timeIntervalSinceReferenceDate)"
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
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
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
            lastError = .fetchFailed(underlying: error)
            print("SwiftData fetch/save error (autoCheckout):", error)
            return 0
        }
    }
}
