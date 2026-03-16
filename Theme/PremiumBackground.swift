import SwiftUI

struct PremiumBackdrop: View {
    var body: some View {
        ZStack {
            AppTheme.heroGradient

            Circle()
                .fill(Color(hex: "17465A").opacity(0.65))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: 120, y: -180)

            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .fill(Color(hex: "0F7A82").opacity(0.18))
                .frame(width: 360, height: 160)
                .rotationEffect(.degrees(-22))
                .blur(radius: 24)
                .offset(x: -90, y: -10)

            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 240, height: 240)
                .blur(radius: 50)
                .offset(x: -140, y: 180)

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.42)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
    }
}

struct PremiumScreenBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0B1016"), Color(hex: "0E1822"), Color(hex: "09131B")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [Color(hex: "123A48").opacity(0.34), .clear, Color(hex: "0B1A25").opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(AppTheme.accent.opacity(0.12))
                .frame(width: 360, height: 360)
                .blur(radius: 120)
                .offset(x: 110, y: -260)
                .ignoresSafeArea()

            Circle()
                .fill(Color(hex: "18485A").opacity(0.09))
                .frame(width: 340, height: 340)
                .blur(radius: 120)
                .offset(x: -140, y: 320)
                .ignoresSafeArea()
        }
    }
}