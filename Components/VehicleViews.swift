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
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(AppTheme.separator, lineWidth: 1)
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
                    .foregroundStyle(AppTheme.secondaryText)

                VStack(alignment: .leading, spacing: 2) {
                    Label(vehicle.currentMileageDisplayString, systemImage: "speedometer")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.88))

                    if let mileageDate = vehicle.latestMileageDate {
                        Text("Updated \(AppFormatters.mediumDate.string(from: mileageDate))")
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }

                HStack(spacing: 10) {
                    Label(AppFormatters.currency(vehicle.totalSpent, code: vehicle.currencyCode), systemImage: AppFormatters.currencyIcon(for: vehicle.currencyCode, filled: false))
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
    var isLocked: Bool = false

    var body: some View {
        SurfaceCard(padding: 0) {
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .top, spacing: 16) {
                    // Vehicle Image
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppTheme.surfaceSecondary)

                        if let reference = vehicle.coverImageReference,
                           let image = UIImage(contentsOfFile: AttachmentStorageService.fileURL(for: reference).path) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else {
                            Image(systemName: "car.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(AppTheme.tertiaryText)
                        }
                    }
                    .frame(width: 96, height: 96)

                    // Vehicle Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(vehicle.make) \(vehicle.model)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.trailing, isLocked ? 24 : 0)

                        HStack(spacing: 6) {
                            Text(vehicle.year > 0 ? String(vehicle.year) : "Unknown Year")
                            if !vehicle.licensePlate.isEmpty {
                                Text("•")
                                Text(vehicle.licensePlate)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                        .font(.system(size: 13.5))
                        .foregroundStyle(AppTheme.secondaryText)

                        ownershipInfoRow(
                            icon: "speedometer",
                            title: "Current mileage",
                            value: vehicle.currentMileageDisplayString
                        )

                        if let lastServiceDate = vehicle.latestServiceDate {
                            ownershipInfoRow(
                                icon: "wrench.and.screwdriver",
                                title: "Last service",
                                value: AppFormatters.mediumDate.string(from: lastServiceDate)
                            )
                        }

                        if let reminder = vehicle.nextDueReminder {
                            ownershipInfoRow(
                                icon: "bell.badge.fill",
                                title: reminder.status(for: vehicle) == .overdue ? "Attention" : "Next due",
                                value: reminder.title
                            )
                        }

                        HStack(spacing: 8) {
                            compactMetric(label: "Docs", value: "\(vehicle.documentsCount)")
                            compactMetric(label: "Service YTD", value: AppFormatters.currency(vehicle.spentThisYear, code: vehicle.currencyCode))
                            compactMetric(label: "Reminders", value: "\(vehicle.activeRemindersCount)")
                        }
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(12)
                        .background(
                            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 16, bottomTrailingRadius: 0, topTrailingRadius: 16)
                                .fill(AppTheme.surfaceSecondary)
                        )
                }
            }
        }
        .opacity(isLocked ? 0.65 : 1.0)
    }

    private func ownershipInfoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
            Text("•")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.tertiaryText)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func compactMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(AppTheme.tertiaryText)
            Text(value)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ReminderBadge: View {
    let status: ReminderStatus

    var body: some View {
        Text(status.title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(status.tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule(style: .continuous).fill(status.tint.opacity(0.14)))
    }
}
