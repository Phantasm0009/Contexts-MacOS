import Foundation
import Security

@MainActor
final class LicenseManager: ObservableObject {
    enum LicenseStatus: Equatable {
        case trial(daysRemaining: Int)
        case active
        case expired
    }

    @Published var status: LicenseStatus = .trial(daysRemaining: 14)

    private let trialLengthDays = 14
    private let firstLaunchDateKey = "com.contexts.Contexts.firstLaunchDate"
    private let licenseService = "com.contexts.Contexts.license"
    private let licenseAccount = "license_key"

    init() {
        refreshTrialStatusFromFirstLaunchDate()

        if let key = loadLicenseKey(), !key.isEmpty {
            Task {
                await validateLicense(existingKey: key)
            }
        }
    }

    func activateLicense(key: String) async throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let body: [String: String] = [
            "license_key": trimmed,
            "instance_name": Host.current().localizedName ?? "Mac",
        ]

        let response = try await postLicenseRequest(
            endpoint: "https://api.lemonsqueezy.com/v1/licenses/activate",
            body: body
        )

        guard response.isSuccessful else {
            throw LicenseError.activationRejected
        }

        saveLicenseKey(trimmed)
        status = .active
    }

    func validateLicense() async {
        guard let key = loadLicenseKey(), !key.isEmpty else { return }
        await validateLicense(existingKey: key)
    }

    // MARK: - Trial

    private func refreshTrialStatusFromFirstLaunchDate() {
        let defaults = UserDefaults.standard
        let now = Date()

        let firstLaunch: Date
        if let stored = defaults.object(forKey: firstLaunchDateKey) as? Date {
            firstLaunch = stored
        } else {
            firstLaunch = now
            defaults.set(firstLaunch, forKey: firstLaunchDateKey)
        }

        let daysPassed = max(0, Calendar.current.dateComponents([.day], from: firstLaunch, to: now).day ?? 0)
        if daysPassed > trialLengthDays {
            status = .expired
        } else {
            status = .trial(daysRemaining: max(0, trialLengthDays - daysPassed))
        }
    }

    // MARK: - Validation

    private func validateLicense(existingKey key: String) async {
        let body: [String: String] = [
            "license_key": key,
            "instance_name": Host.current().localizedName ?? "Mac",
        ]

        do {
            let response = try await postLicenseRequest(
                endpoint: "https://api.lemonsqueezy.com/v1/licenses/validate",
                body: body
            )
            if response.isSuccessful {
                status = .active
            } else {
                refreshTrialStatusFromFirstLaunchDate()
            }
        } catch {
            // Keep app usable offline: fall back to trial/expired state when validation is unavailable.
            refreshTrialStatusFromFirstLaunchDate()
        }
    }

    private func postLicenseRequest(endpoint: String, body: [String: String]) async throws -> LemonSqueezyResponse {
        guard let url = URL(string: endpoint) else { throw LicenseError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        guard let httpResponse = httpResponse as? HTTPURLResponse else {
            throw LicenseError.invalidServerResponse
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw LicenseError.httpFailure(statusCode: httpResponse.statusCode)
        }

        return (try? JSONDecoder().decode(LemonSqueezyResponse.self, from: data)) ?? LemonSqueezyResponse()
    }

    // MARK: - Keychain

    private func saveLicenseKey(_ key: String) {
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: licenseService,
            kSecAttrAccount as String: licenseAccount,
        ]

        SecItemDelete(query as CFDictionary)

        var insert = query
        insert[kSecValueData as String] = data
        SecItemAdd(insert as CFDictionary, nil)
    }

    private func loadLicenseKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: licenseService,
            kSecAttrAccount as String: licenseAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

private enum LicenseError: Error {
    case invalidURL
    case invalidServerResponse
    case httpFailure(statusCode: Int)
    case activationRejected
}

private struct LemonSqueezyResponse: Decodable {
    let activated: Bool?
    let valid: Bool?
    let success: Bool?
    let status: String?
    let data: LemonSqueezyData?
    let meta: LemonSqueezyMeta?

    init(
        activated: Bool? = nil,
        valid: Bool? = nil,
        success: Bool? = nil,
        status: String? = nil,
        data: LemonSqueezyData? = nil,
        meta: LemonSqueezyMeta? = nil
    ) {
        self.activated = activated
        self.valid = valid
        self.success = success
        self.status = status
        self.data = data
        self.meta = meta
    }

    var isSuccessful: Bool {
        if activated == true || valid == true || success == true { return true }
        if let status, status.lowercased() == "active" { return true }
        if let status = data?.attributes?.status, status.lowercased() == "active" { return true }
        if let activated = data?.attributes?.activated, activated { return true }
        if let valid = data?.attributes?.valid, valid { return true }
        if let activated = meta?.activated, activated { return true }
        if let valid = meta?.valid, valid { return true }
        return false
    }
}

private struct LemonSqueezyData: Decodable {
    let attributes: LemonSqueezyAttributes?
}

private struct LemonSqueezyAttributes: Decodable {
    let status: String?
    let activated: Bool?
    let valid: Bool?
}

private struct LemonSqueezyMeta: Decodable {
    let activated: Bool?
    let valid: Bool?
}
