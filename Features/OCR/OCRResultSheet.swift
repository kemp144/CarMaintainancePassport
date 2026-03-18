import SwiftUI

/// Shows OCR-extracted fields and lets the user confirm which ones to apply.
struct OCRResultSheet: View {
    @Environment(\.dismiss) private var dismiss

    let result: OCRService.OCRResult
    let onApply: (OCRService.OCRResult) -> Void

    @State private var applyDate: Bool
    @State private var applyPrice: Bool
    @State private var applyMileage: Bool
    @State private var applyWorkshop: Bool

    init(result: OCRService.OCRResult, onApply: @escaping (OCRService.OCRResult) -> Void) {
        self.result = result
        self.onApply = onApply
        _applyDate = State(initialValue: result.date != nil)
        _applyPrice = State(initialValue: result.price != nil)
        _applyMileage = State(initialValue: result.mileage != nil)
        _applyWorkshop = State(initialValue: result.workshopName != nil)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(AppTheme.surfaceSecondary)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Receipt Scan Results")
                                .font(.title2.bold())
                                .foregroundStyle(AppTheme.primaryText)
                            Text("Select which fields to apply to the service entry.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        if result.date == nil && result.price == nil && result.mileage == nil && result.workshopName == nil {
                            SurfaceCard(padding: 20) {
                                VStack(spacing: 8) {
                                    Image(systemName: "text.magnifyingglass")
                                        .font(.system(size: 36))
                                        .foregroundStyle(AppTheme.tertiaryText)
                                    Text("No data could be extracted from this image.")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.secondaryText)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            VStack(spacing: 2) {
                                if let date = result.date {
                                    ocrRow(
                                        icon: "calendar",
                                        label: "Date",
                                        value: AppFormatters.mediumDate.string(from: date),
                                        isOn: $applyDate
                                    )
                                }
                                if let price = result.price {
                                    ocrRow(
                                        icon: "eurosign.circle",
                                        label: "Cost",
                                        value: String(format: "%.2f", price),
                                        isOn: $applyPrice
                                    )
                                }
                                if let mileage = result.mileage {
                                    ocrRow(
                                        icon: "gauge.with.dots.needle.33percent",
                                        label: "Mileage",
                                        value: AppFormatters.mileage(mileage),
                                        isOn: $applyMileage
                                    )
                                }
                                if let workshop = result.workshopName {
                                    ocrRow(
                                        icon: "wrench.and.screwdriver",
                                        label: "Workshop",
                                        value: workshop,
                                        isOn: $applyWorkshop
                                    )
                                }
                            }
                        }

                        // Raw text disclosure
                        DisclosureGroup {
                            Text(result.rawText.isEmpty ? "No text found." : result.rawText)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(AppTheme.tertiaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                        } label: {
                            Label("Raw scanned text", systemImage: "text.alignleft")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        VStack(spacing: 12) {
                            Button {
                                let filtered = OCRService.OCRResult(
                                    date: applyDate ? result.date : nil,
                                    price: applyPrice ? result.price : nil,
                                    mileage: applyMileage ? result.mileage : nil,
                                    workshopName: applyWorkshop ? result.workshopName : nil,
                                    rawText: result.rawText
                                )
                                onApply(filtered)
                                dismiss()
                            } label: {
                                Text("Apply Selected Fields")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.accent))
                                    .foregroundStyle(.white)
                                    .font(.headline)
                            }

                            Button("Discard") {
                                dismiss()
                            }
                            .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func ocrRow(icon: String, label: String, value: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(isOn.wrappedValue ? AppTheme.accent : AppTheme.tertiaryText)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppTheme.accent)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.vertical, 2)
    }
}
