import Foundation

struct CSVExporter {
    public static func exportVisitors(_ visitors: [Visitor]) -> URL? {
        // Implement unified CSV schema identical to the one in WelcomeView.exportCSV(from:)
        // Header: First Name, Last Name, Company, Visiting, Car Registration, Blocked Car, Pager Number, Badge Number, Date Signed In, Date Signed Out, Auto Logged Out, Pre-Registered
        // Use DateFormatter.csvDateTime and String.escapedAsCSVField (assume they are available in the project).
        let header = [
            "First Name",
            "Last Name",
            "Company",
            "Visiting",
            "Car Registration",
            "Blocked Car",
            "Pager Number",
            "Badge Number",
            "Date Signed In",
            "Date Signed Out",
            "Auto Logged Out",
            "Pre-Registered"
        ]
        let rows: [[String]] = visitors.map { v in
            let car = v.carRegistration.trimmingCharacters(in: .whitespacesAndNewlines)
            let pager = v.pagerNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let badge = v.badgeNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            return [
                v.firstName,
                v.lastName,
                v.company,
                v.visiting,
                car.isEmpty ? "N/A" : car,
                v.blockedCar ? "Yes" : "No",
                pager.isEmpty ? "N/A" : pager,
                badge.isEmpty ? "N/A" : badge,
                DateFormatter.csvDateTime.string(from: v.checkIn),
                v.checkOut.map { DateFormatter.csvDateTime.string(from: $0) } ?? "N/A",
                v.wasAutoCheckedOut ? "Yes" : "No",
                v.wasPreRegistered ? "Yes" : "No"
            ]
        }
        let csv = ([header] + rows).map { row in
            row.map { $0.escapedAsCSVField }.joined(separator: ",")
        }.joined(separator: "\n")
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("visitors_\(Int(Date().timeIntervalSince1970)).csv")
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
