import SwiftUI

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String
    var action: () -> Void

    var body: some View {
        SurfaceCard(padding: 24) {
            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    Circle()
                        .fill(AppTheme.surfaceSecondary)
                        .frame(width: 58, height: 58)

                    Image(systemName: icon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.accentSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text(message)
                        .font(.body)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}