import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers
import Charts

struct WelcomeView: View {
    @Environment(VisitorStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    
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
    @State private var hasAttemptedSubmit = false

    @State private var activeSheet: ActiveSheet?
    @State private var showBlockedCarPrompt = false
    @State private var showPagerPrompt = false
    @State private var pendingSubmit = false
    
    @State private var showingInduction = false
    @State private var inductionImages: [String] = ["induction_1", "induction_2", "induction_3", "induction_4"]
    
    @State private var showRegisteredAlert = false
    @State private var lastRegisteredName: String = ""
    
    @State private var showCheckoutBanner = false
    @State private var lastCheckedOutName: String = ""
    
    @AppStorage("autoCheckoutEnabled") private var autoCheckoutEnabled: Bool = false
    @AppStorage("autoCheckoutHour") private var autoCheckoutHour: Int = 5
    @AppStorage("autoCheckoutMinute") private var autoCheckoutMinute: Int = 0
    @State private var scheduler = AutoCheckoutScheduler()

    // Backup scheduler
    @AppStorage("autoBackupEnabled") private var autoBackupEnabled: Bool = false
    @State private var backupScheduler = BackupScheduler()

    // CSV import state
    @State private var showingImportPicker = false
    @State private var importPending: [Visitor] = []
    @State private var importSummary: VisitorStore.ImportSummary? = nil

    // Reuse a single generator instance rather than creating one per haptic call.
    private let hapticGenerator = UINotificationFeedbackGenerator()
    private let pinSessionTimeout: TimeInterval = 5 * 60
    private let availablePagerRange: ClosedRange<Int> = 1...30

    @State private var pinGateAction: ProtectedAction = .settings
    @AppStorage("pinLastUnlockTimestamp") private var pinLastUnlockTimestamp: Double = 0

    @State private var showPersistenceError = false

    @FocusState private var focusedField: Field?
    enum Field: Hashable {
        case firstName, lastName, company, visiting, carReg, badge
    }

    private enum ProtectedAction {
        case settings
        case exportCSV
        case signInBook
        case fireRollCall
        case analytics
    }

    private enum ActiveSheet: String, Identifiable {
        case about
        case settings
        case leaving
        case signInBook
        case rollCall
        case pinGate
        case analytics
        case importConfirmation

        var id: String { rawValue }
    }

    // Track pagers already in use by active visitors.
    // Strip any legacy "Pager " prefix so older stored values ("Pager 3") compare
    // correctly against the bare numeric picker tags ("3").
    private var usedPagers: Set<String> {
        Set(activeVisitors.compactMap { visitor -> String? in
            guard let raw = visitor.pagerNumber else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            let lower = trimmed.lowercased()
            return lower.hasPrefix("pager ") ? String(trimmed.dropFirst("pager ".count)) : trimmed
        })
    }

    @Query(filter: #Predicate<Visitor> { $0.checkOut == nil }, sort: [SortDescriptor(\Visitor.checkIn, order: .reverse)]) private var activeVisitors: [Visitor]
    @Query(sort: [SortDescriptor(\Visitor.checkIn, order: .reverse)]) private var allVisitors: [Visitor]
    
    // Share support for exported CSV (ActivityView presenter)
    struct ShareItem: Identifiable { let url: URL; var id: URL { url } }
    @State private var shareItem: ShareItem?
    
    init() {}
    
    private var firstNameInvalid: Bool { hasAttemptedSubmit && firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var lastNameInvalid: Bool { hasAttemptedSubmit && lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var companyInvalid: Bool { hasAttemptedSubmit && company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var visitingInvalid: Bool { hasAttemptedSubmit && visiting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var badgeInvalid: Bool { hasAttemptedSubmit && badgeNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var pagerInvalid: Bool { blockedCar && pagerNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        decoratedContent
    }

    // MARK: - Main layout content

    private var mainContent: some View {
        ZStack(alignment: .bottomLeading) {
            ScrollView {
                VStack(spacing: 0) {
                    BrandHeader()
                    formCard
                        .offset(y: -32)
                        .padding(.bottom, 48)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))

            settingsMenu
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Form card

    private var formCard: some View {
        VStack(spacing: 20) {
            VisitorFormFields(
                useColumns: hSizeClass == .regular,
                firstName: $firstName,
                lastName: $lastName,
                company: $company,
                visiting: $visiting,
                carRegistration: $carRegistration,
                badgeNumber: $badgeNumber,
                showBlockedCarPrompt: $showBlockedCarPrompt,
                firstNameInvalid: firstNameInvalid,
                lastNameInvalid: lastNameInvalid,
                companyInvalid: companyInvalid,
                visitingInvalid: visitingInvalid,
                badgeInvalid: badgeInvalid,
                focusedField: $focusedField
            )

            Divider()

            formCardButtons
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
        )
        .padding(.horizontal, hSizeClass == .regular ? 48 : 16)
    }

    private var formCardButtons: some View {
        VStack(spacing: 12) {
            registerButton

            HStack(spacing: 12) {
                leavingButton
                signInBookButton
            }
        }
    }

    // MARK: - Sheets and alerts (first half of decorator chain)

    @ViewBuilder
    private var decoratedContentPart1: some View {
        mainContent
            // Share sheet for CSV export — temp file is cleaned up on dismiss.
            .sheet(item: $shareItem) { item in
                // Capture URL from item — shareItem is nil by the time onDismiss fires.
                ActivityView(activityItems: [item.url])
                    .onDisappear {
                        try? FileManager.default.removeItem(at: item.url)
                        shareItem = nil
                    }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .about:
                    AboutView()
                case .settings:
                    AutoCheckoutSettingsView(
                        enabled: $autoCheckoutEnabled,
                        hour: $autoCheckoutHour,
                        minute: $autoCheckoutMinute,
                        autoBackupEnabled: $autoBackupEnabled,
                        onManualBackup: runManualBackup,
                        onImportCSV: { showingImportPicker = true },
                        onOpenAnalytics: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                requestProtectedAccess(for: .analytics)
                            }
                        },
                        existingBackups: BackupScheduler.existingBackups()
                    )
                    .presentationDetents([.large])
                case .leaving:
                    LeavingSearchSheet(activeVisitors: activeVisitors) { name in
                        lastCheckedOutName = name
                        showSignedOutBannerTemporarily()
                        activeSheet = nil
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                case .signInBook:
                    SignInBookView {
                        activeSheet = nil
                    } onCheckedOut: { name in
                        lastCheckedOutName = name
                        showSignedOutBannerTemporarily()
                        activeSheet = nil
                    }
                    .interactiveDismissDisabled()
                case .rollCall:
                    FireAlarmRollCallView(visitors: activeVisitors) { activeSheet = nil }
                case .pinGate:
                    PinGateSheet(
                        actionName: protectedActionName(for: pinGateAction),
                        onSuccess: {
                            markPinSessionUnlocked()
                            activeSheet = nil
                            runProtectedAction(pinGateAction)
                        },
                        onCancel: {
                            activeSheet = nil
                        }
                    )
                case .analytics:
                    AnalyticsDashboardView(visitors: allVisitors)
                case .importConfirmation:
                    if let summary = importSummary {
                        ImportConfirmationView(
                            summary: summary,
                            onConfirm: {
                                store.commitImport(context, pending: importPending)
                                importPending = []
                                importSummary = nil
                                activeSheet = nil
                            },
                            onCancel: {
                                importPending = []
                                importSummary = nil
                                activeSheet = nil
                            }
                        )
                        .presentationDetents([.large])
                    }
                }
            }
            .alert("Thank you for registering", isPresented: $showRegisteredAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                let registeredMessage: String = "\(lastRegisteredName): Your information has been recorded successfully.\n\nThe information collected is for safety and security purposes and all personal details will be stored in accordance with the Cemex Privacy Policy available at cemex.co.uk"
                Text(registeredMessage)
                    .multilineTextAlignment(.center)
            }
            // Ask if they've blocked a car when a car reg is provided
            .alert("Have you blocked a car in?", isPresented: $showBlockedCarPrompt) {
                Button("No", role: .cancel) {
                    blockedCar = false
                    pagerNumber = ""
                    if pendingSubmit {
                        showingInduction = true
                        // pendingSubmit will be cleared in the induction completion handler
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
                    let currentNumeric = pagerNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                    let normalizedUsedPagers: Set<String> = usedPagers
                    let effectiveUsedPagers: Set<String> = normalizedUsedPagers.subtracting(currentNumeric.isEmpty ? [] : [currentNumeric])
                    let pagerInUseError: Bool = !currentNumeric.isEmpty && normalizedUsedPagers.contains(currentNumeric)
                    let pagerInUseMessage: String = "That pager is currently in use. Please choose another."

                    Form {
                        Section {
                            Text("Kindly obtain a pager from Reception; your vehicle is obstructing another vehicle. If the person you are blocking in needs to move their car, we will buzz you. We would appreciate your prompt attention if your pager buzzes. Please select an available pager from the list.")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.orange.opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                                        )
                                )
                                .padding(.vertical, 4)
                            VStack(alignment: .leading, spacing: 4) {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                                    ForEach(availablePagerRange, id: \.self) { i in
                                        let tag = String(i)
                                        let isTaken = effectiveUsedPagers.contains(tag)
                                        let isSelected = pagerNumber == tag
                                        Button {
                                            if !isTaken { pagerNumber = tag }
                                        } label: {
                                            HStack(spacing: 6) {
                                                Circle()
                                                    .fill(isTaken ? Color.red : Color.green)
                                                    .frame(width: 10, height: 10)
                                                Text("Pager \(i)")
                                                    .fontWeight(isSelected ? .bold : .regular)
                                                if isSelected {
                                                    Image(systemName: "checkmark")
                                                        .imageScale(.small)
                                                }
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray6))
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
                                .padding(.top, 4)

                                if pagerInvalid {
                                    Text("Pager selection is required").font(.caption2).foregroundStyle(.red)
                                }
                                if pagerInUseError {
                                    Text(pagerInUseMessage)
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                    .navigationTitle("Contact Pager")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") {
                                blockedCar = false
                                pagerNumber = ""
                                showPagerPrompt = false
                                pendingSubmit = false
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Save") {
                                if normalizedUsedPagers.contains(currentNumeric) || currentNumeric.isEmpty {
                                    pagerNumber = ""
                                    return
                                }
                                showPagerPrompt = false
                                if pendingSubmit {
                                    showingInduction = true
                                    // pendingSubmit will be cleared in the induction completion handler
                                }
                            }
                            .disabled(currentNumeric.isEmpty || normalizedUsedPagers.contains(currentNumeric))
                        }
                    }
                }
                .interactiveDismissDisabled(true)
            }
    }

    // MARK: - Cover, sign-in-book, overlays (second piece of decorator chain)

    @ViewBuilder
    private var decoratedContentPart2: some View {
        decoratedContentPart1
            // Induction flow full-screen
            .fullScreenCover(isPresented: $showingInduction) {
                InductionFlowView(
                    imageNames: inductionImages,
                    visitorFirstName: firstName,
                    visitorLastName: lastName
                ) { confirmed in
                    showingInduction = false
                    if confirmed {
                        submit()
                    }
                    pendingSubmit = false
                }
                .ignoresSafeArea()
            }
            .overlay(alignment: .top) {
                checkoutBanner
            }
            .ignoresSafeArea(.keyboard)
    }

    // MARK: - Lifecycle onChange handlers (third piece)

    @ViewBuilder
    private var decoratedContentPart3: some View {
        decoratedContentPart2
            .onChange(of: showPagerPrompt) { oldValue, newValue in
                if oldValue == true && newValue == false {
                    if pendingSubmit {
                        showingInduction = true
                    }
                    pendingSubmit = false
                }
            }
            .onChange(of: showBlockedCarPrompt) { oldValue, newValue in
                if oldValue == true && newValue == false {
                    if pendingSubmit && !showPagerPrompt && !blockedCar {
                        showingInduction = true
                        pendingSubmit = false
                    }
                }
            }
            .onChange(of: store.lastError) { _, newValue in
                if newValue != nil {
                    showPersistenceError = true
                }
            }
            .onAppear {
                // Run a catch-up pass on launch so overnight records are closed even
                // if the app was not running at the scheduled timer time.
                store.autoCheckoutPreviousDay(context, at: Date())
                if autoCheckoutEnabled { startScheduler() }
                if autoBackupEnabled { startBackupScheduler() }
            }
            .onDisappear {
                scheduler.cancel()
                backupScheduler.cancel()
            }
            .onChange(of: autoCheckoutEnabled) { _, enabled in
                if enabled { startScheduler() } else { scheduler.cancel() }
            }
            .onChange(of: autoCheckoutHour) { _, _ in
                if autoCheckoutEnabled { startScheduler() }
            }
            .onChange(of: autoCheckoutMinute) { _, _ in
                if autoCheckoutEnabled { startScheduler() }
            }
            .onChange(of: autoBackupEnabled) { _, enabled in
                if enabled { startBackupScheduler() } else { backupScheduler.cancel() }
            }
    }

    // MARK: - File importer, import confirmation sheet and error alert (fourth piece)

    @ViewBuilder
    private var decoratedContent: some View {
        decoratedContentPart3
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let (summary, pending) = store.previewImport(from: url, context: context)
                    importSummary = summary
                    importPending = pending
                    activeSheet = .importConfirmation
                case .failure(let error):
                    store.lastError = .importMessage("Could not open file: \(error.localizedDescription)")
                    showPersistenceError = true
                }
            }
            .alert("Error", isPresented: $showPersistenceError, presenting: store.lastError) { _ in
                Button("OK", role: .cancel) {
                    store.lastError = nil
                }
            } message: { error in
                Text(error.localizedDescription)
            }
    }

    private var isValid: Bool {
        let hasBasics = !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !visiting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !badgeNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let needsPager = blockedCar
        let hasPagerIfNeeded = !needsPager || !pagerNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasBasics && hasPagerIfNeeded
    }

    private func submit() {
        guard isValid else { return }
        
        let name = firstName + " " + lastName
        
        // pagerNumber is always a bare numeric string from the picker; just trim whitespace.
        let normalizedPager = pagerNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let pagerForStorage: String? = normalizedPager.isEmpty ? nil : normalizedPager

        store.signIn(context,
                     firstName: firstName,
                     lastName: lastName,
                     company: company,
                     visiting: visiting,
                     carRegistration: carRegistration,
                     blockedCar: blockedCar,
                     pagerNumber: pagerForStorage,
                     badgeNumber: badgeNumber)
        if store.lastError != nil {
            return
        }
        hasAttemptedSubmit = false
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
    
    private func startScheduler() {
        // Cancel any existing timer before scheduling a new one to prevent stacking.
        scheduler.cancel()
        scheduler.scheduleDailyCheckout(atHour: autoCheckoutHour, minute: autoCheckoutMinute) {
            // Pass the actual fire time so checkout records the real time rather than a hardcoded value.
            store.autoCheckoutPreviousDay(context, at: Date())
        }
    }

    private func startBackupScheduler() {
        backupScheduler.cancel()
        backupScheduler.scheduleDailyBackup(atHour: 6, minute: 0) {
            let csv = store.backupCSVString(from: allVisitors)
            BackupScheduler.writeBackup(csvString: csv)
        }
    }

    private func runManualBackup() {
        let csv = store.backupCSVString(from: allVisitors)
        if let url = BackupScheduler.writeBackup(csvString: csv) {
            shareItem = ShareItem(url: url)
        } else {
            store.lastError = .importMessage("Backup failed: could not write file.")
            showPersistenceError = true
        }
    }


    private func showSignedOutBannerTemporarily() {
        withAnimation { showCheckoutBanner = true }
        hapticGenerator.prepare()
        hapticGenerator.notificationOccurred(.success)
    }
    
    private func exportCSV(from visitors: [Visitor]) -> URL? {
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
            "Auto Logged Out"
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
                v.wasAutoCheckedOut ? "Yes" : "No"
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
    
    private var registerButton: some View {
        Button(action: {
            hasAttemptedSubmit = true
            guard isValid else { return }
            if !carRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pendingSubmit = true
                showBlockedCarPrompt = true
            } else {
                pendingSubmit = true
                showingInduction = true
            }
        }) {
            Label("Register", systemImage: "person.badge.plus")
                .font(.title3)
                .fontWeight(.semibold)
                .imageScale(.large)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.cemexBlue)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.cemexBlue.opacity(0.35), radius: 6, x: 0, y: 3)
    }

    private var leavingButton: some View {
        Button {
            activeSheet = .leaving
        } label: {
            Label("I'm Leaving", systemImage: "door.right.hand.open")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var signInBookButton: some View {
        Button {
            requestProtectedAccess(for: .signInBook)
        } label: {
            Label("Sign In Book", systemImage: "book.closed")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
        }
        .buttonStyle(.bordered)
        .tint(.cemexBlue)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private var settingsMenu: some View {
        Menu {
            Button {
                requestProtectedAccess(for: .exportCSV)
            } label: {
                Label("Export CSV", systemImage: "square.and.arrow.up")
            }
            .disabled(allVisitors.isEmpty)

            Button {
                requestProtectedAccess(for: .fireRollCall)
            } label: {
                Label("Fire Alarm Roll Call", systemImage: "alarm")
            }

            Button {
                activeSheet = .about
            } label: {
                Label("About", systemImage: "info.circle")
            }
            
            Button {
                requestProtectedAccess(for: .settings)
            } label: {
                Label("Settings", systemImage: "slider.horizontal.3")
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

    private var checkoutBanner: some View {
        Group {
            if showCheckoutBanner {
                VStack {
                    Spacer(minLength: 0)
                    VStack(spacing: 8) {
                        Text("Thank you for visiting. Have a safe journey")
                            .font(.largeTitle).bold()
                            .multilineTextAlignment(.center)
                        Text("Don't forget to return your badge and pager (if you have one) to reception. Thank you again.")
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.9))
                        Button("Done") {
                            withAnimation { showCheckoutBanner = false }
                        }
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(.systemGray5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(.systemGray3), lineWidth: 1)
                        )
                        .foregroundStyle(.primary)
                        .padding(.top, 12)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.vertical, 28)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.green)
                            .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: showCheckoutBanner)
            }
        }
    }

    private func requestProtectedAccess(for action: ProtectedAction) {
        if isPinSessionValid {
            runProtectedAction(action)
            return
        }
        pinGateAction = action
        activeSheet = .pinGate
    }

    private func protectedActionName(for action: ProtectedAction) -> String {
        switch action {
        case .settings: return "Settings"
        case .exportCSV: return "Export CSV"
        case .signInBook: return "Sign In Book"
        case .fireRollCall: return "Fire Alarm Roll Call"
        case .analytics: return "Analytics Dashboard"
        }
    }

    private func runProtectedAction(_ action: ProtectedAction) {
        switch action {
        case .settings:
            activeSheet = .settings
        case .exportCSV:
            if let url = exportCSV(from: allVisitors) {
                shareItem = ShareItem(url: url)
            } else {
                store.lastError = .importMessage("Export failed: could not create CSV file.")
                showPersistenceError = true
            }
        case .signInBook:
            activeSheet = .signInBook
        case .fireRollCall:
            activeSheet = .rollCall
        case .analytics:
            activeSheet = .analytics
        }
    }

    private var isPinSessionValid: Bool {
        guard pinLastUnlockTimestamp > 0 else { return false }
        let lastUnlock = Date(timeIntervalSince1970: pinLastUnlockTimestamp)
        return Date().timeIntervalSince(lastUnlock) < pinSessionTimeout
    }

    private func markPinSessionUnlocked() {
        pinLastUnlockTimestamp = Date().timeIntervalSince1970
    }
}


private struct InductionFlowView: View {
    let imageNames: [String]
    let visitorFirstName: String
    let visitorLastName: String
    let onComplete: (Bool) -> Void

    @State private var index: Int = 0
    @State private var showingSignatureSheet: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                TabView(selection: $index) {
                    ForEach(Array(imageNames.enumerated()), id: \.offset) { i, name in
                        ZoomableImage(name: name)
                            .tag(i)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if index < imageNames.count - 1 {
                    Button {
                        withAnimation { index += 1 }
                    } label: {
                        Label("Next", systemImage: "chevron.right")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .padding(.horizontal)
                } else {
                    Button {
                        showingSignatureSheet = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "signature")
                                .font(.title3)
                            Text("Tap here to sign")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.cemexBlue)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }
            }
            .navigationTitle("Visitor Induction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onComplete(false) }
                }
            }
        }
        .ignoresSafeArea(edges: [.bottom])
        .sheet(isPresented: $showingSignatureSheet) {
            InductionSignatureSheet(
                firstName: visitorFirstName,
                lastName: visitorLastName
            ) { confirmed in
                showingSignatureSheet = false
                if confirmed {
                    onComplete(true)
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Signature confirmation sheet

private struct InductionSignatureSheet: View {
    let firstName: String
    let lastName: String
    let onDismiss: (Bool) -> Void

    @State private var signatureVisible = false

    var body: some View {
        VStack(spacing: 0) {
            // Icon + heading
            VStack(spacing: 10) {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.cemexBlue)
                    .padding(.top, 32)

                Text("Confirm Understanding")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("By signing below, you confirm that you have read and fully understood the Cemex site induction information.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 2)
            }

            Divider()
                .padding(.vertical, 28)

            // Signature box
            Text("\(firstName) \(lastName)")
                .font(.custom("BradleyHandITCTT-Bold", size: 58))
                .foregroundStyle(Color(red: 0/255, green: 30/255, blue: 100/255))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .padding(.horizontal, 28)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color(red: 0/255, green: 30/255, blue: 100/255).opacity(0.25), lineWidth: 1.5)
                        )
                )
                .padding(.horizontal, 24)
                .scaleEffect(signatureVisible ? 1 : 0.75)
                .opacity(signatureVisible ? 1 : 0)

            Spacer()

            // Buttons
            VStack(spacing: 10) {
                Button {
                    onDismiss(true)
                } label: {
                    Text("I Agree")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.cemexBlue)
                .padding(.horizontal, 24)

                Button(role: .cancel) {
                    onDismiss(false)
                } label: {
                    Text("Go Back")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.15)) {
                signatureVisible = true
            }
        }
    }
}

private struct ZoomableImage: View {
    let name: String
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            if let uiImage = UIImage(named: name) {
                let image = Image(uiImage: uiImage)
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                    .scaleEffect(scale)
                    .gesture(MagnificationGesture()
                        .onChanged { value in
                            scale = min(max(1.0, lastScale * value), 4.0)
                        }
                        .onEnded { _ in
                            lastScale = scale
                        }
                    )
                    .animation(.easeInOut(duration: 0.15), value: scale)
                    .accessibilityLabel(Text("Induction image"))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.15))
                    Text("Missing image: \(name)")
                        .foregroundStyle(.secondary)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(visitor.fullName)
                                        .font(.headline)
                                    Text(visitor.company)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("Car: \(visitor.carRegistration.isEmpty ? "None" : visitor.carRegistration)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    let pagerString: String = {
                                        if let p = visitor.pagerNumber, !p.isEmpty { return "Pager: " + p }
                                        return "Pager: None"
                                    }()
                                    Text(pagerString)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("Badge: \(visitor.badgeNumber)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("Checked in: \(dateTime(visitor.checkIn))")
                                }
                                Spacer(minLength: 8)
                                Button(role: .destructive) {
                                    store.checkOut(context, visitor)
                                    onCheckedOut(visitor.fullName)
                                } label: {
                                    Label("Check out", systemImage: "door.right.hand.open")
                                }
                                .buttonStyle(.borderedProminent)
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
                                Text("Car: \(visitor.carRegistration.isEmpty ? "None" : visitor.carRegistration)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                let pagerStringArchived: String = {
                                    if let p = visitor.pagerNumber, !p.isEmpty { return "Pager: " + p }
                                    return "Pager: None"
                                }()
                                Text(pagerStringArchived)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Badge: \(visitor.badgeNumber)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Checked in: \(dateTime(visitor.checkIn))")
                                let checkedOutString: String = {
                                    if let date = visitor.checkOut { return "Checked out: " + dateTime(date) }
                                    return "Checked out: "
                                }()
                                Text(checkedOutString)
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

    private func dateTime(_ date: Date) -> String {
        DateFormatter.mediumDateTime.string(from: date)
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
    @State private var snapshot: [Visitor]? = nil

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
                            Text(dateTime(v.checkIn)).font(.caption)
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
                            LabeledContent("Checked in", value: dateTime(v.checkIn))
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
        let source = snapshot ?? activeVisitors
        if searchText.isEmpty { return source }
        let q = searchText.lowercased()
        return source.filter { v in
            v.fullName.lowercased().contains(q) || v.company.lowercased().contains(q) || v.carRegistration.lowercased().contains(q)
        }
    }

    private func dateTime(_ date: Date) -> String {
        DateFormatter.mediumDateTime.string(from: date)
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
                    Text("Developed by Clint Yarwood (Cemex UK IT) for visitor registration at CEMEX UK HQ.")
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
    @State private var snapshot: [Visitor] = []
    let visitors: [Visitor]
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List(snapshot, id: \.id) { visitor in
                HStack {
                    Text(visitor.fullName)
                    Spacer()
                    if confirmedOut.contains(visitor.id) {
                        Button("Confirmed") { }
                            .buttonStyle(.bordered)
                            .tint(.green)
                            .disabled(true)
                    } else {
                        Button("Confirm Out") {
                            store.checkOut(context, visitor)
                            _ = withAnimation {
                                confirmedOut.insert(visitor.id)
                            }
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
            .onAppear {
                // Take a local snapshot so rows persist visually after checkout
                if snapshot.isEmpty {
                    snapshot = visitors
                }
            }
        }
    }
}

private struct AutoCheckoutSettingsView: View {
    @Binding var enabled: Bool
    @Binding var hour: Int
    @Binding var minute: Int
    @Binding var autoBackupEnabled: Bool
    var onManualBackup: () -> Void
    var onImportCSV: () -> Void
    var onOpenAnalytics: () -> Void
    var existingBackups: [URL]
    @Environment(\.dismiss) private var dismiss
    @State private var showingPinChange = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Auto-checkout") {
                    Toggle("Enable auto-checkout", isOn: $enabled)
                    HStack {
                        Picker("Hour", selection: $hour) {
                            ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                        }
                        Picker("Minute", selection: $minute) {
                            ForEach([0,5,10,15,20,25,30,35,40,45,50,55], id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                        }
                    }
                    .labelsHidden()
                }

                Section("Backup") {
                    Toggle("Automatic daily backup (06:00)", isOn: $autoBackupEnabled)

                    Button {
                        onManualBackup()
                        dismiss()
                    } label: {
                        Label("Export Backup Now", systemImage: "arrow.up.doc")
                    }

                    if let latest = existingBackups.first {
                        LabeledContent("Latest backup") {
                            Text(latest.deletingPathExtension().lastPathComponent
                                    .replacingOccurrences(of: "visitor_backup_", with: ""))
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("Saved backups") {
                        Text("\(existingBackups.count) file\(existingBackups.count == 1 ? "" : "s") in Documents")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Restore") {
                    Button {
                        onImportCSV()
                        dismiss()
                    } label: {
                        Label("Import CSV…", systemImage: "arrow.down.doc")
                    }
                    Text("Imports visitor records from a CSV backup. Duplicate entries are skipped. Missing columns (older files) receive safe default values.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Insights") {
                    Button {
                        onOpenAnalytics()
                        dismiss()
                    } label: {
                        Label("Analytics Dashboard", systemImage: "chart.bar.xaxis")
                    }
                    Text("View visitor trends, totals, busiest times, and top departments.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Security") {
                    Button {
                        showingPinChange = true
                    } label: {
                        Label("Change PIN", systemImage: "key")
                    }
                    Text("The PIN is stored securely in the iOS Keychain and will be requested again after 5 minutes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showingPinChange) {
                PinChangeSheet()
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

/// Shown after parsing a CSV import so the user can review counts before committing.
private struct ImportConfirmationView: View {
    let summary: VisitorStore.ImportSummary
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Import Preview") {
                    LabeledContent("New records to import", value: "\(summary.imported)")
                    LabeledContent("Duplicates (will be skipped)", value: "\(summary.skipped)")
                    LabeledContent("Rows failed to parse", value: "\(summary.failed)")
                }
                if summary.imported == 0 {
                    Section {
                        Text("Nothing to import. All records in the file already exist in the app, or no valid rows were found.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Import CSV")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Import \(summary.imported) Records") { onConfirm() }
                        .disabled(summary.imported == 0)
                        .bold()
                }
            }
        }
    }
}

// MARK: - Brand Header

private struct BrandHeader: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            // Blue band
            LinearGradient(
                colors: [
                    Color.cemexBlue,
                    Color(red: 1/255, green: 35/255, blue: 100/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                // Logo and text sit inside the blue band
                VStack(spacing: 14) {
                    // White pill backing so the logo is clearly visible on dark blue
                    Image("cemex_logo")
                        .renderingMode(.original)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(maxWidth: 200)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white)
                                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
                        )
                        .accessibilityHidden(true)

                    Text("Welcome to Cemex UK HQ")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    Text("Please sign in below")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top, 32)
                .padding(.bottom, 28)

                // Light accent strip below the blue band for contrast and polish
                LinearGradient(
                    colors: [
                        Color(red: 220/255, green: 230/255, blue: 248/255),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 56)
            }
        }
    }
}

// MARK: - FormField (replaces inputTextField free function)

private struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isInvalid: Bool = false
    var errorMessage: String? = nil
    var textCapitalization: TextInputAutocapitalization? = .words
    var keyboardType: UIKeyboardType = .default
    var autocorrectionDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(textCapitalization)
                .keyboardType(keyboardType)
                .autocorrectionDisabled(autocorrectionDisabled)
                .font(.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isInvalid ? Color.red : Color.secondary.opacity(0.2),
                                lineWidth: isInvalid ? 1.5 : 1)
                )

            if isInvalid, let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - VisitorFormFields (replaces RegularFormFields + CompactFormFields)

private struct VisitorFormFields: View {
    let useColumns: Bool

    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var company: String
    @Binding var visiting: String
    @Binding var carRegistration: String
    @Binding var badgeNumber: String
    @Binding var showBlockedCarPrompt: Bool

    let firstNameInvalid: Bool
    let lastNameInvalid: Bool
    let companyInvalid: Bool
    let visitingInvalid: Bool
    let badgeInvalid: Bool

    let focusedField: FocusState<WelcomeView.Field?>.Binding

    var body: some View {
        VStack(spacing: 14) {
            fieldRow { firstNameField } right: { lastNameField }
            fieldRow { companyField } right: { visitingField }
            fieldRow { badgeField } right: { carRegField }
        }
    }

    @ViewBuilder
    private func fieldRow<L: View, R: View>(
        @ViewBuilder _ left: () -> L,
        @ViewBuilder right: () -> R
    ) -> some View {
        if useColumns {
            HStack(alignment: .top, spacing: 16) { left(); right() }
        } else {
            VStack(spacing: 14) { left(); right() }
        }
    }

    private var firstNameField: some View {
        FormField(label: "First Name", placeholder: "First name",
                  text: autoCapitalizedWordsBinding($firstName),
                  isInvalid: firstNameInvalid,
                  errorMessage: "First name is required")
            .focused(focusedField, equals: .firstName)
            .submitLabel(.next)
            .onSubmit { focusedField.wrappedValue = .lastName }
    }

    private var lastNameField: some View {
        FormField(label: "Last Name", placeholder: "Last name",
                  text: autoCapitalizedWordsBinding($lastName),
                  isInvalid: lastNameInvalid,
                  errorMessage: "Last name is required")
            .focused(focusedField, equals: .lastName)
            .submitLabel(.next)
            .onSubmit { focusedField.wrappedValue = .company }
    }

    private var companyField: some View {
        FormField(label: "Company", placeholder: "Company",
                  text: autoCapitalizedWordsBinding($company),
                  isInvalid: companyInvalid,
                  errorMessage: "Company is required")
            .focused(focusedField, equals: .company)
            .submitLabel(.next)
            .onSubmit { focusedField.wrappedValue = .visiting }
    }

    private var visitingField: some View {
        FormField(label: "Visiting", placeholder: "Who are you visiting",
                  text: autoCapitalizedWordsBinding($visiting),
                  isInvalid: visitingInvalid,
                  errorMessage: "Who you are visiting is required")
            .focused(focusedField, equals: .visiting)
            .submitLabel(.next)
            .onSubmit { focusedField.wrappedValue = .badge }
    }

    private var badgeField: some View {
        FormField(label: "Badge Number", placeholder: "Badge number",
                  text: Binding(get: { badgeNumber },
                                set: { badgeNumber = $0.filter { $0.isNumber } }),
                  isInvalid: badgeInvalid,
                  errorMessage: "Badge number is required",
                  textCapitalization: .never,
                  keyboardType: .numbersAndPunctuation,
                  autocorrectionDisabled: true)
            .focused(focusedField, equals: .badge)
            .submitLabel(.next)
            .onSubmit { focusedField.wrappedValue = .carReg }
    }

    private var carRegField: some View {
        FormField(label: "Car Registration", placeholder: "Optional",
                  text: Binding(
                    get: { carRegistration },
                    set: { carRegistration = String($0.uppercased().filter { $0.isNumber || ("A"..."Z").contains(String($0)) }) }
                  ),
                  textCapitalization: .characters,
                  keyboardType: .asciiCapable,
                  autocorrectionDisabled: true)
            .focused(focusedField, equals: .carReg)
            .submitLabel(.done)
            .onSubmit {
                if !carRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    showBlockedCarPrompt = true
                }
                focusedField.wrappedValue = nil
            }
    }

    private func autoCapitalizedWordsBinding(_ binding: Binding<String>) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                binding.wrappedValue = capitalizingWordInitials(in: newValue)
            }
        )
    }

    private func capitalizingWordInitials(in text: String) -> String {
        var result = ""
        var shouldCapitalizeNext = true

        for character in text {
            if shouldCapitalizeNext, character.isLetter {
                result.append(contentsOf: String(character).uppercased())
                shouldCapitalizeNext = false
            } else {
                result.append(character)
                if character.isWhitespace || character == "-" {
                    shouldCapitalizeNext = true
                }
            }
        }

        return result
    }
}

#Preview {
    RootView()
        .modelContainer(for: Visitor.self, inMemory: true)
        .environment(VisitorStore())
}
