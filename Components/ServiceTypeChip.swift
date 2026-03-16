import SwiftUI

struct ServiceTypeChip: View {
    let type: ServiceType
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: type.icon)
            Text(type.title)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(isSelected ? Color.black : AppTheme.primaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(isSelected ? AppTheme.accentSecondary : AppTheme.surfaceSecondary)
        )
    }
}