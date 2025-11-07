import SwiftUI
import SwiftData

struct WelcomeView: View {
    @Environment(VisitorStore.self) private var store
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Visitor> { $0.checkOut == nil }, sort: [SortDescriptor(\.checkIn, order: .reverse)]) private var activeVisitors: [Visitor]

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var company = ""
    @State private var carRegistration = ""

    @State private var showingLeaving = false
    @State private var leavingSearch = ""

    var body: some View {
        Form {
            Section(header: Text("Welcome")) {
                Text("Please sign in below").font(.headline)
            }
            Section("Your details") {
                TextField("First name", text: $firstName)
                TextField("Last name", text: $lastName)
                TextField("Company", text: $company)
                TextField("Car registration", text: $carRegistration)
            }
            Section {
                Button(action: submit) {
                    Label("Sign In", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!isValid)
                Button {
                    showingLeaving = true
                } label: {
                    Label("I'm leaving", systemImage: "door.right.hand.open")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .sheet(isPresented: $showingLeaving) {
            LeavingSearchSheet(activeVisitors: activeVisitors)
        }
    }

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        store.signIn(context, firstName: firstName, lastName: lastName, company: company, carRegistration: carRegistration)
        firstName = ""; lastName = ""; company = ""; carRegistration = ""
    }
}

private struct LeavingSearchSheet: View {
    @Environment(VisitorStore.self) private var store
    @Environment(\.modelContext) private var context

    let activeVisitors: [Visitor]
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
                        } label: {
                            Label("Confirm I'm leaving", systemImage: "door.right.hand.open")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .navigationTitle(v.fullName)
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
