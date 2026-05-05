import SwiftUI

/// Dashboard strip for permission / setup status (Plan: Setup Health).
struct SetupHealthView: View {
    @EnvironmentObject private var permissions: PermissionsManager
    @State private var showAccessGuide = false

    var body: some View {
        Group {
            if permissions.isAccessibilityTrusted {
                Label {
                    Text("Accessibility")
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.green, .primary.opacity(0.35))
                }
                .accessibilityLabel("Accessibility permission granted")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 12) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Accessibility")
                                    .font(.body.weight(.medium))
                                Text("Needed to restore window layouts.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                        .labelStyle(.titleAndIcon)
                        .accessibilityLabel("Accessibility permission missing")

                        Spacer(minLength: 8)

                        Button("Grant Permission") {
                            permissions.promptForAccessibilityPermission()
                            showAccessGuide = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.small)
                    }

                    Text(
                        "The system prompt often does not appear for apps run from Xcode. Use the steps in the panel that opens after Grant Permission."
                    )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

                    Button("Refresh status") {
                        permissions.refreshAccessibilityStatus()
                    }
                    .buttonStyle(.link)
                    .font(.caption2)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            permissions.refreshAccessibilityStatus()
        }
        .confirmationDialog(
            "Enable Accessibility for Contexts",
            isPresented: $showAccessGuide,
            titleVisibility: .visible
        ) {
            Button("Open System Settings") {
                permissions.openAccessibilitySettings()
            }
            Button("Show Contexts in Finder") {
                permissions.revealApplicationInFinder()
            }
            Button("Done", role: .cancel) {}
        } message: {
            Text(
                "Go to Privacy & Security → Accessibility and turn on Contexts. If it is not in the list, click +, then choose the Contexts app. When you run from Xcode, use “Show Contexts in Finder” so you can select the exact app that is running—usually under DerivedData."
            )
        }
    }
}

#Preview {
    SetupHealthView()
        .environmentObject(PermissionsManager())
        .frame(width: 440)
        .padding()
}
