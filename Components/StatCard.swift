import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    var footnote: String? = nil
    var tint: Color = AppTheme.accentSecondary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.tertiaryText)

            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(2)

            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(tint)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.surfaceSecondary)
        )
    }
}