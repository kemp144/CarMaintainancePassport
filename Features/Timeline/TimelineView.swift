import SwiftData
import SwiftUI

struct TimelineView: View {
    enum SortOption: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case oldest = "Oldest"
        case mileage = "Mileage"
        case cost = "Cost"

        var id: String { rawValue }
    }

    enum CategoryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case maintenance = "Maintenance"
        case repairs = "Repairs"
        case documents = "Documents"
        case expenses = "Expenses"

        var id: String { rawValue }
    }

    private struct TimelineEvent: Identifiable {
        enum Kind {
            case service(ServiceEntry)
            case document(AttachmentRecord)
        }

        let id: UUID
        let date: Date
        let kind: Kind
        let mileage: Int
        let cost: Double
        let vehicleTitle: String
    }

    @Query(sort: \ServiceEntry.date, order: .reverse) private var services: [ServiceEntry]
    @Query(sort: \AttachmentRecord.createdAt, order: .reverse) private var attachments: [AttachmentRecord]
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]

    @EnvironmentObject private var appState: AppState
    @State private var sort: SortOption = .newest
    @State private var searchText = ""
    @State private var previewURL: URL?

    private var currentCategory: CategoryFilter {
        CategoryFilter(rawValue: appState.timelineCategory) ?? .all
    }

    private var events: [TimelineEvent] {
        var combined: [TimelineEvent] = services.compactMap { service in
            guard let vehicleTitle = service.vehicle?.title else { return nil }
            return TimelineEvent(id: service.id, date: service.date, kind: .service(service), mileage: service.mileage, cost: service.price, vehicleTitle: vehicleTitle)
        }

        combined.append(contentsOf: attachments.filter { $0.serviceEntry == nil }.compactMap { attachment in
            guard let vehicleTitle = attachment.vehicle?.title else { return nil }
            return TimelineEvent(id: attachment.id, date: attachment.createdAt, kind: .document(attachment), mileage: attachment.serviceEntry?.mileage ?? 0, cost: 0, vehicleTitle: vehicleTitle)
        })

        let filtered = combined.filter { event in
            var matchesVehicle = true
            if appState.showOnlyCurrentVehicle, let globalID = appState.selectedVehicleID {
                matchesVehicle = (vehicleID(for: event) == globalID)
            } else if let localID = appState.selectedVehicleID {
                matchesVehicle = (vehicleID(for: event) == localID)
            }
            
            let matchesCategory = matchesCategoryFilter(for: event)
            let matchesSearch = matchesSearch(for: event)
            return matchesVehicle && matchesCategory && matchesSearch
        }

        switch sort {
        case .newest:
            return filtered.sorted { $0.date > $1.date }
        case .oldest:
            return filtered.sorted { $0.date < $1.date }
        case .mileage:
            return filtered.sorted { $0.mileage > $1.mileage }
        case .cost:
            return filtered.sorted { $0.cost > $1.cost }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Header
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Timeline")
                                .font(.system(size: 30, weight: .bold)) // text-3xl
                                .foregroundStyle(AppTheme.primaryText)
                            
                            Text(events.isEmpty ? "No events yet" : "\(events.count) \(events.count == 1 ? "event" : "events")")
                                .font(.system(size: 16)) // text-base
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        
                        Spacer()
                        
                        Menu {
                            Picker("Sort", selection: $sort) {
                                ForEach(SortOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.tertiaryText)
                        }
                        
                        Menu {
                            Picker("Category", selection: $appState.timelineCategory) {
                                ForEach(CategoryFilter.allCases) { filter in
                                    Text(filter.rawValue).tag(filter.rawValue)
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.tertiaryText)
                                .padding(.leading, 8)
                        }
                    }
                    
                    if !events.isEmpty {
                        InlineSearchField(title: "Workshop, note or vehicle...", text: $searchText)
                            .padding(.top, 16)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 48) // pt-12
                .padding(.bottom, 32) // pb-8
                .background(AppTheme.heroGradient)

                VehicleFilterScrollView(vehicles: vehicles)

                if events.isEmpty {
                    ScrollView(showsIndicators: false) {
                        ContentUnavailableView {
                            Label("No timeline results", systemImage: "clock.badge.xmark.fill")
                        } description: {
                            Text("Adjust filters or add a service entry to start the vehicle history.")
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding(.top, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(events) { event in
                                switch event.kind {
                                case .service(let entry):
                                    NavigationLink {
                                        ServiceDetailView(entry: entry)
                                    } label: {
                                        SurfaceCard {
                                            timelineListRow(for: event)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                case .document(let attachment):
                                    Button {
                                        previewURL = AttachmentStorageService.fileURL(for: attachment.storageReference)
                                    } label: {
                                        SurfaceCard {
                                            timelineListRow(for: event)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(24)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(item: Binding(get: {
            previewURL.map(PreviewURL.init(url:))
        }, set: { value in
            previewURL = value?.url
        })) { item in
            QuickLookPreviewSheet(url: item.url)
        }
    }

    private func timelineListRow(for event: TimelineEvent) -> some View {
        HStack(alignment: .top, spacing: 14) {
            icon(for: event)
            VStack(alignment: .leading, spacing: 6) {
                Text(title(for: event))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(event.vehicleTitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                Text(detail(for: event))
                    .font(.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
                
                if case .service(let entry) = event.kind, !entry.attachments.isEmpty {
                    Label("\(entry.attachments.count) \(entry.attachments.count == 1 ? "photo/doc" : "photos/docs")", systemImage: "paperclip")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.accentSecondary)
                        .padding(.top, 2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(AppFormatters.mediumDate.string(from: event.date))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)
                if event.cost > 0 {
                    Text(AppFormatters.currency(event.cost, code: currencyCode(for: event)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accentSecondary)
                }
            }
        }
    }

    private func icon(for event: TimelineEvent) -> some View {
        let iconName: String
        switch event.kind {
        case .service(let entry):
            iconName = entry.serviceType.icon
        case .document(let attachment):
            iconName = attachment.type.icon
        }

        return ZStack {
            Circle()
                .fill(AppTheme.surfaceSecondary)
                .frame(width: 44, height: 44)
            Image(systemName: iconName)
                .foregroundStyle(AppTheme.accentSecondary)
        }
    }

    private func title(for event: TimelineEvent) -> String {
        switch event.kind {
        case .service(let entry):
            return entry.displayTitle
        case .document(let attachment):
            return attachment.filename
        }
    }

    private func detail(for event: TimelineEvent) -> String {
        switch event.kind {
        case .service(let entry):
            let workshop = entry.workshopName.isEmpty ? "No workshop" : entry.workshopName
            return "\(AppFormatters.mileage(entry.mileage)) • \(workshop)"
        case .document(let attachment):
            return attachment.serviceEntry?.displayTitle ?? "Vehicle document"
        }
    }

    private func currencyCode(for event: TimelineEvent) -> String {
        switch event.kind {
        case .service(let entry):
            return entry.currencyCode
        case .document(let attachment):
            return attachment.vehicle?.currencyCode ?? CurrencyPreset.eur.rawValue
        }
    }

    private func searchBlob(for event: TimelineEvent) -> String {
        switch event.kind {
        case .service(let entry):
            return [entry.displayTitle, entry.workshopName, entry.notes, entry.vehicle?.title ?? ""].joined(separator: " ")
        case .document(let attachment):
            return [attachment.filename, attachment.vehicle?.title ?? "", attachment.serviceEntry?.displayTitle ?? ""].joined(separator: " ")
        }
    }

    private func vehicleID(for event: TimelineEvent) -> UUID? {
        switch event.kind {
        case .service(let entry):
            return entry.vehicle?.id
        case .document(let attachment):
            return attachment.vehicle?.id
        }
    }

    private func matchesCategoryFilter(for event: TimelineEvent) -> Bool {
        switch currentCategory {
        case .all:
            return true
        case .maintenance:
            guard case .service(let entry) = event.kind else { return false }
            return entry.category == .maintenance || entry.category == .care
        case .repairs:
            guard case .service(let entry) = event.kind else { return false }
            return entry.category == .repair
        case .documents:
            switch event.kind {
            case .document:
                return true
            case .service(let entry):
                return !entry.attachments.isEmpty
            }
        case .expenses:
            guard case .service(let entry) = event.kind else { return false }
            return entry.price > 0
        }
    }

    private func matchesSearch(for event: TimelineEvent) -> Bool {
        guard !searchText.isEmpty else { return true }
        return searchBlob(for: event).localizedCaseInsensitiveContains(searchText)
    }
}