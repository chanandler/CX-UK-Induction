import SwiftUI
import SwiftData

struct VisitorTabs: View {
    var body: some View {
        TabView {
            ActiveVisitorsView()
                .tabItem { Label("Active", systemImage: "person.2.fill") }
            ArchivedVisitorsView()
                .tabItem { Label("Archived", systemImage: "archivebox.fill") }
        }
    }
}

struct ActiveVisitorsView: View {
    @Query(filter: #Predicate<Visitor> { $0.checkOut == nil }, sort: [SortDescriptor(\.checkIn, order: .reverse)]) private var active: [Visitor]
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List(filteredActive) { visitor in
                NavigationLink(value: visitor) {
                    VisitorRow(visitor: visitor)
                }
            }
            .navigationTitle("Signed In")
            .searchable(text: $searchText)
            .navigationDestination(for: Visitor.self) { v in
                VisitorDetail(visitor: v, isActive: true)
            }
        }
    }

    private var filteredActive: [Visitor] {
        if searchText.isEmpty { return active }
        return active.filter { v in
            let q = searchText.lowercased()
            return v.fullName.lowercased().contains(q) || v.company.lowercased().contains(q) || v.carRegistration.lowercased().contains(q)
        }
    }
}

struct ArchivedVisitorsView: View {
    @Environment(VisitorStore.self) private var store
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Visitor> { $0.checkOut != nil }, sort: [SortDescriptor(\.checkOut, order: .reverse)]) private var archived: [Visitor]
    @State private var searchText = ""
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredArchived) { visitor in
                    NavigationLink(value: visitor) {
                        VisitorRow(visitor: visitor)
                    }
                }
                .onDelete { offsets in
                    store.deleteArchived(context, at: offsets, from: filteredArchived)
                }
            }
            .navigationTitle("Archived")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let url = shareURL {
                        ShareLink(item: url) {
                            Label("Export CSV", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            shareURL = exportCSV()
                        } label: {
                            Label("Export CSV", systemImage: "square.and.arrow.up")
                        }
                        .disabled(filteredArchived.isEmpty)
                    }
                }
            }
            .navigationDestination(for: Visitor.self) { v in
                VisitorDetail(visitor: v, isActive: false)
            }
        }
        .onChange(of: searchText) { _, _ in
            // reset share URL when filter changes to regenerate file
            shareURL = nil
        }
    }

    private var filteredArchived: [Visitor] {
        if searchText.isEmpty { return archived }
        return archived.filter { v in
            let q = searchText.lowercased()
            return v.fullName.lowercased().contains(q) || v.company.lowercased().contains(q) || v.carRegistration.lowercased().contains(q)
        }
    }

    private func exportCSV() -> URL? {
        let header = ["First Name","Last Name","Company","Car Registration","Check In","Check Out"]
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let rows: [[String]] = filteredArchived.map { v in
            [v.firstName,
             v.lastName,
             v.company,
             v.carRegistration,
             df.string(from: v.checkIn),
             v.checkOut.map { df.string(from: $0) } ?? ""]
        }
        let csv = ([header] + rows).map { row in
            row.map { escapeCSV($0) }.joined(separator: ",")
        }.joined(separator: "\n")

        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("archived_visitors_\(Int(Date().timeIntervalSince1970)).csv")
            try csv.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\n") || field.contains("\"") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}

struct VisitorRow: View {
    let visitor: Visitor

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(visitor.fullName).font(.headline)
                Text(visitor.company).font(.subheadline).foregroundStyle(.secondary)
                Text(visitor.carRegistration).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("In: \(format(date: visitor.checkIn))")
                if let out = visitor.checkOut {
                    Text("Out: \(format(date: out))")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
    }

    private func format(date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df.string(from: date)
    }
}

struct VisitorDetail: View {
    @Environment(VisitorStore.self) private var store
    @Environment(\.modelContext) private var context
    let visitor: Visitor
    let isActive: Bool

    var body: some View {
        Form {
            Section("Visitor") {
                LabeledContent("Name", value: visitor.fullName)
                LabeledContent("Company", value: visitor.company)
                LabeledContent("Car", value: visitor.carRegistration)
                LabeledContent("Checked in", value: dateTime(visitor.checkIn))
                if let out = visitor.checkOut {
                    LabeledContent("Checked out", value: dateTime(out))
                }
            }
            if isActive {
                Section {
                    Button(role: .destructive) {
                        store.checkOut(context, visitor)
                    } label: {
                        Label("Mark as Leaving", systemImage: "door.right.hand.open")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle(visitor.fullName)
    }

    private func dateTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
}

#Preview {
    VisitorTabs()
        .modelContainer(for: Visitor.self, inMemory: true)
        .environment(VisitorStore())
}
