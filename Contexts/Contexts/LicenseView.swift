import AppKit
import SwiftUI

struct LicenseView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var licenseManager: LicenseManager

    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var activationError: String?

    private var statusText: String {
        switch licenseManager.status {
        case .trial(let daysRemaining):
            return "You have \(daysRemaining) day\(daysRemaining == 1 ? "" : "s") remaining in your free trial."
        case .expired:
            return "Your trial has expired."
        case .active:
            return "Contexts is activated."
        }
    }

    private var statusColor: Color {
        switch licenseManager.status {
        case .active:
            return .green
        case .trial:
            return .secondary
        case .expired:
            return .orange
        }
    }

    private var isActivated: Bool {
        if case .active = licenseManager.status { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 3)

                Text("Contexts Pro")
                    .font(.title2.weight(.semibold))

                Text(statusText)
                    .font(.callout)
                    .foregroundStyle(statusColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            if !isActivated {
                VStack(alignment: .leading, spacing: 10) {
                    Text("License Key")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    TextField("Enter your license key", text: $licenseKey)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.none)
                        .disableAutocorrection(true)
                        .font(.body.monospaced())

                    if let activationError, !activationError.isEmpty {
                        Text(activationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 10) {
                        Button {
                            Task { await activate() }
                        } label: {
                            HStack(spacing: 8) {
                                if isActivating {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(isActivating ? "Activating..." : "Activate")
                            }
                            .frame(minWidth: 110)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isActivating || licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button("Buy License") {
                            if let url = URL(string: "https://contexts-app.com") {
                                openURL(url)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(22)
        .frame(width: 440)
    }

    private func activate() async {
        let trimmed = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        activationError = nil
        isActivating = true
        defer { isActivating = false }

        do {
            try await licenseManager.activateLicense(key: trimmed)
        } catch {
            activationError = "Activation failed. Please check your key and try again."
        }
    }
}

#Preview {
    LicenseView()
        .environmentObject(LicenseManager())
}
