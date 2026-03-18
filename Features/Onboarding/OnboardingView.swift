import SwiftUI

struct OnboardingView: View {
    let onFinished: () -> Void
    @State private var page = 0

    private let items: [(title: String, message: String, icon: String)] = [
        ("Your car, one clean passport", "Keep service records, reminders, and ownership history in one calm place.", "car.rear.and.tire.marks"),
        ("Receipts and documents stay close", "Store photos, PDFs, and vehicle paperwork with the car they belong to.", "doc.on.doc.fill"),
        ("See what matters next", "Add reminders, log service, and export a polished history when you need it.", "bell.badge.fill")
    ]

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 28) {
                TabView(selection: $page) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        VStack(spacing: 28) {
                            PremiumBackdrop()
                                .frame(height: 300)
                                .overlay(alignment: .bottomLeading) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Image(systemName: item.icon)
                                            .font(.system(size: 34, weight: .semibold))
                                            .foregroundStyle(AppTheme.accentSecondary)

                                        Text(item.title)
                                            .font(.largeTitle.weight(.bold))
                                            .foregroundStyle(.white)

                                        Text(item.message)
                                            .font(.body)
                                            .foregroundStyle(Color.white.opacity(0.8))
                                    }
                                    .padding(28)
                                }

                            Text("Private by default. No account required.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .tag(index)
                        .padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                VStack(spacing: 12) {
                    Button(page == items.indices.last ? "Create Your Garage" : "Continue") {
                        withAnimation(.smooth(duration: 0.35)) {
                            if page == items.indices.last {
                                onFinished()
                            } else {
                                page += 1
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Skip") {
                        onFinished()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
    }
}