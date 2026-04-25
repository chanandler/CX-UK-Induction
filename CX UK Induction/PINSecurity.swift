import SwiftUI
import Security

// MARK: - Keychain-backed PIN storage

enum PinKeychain {
    private static let service = "com.cemex.cxukinduction"
    private static let account = "app_pin"
    private static let failedAttemptsKey = "pin_failed_attempts"
    private static let lockoutUntilKey = "pin_lockout_until"

    private static var defaults: UserDefaults { .standard }

    static func hasPin() -> Bool {
        readPin() != nil
    }

    static func verify(_ pin: String) -> Bool {
        guard let stored = readPin() else { return false }
        return stored == pin
    }

    static var lockoutRemainingSeconds: Int {
        let remaining = defaults.double(forKey: lockoutUntilKey) - Date().timeIntervalSince1970
        return max(0, Int(ceil(remaining)))
    }

    static func clearLockout() {
        defaults.removeObject(forKey: failedAttemptsKey)
        defaults.removeObject(forKey: lockoutUntilKey)
    }

    /// Records a failed verification attempt and returns the lockout time
    /// (in seconds) if the attempt triggered a temporary lockout.
    @discardableResult
    static func registerFailedAttempt() -> Int {
        let attempts = defaults.integer(forKey: failedAttemptsKey) + 1
        defaults.set(attempts, forKey: failedAttemptsKey)

        guard attempts >= 3 else { return 0 }

        // Exponential backoff after 3 failed attempts: 30s, 60s, 120s...
        let exponent = min(attempts - 3, 4) // cap at 8 minutes
        let lockoutSeconds = Int(pow(2.0, Double(exponent)) * 30.0)
        let until = Date().timeIntervalSince1970 + Double(lockoutSeconds)
        defaults.set(until, forKey: lockoutUntilKey)
        return lockoutSeconds
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
            let remaining = PinKeychain.lockoutRemainingSeconds
            guard remaining == 0 else {
                let template = String(localized: "pin.error.locked_try_again_template")
                errorMessage = String(format: template, remaining)
                return
            }
            guard !enteredPin.isEmpty else {
                errorMessage = String(localized: "pin.error.enter_pin")
                return
            }
            guard PinKeychain.verify(enteredPin) else {
                let lockout = PinKeychain.registerFailedAttempt()
                if lockout > 0 {
                    let template = String(localized: "pin.error.locked_try_again_template")
                    errorMessage = String(format: template, lockout)
                } else {
                    errorMessage = String(localized: "pin.error.incorrect_pin")
                }
                return
            }
            PinKeychain.clearLockout()
            onSuccess()

        case .create:
            guard newPin.count >= 4 else {
                errorMessage = String(localized: "pin.error.minimum_length")
                return
            }
            guard newPin == confirmPin else {
                errorMessage = String(localized: "pin.error.mismatch")
                return
            }
            guard PinKeychain.set(newPin) else {
                errorMessage = String(localized: "pin.error.keychain_save_failed")
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
            errorMessage = String(localized: "pin.error.minimum_length")
            return
        }
        guard newPin == confirmPin else {
            errorMessage = String(localized: "pin.error.mismatch")
            return
        }

        if hasExistingPin {
            guard PinKeychain.change(currentPin: currentPin, newPin: newPin) else {
                errorMessage = String(localized: "pin.error.current_incorrect")
                return
            }
        } else {
            guard PinKeychain.set(newPin) else {
                errorMessage = String(localized: "pin.error.keychain_save_failed")
                return
            }
        }

        successMessage = String(localized: "pin.success.updated")
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
