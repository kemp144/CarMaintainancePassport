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
        SurfaceCard(padding: 0) {
            HStack(alignment: .top, spacing: 16) {
                // Vehicle Image (w-24 h-24 rounded-lg bg-slate-800)
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
                            .font(.system(size: 40)) // w-10 h-10 roughly
                            .foregroundStyle(AppTheme.tertiaryText) // text-slate-600
                    }
                }
                .frame(width: 96, height: 96)

                // Vehicle Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(vehicle.make) \(vehicle.model)")
                        .font(.system(size: 18, weight: .semibold)) // text-lg font-semibold
                        .foregroundStyle(AppTheme.primaryText) // text-white
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(vehicle.year > 0 ? String(vehicle.year) : "Unknown Year")
                        if !vehicle.licensePlate.isEmpty {
                            Text("•")
                            Text(vehicle.licensePlate)
                        }
                    }
                    .font(.system(size: 13.5)) // text-sm
                        .foregroundStyle(AppTheme.secondaryText) // text-slate-400
                        .lineLimit(1)

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
                        compactMetric(label: "This year", value: AppFormatters.currency(vehicle.spentThisYear, code: vehicle.currencyCode))
                        compactMetric(label: "Reminders", value: "\(vehicle.activeRemindersCount)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16) // p-4
        }
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