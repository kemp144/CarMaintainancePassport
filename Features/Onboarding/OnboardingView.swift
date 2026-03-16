import SwiftUI

struct OnboardingView: View {
    let onFinished: () -> Void
    @State private var page = 0

    private let items: [(title: String, message: String, icon: String)] = [
        ("Every service, one calm record", "Track maintenance, repairs and ownership costs in a private service passport.", "car.rear.and.tire.marks"),
        ("Keep receipts close", "Store receipt photos, PDFs and vehicle documents locally, ready for visits or resale.", "doc.on.doc.fill"),
        ("Never miss what is due next", "Create reminders by date or mileage, then review what is due soon at a glance.", "bell.badge.fill"),
        ("Export a polished history", "Generate a clean PDF passport whenever you want to share or archive your records.", "square.and.arrow.up.on.square.fill")
    ]

    var body: some View {
        ZStack {
            PremiumScreenBackground()

            VStack(spacing: 28) {
                TabView(selection: $page) {
                    ForEach(Array(items.enumerated()), id: \ .offset) { index, item in
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