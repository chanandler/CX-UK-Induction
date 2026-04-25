import SwiftUI
import SwiftData

// MARK: - Shared brand colours

extension Color {
    /// CEMEX corporate blue: HEX #023185 (RGB 2, 49, 133).
    static let cemexBlue = Color(red: 2/255, green: 49/255, blue: 133/255)
}

// MARK: - Shared CSV / formatting utilities

extension String {
    /// Wraps a field in double-quotes and escapes internal quotes if the value
    /// contains commas, newlines, or double-quote characters.
    var escapedAsCSVField: String {
        if contains(",") || contains("\n") || contains("\"") {
            return "\"\(replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return self
    }
}

extension DateFormatter {
    /// Short time-only formatter used in visitor row cards.
    static let shortTime: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }()

    /// Medium date + short time formatter used in visitor detail and sign-in book.
    static let mediumDateTime: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    /// UK locale dd/MM/yy HH:mm formatter used for CSV exports.
    static let csvDateTime: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_GB")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "dd/MM/yy HH:mm"
        return df
    }()

    /// Alternative ISO-style formatter for parsing legacy CSV files that may use
    /// a different date format (yyyy-MM-dd HH:mm or similar).
    static let csvDateTimeAlt: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_GB")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd HH:mm"
        return df
    }()
}

struct VisitorTabs: View {
    var body: some View {
        TabView {
            ActiveVisitorsView()
                .tabItem { Label("Active", systemImage: "person.2.fill") }
            ArchivedVisitorsView()
                .tabItem { Label("Archived", systemImage: "archivebox.fill") }
        }
        .background(Color.cemexBlue)
    }
}

struct ActiveVisitorsView: View {
    @Query(filter: #Predicate<Visitor> { $0.checkOut == nil }, sort: [SortDescriptor(\.checkIn, order: .reverse)]) private var active: [Visitor]
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cemexBlue.ignoresSafeArea()

                List {
                    ForEach(filteredActive) { visitor in
                        NavigationLink(value: visitor) {
                            VisitorRowCard(visitor: visitor) // rounded card row
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 4) // spacing between cards
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .overlay(ClearBackgroundView()) // clear UIKit superviews
            }
            .navigationTitle("Signed In")
            .searchable(text: $searchText)
            .navigationDestination(for: Visitor.self) { v in
                VisitorDetail(visitor: v, isActive: true)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .tabBar)
        }
        .background(Color.clear)
    }

    private var filteredActive: [Visitor] {
        if searchText.isEmpty { return active }
        let q = searchText.lowercased()
        return active.filter { v in
            v.fullName.lowercased().contains(q)
            || v.company.lowercased().contains(q)
            || v.visiting.lowercased().contains(q)
            || v.carRegistration.lowercased().contains(q)
        }
    }
}

struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}

struct ArchivedVisitorsView: View {
    @Environment(VisitorStore.self) private var store
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Visitor> { $0.checkOut != nil }, sort: [SortDescriptor(\.checkOut, order: .reverse)]) private var archived: [Visitor]
    @State private var searchText = ""
    @State private var shareItem: ShareItem?
    @State private var showExportError = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cemexBlue.ignoresSafeArea()

                List {
                    ForEach(filteredArchived) { visitor in
                        NavigationLink(value: visitor) {
                            VisitorRowCard(visitor: visitor) // rounded card row
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        store.deleteArchived(context, at: offsets, from: filteredArchived)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .overlay(ClearBackgroundView())
            }
            .navigationTitle("Archived")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            if let url = exportCSV() {
                                shareItem = ShareItem(url: url)
                            } else {
                                showExportError = true
                            }
                        } label: {
                            Label("Export CSV", systemImage: "square.and.arrow.up")
                        }
                        .disabled(filteredArchived.isEmpty)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationDestination(for: Visitor.self) { v in
                VisitorDetail(visitor: v, isActive: false)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .tabBar)
        }
        .sheet(item: $shareItem) { item in
            // Capture the URL from the item parameter — by the time onDismiss fires
            // SwiftUI has already cleared shareItem, so reading shareItem?.url returns nil.
            ShareView(url: item.url, onDismiss: {
                try? FileManager.default.removeItem(at: item.url)
                shareItem = nil
            })
        }
        .alert(String(localized: "archived.alert.export_failed.title"), isPresented: $showExportError) {
            Button(String(localized: "common.ok"), role: .cancel) { }
        } message: {
            Text(String(localized: "archived.alert.export_failed.message"))
        }
        .onChange(of: searchText) { _, _ in
            shareItem = nil
        }
        .background(Color.clear)
    }

    private var filteredArchived: [Visitor] {
        if searchText.isEmpty { return archived }
        let q = searchText.lowercased()
        return archived.filter { v in
            v.fullName.lowercased().contains(q)
            || v.company.lowercased().contains(q)
            || v.visiting.lowercased().contains(q)
            || v.carRegistration.lowercased().contains(q)
        }
    }

    private func exportCSV() -> URL? {
        let header = ["First Name","Last Name","Company","Visiting","Car Registration","Check In","Check Out"]
        let rows: [[String]] = filteredArchived.map { v in
            [v.firstName,
             v.lastName,
             v.company,
             v.visiting,
             v.carRegistration,
             DateFormatter.csvDateTime.string(from: v.checkIn),
             v.checkOut.map { DateFormatter.csvDateTime.string(from: $0) } ?? ""]
        }
        let csv = ([header] + rows).map { row in
            row.map { $0.escapedAsCSVField }.joined(separator: ",")
        }.joined(separator: "\n")

        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("archived_visitors_\(Int(Date().timeIntervalSince1970)).csv")
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - Rounded “card” row matching the button shape

private struct VisitorRowCard: View {
    let visitor: Visitor

    var body: some View {
        HStack {
            VisitorRow(visitor: visitor)
                .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.14)) // subtle card fill over blue
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 12) // inset from list edges, similar to your button layout
    }
}

struct VisitorRow: View {
    let visitor: Visitor

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(visitor.fullName).font(.headline)
                Text(visitor.company).font(.subheadline).foregroundStyle(.secondary)
                Text("Visiting: \(visitor.visiting)").font(.caption).foregroundStyle(.secondary)
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
        .foregroundStyle(.white) // better contrast over the blue and translucent card
    }

    private func format(date: Date) -> String {
        DateFormatter.shortTime.string(from: date)
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
                LabeledContent("Visiting", value: visitor.visiting)
                LabeledContent("Car", value: visitor.carRegistration)
                LabeledContent("Badge Number", value: visitor.badgeNumber.isEmpty ? "—" : visitor.badgeNumber)
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
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle(visitor.fullName)
        .overlay(ClearBackgroundView())
    }

    private func dateTime(_ date: Date) -> String {
        DateFormatter.mediumDateTime.string(from: date)
    }
}

struct ShareView: View, Identifiable {
    let url: URL
    var id: URL { url }
    var onDismiss: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Export ready")
                ShareLink(item: url) {
                    Label("Share CSV", systemImage: "square.and.arrow.up")
                }
            }
            .padding()
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss?()
                        dismiss()
                    }
                }
            }
        }
        .background(Color.clear)
    }
}

// MARK: - UIKit transparency helpers

private struct ClearBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            var current: UIView? = view
            while let v = current {
                v.backgroundColor = .clear
                current = v.superview
            }
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) { }
}

#Preview {
    VisitorTabs()
        .modelContainer(for: Visitor.self, inMemory: true)
        .environment(VisitorStore())
}
