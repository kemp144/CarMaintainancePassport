import StoreKit
import SwiftUI

struct PaywallView: View {
    let reason: PaywallReason

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entitlementStore: EntitlementStore

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumScreenBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        PremiumBackdrop()
                            .frame(height: 280)
                            .overlay(alignment: .bottomLeading) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(reason.title)
                                        .font(.largeTitle.weight(.bold))
                                        .foregroundStyle(.white)
                                    Text(reason.message)
                                        .font(.body)
                                        .foregroundStyle(Color.white.opacity(0.82))
                                }
                                .padding(24)
                            }

                        SurfaceCard {
                            PremiumSectionHeader(title: "Free vs Pro", subtitle: "One-time purchase. No subscription. No ads.")

                            comparisonRow(title: "Vehicles", free: "1", pro: "Unlimited")
                            comparisonRow(title: "Service entries", free: "15 total", pro: "Unlimited")
                            comparisonRow(title: "Reminders", free: "Basic", pro: "Unlimited")
                            comparisonRow(title: "Documents", free: "Included", pro: "Unlimited")
                            comparisonRow(title: "PDF export", free: "Locked", pro: "Included")
                        }

                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Why Pro")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(AppTheme.primaryText)

                                Text("Pro keeps the app simple: one quiet upgrade for lifetime access, with all data staying on device unless you choose to export it.")
                                    .font(.body)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }

                        VStack(spacing: 12) {
                            Button(entitlementStore.product.map { "Unlock Pro • \($0.displayPrice)" } ?? "Unlock Pro") {
                                Task {
                                    await entitlementStore.purchaseLifetimePro()
                                    if entitlementStore.hasProAccess {
                                        dismiss()
                                    }
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())

                            Button("Restore Purchases") {
                                Task {
                                    await entitlementStore.restorePurchases()
                                    if entitlementStore.hasProAccess {
                                        dismiss()
                                    }
                                }
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }

                        if let message = entitlementStore.purchaseErrorMessage {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.warning)
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.primaryText)
                }
            }
        }
    }

    private func comparisonRow(title: String, free: String, pro: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            Text(free)
                .foregroundStyle(AppTheme.secondaryText)
                .frame(width: 90, alignment: .trailing)
            Text(pro)
                .foregroundStyle(AppTheme.accentSecondary)
                .frame(width: 110, alignment: .trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 6)
    }
}