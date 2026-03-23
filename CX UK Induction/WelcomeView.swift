import SwiftUI
import SwiftData
import UIKit

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

    @State private var showingLeaving = false
    @State private var showBlockedCarPrompt = false
    @State private var showPagerPrompt = false
    @State private var pendingSubmit = false
    
    @State private var showingInduction = false
    @State private var inductionImages: [String] = ["induction_1", "induction_2", "induction_3", "induction_4"]
    
    @State private var showingRollCall = false

    @State private var showRegisteredAlert = false
    @State private var lastRegisteredName: String = ""
    
    @State private var showCheckoutBanner = false
    @State private var lastCheckedOutName: String = ""
    
    @State private var showingSettings = false
    @AppStorage("autoCheckoutEnabled") private var autoCheckoutEnabled: Bool = false
    @AppStorage("autoCheckoutHour") private var autoCheckoutHour: Int = 5
    @AppStorage("autoCheckoutMinute") private var autoCheckoutMinute: Int = 0
    @State private var scheduler = AutoCheckoutScheduler()

    @State private var showingSignInBook = false

    @State private var showPersistenceError = false

    @FocusState private var focusedField: Field?
    enum Field: Hashable {
        case firstName, lastName, company, visiting, carReg, badge
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
    
    // About sheet
    @State private var showingAbout = false
    
    init() {}
    
    private var firstNameInvalid: Bool { firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var lastNameInvalid: Bool { lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var companyInvalid: Bool { company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var visitingInvalid: Bool { visiting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var badgeInvalid: Bool { badgeNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var pagerInvalid: Bool { blockedCar && pagerNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

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
                            RegularFormFields(firstName: $firstName,
                                              lastName: $lastName,
                                              company: $company,
                                              visiting: $visiting,
                                              carRegistration: $carRegistration,
                                              firstNameInvalid: firstNameInvalid,
                                              lastNameInvalid: lastNameInvalid,
                                              companyInvalid: companyInvalid,
                                              visitingInvalid: visitingInvalid,
                                              badgeInvalid: badgeInvalid,
                                              badgeNumber: $badgeNumber,
                                              showBlockedCarPrompt: $showBlockedCarPrompt,
                                              focusedField: $focusedField)
                        } else {
                            CompactFormFields(firstName: $firstName,
                                              lastName: $lastName,
                                              company: $company,
                                              visiting: $visiting,
                                              carRegistration: $carRegistration,
                                              firstNameInvalid: firstNameInvalid,
                                              lastNameInvalid: lastNameInvalid,
                                              companyInvalid: companyInvalid,
                                              visitingInvalid: visitingInvalid,
                                              badgeInvalid: badgeInvalid,
                                              badgeNumber: $badgeNumber,
                                              showBlockedCarPrompt: $showBlockedCarPrompt,
                                              focusedField: $focusedField)
                        }
                    } header: {
                        Text("Please enter your details to register your visit:")
                            .font(.headline)
                            .padding(.bottom, 8)
                    }
                    .padding(.horizontal, 0)
                    .padding(.vertical, 0)
                    Section {
                        registerButton

                        leavingButton
                        
                        signInBookButton
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color(.systemBackground))
                .autocorrectionDisabled()
                .scrollDismissesKeyboard(.interactively)
            }
            
            settingsMenu
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Share sheet for CSV export
        .sheet(item: $shareItem) { item in
            ActivityView(activityItems: [item.url])
        }
        // About sheet
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingSettings) {
            AutoCheckoutSettingsView(enabled: $autoCheckoutEnabled, hour: $autoCheckoutHour, minute: $autoCheckoutMinute)
                .presentationDetents([.medium])
        }
        .alert("Thank you for registering", isPresented: $showRegisteredAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            let registeredMessage: String = "\(lastRegisteredName): Your information has been recorded successfully.\n\nThe information collected is for safety and security purposes and all personal details will be stored in accordance with the Cemex Privacy Policy available at cemex.co.uk"
            Text(registeredMessage)
                .multilineTextAlignment(.center)
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
                // pagerNumber is always stored as a bare numeric string (e.g. "3") from the picker tags below.
                let currentNumeric = pagerNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                // usedPagers is already normalised to bare numeric strings via the computed property above.
                let normalizedUsedPagers: Set<String> = usedPagers
                // Do not include the currently selected pager in the disabled set so the user can keep it selected
                let effectiveUsedPagers: Set<String> = normalizedUsedPagers.subtracting(currentNumeric.isEmpty ? [] : [currentNumeric])
                
                // Local computed error detection and message for pager in use validation
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
                            // Show all pagers as a scrollable segmented list so the
                            // 🔴/🟢 availability icons are always visible, not hidden
                            // inside a collapsed menu.
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                                ForEach(1...30, id: \.self) { i in
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
                            // User cancelled providing a pager; clear blocked state and pager to re-enable Register
                            blockedCar = false
                            pagerNumber = ""
                            showPagerPrompt = false
                            pendingSubmit = false
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            // Final guard: prevent saving a pager that's already in use
                            if normalizedUsedPagers.contains(currentNumeric) || currentNumeric.isEmpty {
                                // Reset selection and keep the sheet open for correction
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
        // Induction flow full-screen
        .fullScreenCover(isPresented: $showingInduction) {
            InductionFlowView(imageNames: inductionImages) { confirmed in
                showingInduction = false
                if confirmed {
                    submit()
                }
                pendingSubmit = false
            }
            .ignoresSafeArea()
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
        .overlay(alignment: .top) {
            checkoutBanner
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
        .ignoresSafeArea(.keyboard) // keep bottom overlay from moving with keyboard
        .onChange(of: showPagerPrompt) { oldValue, newValue in
            // If the pager sheet is dismissed by any means and a submit is pending, present induction now
            if oldValue == true && newValue == false {
                if pendingSubmit {
                    showingInduction = true
                }
                pendingSubmit = false
            }
        }
        .onChange(of: showBlockedCarPrompt) { oldValue, newValue in
            // If the blocked car alert disappears without moving to pager and a submit is pending, present induction now
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
            if autoCheckoutEnabled {
                startScheduler()
            }
        }
        .onDisappear {
            scheduler.cancel()
        }
        .onChange(of: autoCheckoutEnabled) { _, enabled in
            if enabled {
                startScheduler()
            } else {
                scheduler.cancel()
            }
        }
        .onChange(of: autoCheckoutHour) { _, _ in
            if autoCheckoutEnabled { startScheduler() }
        }
        .onChange(of: autoCheckoutMinute) { _, _ in
            if autoCheckoutEnabled { startScheduler() }
        }
        .alert("Save Error", isPresented: $showPersistenceError, presenting: store.lastError) { _ in
            Button("OK", role: .cancel) {
                // clear the error so it won't re-trigger
                store.lastError = nil
            }
        } message: { msg in
            let messageString: String = {
                if let error = msg as? any Error {
                    return error.localizedDescription
                } else {
                    return String(describing: msg)
                }
            }()
            Text(verbatim: messageString)
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

        store.signIn(context,
                     firstName: firstName,
                     lastName: lastName,
                     company: company,
                     visiting: visiting,
                     carRegistration: carRegistration,
                     blockedCar: blockedCar,
                     pagerNumber: normalizedPager,
                     badgeNumber: badgeNumber)
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
    
    private func startScheduler() {
        // Cancel any existing timer before scheduling a new one to prevent stacking.
        scheduler.cancel()
        scheduler.scheduleDailyCheckout(atHour: autoCheckoutHour, minute: autoCheckoutMinute) {
            // Pass the actual fire time so checkout records the real time rather than a hardcoded value.
            store.autoCheckoutPreviousDay(context, at: Date())
        }
    }

    private func showSignedOutBannerTemporarily() {
        withAnimation { showCheckoutBanner = true }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
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
            try csv.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
    
    private var registerButton: some View {
        Button(action: {
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
    }
    
    private var leavingButton: some View {
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
    }

    private var signInBookButton: some View {
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
    }
    
    private var settingsMenu: some View {
        Menu {
            Button {
                if let url = exportCSV(from: allVisitors) {
                    shareItem = ShareItem(url: url)
                }
            } label: {
                Label("Export CSV", systemImage: "square.and.arrow.up")
            }
            .disabled(allVisitors.isEmpty)

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
            
            Button {
                showingSettings = true
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
}

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
    .frame(height: 52)
    .padding(.horizontal, 2)
}

private struct InductionFlowView: View {
    let imageNames: [String]
    let onComplete: (Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int = 0
    @State private var acknowledged: Bool = false

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
                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: { acknowledged.toggle() }) {
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: acknowledged ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(acknowledged ? .green : .secondary)
                                    .imageScale(.large)
                                Text("I have read and understood the induction information")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            onComplete(true)
                        } label: {
                            Label("Confirm and Continue", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(!acknowledged)
                    }
                    .padding(.horizontal)
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
        let source = snapshot.isEmpty ? activeVisitors : snapshot
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
    @Environment(\.dismiss) private var dismiss

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
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
            }
        }
    }
}

private struct RegularFormFields: View {
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var company: String
    @Binding var visiting: String
    @Binding var carRegistration: String
    let firstNameInvalid: Bool
    let lastNameInvalid: Bool
    let companyInvalid: Bool
    let visitingInvalid: Bool
    let badgeInvalid: Bool
    @Binding var badgeNumber: String
    @Binding var showBlockedCarPrompt: Bool
    let focusedField: FocusState<WelcomeView.Field?>.Binding

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    inputTextField("First name", text: $firstName)
                        .focused(focusedField, equals: WelcomeView.Field.firstName)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField.wrappedValue = WelcomeView.Field.lastName
                        }
                        .textInputAutocapitalization(.words)

                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(firstNameInvalid ? Color.red : Color.clear, lineWidth: 1)
                        )
                    if firstNameInvalid { Text("First name is required").font(.caption2).foregroundStyle(.red) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    inputTextField("Company", text: $company)
                        .focused(focusedField, equals: WelcomeView.Field.company)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField.wrappedValue = WelcomeView.Field.visiting
                        }
                        .textInputAutocapitalization(.words)

                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(companyInvalid ? Color.red : Color.clear, lineWidth: 1)
                        )
                    if companyInvalid { Text("Company is required").font(.caption2).foregroundStyle(.red) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    // Moved Badge Number above Car registration
                    inputTextField("Badge Number", text: Binding(
                        get: { badgeNumber },
                        set: { newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            badgeNumber = filtered
                        }
                    ))
                    .focused(focusedField, equals: WelcomeView.Field.badge)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField.wrappedValue = WelcomeView.Field.carReg
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(badgeInvalid ? Color.red : Color.clear, lineWidth: 1)
                    )
                    if badgeInvalid {
                        Text("Badge number is required").font(.caption2).foregroundStyle(.red)
                    }
                }
            }
            VStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    inputTextField("Last name", text: $lastName)
                        .focused(focusedField, equals: WelcomeView.Field.lastName)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField.wrappedValue = WelcomeView.Field.company
                        }
                        .textInputAutocapitalization(.words)

                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(lastNameInvalid ? Color.red : Color.clear, lineWidth: 1)
                        )
                    if lastNameInvalid { Text("Last name is required").font(.caption2).foregroundStyle(.red) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    inputTextField("Who are you visiting", text: $visiting)
                        .focused(focusedField, equals: WelcomeView.Field.visiting)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField.wrappedValue = WelcomeView.Field.badge
                        }
                        .textInputAutocapitalization(.words)

                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(visitingInvalid ? Color.red : Color.clear, lineWidth: 1)
                        )
                    if visitingInvalid { Text("Who you are visiting is required").font(.caption2).foregroundStyle(.red) }
                }
                inputTextField("Car registration", text: Binding(
                    get: { carRegistration },
                    set: { newValue in
                        let allowed = newValue.uppercased().filter { $0.isNumber || ("A"..."Z").contains(String($0)) }
                        carRegistration = String(allowed)
                    }
                ))
                .focused(focusedField, equals: WelcomeView.Field.carReg)
                .textInputAutocapitalization(.characters)
                .keyboardType(.asciiCapable)
                .autocorrectionDisabled(true)
                .submitLabel(.done)
                .onSubmit {
                    if !carRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        showBlockedCarPrompt = true
                    }
                    focusedField.wrappedValue = nil
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CompactFormFields: View {
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var company: String
    @Binding var visiting: String
    @Binding var carRegistration: String
    let firstNameInvalid: Bool
    let lastNameInvalid: Bool
    let companyInvalid: Bool
    let visitingInvalid: Bool
    let badgeInvalid: Bool
    @Binding var badgeNumber: String
    @Binding var showBlockedCarPrompt: Bool
    let focusedField: FocusState<WelcomeView.Field?>.Binding

    var body: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                inputTextField("First name", text: $firstName)
                    .focused(focusedField, equals: WelcomeView.Field.firstName)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField.wrappedValue = WelcomeView.Field.lastName
                    }
                    .textInputAutocapitalization(.words)

                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(firstNameInvalid ? Color.red : Color.clear, lineWidth: 1)
                    )
                if firstNameInvalid { Text("First name is required").font(.caption2).foregroundStyle(.red) }
            }
            VStack(alignment: .leading, spacing: 4) {
                inputTextField("Last name", text: $lastName)
                    .focused(focusedField, equals: WelcomeView.Field.lastName)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField.wrappedValue = WelcomeView.Field.company
                    }
                    .textInputAutocapitalization(.words)

                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(lastNameInvalid ? Color.red : Color.clear, lineWidth: 1)
                    )
                if lastNameInvalid { Text("Last name is required").font(.caption2).foregroundStyle(.red) }
            }
            VStack(alignment: .leading, spacing: 4) {
                inputTextField("Company", text: $company)
                    .focused(focusedField, equals: WelcomeView.Field.company)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField.wrappedValue = WelcomeView.Field.visiting
                    }
                    .textInputAutocapitalization(.words)

                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(companyInvalid ? Color.red : Color.clear, lineWidth: 1)
                    )
                if companyInvalid { Text("Company is required").font(.caption2).foregroundStyle(.red) }
            }
            VStack(alignment: .leading, spacing: 4) {
                inputTextField("Who are you visiting", text: $visiting)
                    .focused(focusedField, equals: WelcomeView.Field.visiting)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField.wrappedValue = WelcomeView.Field.badge
                    }
                    .textInputAutocapitalization(.words)

                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(visitingInvalid ? Color.red : Color.clear, lineWidth: 1)
                    )
                if visitingInvalid { Text("Who you are visiting is required").font(.caption2).foregroundStyle(.red) }
            }
            VStack(alignment: .leading, spacing: 4) {
                // Moved Badge Number above Car registration
                inputTextField("Badge Number", text: Binding(
                    get: { badgeNumber },
                    set: { newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        badgeNumber = filtered
                    }
                ))
                .focused(focusedField, equals: WelcomeView.Field.badge)
                .submitLabel(.next)
                .onSubmit {
                    focusedField.wrappedValue = WelcomeView.Field.carReg
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(badgeInvalid ? Color.red : Color.clear, lineWidth: 1)
                )
                if badgeInvalid {
                    Text("Badge number is required").font(.caption2).foregroundStyle(.red)
                }
            }
            inputTextField("Car registration", text: Binding(
                get: { carRegistration },
                set: { newValue in
                    let allowed = newValue.uppercased().filter { $0.isNumber || ("A"..."Z").contains(String($0)) }
                    carRegistration = String(allowed)
                }
            ))
            .focused(focusedField, equals: WelcomeView.Field.carReg)
            .textInputAutocapitalization(.characters)
            .keyboardType(.asciiCapable)
            .autocorrectionDisabled(true)
            .submitLabel(.done)
            .onSubmit {
                if !carRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    showBlockedCarPrompt = true
                }
                focusedField.wrappedValue = nil
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WelcomeView()
        .modelContainer(for: Visitor.self, inMemory: true)
        .environment(VisitorStore())
}

