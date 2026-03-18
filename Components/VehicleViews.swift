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
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(vehicle.make) \(vehicle.model)")
                        .font(.system(size: 18, weight: .semibold)) // text-lg font-semibold
                        .foregroundStyle(AppTheme.primaryText) // text-white
                        .lineLimit(1)

                    Text(vehicle.year > 0 ? String(vehicle.year) : "Unknown Year")
                        .font(.system(size: 14)) // text-sm
                        .foregroundStyle(AppTheme.secondaryText) // text-slate-400
                        .padding(.bottom, 4) // mb-2

                    if !vehicle.licensePlate.isEmpty {
                        Text(vehicle.licensePlate)
                            .font(.system(size: 12, design: .monospaced)) // text-xs font-mono
                            .foregroundStyle(Color(hex: "CBD5E1")) // text-slate-300
                            .padding(.horizontal, 12) // px-3
                            .padding(.vertical, 4) // py-1
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous) // rounded-md
                                    .fill(AppTheme.surfaceSecondary) // bg-slate-800
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16) // p-4
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