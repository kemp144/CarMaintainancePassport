with open("Features/Garage/VehicleAnalyticsView.swift", "r") as f:
    code = f.read()

insight_message_card = """
struct InsightMessageCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    var messageColor: Color = AppTheme.secondaryText

    var body: some View {
        SurfaceCard(padding: 14) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.surfaceSecondary)
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(messageColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
"""

if "struct InsightMessageCard" not in code:
    old = "struct InsightTile: View {"
    code = code.replace(old, insight_message_card + "\n" + old)

with open("Features/Garage/VehicleAnalyticsView.swift", "w") as f:
    f.write(code)

