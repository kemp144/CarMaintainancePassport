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
            case documentModern(DocumentRecord)
            case document(AttachmentRecord)
        }

        let id: UUID
        let date: Date
        let kind: Kind
        let mileage: Int
        let cost: Double
        let vehicleTitle: String
    }

    private struct TimelineGroup: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let events: [TimelineEvent]
    }

    @Query(sort: \ServiceEntry.date, order: .reverse) private var services: [ServiceEntry]
    @Query(sort: \DocumentRecord.createdAt, order: .reverse) private var documents: [DocumentRecord]
    @Query(sort: \AttachmentRecord.createdAt, order: .reverse) private var attachments: [AttachmentRecord]
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]

    @EnvironmentObject private var appState: AppState
    @State private var sort: SortOption = .newest
    @State private var searchText = ""
    @State private var previewURL: URL?

    @State private var showingServiceForm = false

    private var currentCategory: CategoryFilter {
        CategoryFilter(rawValue: appState.timelineCategory) ?? .all
    }

    private var events: [TimelineEvent] {
        var combined: [TimelineEvent] = services.compactMap { service in
            guard let vehicleTitle = service.vehicle?.title else { return nil }
            return TimelineEvent(id: service.id, date: service.date, kind: .service(service), mileage: service.mileage, cost: service.price, vehicleTitle: vehicleTitle)
        }

        combined.append(contentsOf: documents.compactMap { document in
            guard let vehicleTitle = document.vehicle?.title else { return nil }
            return TimelineEvent(id: document.id, date: document.documentDate, kind: .documentModern(document), mileage: 0, cost: 0, vehicleTitle: vehicleTitle)
        })

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

    private var groupedEvents: [TimelineGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: events) { event in
            calendar.date(from: calendar.dateComponents([.year, .month], from: event.date)) ?? event.date
        }

        let sortedKeys = grouped.keys.sorted(by: sort == .oldest ? (<) : (>))

        return sortedKeys.map { monthStart in
            let monthEvents = grouped[monthStart, default: []]
            return TimelineGroup(
                id: monthStart.formatted(date: .abbreviated, time: .omitted),
                title: monthTitle(for: monthStart),
                subtitle: "\(monthEvents.count) \(monthEvents.count == 1 ? "entry" : "entries")",
                events: monthEvents.sorted { sort == .oldest ? $0.date < $1.date : $0.date > $1.date }
            )
        }
    }

    private var timelineSummary: some View {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: .now)
        let spendingThisYear = events.filter { 
            $0.cost > 0 && calendar.isDate($0.date, equalTo: .now, toGranularity: .year)
        }.reduce(0) { $0 + $1.cost }
        
        let eventsThisYear = events.filter { calendar.isDate($0.date, equalTo: .now, toGranularity: .year) }.count
        let latestDate = events.first?.date

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                SummaryStatTile(title: "This year", value: "\(eventsThisYear) events", icon: "chart.bar.fill")
                SummaryStatTile(title: "Spending (\(String(currentYear)))", value: AppFormatters.currency(spendingThisYear, code: primaryCurrencyCode), icon: "dollarsign.circle.fill")
                SummaryStatTile(title: "Latest", value: latestDate.map { AppFormatters.mediumDate.string(from: $0) } ?? "No history", icon: "clock.fill")
            }

            Text(scopeSummaryText)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(AppTheme.separator, lineWidth: 1)
                }
        )
    }

    @ViewBuilder
    private var timelineEmptyStateCard: some View {
        if vehicles.isEmpty {
            EmptyStateCard(
                icon: "car.fill",
                title: "No vehicle yet",
                message: "Add your first vehicle to start tracking maintenance, fuel, and ownership history.",
                actionTitle: "Open Garage"
            ) {
                appState.selectedTab = .garage
            }
        } else {
            let vehicleContext: String = {
                if let id = appState.selectedVehicleID, let selectedVehicle = vehicles.first(where: { $0.id == id }) {
                    return " for \(selectedVehicle.title)"
                }
                return ""
            }()
            
            EmptyStateCard(
                icon: "clock.badge.xmark.fill",
                title: "No service history yet",
                message: "Add your first service entry\(vehicleContext) to start building a clean ownership timeline.",
                actionTitle: "Add Service"
            ) {
                showingServiceForm = true
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Header
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Timeline")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)

                            Text(events.isEmpty ? "No events yet" : "\(events.count) \(events.count == 1 ? "event" : "events")")
                                .font(.subheadline)
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
                            .padding(.top, 14)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.pageEdge)
                .padding(.top, AppTheme.Spacing.headerTop)
                .padding(.bottom, AppTheme.Spacing.headerBottom)
                .background(AppTheme.heroGradient)

                VehicleFilterScrollView(vehicles: vehicles)

                if events.isEmpty {
                    ScrollView(showsIndicators: false) {
                        timelineEmptyStateCard
                            .padding(.horizontal, AppTheme.Spacing.pageEdge)
                            .padding(.top, AppTheme.Spacing.filterToContent)
                            .padding(.bottom, AppTheme.Spacing.bottomSafeArea)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            timelineSummary

                            ForEach(groupedEvents) { group in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(group.title)
                                                .font(.headline.weight(.semibold))
                                                .foregroundStyle(AppTheme.primaryText)
                                            Text(group.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.secondaryText)
                                        }
                                        Spacer()
                                    }

                                    LazyVStack(spacing: 12) {
                                        ForEach(group.events) { event in
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
                                            case .documentModern(let doc):
                                                NavigationLink {
                                                    DocumentDetailView(selection: .modern(doc))
                                                } label: {
                                                    SurfaceCard {
                                                        timelineListRow(for: event)
                                                    }
                                                }
                                                .buttonStyle(.plain)
                                            case .document(let att):
                                                NavigationLink {
                                                    DocumentDetailView(selection: .legacy(att))
                                                } label: {
                                                    SurfaceCard {
                                                        timelineListRow(for: event)
                                                    }
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.pageEdge)
                        .padding(.top, AppTheme.Spacing.filterToContent)
                        .padding(.bottom, AppTheme.Spacing.bottomSafeArea)
                    }
                }
            }
            
        }
        .navigationBarHidden(true)
        .sheet(item: Binding(get: {
            previewURL.map(PreviewURL.init(url:))
        }, set: { item in
            previewURL = item?.url
        })) { item in
            QuickLookPreviewSheet(url: item.url)
        }
        .sheet(isPresented: $showingServiceForm) {
            let vehicle = appState.selectedVehicleID.flatMap { id in vehicles.first(where: { $0.id == id }) } ?? vehicles.first
            if let vehicle {
                NavigationStack {
                    ServiceEntryFormView(vehicle: vehicle)
                }
            }
        }
    }


    private func timelineListRow(for event: TimelineEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            icon(for: event)
            VStack(alignment: .leading, spacing: 5) {
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
                } else if case .documentModern(let document) = event.kind, document.pageCount > 1 {
                    Label("\(document.pageCount) pages", systemImage: "paperclip")
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
        case .documentModern(let document):
            iconName = document.category.icon
        case .document(let attachment):
            iconName = attachment.type.icon
        }

        return ZStack {
            Circle()
                .fill(AppTheme.surfaceSecondary)
                .frame(width: 38, height: 38)
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.accentSecondary)
        }
    }

    private func title(for event: TimelineEvent) -> String {
        switch event.kind {
        case .service(let entry):
            return entry.displayTitle
        case .documentModern(let document):
            return document.title
        case .document(let attachment):
            return attachment.filename
        }
    }

    private func detail(for event: TimelineEvent) -> String {
        switch event.kind {
        case .service(let entry):
            let workshop = entry.workshopName.isEmpty ? "No workshop" : entry.workshopName
            return "\(AppFormatters.mileage(entry.mileage)) • \(workshop)"
        case .documentModern(let document):
            let linked = document.serviceEntry?.displayTitle ?? document.category.title
            return linked
        case .document(let attachment):
            return attachment.serviceEntry?.displayTitle ?? "Vehicle document"
        }
    }

    private func currencyCode(for event: TimelineEvent) -> String {
        switch event.kind {
        case .service(let entry):
            return entry.currencyCode
        case .documentModern(let document):
            return document.vehicle?.currencyCode ?? CurrencyPreset.eur.rawValue
        case .document(let attachment):
            return attachment.vehicle?.currencyCode ?? CurrencyPreset.eur.rawValue
        }
    }

    private func searchBlob(for event: TimelineEvent) -> String {
        switch event.kind {
        case .service(let entry):
            return [entry.displayTitle, entry.workshopName, entry.notes, entry.vehicle?.title ?? ""].joined(separator: " ")
        case .documentModern(let document):
            return [document.title, document.notes, document.category.title, document.vehicle?.title ?? "", document.serviceEntry?.displayTitle ?? ""].joined(separator: " ")
        case .document(let attachment):
            return [attachment.filename, attachment.vehicle?.title ?? "", attachment.serviceEntry?.displayTitle ?? ""].joined(separator: " ")
        }
    }

    private func vehicleID(for event: TimelineEvent) -> UUID? {
        switch event.kind {
        case .service(let entry):
            return entry.vehicle?.id
        case .documentModern(let document):
            return document.vehicle?.id
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
            case .documentModern, .document:
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

    private var primaryCurrencyCode: String {
        events.first.flatMap { event in
            switch event.kind {
            case .service(let entry):
                return entry.currencyCode
            case .documentModern(let document):
                return document.vehicle?.currencyCode
            case .document(let attachment):
                return attachment.vehicle?.currencyCode
            }
        } ?? CurrencyPreset.suggested().rawValue
    }

    private var scopeSummaryText: String {
        if let localID = appState.selectedVehicleID, let vehicle = vehicles.first(where: { $0.id == localID }) {
            return "Showing \(vehicle.title)"
        }
        if appState.showOnlyCurrentVehicle {
            return "Showing the current vehicle"
        }
        return "Showing all vehicles in your garage"
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
}
