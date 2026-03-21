import SwiftUI
import SwiftData

struct VehicleFilterChip: View {
    let title: String
    let icon: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon ?? "car")
            Text(title)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(isSelected ? Color.black : AppTheme.primaryText)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(isSelected ? AppTheme.accentSecondary : AppTheme.surfaceSecondary)
        )
    }
}

struct VehicleFilterScrollView: View {
    @EnvironmentObject private var appState: AppState
    var vehicles: [Vehicle]
    
    var body: some View {
        if !vehicles.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    VehicleFilterChip(title: "All", icon: "square.grid.2x2", isSelected: appState.selectedVehicleFilterID == nil)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                appState.selectSharedVehicleFilter(nil)
                            }
                        }
                    
                    ForEach(vehicles) { vehicle in
                        VehicleFilterChip(title: vehicle.title, icon: "car.fill", isSelected: appState.selectedVehicleFilterID == vehicle.id)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    appState.selectSharedVehicleFilter(vehicle.id)
                                }
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(Color.clear)
            .overlay(
                Rectangle()
                    .fill(AppTheme.separator)
                    .frame(height: 1),
                alignment: .bottom
            )
        }
    }
}
