import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers
import Charts

protocol VisitorStoreTolerantPreviewing {
    func previewImportTolerant(data: Data, context: ModelContext) -> (VisitorStore.ImportSummary, [Visitor])
}

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
    @State private var showPagerPrompt = false
    @State private var registrationFlow: RegistrationFlow = .idle
    @State private var deferredSelection: DeferredSelection?
    
    @State private var showingInduction = false
    @State private var inductionImages: [String] = ["induction_1", "induction_2", "induction_3", "induction_4"]
    
    @State private var lastRegisteredName: String = ""
    @State private var isSigningInPreRegisteredVisitor = false
    @State private var selectedPreRegisteredVisitorID: UUID?
    
    @State private var showCheckoutBanner = false
    @State private var checkoutBannerSecondsRemaining = 5
    @State private var checkoutBannerCountdownID = UUID()

    @State private var kioskBannerText = ""
    @State private var showKioskBanner = false
    @State private var kioskBannerTask: Task<Void, Never>? = nil
    
    @AppStorage("autoCheckoutEnabled") private var autoCheckoutEnabled: Bool = false
    @AppStorage("autoCheckoutHour") private var autoCheckoutHour: Int = 5
    @AppStorage("autoCheckoutMinute") private var autoCheckoutMinute: Int = 0
    @AppStorage("autoReturnPagersOnAutoCheckout") private var autoReturnPagersOnAutoCheckout: Bool = false
    @AppStorage("kioskModeEnabled") private var kioskModeEnabled: Bool = false
    @AppStorage("lastAutoCheckoutRun") private var lastAutoCheckoutRun: Double = 0
    @State private var scheduler = AutoCheckoutScheduler()

    // Backup scheduler
    @AppStorage("autoBackupEnabled") private var autoBackupEnabled: Bool = false
    @State private var backupScheduler = BackupScheduler()

    // CSV import state
    @State private var showingImportPicker = false
    @State private var importPending: [Visitor] = []
    @State private var importSummary: VisitorStore.ImportSummary? = nil
    @State private var queuedImportAfterDismiss = false

    // Reuse a single generator instance rather than creating one per haptic call.
    private let hapticGenerator = UINotificationFeedbackGenerator()
    private let pinSessionTimeout: TimeInterval = 5 * 60
    private let availablePagerRange: ClosedRange<Int> = 1...30

    @State private var pinGateAction: ProtectedAction = .settings
    @State private var queuedProtectedActionAfterDismiss: ProtectedAction?
    @AppStorage("pinLastUnlockTimestamp") private var pinLastUnlockTimestamp: Double = 0

    // Added state for recently freed pagers and grace window duration
    @State private var recentlyFreedPagers: Set<String> = []
    @State private var pagerGraceWindowSeconds: Int = 3

    // New consolidated alert enum and state
    enum AppAlert: Identifiable, Equatable {
        case registered(name: String)
        case blockedCarPrompt
        case badgeConflict
        case duplicateSignIn
        case kioskConfirm(enabled: Bool)
        case pinReset
        case persistenceError(message: String)
        var id: String {
            switch self {
            case .registered: return "registered"
            case .blockedCarPrompt: return "blockedCarPrompt"
            case .badgeConflict: return "badgeConflict"
            case .duplicateSignIn: return "duplicateSignIn"
            case .kioskConfirm(let enabled): return enabled ? "kioskConfirm_disable" : "kioskConfirm_enable"
            case .pinReset: return "pinReset"
            case .persistenceError: return "persistenceError"
            }
        }
    }
    @State private var activeAlert: AppAlert?

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
        case preRegistrationAdmin
        case kioskModeToggle
    }

    private enum ActiveSheet: String, Identifiable {
        case about
        case settings
        case leaving
        case signInBook
        case rollCall
        case staffPager
        case returnPagers
        case pinGate
        case analytics
        case importConfirmation
        case preRegistrationList
        case preRegistrationAdmin
        case returningVisitorSearch
        case pinChange

        var id: String { rawValue }
    }

    private enum RegistrationFlow {
        case idle
        case waitingBlockedCarDecision
        case waitingPagerSelection
        case waitingForInduction
    }

    private enum DeferredSelection {
        case preRegistered(id: UUID, droveCarRegistration: String?)
        case returningVisitor(id: UUID, droveCarRegistration: String?)
    }

    // Track pagers already in use by active visitors.
    // Strip any legacy "Pager " prefix so older stored values ("Pager 3") compare
    // correctly against the bare numeric picker tags ("3").
    private var usedPagers: Set<String> {
        let visitorPagers = Set(activeVisitors.compactMap { visitor -> String? in
            guard let raw = visitor.pagerNumber else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            let lower = trimmed.lowercased()
            return lower.hasPrefix("pager ") ? String(trimmed.dropFirst("pager ".count)) : trimmed
        })
        let staffPagers = Set(activeStaffPagerIssues.map { $0.pagerNumber.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        let all = visitorPagers.union(staffPagers)
        return all.subtracting(recentlyFreedPagers)
    }

    @Query(filter: #Predicate<Visitor> { $0.checkOut == nil }, sort: [SortDescriptor(\Visitor.checkIn, order: .reverse)]) private var activeVisitors: [Visitor]
    @Query(filter: #Predicate<StaffPagerIssue> { $0.returnedAt == nil }, sort: [SortDescriptor(\StaffPagerIssue.issuedAt, order: .reverse)]) private var activeStaffPagerIssues: [StaffPagerIssue]
    @Query(sort: [SortDescriptor(\Visitor.checkIn, order: .reverse)]) private var allVisitors: [Visitor]
    @Query(sort: [SortDescriptor(\PreRegisteredVisitor.createdAt, order: .reverse)]) private var preRegisteredVisitors: [PreRegisteredVisitor]
    
    // Share support for exported CSV (ActivityView presenter)
    struct ShareItem: Identifiable {
        let url: URL
        var deleteOnDismiss: Bool = true
        var id: URL { url }
    }
    @State private var shareItem: ShareItem?
    
    init() {}
    
    private var firstNameInvalid: Bool { hasAttemptedSubmit && firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var lastNameInvalid: Bool { hasAttemptedSubmit && lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var companyInvalid: Bool { hasAttemptedSubmit && company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var visitingInvalid: Bool { hasAttemptedSubmit && visiting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var badgeInvalid: Bool { hasAttemptedSubmit && badgeNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var pagerInvalid: Bool { blockedCar && pagerNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var badgeAlreadyInUse: Bool {
        let entered = badgeNumber.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !entered.isEmpty else { return false }
        return activeVisitors.contains { visitor in
            visitor.badgeNumber.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == entered
        }
    }
    private var hasDuplicateActiveSignIn: Bool {
        let enteredFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let enteredLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !enteredFirst.isEmpty, !enteredLast.isEmpty else { return false }
        return activeVisitors.contains { visitor in
            visitor.firstName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == enteredFirst &&
            visitor.lastName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == enteredLast
        }
    }

    private func allocatedBadges(on date: Date) -> Set<String> {
        // Active visitors only conflict on the actual current day
        let activeOnDate = activeVisitors.compactMap { v -> String? in
            let badge = normalizedBadge(v.badgeNumber)
            guard !badge.isEmpty else { return nil }
            if Calendar.current.isDateInToday(date) {
                return Calendar.current.isDateInToday(v.checkIn) ? badge : nil
            } else {
                return nil
            }
        }
        // Pre-registered visitors conflict if their intended visit date matches the given date.
        let preregOnDate = preRegisteredVisitors.compactMap { p -> String? in
            let badge = normalizedBadge(p.badgeNumber)
            guard !badge.isEmpty else { return nil }
            // Only enforce conflicts when a visit date is explicitly set.
            if let visitDate = p.visitDate, Calendar.current.isDate(visitDate, inSameDayAs: date) {
                return badge
            }
            return nil
        }
        return Set(activeOnDate + preregOnDate)
    }
    
    private func normalizedBadge(_ raw: String) -> String {
        return raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func scheduledCheckoutDate(for date: Date) -> Date? {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = autoCheckoutHour
        comps.minute = autoCheckoutMinute
        return Calendar.current.date(from: comps)
    }

    private func shouldRunAutoCheckoutNow(now: Date = Date()) -> Bool {
        guard autoCheckoutEnabled else { return false }
        guard let scheduledToday = scheduledCheckoutDate(for: now) else { return false }
        if lastAutoCheckoutRun > 0 {
            let last = Date(timeIntervalSince1970: lastAutoCheckoutRun)
            if Calendar.current.isDate(last, inSameDayAs: now) { return false }
        }
        return now >= scheduledToday
    }

    var body: some View {
        decoratedContent
    }

    // MARK: - Main layout content

    private var mainContent: some View {
        ZStack {
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
                showBlockedCarPrompt: Binding(get: { activeAlert == .blockedCarPrompt }, set: { newValue in if newValue { activeAlert = .blockedCarPrompt } }),
                firstNameInvalid: firstNameInvalid,
                lastNameInvalid: lastNameInvalid,
                companyInvalid: companyInvalid,
                visitingInvalid: visitingInvalid,
                badgeInvalid: badgeInvalid,
                focusedField: $focusedField
            )

            formCardButtons

            statusSummary
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
            HStack(spacing: 12) {
                registerButton
                leavingButton
            }

            HStack(spacing: 12) {
                preRegisteredButton
                returningVisitorButton
            }

            HStack(spacing: 12) {
                if !kioskModeEnabled {
                    signInBookButton
                    utilityActionButtons
                        .frame(maxWidth: .infinity, minHeight: 52)
                } else {
                    Spacer()
                    fireRollCallShortcutButton
                        .frame(minHeight: 52)
                    kioskModeButton
                        .frame(minHeight: 52)
                    Spacer()
                }
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
                        if item.deleteOnDismiss {
                            try? FileManager.default.removeItem(at: item.url)
                        }
                        shareItem = nil
                        refocusFirstNameIfIdle()
                    }
            }
            .sheet(item: $activeSheet, onDismiss: {
                if queuedImportAfterDismiss {
                    queuedImportAfterDismiss = false
                    // Present the file importer after the settings sheet closes.
                    DispatchQueue.main.async { showingImportPicker = true }
                }
                if let action = queuedProtectedActionAfterDismiss {
                    queuedProtectedActionAfterDismiss = nil
                    requestProtectedAccess(for: action)
                }
                applyDeferredSelectionIfNeeded()
                refocusFirstNameIfIdle()
            }) { sheet in
                switch sheet {
                case .about:
                    NavigationStack {
                        AboutView()
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "common.close")) { activeSheet = nil } }
                            }
                    }
                case .settings:
                    AutoCheckoutSettingsView(
                        enabled: $autoCheckoutEnabled,
                        hour: $autoCheckoutHour,
                        minute: $autoCheckoutMinute,
                        autoBackupEnabled: $autoBackupEnabled,
                        autoReturnPagersOnAutoCheckout: $autoReturnPagersOnAutoCheckout,
                        onManualBackup: runManualBackup,
                        onImportCSV: {
                            queuedImportAfterDismiss = true
                            activeSheet = nil
                        },
                        onLockAdminSession: invalidatePinSession,
                        onOpenAnalytics: {
                            queuedProtectedActionAfterDismiss = .analytics
                            activeSheet = nil
                        },
                        existingBackups: BackupScheduler.existingBackups(),
                        onOpenPreRegistrationAdmin: {
                            queuedProtectedActionAfterDismiss = .preRegistrationAdmin
                            activeSheet = nil
                        })
                    .presentationDetents([.large])
                case .leaving:
                    NavigationStack {
                        LeavingSearchSheet(activeVisitors: activeVisitors) { visitor in
                            checkOut(visitor)
                            activeSheet = nil
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "common.close")) { activeSheet = nil } }
                        }
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                case .signInBook:
                    NavigationStack {
                        SignInBookView(activeVisitors: activeVisitors) {
                            activeSheet = nil
                        } onCheckedOut: { visitor in
                            checkOutSilently(visitor)
                            activeSheet = nil
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "common.close")) { activeSheet = nil } }
                        }
                    }
                    .interactiveDismissDisabled()
                case .rollCall:
                    FireAlarmRollCallView(
                        visitors: activeVisitors,
                        onDone: { activeSheet = nil },
                        onCheckOut: { visitor in
                            checkOutSilently(visitor)
                        },
                        onQuickSignIn: { prior in
                            quickSignIn(from: prior)
                        }
                    )
                case .staffPager:
                    NavigationStack {
                        StaffCarPagerSheet(
                            usedPagers: usedPagers,
                            availablePagerRange: availablePagerRange,
                            onIssue: { firstName, lastName, carRegistration, pagerNumber in
                                issueStaffPager(
                                    firstName: firstName,
                                    lastName: lastName,
                                    carRegistration: carRegistration,
                                    pagerNumber: pagerNumber
                                )
                            },
                            onCancel: {
                                activeSheet = nil
                            }
                        )
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "common.close")) { activeSheet = nil } }
                        }
                    }
                case .returnPagers:
                    NavigationStack {
                        ReturnPagersSheet(
                            activeIssues: activeStaffPagerIssues,
                            onReturn: { issue in
                                returnStaffPager(issue)
                            },
                            onDone: {
                                activeSheet = nil
                            }
                        )
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "common.close")) { activeSheet = nil } }
                        }
                    }
                case .pinGate:
                    PinGateSheet(
                        actionName: protectedActionName(for: pinGateAction),
                        promptText: protectedPromptText(for: pinGateAction),
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
                    NavigationStack {
                        AnalyticsDashboardView(visitors: allVisitors)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "common.close")) { activeSheet = nil } }
                            }
                    }
                case .preRegistrationList:
                    NavigationStack {
                        PreRegisteredListView(preRegisteredVisitors: preRegisteredVisitors) { selected in
                            deferredSelection = .preRegistered(id: selected.id, droveCarRegistration: nil)
                            activeSheet = nil
                        } onSelectWithCar: { selected, carRegistration in
                            deferredSelection = .preRegistered(id: selected.id, droveCarRegistration: carRegistration)
                            activeSheet = nil
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(String(localized: "common.close")) { activeSheet = nil }
                            }
                        }
                    }
                case .preRegistrationAdmin:
                    PreRegistrationAdminView(
                        preRegisteredVisitors: preRegisteredVisitors,
                        onAdd: { firstName, lastName, company, visiting, badgeNumber, visitDate in
                            addPreRegisteredVisitor(
                                firstName: firstName,
                                lastName: lastName,
                                company: company,
                                visiting: visiting,
                                badgeNumber: badgeNumber,
                                visitDate: visitDate
                            )
                        },
                        onDelete: { visitor in
                            deletePreRegisteredVisitor(visitor)
                        },
                        onDone: {
                            activeSheet = nil
                        }
                    )
                case .returningVisitorSearch:
                    NavigationStack {
                        ReturningVisitorSearchView(visitors: allVisitors) { selected in
                            deferredSelection = .returningVisitor(id: selected.id, droveCarRegistration: nil)
                            activeSheet = nil
                        } onSelectWithCar: { selected, carRegistration in
                            deferredSelection = .returningVisitor(id: selected.id, droveCarRegistration: carRegistration)
                            activeSheet = nil
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(String(localized: "common.close")) { activeSheet = nil }
                            }
                        }
                    }
                case .pinChange:
                    PinChangeSheet()
                case .importConfirmation:
                    if let summary = importSummary {
                        ImportConfirmationView(
                            summary: summary,
                            onConfirm: {
                                if store.commitImport(context, pending: importPending) {
                                    importPending = []
                                    importSummary = nil
                                    activeSheet = nil
                                } else {
                                    activeAlert = .persistenceError(message: store.lastError?.localizedDescription ?? unknownErrorMessage)
                                }
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
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .registered(let name):
                    return Alert(
                        title: Text(String(localized: "welcome.alert.registered.title")),
                        message: Text(String(format: String(localized: "welcome.alert.registered.message_template"), name)),
                        dismissButton: .default(Text(String(localized: "common.ok")))
                    )
                case .blockedCarPrompt:
                    return Alert(
                        title: Text(String(localized: "welcome.alert.blocked_car.title")),
                        message: Text(String(localized: "welcome.alert.blocked_car.message")),
                        primaryButton: .cancel(Text(String(localized: "common.no")), action: {
                            blockedCar = false
                            pagerNumber = ""
                            registrationFlow = .waitingForInduction
                            routeToInductionIfReady()
                        }),
                        secondaryButton: .default(Text(String(localized: "common.yes")), action: {
                            blockedCar = true
                            registrationFlow = .waitingPagerSelection
                            showPagerPrompt = true
                        })
                    )
                case .badgeConflict:
                    return Alert(
                        title: Text(String(localized: "welcome.alert.badge_conflict.title")),
                        message: Text(String(localized: "welcome.alert.badge_conflict.message")),
                        dismissButton: .default(Text(String(localized: "common.ok")))
                    )
                case .duplicateSignIn:
                    return Alert(
                        title: Text(String(localized: "welcome.alert.duplicate_signin.title")),
                        message: Text(String(localized: "welcome.alert.duplicate_signin.message")),
                        primaryButton: .cancel(Text(String(localized: "common.cancel"))),
                        secondaryButton: .default(Text(String(localized: "welcome.alert.duplicate_signin.continue")), action: {
                            submit(allowDuplicateSignIn: true)
                        })
                    )
                case .kioskConfirm(let enabled):
                    return Alert(
                        title: Text(enabled ? String(localized: "welcome.kiosk.confirm.disable_title") : String(localized: "welcome.kiosk.confirm.enable_title")),
                        message: Text(enabled ? String(localized: "welcome.kiosk.confirm.disable_message") : String(localized: "welcome.kiosk.confirm.enable_message")),
                        primaryButton: .cancel(Text(String(localized: "common.cancel"))),
                        secondaryButton: .default(Text(enabled ? String(localized: "welcome.kiosk.action.disable") : String(localized: "welcome.kiosk.action.enable")), action: {
                            kioskModeEnabled.toggle()
                            kioskBannerText = kioskModeEnabled ? String(localized: "welcome.kiosk.banner.enabled") : String(localized: "welcome.kiosk.banner.disabled")
                            withAnimation { showKioskBanner = true }
                            hapticGenerator.prepare()
                            hapticGenerator.notificationOccurred(.success)
                            kioskBannerTask?.cancel()
                            kioskBannerTask = Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                if !Task.isCancelled { withAnimation { showKioskBanner = false } }
                            }
                        })
                    )
                case .pinReset:
                    return Alert(
                        title: Text(String(localized: "welcome.alert.pin_reset.title")),
                        message: Text(String(localized: "welcome.alert.pin_reset.message")),
                        primaryButton: .default(Text(String(localized: "welcome.alert.pin_reset.action_set_now")), action: { activeSheet = .pinChange }),
                        secondaryButton: .cancel(Text(String(localized: "common.ok")))
                    )
                case .persistenceError(let message):
                    return Alert(
                        title: Text(String(localized: "common.error")),
                        message: Text(message),
                        dismissButton: .default(Text(String(localized: "common.ok")), action: { store.lastError = nil })
                    )
                }
            }
            // Pager sheet to capture contact number when a car is blocked
            .sheet(isPresented: $showPagerPrompt) {
                PagerSelectionSheet(
                    usedPagers: usedPagers,
                    availablePagerRange: availablePagerRange,
                    pagerNumber: $pagerNumber,
                    onCancel: {
                        blockedCar = false
                        pagerNumber = ""
                        showPagerPrompt = false
                        registrationFlow = .idle
                    },
                    onSave: { selected in
                        pagerNumber = selected
                        showPagerPrompt = false
                        registrationFlow = .waitingForInduction
                        routeToInductionIfReady()
                    }
                )
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
                    registrationFlow = .idle
                    if confirmed {
                        submit()
                    }
                }
                .ignoresSafeArea()
            }
            .overlay(alignment: .top) {
                checkoutBanner
            }
            .overlay(alignment: .top) {
                if showKioskBanner {
                    Text(kioskBannerText)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(kioskModeEnabled ? Color.blue : Color.gray)
                                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                        )
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .ignoresSafeArea(.keyboard)
    }

    // MARK: - Lifecycle onChange handlers (third piece)

    @ViewBuilder
    private var decoratedContentPart3: some View {
        decoratedContentPart2
            .onChange(of: showPagerPrompt) { oldValue, newValue in
                if oldValue == true && newValue == false {
                    routeToInductionIfReady()
                }
            }
            .onChange(of: activeAlert) { oldValue, newValue in
                if case .registered = oldValue, newValue == nil {
                    refocusFirstNameIfIdle()
                }
            }
            .onChange(of: store.lastError) { _, newValue in
                if let newValue = newValue {
                    activeAlert = .persistenceError(message: newValue.localizedDescription)
                }
            }
            .onAppear {
                if autoCheckoutEnabled { startScheduler() }
                if autoBackupEnabled { startBackupScheduler() }
                if shouldRunAutoCheckoutNow() {
                    performAutoCheckoutNow()
                }
                refocusFirstNameIfIdle()
            }
            .onDisappear {
                scheduler.cancel()
                backupScheduler.cancel()
                kioskBannerTask?.cancel()
                kioskBannerTask = nil
                showKioskBanner = false
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
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    if shouldRunAutoCheckoutNow() {
                        performAutoCheckoutNow()
                    }
                }
            }
            .onChange(of: showKioskBanner) { _, visible in
                if !visible {
                    kioskBannerTask?.cancel()
                    kioskBannerTask = nil
                }
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

                    let didStart = url.startAccessingSecurityScopedResource()
                    defer { if didStart { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let data = try Data(contentsOf: url)
                        // Try tolerant import if available via extension; else fall back to URL-based method.
                        if let tolerant = (store as AnyObject) as? VisitorStoreTolerantPreviewing {
                            let (summary, pending) = tolerant.previewImportTolerant(data: data, context: context)
                            if store.lastError == nil {
                                importSummary = summary
                                importPending = pending
                                activeSheet = .importConfirmation
                            } else {
                                importSummary = nil
                                importPending = []
                                activeAlert = .persistenceError(message: store.lastError?.localizedDescription ?? unknownErrorMessage)
                            }
                        } else {
                            let (summary, pending) = store.previewImport(from: url, context: context)
                            if store.lastError == nil {
                                importSummary = summary
                                importPending = pending
                                activeSheet = .importConfirmation
                            } else {
                                importSummary = nil
                                importPending = []
                                activeAlert = .persistenceError(message: store.lastError?.localizedDescription ?? unknownErrorMessage)
                            }
                        }
                    } catch {
                        store.lastError = .importMessage("Could not read file: \(error.localizedDescription)")
                        activeAlert = .persistenceError(message: store.lastError?.localizedDescription ?? unknownErrorMessage)
                    }

                case .failure(let error):
                    store.lastError = .importMessage("Could not open file: \(error.localizedDescription)")
                    activeAlert = .persistenceError(message: store.lastError?.localizedDescription ?? unknownErrorMessage)
                }
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

    private func submit(allowDuplicateSignIn: Bool = false) {
        guard isValid else { return }
        guard !badgeAlreadyInUse else {
            activeAlert = .badgeConflict
            return
        }
        if !allowDuplicateSignIn && hasDuplicateActiveSignIn {
            activeAlert = .duplicateSignIn
            return
        }
        
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
                     badgeNumber: badgeNumber,
                     wasPreRegistered: isSigningInPreRegisteredVisitor)
        if store.lastError != nil {
            // If sign-in fails, clear pre-registration session state to avoid
            // leaking it into a later manual registration attempt.
            isSigningInPreRegisteredVisitor = false
            selectedPreRegisteredVisitorID = nil
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
        if let selectedID = selectedPreRegisteredVisitorID,
           let matched = preRegisteredVisitors.first(where: { $0.id == selectedID }) {
            context.delete(matched)
            do {
                try context.save()
            } catch {
                context.rollback()
                store.lastError = .saveFailed(underlying: error)
                activeAlert = .persistenceError(message: store.lastError?.localizedDescription ?? unknownErrorMessage)
            }
        }
        selectedPreRegisteredVisitorID = nil
        isSigningInPreRegisteredVisitor = false
        lastRegisteredName = name
        activeAlert = .registered(name: name)
    }

    private func refocusFirstNameIfIdle() {
        guard activeSheet == nil,
              activeAlert == nil,
              !showPagerPrompt,
              !showingInduction else { return }
        DispatchQueue.main.async {
            focusedField = .firstName
        }
    }
    
    private func startScheduler() {
        // Cancel any existing timer before scheduling a new one to prevent stacking.
        scheduler.cancel()
        scheduler.scheduleDailyCheckout(atHour: autoCheckoutHour, minute: autoCheckoutMinute) {
            performAutoCheckoutNow(at: Date())
        }
    }

    private func performAutoCheckoutNow(at date: Date = Date()) {
        store.autoCheckoutAllActive(context, at: date)
        if autoReturnPagersOnAutoCheckout {
            for issue in activeStaffPagerIssues {
                store.returnStaffPager(context, issue)
            }
        }
        lastAutoCheckoutRun = date.timeIntervalSince1970
    }

    private func startBackupScheduler() {
        backupScheduler.cancel()
        backupScheduler.scheduleDailyBackup(atHour: autoCheckoutHour, minute: autoCheckoutMinute) {
            let csv = store.backupCSVString(from: allVisitors)
            BackupScheduler.writeBackup(csvString: csv)
        }
    }

    private func runManualBackup() {
        let csv = store.backupCSVString(from: allVisitors)
        if let url = BackupScheduler.writeBackup(csvString: csv) {
            shareItem = ShareItem(url: url, deleteOnDismiss: false)
        } else {
            store.lastError = .importMessage("Backup failed: could not write file.")
            activeAlert = .persistenceError(message: store.lastError?.localizedDescription ?? unknownErrorMessage)
        }
    }


    private func showSignedOutBanner() {
        checkoutBannerSecondsRemaining = 5
        checkoutBannerCountdownID = UUID()
        withAnimation { showCheckoutBanner = true }
        hapticGenerator.prepare()
        hapticGenerator.notificationOccurred(.success)
    }

    private func checkOut(_ visitor: Visitor) {
        store.checkOut(context, visitor)
        if store.lastError == nil {
            showSignedOutBanner()
            
            // Mark pager as recently freed and schedule removal after grace period
            if let pager = visitor.pagerNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !pager.isEmpty {
                recentlyFreedPagers.insert(pager)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(pagerGraceWindowSeconds) * 1_000_000_000)
                    recentlyFreedPagers.remove(pager)
                }
            }
        } else {
            activeAlert = .persistenceError(message: store.lastError?.localizedDescription ?? unknownErrorMessage)
        }
    }

    private func checkOutSilently(_ visitor: Visitor) {
        store.checkOut(context, visitor)
        if store.lastError != nil {
            activeAlert = .persistenceError(message: store.lastError?.localizedDescription ?? unknownErrorMessage)
        }
    }

    private func quickSignIn(from prior: Visitor) {
        // Reuse prior visitor details to sign back in immediately.
        store.signIn(
            context,
            firstName: prior.firstName,
            lastName: prior.lastName,
            company: prior.company,
            visiting: prior.visiting,
            carRegistration: prior.carRegistration,
            blockedCar: prior.blockedCar,
            pagerNumber: prior.pagerNumber,
            badgeNumber: prior.badgeNumber,
            wasPreRegistered: false
        )
        if store.lastError != nil {
            activeAlert = .persistenceError(message: store.lastError?.localizedDescription ?? unknownErrorMessage)
        } else {
            // Optional: brief haptic or feedback could be added here
        }
    }

    private func issueStaffPager(firstName: String, lastName: String, carRegistration: String, pagerNumber: String) {
        store.issueStaffPager(
            context,
            firstName: firstName,
            lastName: lastName,
            carRegistration: carRegistration,
            pagerNumber: pagerNumber
        )
        if store.lastError == nil {
            activeSheet = nil
        } else {
            activeAlert = .persistenceError(message: store.lastError?.localizedDescription ?? unknownErrorMessage)
        }
    }

    private func returnStaffPager(_ issue: StaffPagerIssue) {
        store.returnStaffPager(context, issue)
        if store.lastError != nil {
            activeAlert = .persistenceError(message: store.lastError?.localizedDescription ?? unknownErrorMessage)
        } else {
            let pager = issue.pagerNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            if !pager.isEmpty {
                recentlyFreedPagers.insert(pager)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(pagerGraceWindowSeconds) * 1_000_000_000)
                    recentlyFreedPagers.remove(pager)
                }
            }
        }
    }

    private func addPreRegisteredVisitor(firstName: String, lastName: String, company: String, visiting: String, badgeNumber: String, visitDate: Date) -> Bool {
        let normalized = normalizedBadge(badgeNumber)
        let conflicts = allocatedBadges(on: visitDate)
        if !normalized.isEmpty && conflicts.contains(normalized) {
            store.lastError = .importMessage("That badge is already allocated for the selected visit date. Please choose a different badge number.")
            return false
        }
        store.addPreRegisteredVisitor(
            context,
            firstName: firstName,
            lastName: lastName,
            company: company,
            visiting: visiting,
            badgeNumber: badgeNumber,
            carRegistration: "",
            visitDate: visitDate
        )
        if store.lastError != nil {
            return false
        }
        return true
    }

    private func deletePreRegisteredVisitor(_ visitor: PreRegisteredVisitor) {
        store.deletePreRegisteredVisitor(context, visitor)
        if store.lastError != nil {
            activeAlert = .persistenceError(message: store.lastError?.localizedDescription ?? unknownErrorMessage)
        }
    }
    
    private func exportCSV(from visitors: [Visitor]) -> URL? {
        return CSVExporter.exportVisitors(visitors)
    }
    
    private var registerButton: some View {
        Button(action: {
            hasAttemptedSubmit = true
            guard isValid else { return }
            guard !badgeAlreadyInUse else {
                activeAlert = .badgeConflict
                return
            }
            if !carRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                registrationFlow = .waitingBlockedCarDecision
                activeAlert = .blockedCarPrompt
            } else {
                registrationFlow = .waitingForInduction
                routeToInductionIfReady()
            }
        }) {
            Label(String(localized: "welcome.action.register"), systemImage: "person.badge.plus")
                .font(.title3)
                .fontWeight(.semibold)
                .imageScale(.large)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
        }
        .welcomePrimaryActionStyle(emphasizedShadow: true)
        .accessibilityLabel(String(localized: "welcome.a11y.register.label"))
        .accessibilityHint(String(localized: "welcome.a11y.register.hint"))
    }

    private var leavingButton: some View {
        Button {
            activeSheet = .leaving
        } label: {
            Label(String(localized: "welcome.action.leaving"), systemImage: "door.right.hand.open")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
        }
        .welcomeProminentActionStyle(tint: .orange)
        .accessibilityLabel(String(localized: "welcome.a11y.leaving.label"))
        .accessibilityHint(String(localized: "welcome.a11y.leaving.hint"))
    }

    private var preRegisteredButton: some View {
        Button {
            activeSheet = .preRegistrationList
        } label: {
            Label(String(localized: "welcome.prereg.tap_here"), systemImage: "person.text.rectangle")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .welcomeSecondaryActionStyle()
    }

    private var returningVisitorButton: some View {
        Button {
            activeSheet = .returningVisitorSearch
        } label: {
            Label(String(localized: "welcome.returning.tap_here"), systemImage: "person.crop.circle.badge.clock")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .welcomeSecondaryActionStyle()
    }

    private var signInBookButton: some View {
        Button {
            requestProtectedAccess(for: .signInBook)
        } label: {
            Label(String(localized: "welcome.menu.signin_book"), systemImage: "book.closed")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .welcomeSecondaryActionStyle()
    }
    
    private var utilityActionButtons: some View {
        HStack(spacing: 8) {
            kioskModeButton
            settingsMenuButton
            fireRollCallShortcutButton
            staffPagerButton
            returnPagersButton
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var settingsMenuButton: some View {
        Menu {
            Button {
                activeSheet = .about
            } label: {
                Label(String(localized: "welcome.menu.about"), systemImage: "info.circle")
            }

            Button {
                requestProtectedAccess(for: .analytics)
            } label: {
                Label(String(localized: "welcome.settings.analytics_dashboard"), systemImage: "chart.bar.xaxis")
            }

            Button {
                requestProtectedAccess(for: .kioskModeToggle)
            } label: {
                Label(kioskModeEnabled ? String(localized: "welcome.menu.kiosk.disable") : String(localized: "welcome.menu.kiosk.enable"),
                      systemImage: kioskModeEnabled ? "lock.open.fill" : "lock.fill")
            }

            Button {
                requestProtectedAccess(for: .settings)
            } label: {
                Label(String(localized: "welcome.menu.settings"), systemImage: "slider.horizontal.3")
            }

            Button {
                requestProtectedAccess(for: .preRegistrationAdmin)
            } label: {
                Label(String(localized: "welcome.prereg.manage_button"), systemImage: "person.badge.plus")
            }

            Button {
                runManualBackup()
            } label: {
                Label(String(localized: "settings.backups.backup_now"), systemImage: "externaldrive.fill.badge.plus")
            }

            Button {
                requestProtectedAccess(for: .exportCSV)
            } label: {
                Label(String(localized: "welcome.menu.export_csv"), systemImage: "square.and.arrow.up")
            }
            .disabled(allVisitors.isEmpty)

            Button(role: .destructive) {
                requestProtectedAccess(for: .fireRollCall)
            } label: {
                Label(String(localized: "welcome.menu.fire_roll_call"), systemImage: "alarm")
            }
        } label: {
            utilityIcon(systemName: "gearshape.fill", foreground: .blue)
        }
    }

    private var staffPagerButton: some View {
        Button {
            activeSheet = .staffPager
        } label: {
            utilityIcon(systemName: "car.fill", foreground: .blue)
        }
        .accessibilityLabel(String(localized: "welcome.a11y.staff_pager.label"))
        .accessibilityHint(String(localized: "welcome.a11y.staff_pager.hint"))
    }

    private var fireRollCallShortcutButton: some View {
        Button {
            requestProtectedAccess(for: .fireRollCall)
        } label: {
            utilityIcon(systemName: "flame.fill", foreground: .red)
        }
        .accessibilityLabel(String(localized: "welcome.a11y.fire_roll_call.label"))
        .accessibilityHint(String(localized: "welcome.a11y.fire_roll_call.hint"))
    }

    private var returnPagersButton: some View {
        Button {
            activeSheet = .returnPagers
        } label: {
            utilityIcon(systemName: "dot.radiowaves.left.and.right", foreground: .green)
        }
        .accessibilityLabel(String(localized: "welcome.a11y.return_pagers.label"))
        .accessibilityHint(String(localized: "welcome.a11y.return_pagers.hint"))
    }

    private var kioskModeButton: some View {
        Button {
            requestProtectedAccess(for: .kioskModeToggle, requireFreshPin: true)
        } label: {
            utilityIcon(systemName: kioskModeEnabled ? "key.fill" : "key", foreground: .yellow)
        }
        .accessibilityLabel(kioskModeEnabled ? String(localized: "welcome.a11y.kiosk.disable") : String(localized: "welcome.a11y.kiosk.enable"))
        .accessibilityHint(String(localized: "welcome.a11y.kiosk.hint"))
    }

    private func utilityIcon(systemName: String, foreground: Color) -> some View {
        Image(systemName: systemName)
            .imageScale(.medium)
            .foregroundStyle(foreground)
            .frame(width: 52, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.cemexBlue.opacity(0.10))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)
    }

    private var checkoutBanner: some View {
        Group {
            if showCheckoutBanner {
                VStack {
                    Spacer(minLength: 0)
                    VStack(spacing: 8) {
                        Text(String(localized: "welcome.checkout_banner.title"))
                            .font(.largeTitle).bold()
                            .multilineTextAlignment(.center)
                        Text(String(localized: "welcome.checkout_banner.message"))
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.vertical, 28)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.green)
                            .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
                    )
                    .overlay(alignment: .topTrailing) {
                        Text(String(format: String(localized: "welcome.checkout_banner.countdown_template"), checkoutBannerSecondsRemaining))
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.25), in: Capsule())
                            .padding(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: showCheckoutBanner)
                .task(id: checkoutBannerCountdownID) {
                    for second in stride(from: 5, through: 1, by: -1) {
                        guard showCheckoutBanner else { return }
                        checkoutBannerSecondsRemaining = second
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        if Task.isCancelled { return }
                    }
                    withAnimation { showCheckoutBanner = false }
                }
            }
        }
    }

    private func requestProtectedAccess(for action: ProtectedAction, requireFreshPin: Bool = false) {
        if !requireFreshPin && isPinSessionValid {
            runProtectedAction(action)
            return
        }
        pinGateAction = action
        activeSheet = .pinGate
    }

    private func protectedActionName(for action: ProtectedAction) -> String {
        switch action {
        case .settings: return String(localized: "welcome.protected.settings")
        case .exportCSV: return String(localized: "welcome.protected.export_csv")
        case .signInBook: return String(localized: "welcome.protected.signin_book")
        case .fireRollCall: return String(localized: "welcome.protected.fire_roll_call")
        case .analytics: return String(localized: "welcome.protected.analytics")
        case .preRegistrationAdmin: return String(localized: "welcome.prereg.admin_title")
        case .kioskModeToggle: return String(localized: "welcome.protected.kiosk_mode")
        }
    }

    private func protectedPromptText(for action: ProtectedAction) -> String? {
        switch action {
        case .kioskModeToggle:
            return kioskModeEnabled
            ? String(localized: "welcome.kiosk.prompt.disable")
            : String(localized: "welcome.kiosk.prompt.enable")
        default:
            return nil
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
                store.lastError = .importMessage(String(localized: "welcome.export_csv.error_failed"))
                activeAlert = .persistenceError(message: store.lastError?.localizedDescription ?? unknownErrorMessage)
            }
        case .signInBook:
            activeSheet = .signInBook
        case .fireRollCall:
            activeSheet = .rollCall
        case .analytics:
            activeSheet = .analytics
        case .preRegistrationAdmin:
            activeSheet = .preRegistrationAdmin
        case .kioskModeToggle:
            activeAlert = .kioskConfirm(enabled: kioskModeEnabled)
        }
    }

    private func applyDeferredSelectionIfNeeded() {
        guard let deferredSelection else { return }
        self.deferredSelection = nil

        switch deferredSelection {
        case .preRegistered(let id, let droveCarRegistration):
            guard let visitor = preRegisteredVisitors.first(where: { $0.id == id }) else { return }
            prefillFromPreRegistered(visitor, droveCarRegistration: droveCarRegistration)
        case .returningVisitor(let id, let droveCarRegistration):
            guard let visitor = allVisitors.first(where: { $0.id == id }) else { return }
            prefillFromReturningVisitor(visitor, droveCarRegistration: droveCarRegistration)
        }
    }

    private func prefillFromPreRegistered(_ visitor: PreRegisteredVisitor, droveCarRegistration: String?) {
        firstName = visitor.firstName
        lastName = visitor.lastName
        company = visitor.company
        visiting = visitor.visiting
        if let droveCarRegistration {
            carRegistration = droveCarRegistration
            blockedCar = false
            pagerNumber = ""
            registrationFlow = .waitingBlockedCarDecision
            activeAlert = .blockedCarPrompt
        } else {
            carRegistration = ""
            blockedCar = false
            pagerNumber = ""
            registrationFlow = .waitingForInduction
        }
        badgeNumber = visitor.badgeNumber
        isSigningInPreRegisteredVisitor = true
        selectedPreRegisteredVisitorID = visitor.id
        hasAttemptedSubmit = true
        if droveCarRegistration == nil {
            routeToInductionIfReady()
        }
    }

    private func prefillFromReturningVisitor(_ visitor: Visitor, droveCarRegistration: String?) {
        firstName = visitor.firstName
        lastName = visitor.lastName
        company = visitor.company
        visiting = visitor.visiting
        if let droveCarRegistration {
            carRegistration = droveCarRegistration
            blockedCar = false
            pagerNumber = ""
            registrationFlow = .waitingBlockedCarDecision
            activeAlert = .blockedCarPrompt
        } else {
            carRegistration = ""
            blockedCar = false
            pagerNumber = ""
            registrationFlow = .waitingForInduction
        }
        badgeNumber = visitor.badgeNumber
        isSigningInPreRegisteredVisitor = false
        selectedPreRegisteredVisitorID = nil
        hasAttemptedSubmit = true
        if droveCarRegistration == nil {
            routeToInductionIfReady()
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

    private func invalidatePinSession() {
        pinLastUnlockTimestamp = 0
    }

    private var statusSummary: some View {
        let visitorCount = activeVisitors.count
        let pagerCount = activeStaffPagerIssues.count
        return HStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .imageScale(.medium)
                .foregroundStyle(.white)
            Text(String(format: String(localized: "welcome.status.signed_in_template"), visitorCount))
                .font(.headline)
                .foregroundStyle(.white)
            Spacer(minLength: 12)
            Image(systemName: "dot.radiowaves.left.and.right")
                .imageScale(.medium)
                .foregroundStyle(.white)
            Text(String(format: String(localized: "welcome.status.staff_pagers_template"), pagerCount))
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.cemexBlue)
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: String(localized: "welcome.status.a11y_template"), visitorCount, pagerCount))
    }
    
    private func routeToInductionIfReady() {
        // Present induction only when the registration flow has reached the ready state.
        guard registrationFlow == .waitingForInduction,
              !showPagerPrompt,
              activeAlert != .blockedCarPrompt,
              !showingInduction else { return }
        showingInduction = true
    }

    private var unknownErrorMessage: String {
        String(localized: "common.unknown_error")
    }
}


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

                    Text(String(localized: "welcome.header.title"))
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    Text(String(localized: "welcome.header.subtitle"))
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top, 26)
                .padding(.bottom, 22)

                // Light accent strip below the blue band for contrast and polish
                LinearGradient(
                    colors: [
                        Color(red: 220/255, green: 230/255, blue: 248/255),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 48)
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
                .font(.callout)
                .fontWeight(.bold)
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

private struct PagerSelectionSheet: View {
    let usedPagers: Set<String>
    let availablePagerRange: ClosedRange<Int>
    @Binding var pagerNumber: String
    let onCancel: () -> Void
    let onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            let currentNumeric = pagerNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedUsedPagers: Set<String> = usedPagers
            let effectiveUsedPagers: Set<String> = normalizedUsedPagers.subtracting(currentNumeric.isEmpty ? [] : [currentNumeric])
            let pagerInUseError: Bool = !currentNumeric.isEmpty && normalizedUsedPagers.contains(currentNumeric)

            Form {
                Section {
                    Text(String(localized: "welcome.pager.instructions"))
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
                                        Text(String(format: String(localized: "welcome.pager.item_template"), i))
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

                        if pagerNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(String(localized: "welcome.pager.error.required")).font(.caption2).foregroundStyle(.red)
                        }
                        if pagerInUseError {
                            Text(String(localized: "welcome.pager.error.in_use"))
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "welcome.pager.title"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.close")) { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.save")) {
                        let selected = pagerNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !selected.isEmpty, !normalizedUsedPagers.contains(selected) else { return }
                        onSave(selected)
                    }
                    .disabled(pagerNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || normalizedUsedPagers.contains(pagerNumber.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Visitor.self, inMemory: true)
        .environment(VisitorStore())
}

private extension View {
    func welcomePrimaryActionStyle(emphasizedShadow: Bool = false) -> some View {
        self
            .buttonStyle(.borderedProminent)
            .tint(.cemexBlue)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(
                color: emphasizedShadow ? Color.cemexBlue.opacity(0.35) : .clear,
                radius: emphasizedShadow ? 6 : 0,
                x: 0,
                y: emphasizedShadow ? 3 : 0
            )
    }

    func welcomeProminentActionStyle(tint: Color) -> some View {
        self
            .buttonStyle(.borderedProminent)
            .tint(tint)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func welcomeSecondaryActionStyle() -> some View {
        self
            .buttonStyle(.bordered)
            .tint(.cemexBlue)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
