import SwiftData
import SwiftUI
import UIKit

struct CreateDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var paywallCoordinator: PaywallCoordinator

    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]

    let preselectedVehicle: Vehicle?

    @State private var selectedVehicleID: UUID?
    @State private var selectedServiceID: UUID?
    @State private var title: String
    @State private var category: DocumentVaultCategory
    @State private var documentDate: Date
    @State private var notes: String
    @State private var pages: [DocumentDraftPage]
    @State private var showingAddFilesSheet = false
    @State private var isSaving = false
    @State private var previewPage: DocumentDraftPage?

    init(
        preselectedVehicle: Vehicle? = nil,
        initialPages: [DocumentDraftPage] = [],
        draftSeed: DocumentDraftSeed? = nil
    ) {
        self.preselectedVehicle = preselectedVehicle
        _selectedVehicleID = State(initialValue: preselectedVehicle?.id)
        _selectedServiceID = State(initialValue: nil)
        _title = State(initialValue: draftSeed?.title ?? "New Document")
        _category = State(initialValue: draftSeed?.category ?? .general)
        _documentDate = State(initialValue: .now)
        _notes = State(initialValue: "")
        _pages = State(initialValue: draftSeed?.pages ?? initialPages)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    metadataCard
                    DocumentAttachmentsSection(
                        pages: $pages,
                        previewPage: $previewPage
                    ) {
                        presentAddFiles()
                    }

                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("New Document")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .task {
            if selectedVehicleID == nil {
                selectedVehicleID = preselectedVehicle?.id ?? vehicles.first?.id
            }
        }
        .onChange(of: selectedVehicleID) { _, _ in
            selectedServiceID = nil
        }
        .sheet(isPresented: $showingAddFilesSheet) {
            DocumentAddFilesSheet(
                allowReceiptScan: false,
                onDocumentSeed: { seed in
                    appendDraftSeed(seed)
                }
            )
        }
        .sheet(item: $previewPage) { page in
            DraftPagePreviewSheet(page: page)
        }
    }

    private var selectedVehicle: Vehicle? {
        vehicles.first(where: { $0.id == selectedVehicleID }) ?? preselectedVehicle
    }

    private var selectedServiceEntry: ServiceEntry? {
        selectedVehicle?.sortedServices.first(where: { $0.id == selectedServiceID })
    }

    private func presentAddFiles() {
        guard entitlementStore.canUseDocumentVault() else {
            paywallCoordinator.present(.documentVault)
            return
        }

        showingAddFilesSheet = true
    }

    private var attachmentSummary: String {
        guard !pages.isEmpty else { return "No files added yet" }
        return "\(pages.count) \(pages.count == 1 ? "file" : "files") attached"
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

                        Image(systemName: category.icon)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(AppTheme.accentSecondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("New Document")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                        Text(attachmentSummary)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()
                }

                Text("Add photos or PDFs to create a document for this vehicle.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
        }
    }

    @ViewBuilder
    private var metadataCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionLabel("Document details")

                VStack(alignment: .leading, spacing: 10) {
                    labeledTextField("Title", text: $title, placeholder: "Receipt, registration, warranty...")
                    Picker("Category", selection: $category) {
                        ForEach(DocumentVaultCategory.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    DatePicker("Date", selection: $documentDate, displayedComponents: .date)
                        .foregroundStyle(AppTheme.primaryText)
                }

                Divider().overlay(AppTheme.separator)

                sectionLabel("Vehicle")

                Picker("Vehicle", selection: $selectedVehicleID) {
                    ForEach(vehicles) { vehicle in
                        Text(vehicle.title).tag(Optional(vehicle.id))
                    }
                }
                .disabled(preselectedVehicle != nil)

                if let selectedVehicle {
                    Picker("Link to service entry", selection: $selectedServiceID) {
                        Text("No linked service").tag(Optional<UUID>.none)
                        ForEach(selectedVehicle.sortedServices) { service in
                            Text("\(service.displayTitle) • \(AppFormatters.mediumDate.string(from: service.date))")
                                .tag(Optional(service.id))
                        }
                    }
                    .pickerStyle(.menu)
                } else {
                    Text("Choose a vehicle to optionally link this document to a service entry.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.tertiaryText)
                }

                Divider().overlay(AppTheme.separator)

                sectionLabel("Notes")

                TextField("Optional notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(AppTheme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var saveButton: some View {
        Button {
            Task { await saveDocument() }
        } label: {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                }
                Text(isSaving ? "Saving..." : "Save Document")
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
        .disabled(isSaving || selectedVehicle == nil || pages.isEmpty)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.secondaryText)
            .tracking(0.8)
    }

    private func labeledTextField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
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

    @MainActor
    private func appendDraftSeed(_ seed: DocumentDraftSeed) {
        guard !seed.pages.isEmpty else { return }

        if pages.isEmpty {
            title = seed.title
            category = seed.category
        } else if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title == "New Document" {
            title = seed.title
        }

        pages.append(contentsOf: seed.pages)
    }

    @MainActor
    private func saveDocument() async {
        guard let vehicle = selectedVehicle, !pages.isEmpty else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            _ = try await DocumentVaultStorageService.shared.saveDocument(
                pages: pages,
                title: title,
                category: category,
                documentDate: documentDate,
                notes: notes,
                vehicle: vehicle,
                serviceEntry: selectedServiceEntry,
                in: modelContext
            )
            Haptics.success()
            dismiss()
        } catch {
            Haptics.error()
        }
    }
}

private struct DraftPagePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let page: DocumentDraftPage

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text(page.filename)
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(AppTheme.primaryText)
                                    Spacer()
                                    Text(page.type.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.accent)
                                }

                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(AppTheme.surfaceSecondary)
                                    .overlay {
                                        if let previewImage = page.previewImage {
                                            Image(uiImage: previewImage)
                                                .resizable()
                                                .scaledToFit()
                                                .padding(12)
                                        } else {
                                            Image(systemName: page.type.icon)
                                                .font(.system(size: 42, weight: .semibold))
                                                .foregroundStyle(AppTheme.accentSecondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 420)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Page Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
