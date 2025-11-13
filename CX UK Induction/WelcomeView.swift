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
                            HStack(alignment: .top, spacing: 16) {
                                VStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        inputTextField("First name", text: $firstName)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(firstNameInvalid ? Color.red : Color.clear, lineWidth: 1)
                                            )
                                        if firstNameInvalid { Text("First name is required").font(.caption2).foregroundStyle(.red) }
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        inputTextField("Company", text: $company)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(companyInvalid ? Color.red : Color.clear, lineWidth: 1)
                                            )
                                        if companyInvalid { Text("Company is required").font(.caption2).foregroundStyle(.red) }
                                    }
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
                                    VStack(alignment: .leading, spacing: 4) {
                                        inputTextField("Last name", text: $lastName)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(lastNameInvalid ? Color.red : Color.clear, lineWidth: 1)
                                            )
                                        if lastNameInvalid { Text("Last name is required").font(.caption2).foregroundStyle(.red) }
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        inputTextField("Who are you visiting", text: $visiting)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(visitingInvalid ? Color.red : Color.clear, lineWidth: 1)
                                            )
                                        if visitingInvalid { Text("Who you are visiting is required").font(.caption2).foregroundStyle(.red) }
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        inputTextField("Badge Number", text: $badgeNumber)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(badgeInvalid ? Color.red : Color.clear, lineWidth: 1)
                                            )
                                        if badgeInvalid { Text("Badge number is required").font(.caption2).foregroundStyle(.red) }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        } else {
                            VStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    inputTextField("First name", text: $firstName)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(firstNameInvalid ? Color.red : Color.clear, lineWidth: 1)
                                        )
                                    if firstNameInvalid { Text("First name is required").font(.caption2).foregroundStyle(.red) }
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    inputTextField("Last name", text: $lastName)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(lastNameInvalid ? Color.red : Color.clear, lineWidth: 1)
                                        )
                                    if lastNameInvalid { Text("Last name is required").font(.caption2).foregroundStyle(.red) }
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    inputTextField("Company", text: $company)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(companyInvalid ? Color.red : Color.clear, lineWidth: 1)
                                        )
                                    if companyInvalid { Text("Company is required").font(.caption2).foregroundStyle(.red) }
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    inputTextField("Who are you visiting", text: $visiting)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(visitingInvalid ? Color.red : Color.clear, lineWidth: 1)
                                        )
                                    if visitingInvalid { Text("Who you are visiting is required").font(.caption2).foregroundStyle(.red) }
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    inputTextField("Badge Number", text: $badgeNumber)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(badgeInvalid ? Color.red : Color.clear, lineWidth: 1)
                                        )
                                    if badgeInvalid { Text("Badge number is required").font(.caption2).foregroundStyle(.red) }
                                }
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
                                // Defer final submit until after induction screens
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Share sheet for CSV export
        .sheet(item: $shareItem, onDismiss: { shareItem = nil }) { item in
            ActivityView(activityItems: [item.url])
        }
        // About sheet
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingSettings) {
            AutoCheckoutSettingsView(enabled: .constant(false), hour: .constant(7), minute: .constant(0))
                .presentationDetents([.medium])
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
                Form {
                    Section {
                        Text("Kindly obtain a pager from Reception; your vehicle is obstructing another vehicle. If the person you are blocking in needs to move their car, we will page you. We would appreciate your prompt attention if your pager buzzes. Enter the pager number in the box below and tap save.")
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
                            TextField("Enter pager number", text: $pagerNumber)
                                .keyboardType(.numberPad)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(pagerInvalid ? Color.red : Color.clear, lineWidth: 1)
                                )
                            if pagerInvalid {
                                Text("Pager number is required").font(.caption2).foregroundStyle(.red)
                            }
                        }
                    }
                }
                .navigationTitle("Contact Pager")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            // Keep blockedCar = true but no pager; dismiss without submitting
                            showPagerPrompt = false
                            // Do not auto-submit if pager is required and missing
                            pendingSubmit = false
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            showPagerPrompt = false
                            if pendingSubmit {
                                showingInduction = true
                                // pendingSubmit will be cleared in the induction completion handler
                            }
                        }
                        .disabled(pagerNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        // Validate required fields before attempting sign-in
        let requiredBasicsFilled = !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !visiting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !badgeNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let pagerRequired = blockedCar
        let pagerOk = !pagerRequired || !pagerNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard requiredBasicsFilled && pagerOk else { return }
        
        let name = firstName + " " + lastName
        store.signIn(context,
                     firstName: firstName,
                     lastName: lastName,
                     company: company,
                     visiting: visiting,
                     carRegistration: carRegistration,
                     blockedCar: blockedCar,
                     pagerNumber: pagerNumber,
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
    
    private func showSignedOutBannerTemporarily() {
        withAnimation { showCheckoutBanner = true }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    // CSV export (duplicated here so WelcomeView can export independently)
    private func exportCSV(from visitors: [Visitor]) -> URL? {
        let header = [
            "First Name",
            "Last Name",
            "Company",
            "Visiting",
            "Car Registration",
            "Date Signed In",
            "Date Signed Out"
        ]
        let df = DateFormatter()
        // Format: dd/MM/YY HH:mm (day/month/two-digit year, 24-hour, minute)
        // Using lowercase dd for day-of-month and yy for two-digit year
        df.locale = Locale(identifier: "en_GB")
        df.timeZone = TimeZone(secondsFromGMT: 0) // optional: force UTC; remove if you want local time
        df.dateFormat = "dd/MM/yy HH:mm"
        let rows: [[String]] = visitors.map { v in
            let car = v.carRegistration.trimmingCharacters(in: .whitespacesAndNewlines)
            let carValue = car.isEmpty ? "None" : car
            return [
                v.firstName,
                v.lastName,
                v.company,
                v.visiting,
                carValue,
                df.string(from: v.checkIn),
                v.checkOut.map { df.string(from: $0) } ?? ""
            ]
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
                                Text("Checked in: \(dateTime(visitor.checkIn))")
                                Text("Checked out: \(visitor.checkOut.map { dateTime($0) } ?? "")")
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
        let df = DateFormatter()
        df.dateStyle = .medium
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
        let df = DateFormatter()
        df.dateStyle = .medium
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

#Preview {
    WelcomeView()
        .modelContainer(for: Visitor.self, inMemory: true)
        .environment(VisitorStore())
}

