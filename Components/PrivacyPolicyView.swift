import SwiftUI

enum AppLegalLinks {
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let support = URL(string: "https://github.com/kemp144/CarMaintainancePassport/issues")!
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Privacy Policy")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(AppTheme.primaryText)

                                Text("Effective date: March 21, 2026")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(AppTheme.tertiaryText)

                                Text("Car Service Passport is designed as a local-first app. Most of your records stay on this device, and you can use the app without creating an account.")
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }

                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 12) {
                                policySection(
                                    title: "What we do not collect",
                                    bullets: [
                                        "No third-party analytics or usage tracking.",
                                        "No crash reporting sent to third parties.",
                                        "No advertising identifiers or ad tracking.",
                                        "No account registration or login.",
                                        "No location, contacts, or calendar data."
                                    ]
                                )

                                policySection(
                                    title: "Local storage",
                                    body: "Vehicles, services, fuel logs, reminders, and attached documents are stored locally on your device by default."
                                )

                                policySection(
                                    title: "In-App Purchases",
                                    body: "Pro upgrades are handled by Apple through In-App Purchase. The developer does not receive or store your payment information."
                                )

                                policySection(
                                    title: "VIN Lookup",
                                    body: "If you tap Autofill after entering a VIN, the VIN is sent to the NHTSA VIN decoder service to fetch make, model, and year details. This happens only when you choose to use VIN autofill."
                                )

                                policySection(
                                    title: "iCloud backup",
                                    body: "Local data remains on your device. Pro can also store backup copies in your personal iCloud Drive for recovery when iCloud is available and enabled on your device. The developer has no access to your iCloud data."
                                )

                                policySection(
                                    title: "Documents and notifications",
                                    body: "Attached photos and PDFs stay local and are included in backups. Reminder notifications are scheduled on-device by iOS and do not require an external server."
                                )

                                policySection(
                                    title: "Children's privacy",
                                    body: "The app does not knowingly collect data from children under 13. Optional VIN autofill is used only when triggered by the user."
                                )
                            }
                        }

                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Support and terms")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(AppTheme.primaryText)

                                Text("If you have questions about privacy, purchases, or backups, you can review the terms of use or contact support from the links below.")
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.secondaryText)

                                Button {
                                    openURL(AppLegalLinks.termsOfUse)
                                } label: {
                                    legalLinkRow(
                                        title: "Terms of Use",
                                        subtitle: "View Apple's standard terms for auto-renewable subscriptions and purchases.",
                                        icon: "doc.text"
                                    )
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .overlay(AppTheme.separator)

                                Button {
                                    openURL(AppLegalLinks.support)
                                } label: {
                                    legalLinkRow(
                                        title: "Support",
                                        subtitle: "Open the support page for questions, bug reports, or purchase help.",
                                        icon: "questionmark.circle"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)

            Text(body)
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func policySection(title: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)

            ForEach(bullets, id: \.self) { bullet in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 4, height: 4)
                        .padding(.top, 6)

                    Text(bullet)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func legalLinkRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.surfaceSecondary)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.primaryText)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.tertiaryText)
                .padding(.top, 2)
        }
    }
}
