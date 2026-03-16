import SwiftUI

struct VehicleHeroCard: View {
    let vehicle: Vehicle

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PremiumBackdrop()
                .frame(height: 250)
                .overlay(alignment: .topTrailing) {
                    if let reference = vehicle.coverImageReference,
                       let image = UIImage(contentsOfFile: AttachmentStorageService.fileURL(for: reference).path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 156, height: 132)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            }
                            .padding(16)
                    }
                }

            VStack(alignment: .leading, spacing: 12) {
                Text(vehicle.title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                Text(vehicle.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.8))

                HStack(spacing: 10) {
                    Label(AppFormatters.mileage(vehicle.currentMileage), systemImage: "speedometer")
                    Label(AppFormatters.currency(vehicle.totalSpent, code: vehicle.currencyCode), systemImage: "eurosign.circle")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.88))
            }
            .padding(24)
        }
    }
}

struct VehicleRowCard: View {
    let vehicle: Vehicle

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surfaceSecondary)
                .frame(width: 62, height: 62)
                .overlay {
                    if let reference = vehicle.coverImageReference,
                       let image = UIImage(contentsOfFile: AttachmentStorageService.fileURL(for: reference).path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        Image(systemName: "car.side.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.accentSecondary)
                    }
                }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(vehicle.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)

                        Text(vehicle.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer(minLength: 8)

                    Text(AppFormatters.currency(vehicle.totalSpent, code: vehicle.currencyCode))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accentSecondary)
                }

                Label(AppFormatters.mileage(vehicle.currentMileage), systemImage: "gauge.with.dots.needle.33percent")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)

                if let latest = vehicle.latestService {
                    Text("Latest: \(latest.displayTitle) • \(AppFormatters.mediumDate.string(from: latest.date))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .lineLimit(1)
                } else if let reminder = vehicle.nextActiveReminder() {
                    Text("Next: \(reminder.title)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .lineLimit(1)
                }
            }
        }
    }
}

struct ReminderBadge: View {
    let status: ReminderStatus

    var body: some View {
        Text(status.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(status.tint.opacity(0.14)))
    }
}