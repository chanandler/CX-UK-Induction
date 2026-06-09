import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

// MARK: - UIKit Share Sheet Wrapper
#if canImport(UIKit)
struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - About
struct AboutView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "info.circle.fill").font(.largeTitle)
                Text("CX UK Induction")
                    .font(.title2).bold()
                Text("Version information and acknowledgements.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("About")
        }
    }
}

// MARK: - Settings / Auto-Checkout
struct AutoCheckoutSettingsView: View {
    @Binding var enabled: Bool
    @Binding var hour: Int
    @Binding var minute: Int
    @Binding var autoBackupEnabled: Bool
    @Binding var autoReturnPagersOnAutoCheckout: Bool
    var onManualBackup: () -> Void
    var onImportCSV: () -> Void
    var onLockAdminSession: () -> Void
    var onOpenAnalytics: () -> Void
    var existingBackups: [URL]
    var onOpenPreRegistrationAdmin: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "settings.section.auto_checkout")) {
                    Toggle(String(localized: "settings.auto_checkout.enable"), isOn: $enabled)
                    Picker(String(localized: "settings.auto_checkout.time"), selection: fixedTimeSelectionBinding) {
                        Text(String(localized: "settings.auto_checkout.time.5am")).tag(0)
                        Text(String(localized: "settings.auto_checkout.time.6am")).tag(1)
                        Text(String(localized: "settings.auto_checkout.time.7am")).tag(2)
                    }
                    .pickerStyle(.segmented)
                    Toggle(String(localized: "settings.auto_checkout.return_all_pagers"), isOn: $autoReturnPagersOnAutoCheckout)
                        .tint(.red)
                }
                Section(String(localized: "settings.section.backups")) {
                    Toggle(String(localized: "settings.backups.enable_daily"), isOn: $autoBackupEnabled)
                    Button(String(localized: "settings.backups.backup_now"), action: onManualBackup)
                    Button(String(localized: "settings.backups.import_csv"), action: onImportCSV)
                    if existingBackups.isEmpty {
                        Text(String(localized: "settings.backups.none_found")).foregroundStyle(.secondary)
                    } else {
                        ForEach(existingBackups, id: \.self) { url in
                            Text(url.lastPathComponent)
                        }
                    }
                }
                Section(String(localized: "settings.section.admin")) {
                    Button(String(localized: "settings.admin.open_analytics"), action: onOpenAnalytics)
                    Button(String(localized: "settings.admin.preregistration_admin"), action: onOpenPreRegistrationAdmin)
                    Button(String(localized: "settings.admin.lock_session"), action: onLockAdminSession)
                }
            }
            .navigationTitle(String(localized: "settings.title"))
        }
    }

    private var fixedTimeSelectionBinding: Binding<Int> {
        Binding<Int>(
            get: {
                switch (hour, minute) {
                case (5, 0): return 0
                case (6, 0): return 1
                case (7, 0): return 2
                default:
                    // Snap unknown values to the closest valid option (default to 5:00 AM)
                    return 0
                }
            },
            set: { newValue in
                switch newValue {
                case 0: hour = 5; minute = 0
                case 1: hour = 6; minute = 0
                case 2: hour = 7; minute = 0
                default: hour = 5; minute = 0
                }
            }
        )
    }
}

// MARK: - Leaving Search Sheet
struct LeavingSearchSheet: View {
    var activeVisitors: [Visitor]
    var onCheckedOut: (Visitor) -> Void

    var body: some View {
        NavigationStack {
            List(activeVisitors, id: \.self) { v in
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(v.firstName) \(v.lastName)")
                        Text(v.company).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Check out") { onCheckedOut(v) }
                }
            }
            .navigationTitle("I'm Leaving")
        }
    }
}

// MARK: - Sign In Book
struct SignInBookView: View {
    var activeVisitors: [Visitor]
    var onDone: () -> Void
    var onCheckedOut: (Visitor) -> Void
    @State private var pendingCheckout: Visitor?

    var body: some View {
        NavigationStack {
            List {
                Section("Currently Signed In") {
                    if activeVisitors.isEmpty {
                        Text("No active visitors")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(activeVisitors, id: \.self) { visitor in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(visitor.fullName)
                                    Text(visitor.company)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Check out") { pendingCheckout = visitor }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sign In Book")
        }
        .alert("Confirm Check Out", isPresented: checkoutConfirmationBinding) {
            Button("Cancel", role: .cancel) { pendingCheckout = nil }
            Button("Check Out", role: .destructive) {
                if let pendingCheckout {
                    onCheckedOut(pendingCheckout)
                }
                pendingCheckout = nil
            }
        } message: {
            Text("Mark \(pendingCheckout?.fullName ?? "this visitor") as leaving?")
        }
    }

    private var checkoutConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingCheckout != nil },
            set: { if !$0 { pendingCheckout = nil } }
        )
    }
}

// MARK: - Fire Alarm Roll Call
struct FireAlarmRollCallView: View {
    var visitors: [Visitor]
    var onDone: () -> Void
    var onCheckOut: (Visitor) -> Void
    var onQuickSignIn: (Visitor) -> Void

    @State private var recentlySignedOut: Set<UUID> = []
    @State private var recentlySignedOutVisitors: [Visitor] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("\(visitors.count)", systemImage: "person.2.fill")
                            .font(.title2.bold())
                        Spacer()
                        Text("currently signed in")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Visitors") {
                    if visitors.isEmpty {
                        Text("No active visitors")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(visitors, id: \.self) { visitor in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(visitor.fullName)
                                    .font(.headline)
                                Text("\(visitor.company) · Visiting \(visitor.visiting)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    if !visitor.badgeNumber.isEmpty {
                                        Label("Badge \(visitor.badgeNumber)", systemImage: "lanyardcard")
                                    }
                                    if !visitor.carRegistration.isEmpty {
                                        Label(visitor.carRegistration, systemImage: "car.fill")
                                    }
                                    if let pager = visitor.pagerNumber, !pager.isEmpty {
                                        Label("Pager \(pager)", systemImage: "dot.radiowaves.left.and.right")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                HStack(spacing: 8) {
                                    Button("Mark Out") {
                                        // Keep a local snapshot so we can offer instant sign-in even after the active list updates
                                        if !recentlySignedOut.contains(visitor.id) {
                                            recentlySignedOutVisitors.append(visitor)
                                        }
                                        onCheckOut(visitor)
                                        recentlySignedOut.insert(visitor.id)
                                    }
                                    .buttonStyle(.borderedProminent)

                                    if recentlySignedOut.contains(visitor.id) {
                                        Button("Sign Back In Instantly") {
                                            onQuickSignIn(visitor)
                                            recentlySignedOut.remove(visitor.id)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }

                Section("Recently Signed Out") {
                    if recentlySignedOutVisitors.isEmpty {
                        Text("No recent sign-outs")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentlySignedOutVisitors, id: \.id) { v in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(v.fullName)
                                    .font(.headline)
                                Text("\(v.company) · Visiting \(v.visiting)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 8) {
                                    Button("Sign Back In Instantly") {
                                        onQuickSignIn(v)
                                        recentlySignedOut.remove(v.id)
                                        recentlySignedOutVisitors.removeAll { $0.id == v.id }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .navigationTitle("Fire Alarm Roll Call")
        }
    }
}

// MARK: - Staff Car Pager Issue
struct StaffCarPagerSheet: View {
    var usedPagers: Set<String>
    var availablePagerRange: ClosedRange<Int>
    var onIssue: (_ firstName: String, _ lastName: String, _ carRegistration: String, _ pagerNumber: String) -> Void
    var onCancel: () -> Void

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var carRegistration = ""
    @State private var selectedPager = ""
    @State private var hasAttemptedSave = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Staff Member") {
                    TextField("First name", text: $firstName)
                        .textInputAutocapitalization(.words)
                    TextField("Last name", text: $lastName)
                        .textInputAutocapitalization(.words)
                    TextField("Car registration", text: carRegistrationBinding)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Text("The Issue button will appear once first name, last name, car registration and a pager are selected.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(action: {
                        hasAttemptedSave = true
                        if isValid {
                            onIssue(firstName, lastName, carRegistration, selectedPager)
                        }
                    }) {
                        Text("Issue Pager")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Section("Pager") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                        ForEach(availablePagerRange, id: \.self) { pager in
                            let tag = String(pager)
                            let isTaken = usedPagers.contains(tag)
                            let isSelected = selectedPager == tag
                            Button {
                                if !isTaken { selectedPager = tag }
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(isTaken ? Color.red : Color.green)
                                        .frame(width: 10, height: 10)
                                    Text("Pager \(pager)")
                                    if isSelected {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isSelected ? Color.blue.opacity(0.18) : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isTaken)
                            .opacity(isTaken ? 0.45 : 1)
                        }
                    }
                }

                if hasAttemptedSave && !isValid {
                    Section {
                        Text("First name, last name, car registration and an available pager are required.")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Issue Staff Pager")
        }
    }

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !carRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedPager.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !usedPagers.contains(selectedPager)
    }

    private var carRegistrationBinding: Binding<String> {
        Binding(
            get: { carRegistration },
            set: { newValue in
                carRegistration = String(newValue.uppercased().filter { $0.isNumber || ("A"..."Z").contains(String($0)) })
            }
        )
    }
}

// MARK: - Return Pagers
struct ReturnPagersSheet: View {
    var activeIssues: [StaffPagerIssue]
    var onReturn: (StaffPagerIssue) -> Void
    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if activeIssues.isEmpty {
                    Text("No issued pagers")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(activeIssues, id: \.id) { issue in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(issue.fullName)
                                Text("\(issue.carRegistration) · Pager \(issue.pagerNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Mark Returned") {
                                onReturn(issue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Return Pagers")
        }
    }
}

// MARK: - Pre-Registered List
struct PreRegisteredListView: View {
    var preRegisteredVisitors: [PreRegisteredVisitor]
    var onSelect: (PreRegisteredVisitor) -> Void
    var onSelectWithCar: (PreRegisteredVisitor, String) -> Void
    @State private var searchText = ""
    @State private var selectedForCar: PreRegisteredVisitor?
    @State private var carRegistration = ""

    var body: some View {
        NavigationStack {
            List {
                if filteredVisitors.isEmpty {
                    Text("No pre-registered visitors")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredVisitors, id: \.id) { visitor in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(visitor.fullName)
                                .font(.headline)
                            Text("\(visitor.company) · Visiting \(visitor.visiting)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let visitDate = visitor.visitDate {
                                Text("Visit on: \(Self.dateOnlyFormatter.string(from: visitDate))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Visit on: Date not set")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Button("Sign in") { onSelect(visitor) }
                                    .buttonStyle(.borderedProminent)
                                Button("Sign in with car") {
                                    selectedForCar = visitor
                                    carRegistration = visitor.carRegistration
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Pre-Registered")
            .searchable(text: $searchText)
            .sheet(item: $selectedForCar) { visitor in
                NavigationStack {
                    Form {
                        Section(visitor.fullName) {
                            TextField("Car registration", text: carRegistrationBinding)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                        }
                    }
                    .navigationTitle("Car Registration")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { selectedForCar = nil }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Continue") {
                                onSelectWithCar(visitor, carRegistration)
                                selectedForCar = nil
                            }
                            .disabled(carRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
        }
    }

    private var filteredVisitors: [PreRegisteredVisitor] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base: [PreRegisteredVisitor]
        if query.isEmpty {
            base = preRegisteredVisitors
        } else {
            base = preRegisteredVisitors.filter {
                $0.fullName.lowercased().contains(query) ||
                $0.company.lowercased().contains(query) ||
                $0.visiting.lowercased().contains(query)
            }
        }
        return base.sorted { a, b in
            switch (a.visitDate, b.visitDate) {
            case let (da?, db?):
                if da != db { return da < db } // earlier dates first
                return a.fullName.lowercased() < b.fullName.lowercased()
            case (.some, nil):
                return true  // a has a date, b does not — a first
            case (nil, .some):
                return false // b has a date, a does not — b first
            case (nil, nil):
                return a.fullName.lowercased() < b.fullName.lowercased()
            }
        }
    }

    private var carRegistrationBinding: Binding<String> {
        Binding(
            get: { carRegistration },
            set: { newValue in
                carRegistration = String(newValue.uppercased().filter { $0.isNumber || ("A"..."Z").contains(String($0)) })
            }
        )
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()
}

// MARK: - Pre-Registration Admin
struct PreRegistrationAdminView: View {
    var preRegisteredVisitors: [PreRegisteredVisitor]
    var onAdd: (_ firstName: String, _ lastName: String, _ company: String, _ visiting: String, _ badgeNumber: String, _ visitDate: Date) -> Bool
    var onDelete: (PreRegisteredVisitor) -> Void
    var onDone: () -> Void

    @Environment(VisitorStore.self) private var store
    @State private var showLocalError = false
    @State private var badgeConflict = false
    @State private var localErrorMessage = ""

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var company = ""
    @State private var visiting = ""
    @State private var badgeNumber = ""
    @State private var visitDate = Date()
    @State private var hasAttemptedSave = false
    private let badgeConflictMessage = "That badge is already allocated for the selected visit date. Please choose a different badge number."
    private let genericAddFailureMessage = "Could not add pre-registration. Please try again."

    var body: some View {
        NavigationStack {
            Form {
                Section("New Visitor") {
                    TextField("First name", text: $firstName)
                        .textInputAutocapitalization(.words)
                    TextField("Last name", text: $lastName)
                        .textInputAutocapitalization(.words)
                    TextField("Company", text: $company)
                        .textInputAutocapitalization(.words)
                    TextField("Visiting", text: $visiting)
                        .textInputAutocapitalization(.words)
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Badge number", text: badgeBinding)
                            .keyboardType(.numberPad)
                            .padding(.horizontal, 0)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(badgeConflict ? Color.red : Color.clear, lineWidth: badgeConflict ? 1.5 : 0)
                            )
                            .onChange(of: badgeNumber) { _, _ in
                                // Clear highlight on any edit; validation will re-trigger on Add
                                if badgeConflict { badgeConflict = false }
                            }
                        if badgeConflict {
                            Text("That badge is already allocated for the selected visit date. Please choose a different badge number.")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                    DatePicker("Date of Visit", selection: $visitDate, displayedComponents: .date)
                    if hasAttemptedSave && !isValid {
                        Text("First name, last name, company and visiting are required.")
                            .foregroundStyle(.red)
                    }
                    Button("Add Pre-Registration") {
                        hasAttemptedSave = true
                        guard isValid else { return }

                        // Local badge conflict validation: same date and same badge number already allocated
                        let sameDay = Calendar.current.startOfDay(for: visitDate)
                        let normalizedEnteredBadge = normalizedBadgeValue(badgeNumber)
                        let conflict = preRegisteredVisitors.contains { v in
                            guard !normalizedEnteredBadge.isEmpty else { return false }
                            let normalizedExistingBadge = normalizedBadgeValue(v.badgeNumber)
                            guard !normalizedExistingBadge.isEmpty else { return false }
                            guard let vDate = v.visitDate else { return false }
                            let vDay = Calendar.current.startOfDay(for: vDate)
                            return normalizedExistingBadge == normalizedEnteredBadge && vDay == sameDay
                        }

                        if conflict {
                            badgeConflict = true
                            localErrorMessage = badgeConflictMessage
                            showLocalError = true
                            return
                        }

                        if onAdd(firstName, lastName, company, visiting, badgeNumber, visitDate) {
                            clearForm()
                        } else {
                            // Show the underlying store error when available.
                            let message = store.lastError?.localizedDescription ?? genericAddFailureMessage
                            localErrorMessage = message
                            badgeConflict = message == badgeConflictMessage
                            showLocalError = true
                        }
                    }
                }

                Section("Pre-Registered Visitors") {
                    if preRegisteredVisitors.isEmpty {
                        Text("No pre-registered visitors")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(preRegisteredVisitors, id: \.id) { visitor in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(visitor.fullName)
                                    .font(.headline)
                                Text("\(visitor.company) · Visiting \(visitor.visiting)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if !visitor.badgeNumber.isEmpty {
                                    Text("Badge \(visitor.badgeNumber)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { offsets in
                            let visitorsToDelete = offsets.map { preRegisteredVisitors[$0] }
                            for visitor in visitorsToDelete {
                                onDelete(visitor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pre-Registration Admin")
            .alert("Error", isPresented: $showLocalError) {
                Button("OK", role: .cancel) { showLocalError = false }
            } message: {
                Text(localErrorMessage.isEmpty ? genericAddFailureMessage : localErrorMessage)
            }
        }
    }

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !visiting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var badgeBinding: Binding<String> {
        Binding(
            get: { badgeNumber },
            set: { badgeNumber = $0.filter(\.isNumber) }
        )
    }

    private func normalizedBadgeValue(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func clearForm() {
        firstName = ""
        lastName = ""
        company = ""
        visiting = ""
        badgeNumber = ""
        visitDate = Date()
        hasAttemptedSave = false
    }
}

// MARK: - Returning Visitor Search
struct ReturningVisitorSearchView: View {
    var visitors: [Visitor]
    var onSelect: (Visitor) -> Void
    var onSelectWithCar: (Visitor, String) -> Void

    @State private var firstNameQuery = ""
    @State private var lastNameQuery = ""
    @State private var selectedForCar: Visitor?
    @State private var carRegistration = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Search") {
                    TextField("First name", text: $firstNameQuery)
                        .textInputAutocapitalization(.words)
                    TextField("Last name", text: $lastNameQuery)
                        .textInputAutocapitalization(.words)
                }

                Section("Results") {
                    if firstNameQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                        lastNameQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Enter a first name or last name to search")
                            .foregroundStyle(.secondary)
                    } else if filteredVisitors.isEmpty {
                        Text("No returning visitors found")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredVisitors, id: \.id) { visitor in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(visitor.fullName)
                                    .font(.headline)
                                Text("\(visitor.company) · Visiting \(visitor.visiting)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Last visit: \(DateFormatter.mediumDateTime.string(from: visitor.checkIn))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Button("Sign in") { onSelect(visitor) }
                                        .buttonStyle(.borderedProminent)
                                    Button("Sign in with car") {
                                        selectedForCar = visitor
                                        carRegistration = visitor.carRegistration
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Returning Visitor")
            .sheet(item: $selectedForCar) { visitor in
                NavigationStack {
                    Form {
                        Section(visitor.fullName) {
                            TextField("Car registration", text: carRegistrationBinding)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                        }
                    }
                    .navigationTitle("Car Registration")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { selectedForCar = nil }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Continue") {
                                onSelectWithCar(visitor, carRegistration)
                                selectedForCar = nil
                            }
                            .disabled(carRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
        }
    }

    private var filteredVisitors: [Visitor] {
        let archived = visitors.filter { $0.checkOut != nil }
        let f = firstNameQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let l = lastNameQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Require at least one non-empty query
        guard !f.isEmpty || !l.isEmpty else { return [] }

        let matches = archived.filter { v in
            let fn = v.firstName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let ln = v.lastName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let firstMatches = f.isEmpty || fn.contains(f)
            let lastMatches = l.isEmpty || ln.contains(l)
            return firstMatches && lastMatches
        }

        // Deduplicate by (first, last, company) keeping the most recent record by checkIn.
        // Including company avoids merging distinct people with the same name.
        var latestByName: [String: Visitor] = [:]
        for v in matches {
            let first = v.firstName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let last = v.lastName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let company = v.company.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let key = "\(first)|\(last)|\(company)"
            if let existing = latestByName[key] {
                if v.checkIn > existing.checkIn { latestByName[key] = v }
            } else {
                latestByName[key] = v
            }
        }
        let unique = Array(latestByName.values)
        return unique.sorted { a, b in
            if a.lastName.lowercased() != b.lastName.lowercased() { return a.lastName.lowercased() < b.lastName.lowercased() }
            if a.firstName.lowercased() != b.firstName.lowercased() { return a.firstName.lowercased() < b.firstName.lowercased() }
            return a.company.lowercased() < b.company.lowercased()
        }
    }

    private var carRegistrationBinding: Binding<String> {
        Binding(
            get: { carRegistration },
            set: { newValue in
                carRegistration = String(newValue.uppercased().filter { $0.isNumber || ("A"..."Z").contains(String($0)) })
            }
        )
    }
}

// MARK: - Import Confirmation
struct ImportConfirmationView: View {
    var summary: VisitorStore.ImportSummary
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Import Preview")
                Text("Imported: \(summary.imported)")
                Text("Skipped: \(summary.skipped)")
                Text("Failed: \(summary.failed)")
                HStack {
                    Button("Cancel", action: onCancel)
                    Button("Confirm", action: onConfirm)
                }
            }
            .padding()
            .navigationTitle("Confirm Import")
        }
    }
}

// MARK: - Induction Flow
struct InductionFlowView: View {
    var imageNames: [String]
    var visitorFirstName: String
    var visitorLastName: String
    var onComplete: (Bool) -> Void
    @State private var selectedIndex = 0
    @State private var showingSignatureSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if imageNames.isEmpty {
                    ContentUnavailableView("No Induction Content", systemImage: "photo.on.rectangle.angled")
                } else {
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(imageNames.enumerated()), id: \.offset) { index, imageName in
                            Image(imageName)
                                .resizable()
                                .scaledToFit()
                                .tag(index)
                                .padding()
                                .background(Color(.systemBackground))
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))

                    Text("\(selectedIndex + 1) of \(imageNames.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Cancel", role: .cancel) { onComplete(false) }
                    Spacer()
                    Button(selectedIndex == imageNames.count - 1 ? "Tap here to sign" : "Next") {
                        if selectedIndex == imageNames.count - 1 {
                            showingSignatureSheet = true
                        } else {
                            selectedIndex += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(imageNames.isEmpty)
                }
                .padding(.horizontal)
            }
            .navigationTitle(visitorFirstName.isEmpty ? "Induction" : "\(visitorFirstName)'s Induction")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onComplete(false) }
                }
            }
            .sheet(isPresented: $showingSignatureSheet) {
                InductionSignatureSheet(
                    visitorFirstName: visitorFirstName,
                    visitorLastName: visitorLastName,
                    onAgree: {
                        showingSignatureSheet = false
                        onComplete(true)
                    },
                    onCancel: {
                        showingSignatureSheet = false
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .task {
                if imageNames.isEmpty {
                    onComplete(false)
                }
            }
        }
    }
}

private struct InductionSignatureSheet: View {
    var visitorFirstName: String
    var visitorLastName: String
    var onAgree: () -> Void
    var onCancel: () -> Void
    @State private var hasAppeared = false

    private var signatureName: String {
        let fullName = "\(visitorFirstName) \(visitorLastName)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return fullName.isEmpty ? "Visitor" : fullName
    }

    private var signatureFont: Font {
        if UIFont(name: "BradleyHandITCTT-Bold", size: 58) != nil {
            return .custom("BradleyHandITCTT-Bold", size: 58)
        }
        if UIFont(name: "SnellRoundhand-Black", size: 58) != nil {
            return .custom("SnellRoundhand-Black", size: 58)
        }
        if UIFont(name: "MarkerFelt-Wide", size: 58) != nil {
            return .custom("MarkerFelt-Wide", size: 58)
        }
        return .system(size: 48, weight: .semibold, design: .serif)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Image(systemName: "signature")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.blue)
                    Text("Confirm Understanding")
                        .font(.title.bold())
                    Text("By agreeing below, you confirm that you have read and understood the visitor induction.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    Text(signatureName)
                        .font(signatureFont)
                        .minimumScaleFactor(0.45)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 28)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.35))
                                .frame(height: 1)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 20)
                        }
                        .scaleEffect(hasAppeared ? 1 : 0.92)
                        .opacity(hasAppeared ? 1 : 0)

                    Text("Signature")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                VStack(spacing: 12) {
                    Button("I Agree", action: onAgree)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)

                    Button("Cancel", role: .cancel, action: onCancel)
                }
            }
            .padding(24)
            .navigationTitle("Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel, action: onCancel)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                    hasAppeared = true
                }
            }
        }
    }
}
