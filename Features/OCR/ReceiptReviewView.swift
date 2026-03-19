import SwiftData
import SwiftUI
import UIKit

struct ReceiptReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let vehicle: Vehicle?
    let draft: ScannedReceiptDraft
    let onCreateServiceDraft: (ScannedReceiptDraft) -> Void

    @State private var receiptTitle: String
    @State private var invoiceNumber: String
    @State private var vendorName: String
    @State private var invoiceDate: Date
    @State private var totalAmount: String
    @State private var subtotalAmount: String
    @State private var taxAmount: String
    @State private var lineItemsText: String
    @State private var notes: String
    @State private var serviceType: ServiceType
    @State private var category: EntryCategory
    @State private var isSaving = false

    init(
        vehicle: Vehicle?,
        draft: ScannedReceiptDraft,
        onCreateServiceDraft: @escaping (ScannedReceiptDraft) -> Void
    ) {
        self.vehicle = vehicle
        self.draft = draft
        self.onCreateServiceDraft = onCreateServiceDraft

        let result = draft.result
        let defaultTitle = result.vendorName?.trimmingCharacters(in: .whitespacesAndNewlines)
        _receiptTitle = State(initialValue: (defaultTitle?.isEmpty == false ? defaultTitle! : "Receipt"))
        _invoiceNumber = State(initialValue: result.invoiceNumber ?? "")
        _vendorName = State(initialValue: result.vendorName ?? result.workshopName ?? "")
        _invoiceDate = State(initialValue: result.date ?? .now)
        _totalAmount = State(initialValue: result.price.map { String(format: "%.2f", $0) } ?? "")
        _subtotalAmount = State(initialValue: result.subtotalAmount.map { String(format: "%.2f", $0) } ?? "")
        _taxAmount = State(initialValue: result.salesTaxAmount.map { String(format: "%.2f", $0) } ?? "")
        _lineItemsText = State(initialValue: result.lineItems.joined(separator: "\n"))
        _notes = State(initialValue: "")
        _serviceType = State(initialValue: result.suggestedServiceType ?? .oilChange)
        _category = State(initialValue: result.suggestedCategory ?? result.suggestedServiceType?.defaultCategory ?? .maintenance)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    previewCard
                    detailsCard
                    actionsCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Review scanned details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private var headerCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.surfaceSecondary)
                            .frame(width: 48, height: 48)

                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(AppTheme.accentSecondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Receipt scanned")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                        Text("We found service details from this receipt. Confirm them before creating a service entry.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()
                }

                if let vehicle {
                    Label(vehicle.title, systemImage: "car.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    @ViewBuilder
    private var previewCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Receipt preview")

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.surfaceSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .overlay {
                        if let image = UIImage(data: draft.imageData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(16)
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 34, weight: .semibold))
                                    .foregroundStyle(AppTheme.tertiaryText)
                                Text("Receipt image unavailable")
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                    }
                    .clipped()
            }
        }
    }

    @ViewBuilder
    private var detailsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionLabel("Scanned details")

                VStack(alignment: .leading, spacing: 12) {
                    editableField("Receipt title", text: $receiptTitle, placeholder: "Receipt")
                    editableField("Vendor / company", text: $vendorName, placeholder: "Workshop, dealer, or vendor")
                    editableField("Invoice number", text: $invoiceNumber, placeholder: "Optional")

                    DatePicker("Invoice date", selection: $invoiceDate, displayedComponents: .date)
                        .foregroundStyle(AppTheme.primaryText)

                    editableField("Total", text: $totalAmount, placeholder: "0.00")

                    HStack(spacing: 12) {
                        editableField("Subtotal", text: $subtotalAmount, placeholder: "0.00")
                        editableField("Tax", text: $taxAmount, placeholder: "0.00")
                    }

                    Picker("Suggested service type", selection: $serviceType) {
                        ForEach(ServiceType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Category", selection: $category) {
                        ForEach(EntryCategory.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Divider().overlay(AppTheme.separator)

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Line items")

                    TextEditor(text: $lineItemsText)
                        .frame(minHeight: 96)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(AppTheme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text("One line per item or description.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.tertiaryText)
                }

                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("Notes")
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(AppTheme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var actionsCard: some View {
        SurfaceCard {
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Button {
                        createServiceDraft()
                    } label: {
                        HStack(spacing: 8) {
                            Text("Create Service Draft")
                                .font(.headline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.accent)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(vehicle == nil)

                    Text("Opens a prefilled service entry using the scanned receipt details.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 6) {
                    Button {
                        Task { await saveReceiptOnly() }
                    } label: {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView()
                                    .tint(AppTheme.primaryText)
                            }
                            Text(isSaving ? "Saving..." : "Save Receipt Only")
                                .font(.headline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(AppTheme.primaryText)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.surfaceSecondary)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving || vehicle == nil)

                    Text("Saves the receipt as a document without creating a service entry.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.secondaryText)
            .tracking(0.8)
    }

    private func editableField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.sentences)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(AppTheme.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func parsedAmount(from string: String) -> Double? {
        let normalized = string
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func createServiceDraft() {
        guard vehicle != nil else { return }

        let editedResult = OCRService.OCRResult(
            date: invoiceDate,
            price: parsedAmount(from: totalAmount),
            mileage: draft.result.mileage,
            workshopName: vendorName.trimmingCharacters(in: .whitespacesAndNewlines),
            suggestedServiceType: serviceType,
            suggestedCategory: category,
            rawText: draft.result.rawText,
            invoiceNumber: invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            subtotalAmount: parsedAmount(from: subtotalAmount),
            salesTaxAmount: parsedAmount(from: taxAmount),
            lineItems: lineItemsText
                .split(whereSeparator: { $0.isNewline })
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
            vendorName: vendorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : vendorName.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: draft.result.dueDate
        )

        let fileName = receiptTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Receipt" : receiptTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let editedDraft = ScannedReceiptDraft(
            imageData: draft.imageData,
            filename: fileName,
            result: editedResult
        )

        onCreateServiceDraft(editedDraft)
        dismiss()
    }

    @MainActor
    private func saveReceiptOnly() async {
        guard let vehicle else { return }

        isSaving = true
        defer { isSaving = false }

        let cleanedTitle = receiptTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileName = cleanedTitle.isEmpty ? "Receipt" : cleanedTitle
        let page = DocumentDraftPage(
            type: .image,
            filename: fileName,
            imageData: draft.imageData,
            sourceURL: nil
        )

        do {
            _ = try await DocumentVaultStorageService.shared.saveDocument(
                pages: [page],
                title: fileName,
                category: .receipts,
                documentDate: invoiceDate,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                vehicle: vehicle,
                in: modelContext
            )
            Haptics.success()
            dismiss()
        } catch {
            Haptics.error()
        }
    }
}
