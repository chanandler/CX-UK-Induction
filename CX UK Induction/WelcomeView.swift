import SwiftUI
import SwiftData

struct WelcomeView: View {
    @Environment(VisitorStore.self) private var store
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Visitor> { $0.checkOut == nil }, sort: [SortDescriptor(\.checkIn, order: .reverse)]) private var activeVisitors: [Visitor]
    // Archived visitors so we can export from the cog
    @Query(filter: #Predicate<Visitor> { $0.checkOut != nil }, sort: [SortDescriptor(\.checkOut, order: .reverse)]) private var archivedVisitors: [Visitor]
    
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var company = ""
    @State private var visiting = ""
    @State private var carRegistration = ""

    @State private var showingLeaving = false

    @State private var showRegisteredAlert = false
    @State private var lastRegisteredName: String = ""
    
    @State private var showCheckoutBanner = false
    @State private var lastCheckedOutName: String = ""
    
    // Share support for exported CSV (ActivityView presenter)
    struct ShareItem: Identifiable { let url: URL; var id: URL { url } }
    @State private var shareItem: ShareItem?
    
    // About sheet
    @State private var showingAbout = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Form {
                Section {
                    if hSizeClass == .regular {
                        HStack(alignment: .top, spacing: 16) {
                            VStack {
                                TextField("First name", text: $firstName)
                                    .textContentType(.givenName)
                                    .submitLabel(.next)
                                TextField("Company", text: $company)
                                    .textContentType(.organizationName)
                                    .submitLabel(.next)
                                TextField("Car registration", text: $carRegistration)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled(true)
                                    .submitLabel(.done)
                            }
                            VStack {
                                TextField("Last name", text: $lastName)
                                    .textContentType(.familyName)
                                    .submitLabel(.next)
                                TextField("Who are you visiting", text: $visiting)
                                    .textContentType(.name)
                                    .submitLabel(.done)
                            }
                        }
                    } else {
                        TextField("First name", text: $firstName)
                            .textContentType(.givenName)
                            .submitLabel(.next)
                        TextField("Last name", text: $lastName)
                            .textContentType(.familyName)
                            .submitLabel(.next)
                        TextField("Company", text: $company)
                            .textContentType(.organizationName)
                            .submitLabel(.next)
                        TextField("Who are you visiting", text: $visiting)
                            .textContentType(.name)
                            .submitLabel(.next)
                        TextField("Car registration", text: $carRegistration)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled(true)
                            .submitLabel(.done)
                    }
                } header: {
                    Text("Your details")
                } footer: {
                    if !isValid {
                        Text("Please enter your details above and tap the 'Register' button to begin.")
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    Button(action: submit) {
                        Label("Register", systemImage: "person.badge.plus")
                            .font(.title2)
                            .imageScale(.large)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)
                    .disabled(!isValid)

                    Button {
                        showingLeaving = true
                    } label: {
                        Label("I'm leaving", systemImage: "door.right.hand.open")
                            .font(.title2)
                            .imageScale(.large)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)

                    // CEMEX logo below the "I'm leaving" button
                    Image("cemex_logo") // use asset name without extension
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260)          // adjust width if you want larger/smaller
                        .padding(.top, 12)
                        .frame(maxWidth: .infinity)     // center horizontally
                        .accessibilityHidden(true)
                }
            }
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .sheet(isPresented: $showingLeaving) {
                LeavingSearchSheet(activeVisitors: activeVisitors) { name in
                    lastCheckedOutName = name
                    showSignedOutBannerTemporarily()
                    showingLeaving = false
                }
                // Keep the sheet full height so the confirm button is visible without scrolling
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .alert("Registered", isPresented: $showRegisteredAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(lastRegisteredName) has been registered.")
            }
            .overlay(alignment: .top) {
                if showCheckoutBanner {
                    Text("\(lastCheckedOutName) signed out")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
            }

            // Bottom-left cog with menu
            Menu {
                Button {
                    if let url = exportCSV(from: archivedVisitors) {
                        shareItem = ShareItem(url: url)
                    }
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(archivedVisitors.isEmpty)

                Button {
                    showingAbout = true
                } label: {
                    Label("About", systemImage: "info.circle")
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .imageScale(.large)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)
                    .padding([.leading, .bottom], 12)
            }
        }
        // Share sheet for CSV export
        .sheet(item: $shareItem, onDismiss: { shareItem = nil }) { item in
            ActivityView(activityItems: [item.url])
        }
        // About sheet
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !visiting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        let name = firstName + " " + lastName
        store.signIn(context, firstName: firstName, lastName: lastName, company: company, visiting: visiting, carRegistration: carRegistration)
        firstName = ""; lastName = ""; company = ""; visiting = ""; carRegistration = ""
        lastRegisteredName = name
        showRegisteredAlert = true
    }
    
    private func showSignedOutBannerTemporarily() {
        withAnimation { showCheckoutBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCheckoutBanner = false }
        }
    }
    
    // CSV export (duplicated here so WelcomeView can export independently)
    private func exportCSV(from visitors: [Visitor]) -> URL? {
        let header = ["First Name","Last Name","Company","Visiting","Car Registration","Check In","Check Out"]
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let rows: [[String]] = visitors.map { v in
            [v.firstName,
             v.lastName,
             v.company,
             v.visiting,
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

private struct LeavingSearchSheet: View {
    @Environment(VisitorStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let activeVisitors: [Visitor]
    let onCheckedOut: (String) -> Void
    @State private var searchText = ""
    @State private var path: [Visitor] = []
    @State private var snapshot: [Visitor] = []

    var body: some View {
        NavigationStack(path: $path) {
            List(filtered) { v in
                Button {
                    path.append(v)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(v.fullName)
                            Text(v.company).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(time(v.checkIn)).font(.caption)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Find your name")
            .searchable(text: $searchText, prompt: "Search by name, company, or car")
            .navigationDestination(for: Visitor.self) { v in
                Form {
                    Section("Confirm") {
                        LabeledContent("Name", value: v.fullName)
                        LabeledContent("Company", value: v.company)
                        LabeledContent("Car", value: v.carRegistration)
                        LabeledContent("Checked in", value: time(v.checkIn))
                    }
                    Section {
                        Button(role: .destructive) {
                            store.checkOut(context, v)
                            onCheckedOut(v.fullName)
                            dismiss()
                        } label: {
                            Label("Confirm leaving", systemImage: "door.right.hand.open")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .navigationTitle(v.fullName)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            store.checkOut(context, v)
                            onCheckedOut(v.fullName)
                            dismiss()
                        } label: {
                            Image(systemName: "door.right.hand.open")
                        }
                    }
                }
            }
        }
        .onAppear {
            path.removeAll()
            snapshot = activeVisitors
        }
        .onChange(of: searchText) { _, _ in
            if !path.isEmpty { path.removeAll() }
        }
    }

    private var filtered: [Visitor] {
        let source = snapshot.isEmpty ? activeVisitors : snapshot
        if searchText.isEmpty { return source }
        let q = searchText.lowercased()
        return source.filter { v in
            v.fullName.lowercased().contains(q) || v.company.lowercased().contains(q) || v.carRegistration.lowercased().contains(q)
        }
    }

    private func time(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df.string(from: date)
    }
}

// UIKit share sheet wrapper so the sheet dismisses automatically when done/cancelled
private struct ActivityView: UIViewControllerRepresentable, Identifiable {
    let id = UUID()
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

// About view showing version/build and basic info
private struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App"
    }
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
    // Runtime fallback for "build date" (bundle creation date)
    private var buildDateTime: String {
        let fm = FileManager.default
        let bundleURL = Bundle.main.bundleURL
        if let attrs = try? fm.attributesOfItem(atPath: bundleURL.path),
           let date = attrs[.creationDate] as? Date {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            return df.string(from: date)
        }
        return "Not available"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(appName)
                    .font(.title).bold()
                Text("Version \(version) (Build \(build))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Built on \(buildDateTime)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.headline)
                    Text("Developed by Clint Yarwood for visitor registration at CEMEX UK HQ.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                Spacer()
            }
            .padding()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    WelcomeView()
        .modelContainer(for: Visitor.self, inMemory: true)
        .environment(VisitorStore())
}
