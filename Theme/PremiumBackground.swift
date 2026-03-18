import SwiftUI

struct PremiumBackdrop: View {
    var body: some View {
        ZStack {
            AppTheme.elevatedBackground

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppTheme.separator, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct PremiumScreenBackground: View {
    var body: some View {
        AppTheme.background
            .ignoresSafeArea()
    }
}