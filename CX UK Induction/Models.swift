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
    var checkIn: Date
    var checkOut: Date?

    init(id: UUID = UUID(), firstName: String, lastName: String, company: String, visiting: String, carRegistration: String, checkIn: Date = Date(), checkOut: Date? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.company = company
        self.visiting = visiting
        self.carRegistration = carRegistration
        self.checkIn = checkIn
        self.checkOut = checkOut
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
    // Derived state for sorting/searching; SwiftData is the source of truth.
    func signIn(_ context: ModelContext, firstName: String, lastName: String, company: String, visiting: String, carRegistration: String, at date: Date = Date()) {
        let v = Visitor(firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                        lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                        company: company.trimmingCharacters(in: .whitespacesAndNewlines),
                        visiting: visiting.trimmingCharacters(in: .whitespacesAndNewlines),
                        carRegistration: carRegistration.trimmingCharacters(in: .whitespacesAndNewlines),
                        checkIn: date,
                        checkOut: nil)
        context.insert(v)
        try? context.save()
    }

    func checkOut(_ context: ModelContext, _ visitor: Visitor, at date: Date = Date()) {
        visitor.checkOut = date
        try? context.save()
    }

    func deleteArchived(_ context: ModelContext, at offsets: IndexSet, from visitors: [Visitor]) {
        for index in offsets {
            context.delete(visitors[index])
        }
        try? context.save()
    }
}

