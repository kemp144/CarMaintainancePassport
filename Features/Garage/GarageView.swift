import SwiftData
import SwiftUI

struct GarageView: View {
    enum SortOption: String, CaseIterable, Identifiable {
        case updated = "Recently Updated"
        case makeModel = "Make / Model"
        case year = "Year"
        case mileage = "Mileage"

        var id: String { rawValue }
    }

    @EnvironmentObject private var entitlementStore: EntitlementStore
    @EnvironmentObject private var paywallCoordinator: PaywallCoordinator
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]

    @State private var searchText = ""
    @State private var sortOption: SortOption = .updated
    @State private var showingVehicleForm = false

    private var singleTrackedVehicle: Vehicle? {
        vehicles.count == 1 ? vehicles.first : nil
    }
    
    private var unlockedVehicle: Vehicle? {
        if entitlementStore.hasProAccess { return nil } // Only relevant for free mode
        if vehicles.isEmpty { return nil }

        // Pin the free slot to the oldest vehicle (first ever added), so editing a
        // locked vehicle cannot silently transfer the unlock to it.
        return vehicles.min(by: { $0.createdAt < $1.createdAt })
    }

    private var filteredVehicles: [Vehicle] {
        let searched = vehicles.filter { vehicle in
            guard !searchText.isEmpty else { return true }
            let haystack = [
                vehicle.make,
                vehicle.model,
                vehicle.licensePlate,
                vehicle.vin,
                String(vehicle.year),
                String(vehicle.currentMileage),
                vehicle.notes,
                vehicle.sortedServices.map { $0.displayTitle }.joined(separator: " "),
                vehicle.sortedReminders.map { $0.title }.joined(separator: " ")
            ].joined(separator: " ").lowercased()
            return haystack.contains(searchText.lowercased())
        }

        switch sortOption {
        case .updated:
            return searched.sorted { $0.updatedAt > $1.updatedAt }
        case .makeModel:
            return searched.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .year:
            return searched.sorted { $0.year > $1.year }
        case .mileage:
            return searched.sorted { $0.currentMileage > $1.currentMileage }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Header
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("My Garage")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)

                            Text(vehicles.isEmpty ? "Add your first vehicle to get started" : "\(vehicles.count) \(vehicles.count == 1 ? "vehicle" : "vehicles")")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        Spacer()

                        HStack(spacing: 10) {
                            if !entitlementStore.hasProAccess {
                                SubtleUpgradeButton(title: "Pro") {
                                    paywallCoordinator.present(.settings)
                                }
                            }

                            Menu {
                                Picker("Sort", selection: $sortOption) {
                                    ForForEach(SortOption.allCases) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(AppTheme.tertiaryText)
                            }

                            Button {
                                addVehicleTapped()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }

                    if !vehicles.isEmpty {
                        InlineSearchField(title: "Search vehicles...", text: $searchText)
                            .padding(.top, 14)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.pageEdge)
                .padding(.top, AppTheme.Spacing.headerTop)
                .padding(.bottom, AppTheme.Spacing.headerBottom)
                .background(AppTheme.heroGradient)

                // Content
                ScrollView(showsIndicators: false) {
                    if filteredVehicles.isEmpty {
                        if vehicles.isEmpty {
                            EmptyStateCard(
                                icon: "car.fill",
                                title: "Start your garage",
                                message: "Add your first car to track services, reminders, fuel, and documents in one calm place.",
                                actionTitle: "Add Vehicle"
                            ) {
                                addVehicleTapped()
                            }
                            .padding(AppTheme.Spacing.pageEdge)
                            .padding(.top, 20)
                        } else {
                            ContentUnavailableView {
                                Label("No vehicles found", systemImage: "magnifyingglass")
                            } description: {
                                Text("Try a different search or sorting option.")
                            }
                            .padding(.top, 40)
                        }
                    } else {
                        LazyVStack(spacing: 14) {
                            if !entitlementStore.hasProAccess && vehicles.count > 1 {
                                SurfaceCard(tier: .compact, padding: 12) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundStyle(AppTheme.accentSecondary)
                                        Text("Free includes 1 active vehicle. Your other vehicles are safely saved and can be unlocked again with Pro.")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(AppTheme.secondaryText)
                                            .lineLimit(2)
                                    }
                                }
                            }

                            ForEach(filteredVehicles) { vehicle in
                                let isLocked = !entitlementStore.hasProAccess && vehicles.count > 1 && vehicle.id != unlockedVehicle?.id
                                
                                if isLocked {
                                    Button {
                                        ContextualPaywallTrigger.trackAndPresent(
                                            reason: .lockedVehicle,
                                            coordinator: paywallCoordinator
                                        )
                                    } label: {
                                        VehicleRowCard(vehicle: vehicle, isLocked: true)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    NavigationLink {
                                        VehicleDetailView(vehicle: vehicle)
                                    } label: {
                                        VehicleRowCard(vehicle: vehicle, isLocked: false)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            if singleTrackedVehicle != nil, !entitlementStore.hasProAccess {
                                singleVehicleComparisonTeaser
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.pageEdge)
                        .padding(.top, 16)
                        .padding(.bottom, 120) // Space for FAB and TabBar
                    }
                }
            }

            if !vehicles.isEmpty {
                FloatingAddButton {
                    addVehicleTapped()
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingVehicleForm) {
            NavigationStack {
                VehicleFormView()
            }
        }
    }

    private func addVehicleTapped() {
        if entitlementStore.canAddVehicle(existingCount: vehicles.count) {
            showingVehicleForm = true
        } else {
            paywallCoordinator.present(
                .secondVehicle,
                context: PaywallPresentationContext(vehicleCount: vehicles.count)
            )
        }
    }

    private func singleVehicleGarageSnapshot(for vehicle: Vehicle) -> some View {
        SurfaceCard(tier: .primary) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Garage Snapshot")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)

                VStack(spacing: 0) {
                    garageTeaserRow(
                        title: "Vehicles tracked",
                        value: "1 vehicle tracked"
                    )
                    Divider().overlay(AppTheme.separator)
                    garageTeaserRow(
                        title: "Garage spend this year",
                        value: AppFormatters.currency(vehicle.spentThisYear, code: vehicle.currencyCode)
                    )
                    Divider().overlay(AppTheme.separator)
                    garageTeaserRow(
                        title: "Latest service",
                        value: vehicle.latestServiceDate.map { AppFormatters.mediumDate.string(from: $0) } ?? "No service history yet"
                    )
                }

            }
        }
    }

    private var singleVehicleComparisonTeaser: some View {
        SurfaceCard(tier: .primary) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Compare vehicles side by side")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)

                        Text("Add another vehicle to compare ownership costs, fuel spend, and maintenance history.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(10)
                        .background(Circle().fill(AppTheme.accent.opacity(0.14)))
                }

                Button("Unlock Pro") {
                    paywallCoordinator.present(
                        .secondVehicle,
                        context: PaywallPresentationContext(vehicleCount: vehicles.count)
                    )
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            }
        }
    }

    private func garageTeaserRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 8)
    }
}

// Helper ForEach wrapper for Picker
struct ForForEach<Data: RandomAccessCollection, ID: Hashable, Content: View>: View where Data.Element: Identifiable, Data.Element.ID == ID {
    let data: Data
    let content: (Data.Element) -> Content
    
    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }
    
    var body: some View {
        ForEach(data, content: content)
    }
}
