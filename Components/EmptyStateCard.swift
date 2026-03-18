import SwiftUI

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String
    var action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(AppTheme.surfaceSecondary.opacity(0.5)) // bg-slate-800/50
                    .frame(width: 96, height: 96) // w-24 h-24

                Image(systemName: icon)
                    .font(.system(size: 40)) // w-12 h-12
                    .foregroundStyle(AppTheme.tertiaryText) // text-slate-600
            }
            .padding(.bottom, 24) // mb-6

            Text(title)
                .font(.system(size: 20, weight: .semibold)) // text-xl font-semibold
                .foregroundStyle(AppTheme.primaryText) // text-white
                .multilineTextAlignment(.center)
                .padding(.bottom, 8) // mb-2

            Text(message)
                .font(.system(size: 16)) // text-base/slate-400
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320) // max-w-xs
                .padding(.bottom, 32) // mb-8

            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold)) // w-5 h-5
                    Text(actionTitle)
                        .font(.system(size: 16, weight: .semibold))
                }
                .padding(.horizontal, 32) // px-8
                .frame(height: 48) // h-12
                .foregroundStyle(.white)
                .background(AppTheme.accent) // bg-orange-500
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)) // rounded-xl
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 64) // py-16
        .padding(.horizontal, 24) // px-6
        .frame(maxWidth: .infinity)
    }
}