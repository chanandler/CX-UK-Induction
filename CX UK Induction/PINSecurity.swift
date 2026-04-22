import SwiftUI
import Security

// MARK: - Keychain-backed PIN storage

enum PinKeychain {
    private static let service = "com.cemex.cxukinduction"
    private static let account = "app_pin"

    static func hasPin() -> Bool {
        readPin() != nil
    }

    static func verify(_ pin: String) -> Bool {
        guard let stored = readPin() else { return false }
        return stored == pin
    }

    @discardableResult
    static func set(_ pin: String) -> Bool {
        guard !pin.isEmpty else { return false }

        _ = deletePin()

        let data = Data(pin.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    static func change(currentPin: String, newPin: String) -> Bool {
        guard verify(currentPin), !newPin.isEmpty else { return false }
        return set(newPin)
    }

    private static func readPin() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let pin = String(data: data, encoding: .utf8) else {
            return nil
        }
        return pin
    }

    @discardableResult
    private static func deletePin() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

// MARK: - PIN gate sheet for protected actions

struct PinGateSheet: View {
    let actionName: String
    let onSuccess: () -> Void
    let onCancel: () -> Void

    private enum Mode {
        case verify
        case create
    }

    @State private var mode: Mode = PinKeychain.hasPin() ? .verify : .create
    @State private var enteredPin = ""
    @State private var newPin = ""
    @State private var confirmPin = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if mode == .verify {
                    Section("PIN Required") {
                        Text("Enter your PIN to access \(actionName).")
                            .foregroundStyle(.secondary)
                        SecureField("PIN", text: digitsOnlyBinding($enteredPin))
                            .keyboardType(.numberPad)
                    }
                } else {
                    Section("Create PIN") {
                        Text("Set a PIN to protect settings and management actions.")
                            .foregroundStyle(.secondary)
                        SecureField("New PIN", text: digitsOnlyBinding($newPin))
                            .keyboardType(.numberPad)
                        SecureField("Confirm PIN", text: digitsOnlyBinding($confirmPin))
                            .keyboardType(.numberPad)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(mode == .verify ? "Enter PIN" : "Set PIN")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(mode == .verify ? "Unlock" : "Save") {
                        submit()
                    }
                    .bold()
                }
            }
        }
    }

    private func submit() {
        errorMessage = nil

        switch mode {
        case .verify:
            guard !enteredPin.isEmpty else {
                errorMessage = "Please enter your PIN."
                return
            }
            guard PinKeychain.verify(enteredPin) else {
                errorMessage = "Incorrect PIN."
                return
            }
            onSuccess()

        case .create:
            guard newPin.count >= 4 else {
                errorMessage = "PIN must be at least 4 digits."
                return
            }
            guard newPin == confirmPin else {
                errorMessage = "PINs do not match."
                return
            }
            guard PinKeychain.set(newPin) else {
                errorMessage = "Could not save PIN to Keychain."
                return
            }
            onSuccess()
        }
    }

    private func digitsOnlyBinding(_ binding: Binding<String>) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue },
            set: { binding.wrappedValue = $0.filter(\.isNumber) }
        )
    }
}

// MARK: - Change PIN sheet

struct PinChangeSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentPin = ""
    @State private var newPin = ""
    @State private var confirmPin = ""
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var hasExistingPin: Bool { PinKeychain.hasPin() }

    var body: some View {
        NavigationStack {
            Form {
                if hasExistingPin {
                    Section("Current PIN") {
                        SecureField("Current PIN", text: digitsOnlyBinding($currentPin))
                            .keyboardType(.numberPad)
                    }
                }

                Section(hasExistingPin ? "New PIN" : "Set PIN") {
                    SecureField("New PIN", text: digitsOnlyBinding($newPin))
                        .keyboardType(.numberPad)
                    SecureField("Confirm PIN", text: digitsOnlyBinding($confirmPin))
                        .keyboardType(.numberPad)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if let successMessage {
                    Section {
                        Text(successMessage)
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle(hasExistingPin ? "Change PIN" : "Set PIN")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { savePin() }
                        .bold()
                }
            }
        }
    }

    private func savePin() {
        errorMessage = nil
        successMessage = nil

        guard newPin.count >= 4 else {
            errorMessage = "PIN must be at least 4 digits."
            return
        }
        guard newPin == confirmPin else {
            errorMessage = "PINs do not match."
            return
        }

        if hasExistingPin {
            guard PinKeychain.change(currentPin: currentPin, newPin: newPin) else {
                errorMessage = "Current PIN is incorrect."
                return
            }
        } else {
            guard PinKeychain.set(newPin) else {
                errorMessage = "Could not save PIN to Keychain."
                return
            }
        }

        successMessage = "PIN updated successfully."
        currentPin = ""
        newPin = ""
        confirmPin = ""
    }

    private func digitsOnlyBinding(_ binding: Binding<String>) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue },
            set: { binding.wrappedValue = $0.filter(\.isNumber) }
        )
    }
}
