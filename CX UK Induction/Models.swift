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
    var badgeNumber: String?
    var checkIn: Date
    var checkOut: Date?
    var wasAutoCheckedOut: Bool

    init(id: UUID = UUID(), firstName: String, lastName: String, company: String, visiting: String, carRegistration: String, blockedCar: Bool = false, pagerNumber: String? = nil, badgeNumber: String? = nil, checkIn: Date = Date(), checkOut: Date? = nil, wasAutoCheckedOut: Bool = false) {
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

@Observable
final class VisitorStore {
    var lastError: String?

    // Derived state for sorting/searching; SwiftData is the source of truth.
    func signIn(_ context: ModelContext, firstName: String, lastName: String, company: String, visiting: String, carRegistration: String, blockedCar: Bool = false, pagerNumber: String? = nil, badgeNumber: String? = nil, at date: Date = Date()) {
        let v = Visitor(firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                        lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                        company: company.trimmingCharacters(in: .whitespacesAndNewlines),
                        visiting: visiting.trimmingCharacters(in: .whitespacesAndNewlines),
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
            lastError = "Sign-in save failed: \(error.localizedDescription)"
            print("SwiftData save error (signIn):", error)
        }
    }

    func checkOut(_ context: ModelContext, _ visitor: Visitor, at date: Date = Date()) {
        visitor.checkOut = date
        do {
            try context.save()
        } catch {
            lastError = "Check-out save failed: \(error.localizedDescription)"
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
            lastError = "Delete archived failed: \(error.localizedDescription)"
            print("SwiftData save error (deleteArchived):", error)
        }
    }

    func autoCheckoutPreviousDay(_ context: ModelContext, at checkoutTime: Date = Date()) {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        // Fetch active visitors (checkOut == nil) whose checkIn is before today
        let descriptor = FetchDescriptor<Visitor>(
            predicate: #Predicate { $0.checkOut == nil && $0.checkIn < startOfToday }
        )
        do {
            let results = try context.fetch(descriptor)
            // Set their checkOut to 07:00 of today for consistency
            var comps = cal.dateComponents([.year, .month, .day], from: Date())
            comps.hour = 7
            comps.minute = 0
            comps.second = 0
            let sevenAM = cal.date(from: comps) ?? Date()
            for v in results {
                v.checkOut = sevenAM
                v.wasAutoCheckedOut = true
            }
            if !results.isEmpty {
                try context.save()
            }
        } catch {
            lastError = "Auto-checkout failed: \(error.localizedDescription)"
            print("SwiftData fetch/save error (autoCheckout):", error)
        }
    }

    @discardableResult
    func autoCheckoutPreviousDayReturningCount(_ context: ModelContext, at checkoutTime: Date = Date()) -> Int {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        let descriptor = FetchDescriptor<Visitor>(
            predicate: #Predicate { $0.checkOut == nil && $0.checkIn < startOfToday }
        )
        do {
            let results = try context.fetch(descriptor)
            if results.isEmpty { return 0 }
            var comps = cal.dateComponents([.year, .month, .day], from: Date())
            comps.hour = 7
            comps.minute = 0
            comps.second = 0
            let sevenAM = cal.date(from: comps) ?? Date()
            for v in results {
                v.checkOut = sevenAM
                v.wasAutoCheckedOut = true
            }
            try context.save()
            return results.count
        } catch {
            lastError = "Auto-checkout failed: \(error.localizedDescription)"
            print("SwiftData fetch/save error (autoCheckout):", error)
            return 0
        }
    }
}
