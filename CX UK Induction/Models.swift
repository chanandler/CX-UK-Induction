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

@Observable
final class VisitorStore {
    var lastError: String?

    // Derived state for sorting/searching; SwiftData is the source of truth.
    func signIn(_ context: ModelContext, firstName: String, lastName: String, company: String, visiting: String, carRegistration: String, blockedCar: Bool = false, pagerNumber: String? = nil, badgeNumber: String = "", at date: Date = Date()) {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCompany = company.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedVisiting = visiting.trimmingCharacters(in: .whitespacesAndNewlines)

        // Guard against blank-after-trim values slipping through
        guard !trimmedFirst.isEmpty, !trimmedLast.isEmpty,
              !trimmedCompany.isEmpty, !trimmedVisiting.isEmpty else {
            lastError = "Sign-in failed: required fields must not be blank."
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
            lastError = "Auto-checkout failed: \(error.localizedDescription)"
            print("SwiftData fetch/save error (autoCheckout):", error)
            return 0
        }
    }
}
