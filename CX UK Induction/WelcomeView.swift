import SwiftUI
import SwiftData

struct WelcomeView: View {
    @Environment(VisitorStore.self) private var store
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Visitor> { $0.checkOut == nil }, sort: [SortDescriptor(\.checkIn, order: .reverse)]) private var activeVisitors: [Visitor]
    
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var company = ""
    @State private var visiting = ""
    @State private var carRegistration = ""

    @State private var showingLeaving = false
    @State private var leavingSearch = ""

    @State private var showRegisteredAlert = false
    @State private var lastRegisteredName: String = ""
    
    @State private var showCheckoutBanner = false
    @State private var lastCheckedOutName: String = ""

    var body: some View {
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
            }
        }
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .scrollDismissesKeyboard(.interactively)
        .toolbar { // Keyboard dismissal in compact environments
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
}

private struct LeavingSearchSheet: View {
    @Environment(VisitorStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let activeVisitors: [Visitor]
    let onCheckedOut: (String) -> Void
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List(filtered) { v in
                NavigationLink(value: v) {
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
        .presentationDetents([.medium, .large])
    }

    private var filtered: [Visitor] {
        if searchText.isEmpty { return activeVisitors }
        let q = searchText.lowercased()
        return activeVisitors.filter { v in
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

#Preview {
    WelcomeView()
        .modelContainer(for: Visitor.self, inMemory: true)
        .environment(VisitorStore())
}
