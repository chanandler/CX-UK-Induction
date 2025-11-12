import SwiftUI
import SwiftData

struct WelcomeView: View {
    @Environment(VisitorStore.self) private var store
    @Environment(\.modelContext) private var context
    
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var company = ""
    @State private var visiting = ""
    @State private var carRegistration = ""
    @State private var badgeNumber = ""
    @State private var blockedCar: Bool = false
    @State private var pagerNumber: String = ""

    @State private var showingLeaving = false
    @State private var showBlockedCarPrompt = false
    @State private var showPagerPrompt = false
    @State private var pendingSubmit = false
    
    @State private var showingRollCall = false

    @State private var showRegisteredAlert = false
    @State private var lastRegisteredName: String = ""
    
    @State private var showCheckoutBanner = false
    @State private var lastCheckedOutName: String = ""

    // Add back activeVisitors query
    @Query(filter: #Predicate<Visitor> { $0.checkOut == nil }, sort: [SortDescriptor(\Visitor.checkIn, order: .reverse)]) private var activeVisitors: [Visitor]
    @Query(filter: #Predicate<Visitor> { $0.checkOut != nil }, sort: [SortDescriptor(\Visitor.checkOut, order: .reverse)]) private var archivedVisitors: [Visitor]
    @Query(sort: [SortDescriptor(\Visitor.checkIn, order: .reverse)]) private var allVisitors: [Visitor]
    
    // Share support for exported CSV (ActivityView presenter)
    struct ShareItem: Identifiable { let url: URL; var id: URL { url } }
    @State private var shareItem: ShareItem?
    
    // About sheet
    @State private var showingAbout = false
    
    @State private var showingSignInBook = false
    @State private var showDebugPanel = true

    @State private var showPersistenceError = false

    init() {}

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack {
                Text("Welcome to Cemex UK HQ")
                    .font(.system(size: 54, weight: .bold))
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                    .padding(.bottom, 8)
                
                Spacer(minLength: 24)
                
                Form {
                    Section {
                        if hSizeClass == .regular {
                            HStack(alignment: .top, spacing: 16) {
                                VStack(spacing: 8) {
                                    inputTextField("First name", text: $firstName)
                                        .textContentType(.givenName)
                                        .submitLabel(.next)
                                    inputTextField("Company", text: $company)
                                        .textContentType(.organizationName)
                                        .submitLabel(.next)
                                    inputTextField("Car registration", text: $carRegistration)
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled(true)
                                        .submitLabel(.next)
                                        .onSubmit {
                                            if !carRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                showBlockedCarPrompt = true
                                            }
                                        }
                                }
                                VStack(spacing: 8) {
                                    inputTextField("Last name", text: $lastName)
                                        .textContentType(.familyName)
                                        .submitLabel(.next)
                                    inputTextField("Who are you visiting", text: $visiting)
                                        .textContentType(.name)
                                        .submitLabel(.next)
                                    inputTextField("Badge Number", text: $badgeNumber)
                                        .submitLabel(.done)
                                }
                            }
                            .padding(.vertical, 4)
                        } else {
                            VStack(spacing: 8) {
                                inputTextField("First name", text: $firstName)
                                    .textContentType(.givenName)
                                    .submitLabel(.next)
                                inputTextField("Last name", text: $lastName)
                                    .textContentType(.familyName)
                                    .submitLabel(.next)
                                inputTextField("Company", text: $company)
                                    .textContentType(.organizationName)
                                    .submitLabel(.next)
                                inputTextField("Who are you visiting", text: $visiting)
                                    .textContentType(.name)
                                    .submitLabel(.next)
                                inputTextField("Badge Number", text: $badgeNumber)
                                    .submitLabel(.next)
                                inputTextField("Car registration", text: $carRegistration)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled(true)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        if !carRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            showBlockedCarPrompt = true
                                        }
                                    }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Please enter your details")
                            .font(.headline)
                            .padding(.bottom, 8)
                    }
                    .padding(.horizontal, 0)
                    .padding(.vertical, 0)
                    Section {
                        Button(action: {
                            if !carRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                pendingSubmit = true
                                showBlockedCarPrompt = true
                            } else {
                                submit()
                            }
                        }) {
                            Label("Register", systemImage: "person.badge.plus")
                                .font(.title3)
                                .imageScale(.large)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
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
                                .font(.title3)
                                .imageScale(.large)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(.horizontal)
                        
                        Button {
                            showingSignInBook = true
                        } label: {
                            Label("View Sign In Book", systemImage: "book.closed")
                                .font(.title3)
                                .imageScale(.large)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        .padding(.horizontal)

                        // Removed the CEMEX logo from here as per instructions
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color(.systemBackground))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .scrollDismissesKeyboard(.interactively)
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
                    showingRollCall = true
                } label: {
                    Label("Fire Alarm Roll Call", systemImage: "alarm")
                }

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Share sheet for CSV export
        .sheet(item: $shareItem, onDismiss: { shareItem = nil }) { item in
            ActivityView(activityItems: [item.url])
        }
        // About sheet
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .alert("Registered", isPresented: $showRegisteredAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\(lastRegisteredName) has been registered.")
        }
        .sheet(isPresented: $showingLeaving) {
            LeavingSearchSheet(activeVisitors: activeVisitors) { name in
                lastCheckedOutName = name
                showSignedOutBannerTemporarily()
                showingLeaving = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        // Ask if they've blocked a car when a car reg is provided
        .alert("Have you blocked a car in?", isPresented: $showBlockedCarPrompt) {
            Button("No", role: .cancel) {
                blockedCar = false
                pagerNumber = ""
                if pendingSubmit {
                    submit()
                    pendingSubmit = false
                }
            }
            Button("Yes") {
                blockedCar = true
                showPagerPrompt = true
            }
        } message: {
            Text("Please let us know if your parking is blocking another vehicle.")
        }
        
        // Pager sheet to capture contact number when a car is blocked
        .sheet(isPresented: $showPagerPrompt) {
            NavigationStack {
                Form {
                    Section("Pager Number") {
                        TextField("Enter pager number", text: $pagerNumber)
                            .keyboardType(.numberPad)
                    }
                }
                .navigationTitle("Contact Pager")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            // Keep blockedCar = true but no pager; dismiss and submit if pending
                            showPagerPrompt = false
                            if pendingSubmit {
                                submit()
                                pendingSubmit = false
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            showPagerPrompt = false
                            if pendingSubmit {
                                submit()
                                pendingSubmit = false
                            }
                        }
                    }
                }
            }
            .interactiveDismissDisabled(true)
        }
        // Sign In Book sheet
        .sheet(isPresented: $showingSignInBook) {
            SignInBookView {
                showingSignInBook = false
            } onCheckedOut: { name in
                lastCheckedOutName = name
                showSignedOutBannerTemporarily()
                showingSignInBook = false
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showingRollCall) {
            FireAlarmRollCallView(visitors: activeVisitors) { showingRollCall = false }
        }
        // Added CEMEX logo overlay pinned to bottom center
        .overlay(alignment: .bottom) {
            Image("cemex_logo") // use asset name without extension
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 325)
                .padding(.bottom, vSizeClass == .compact ? 40 : 16)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            if showDebugPanel {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Diagnostics")
                            .font(.caption).bold()
                        Spacer()
                        Button(action: { showDebugPanel = false }) {
                            Image(systemName: "xmark.circle.fill").imageScale(.small)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Active: \(activeVisitors.count)").font(.caption)
                    Text("Archived: \(archivedVisitors.count)").font(.caption)
                    Text("All: \(allVisitors.count)").font(.caption)
                    if let err = store.lastError, !err.isEmpty {
                        Text(err).font(.caption2).foregroundStyle(.red)
                    }
                    Divider().padding(.vertical, 2)
                    Button("Seed Test Visitor") {
                        let v = Visitor(firstName: "Test",
                                        lastName: "Visitor",
                                        company: "CEMEX",
                                        visiting: "Reception",
                                        carRegistration: "",
                                        blockedCar: false,
                                        pagerNumber: nil,
                                        checkIn: Date(),
                                        checkOut: nil)
                        context.insert(v)
                        do {
                            try context.save()
                        } catch {
                            store.lastError = "Direct save failed: \(error.localizedDescription)"
                            print("Direct SwiftData save error:", error)
                        }
                    }
                    .font(.caption)
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(radius: 2)
                .padding([.top, .leading], 12)
            }
        }
        .ignoresSafeArea(.keyboard) // keep bottom overlay from moving with keyboard
        .onChange(of: showPagerPrompt) { oldValue, newValue in
            // If the pager sheet is dismissed by any means and a submit is pending, submit now
            if oldValue == true && newValue == false {
                if pendingSubmit {
                    submit()
                    pendingSubmit = false
                }
            }
        }
        .onChange(of: showBlockedCarPrompt) { oldValue, newValue in
            // If the blocked car alert disappears without moving to pager and a submit is pending, submit now
            if oldValue == true && newValue == false {
                if pendingSubmit && !showPagerPrompt && !blockedCar {
                    submit()
                    pendingSubmit = false
                }
            }
        }
        .onChange(of: store.lastError) { _, newValue in
            if newValue != nil {
                showPersistenceError = true
            }
        }
        .alert("Save Error", isPresented: $showPersistenceError, presenting: store.lastError) { _ in
            Button("OK", role: .cancel) {
                // clear the error so it won't re-trigger
                store.lastError = nil
            }
        } message: { msg in
            Text(msg)
        }
    }
    
    @ViewBuilder
    private func inputTextField(_ title: String, text: Binding<String>) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                )
            TextField(title, text: text)
                .font(.title3)
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 2)
    }

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !visiting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        let name = firstName + " " + lastName
        store.signIn(context,
                     firstName: firstName,
                     lastName: lastName,
                     company: company,
                     visiting: visiting,
                     carRegistration: carRegistration,
                     blockedCar: blockedCar,
                     pagerNumber: pagerNumber)
        if store.lastError != nil {
            return
        }
        firstName = ""
        lastName = ""
        company = ""
        visiting = ""
        carRegistration = ""
        badgeNumber = ""
        blockedCar = false
        pagerNumber = ""
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

struct SignInBookView: View {
    @Environment(VisitorStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Visitor> { $0.checkOut == nil }, sort: [SortDescriptor(\.checkIn, order: .reverse)]) private var activeVisitors: [Visitor]
    @Query(filter: #Predicate<Visitor> { $0.checkOut != nil }, sort: [SortDescriptor(\.checkOut, order: .reverse)]) private var archivedVisitors: [Visitor]

    let onDone: () -> Void
    let onCheckedOut: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Active") {
                    if activeVisitors.isEmpty {
                        Text("No active visitors")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(activeVisitors) { visitor in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(visitor.fullName)
                                    .font(.headline)
                                Text(visitor.company)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Checked in: \(time(visitor.checkIn))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                Section("Archived") {
                    if archivedVisitors.isEmpty {
                        Text("No archived visitors")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(archivedVisitors) { visitor in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(visitor.fullName)
                                    .font(.headline)
                                Text(visitor.company)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Checked in: \(time(visitor.checkIn))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Checked out: \(visitor.checkOut.map { time($0) } ?? "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Sign In Book")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        onDone()
                        dismiss()
                    }
                }
            }
        }
    }

    private func time(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df.string(from: date)
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
            VStack {
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
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
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
    private var buildDateTime: String {
        Bundle.main.object(forInfoDictionaryKey: "BuildDate") as? String ?? "Not available"
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FireAlarmRollCallView: View {
    @Environment(VisitorStore.self) private var store
    @Environment(\.modelContext) private var context
    
    @State private var confirmedOut: Set<Visitor.ID> = []
    let visitors: [Visitor]
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List(visitors, id: \.id) { visitor in
                HStack {
                    Text(visitor.fullName)
                    Spacer()
                    if confirmedOut.contains(visitor.id) {
                        Button("Confirmed") { }
                            .buttonStyle(.bordered)
                            .disabled(true)
                    } else {
                        Button("Confirm Out") {
                            store.checkOut(context, visitor)
                            confirmedOut.insert(visitor.id)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .padding(8)
                .background(confirmedOut.contains(visitor.id) ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                .cornerRadius(8)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Fire Roll Call")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        onDismiss()
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

