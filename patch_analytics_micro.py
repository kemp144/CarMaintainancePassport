import re

with open("Features/Garage/VehicleAnalyticsView.swift", "r") as f:
    code = f.read()

# 1. Reduce height of small 2-column stat cards slightly more
insight_tile_frame_old = """.frame(minHeight: compact ? 36 : 72, alignment: .topLeading)"""
insight_tile_frame_new = """.frame(minHeight: compact ? 34 : 64, alignment: .topLeading)"""
code = code.replace(insight_tile_frame_old, insight_tile_frame_new)

# Reduce font of small label in insight tile just a tiny bit to help with truncation
insight_tile_label_old = """.font(.system(size: compact ? 10 : 11, weight: .medium))"""
insight_tile_label_new = """.font(.system(size: compact ? 9.5 : 11, weight: .medium))"""
code = code.replace(insight_tile_label_old, insight_tile_label_new)


# 2. Fix truncated helper text in Fuel cards ("All-Time Avg" etc)
# Instead of strict line limits on compact, allow 2 lines for helper text if needed or just scale better
insight_tile_msg_old = """                case .notEnoughHistory(let msg):
                    Text(msg)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .lineLimit(compact ? 1 : 2)
                        .minimumScaleFactor(0.8)"""
insight_tile_msg_new = """                case .notEnoughHistory(let msg):
                    Text(msg)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)"""
code = code.replace(insight_tile_msg_old, insight_tile_msg_new)

insight_tile_never_old = """                case .neverRecorded:
                    Text("No recent record")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                case .incompleteRecord:
                    Text("Estimate — log more history")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.tertiaryText)"""
insight_tile_never_new = """                case .neverRecorded:
                    Text("No recent record")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppTheme.tertiaryText)
                case .incompleteRecord:
                    Text("Estimate — log more")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppTheme.tertiaryText)"""
code = code.replace(insight_tile_never_old, insight_tile_never_new)


# 3. Make helper/info text under sections more compact
# Ensure all DataConfidenceFootnote implementations are extremely tight. 
# They are actually written as `DataConfidenceFootnote(message: ...)` which means there is a component or function. Wait, let me check if there's a component.
# Actually they are just functions or struct? Ah, I don't see the struct for DataConfidenceFootnote in the previous diffs.
# Let's check how they are used.
code = code.replace(".padding(.top, 2)", ".padding(.top, 0)")
code = code.replace(".padding(.top, 4)", ".padding(.top, 2)")
code = code.replace(".padding(.horizontal, 4)", ".padding(.horizontal, 2)")


# 4. Make empty-state wording shorter
fuel_avg_1_old = """.notEnoughHistory("Need valid fill-ups")"""
fuel_avg_1_new = """.notEnoughHistory("Log full fill-ups")"""
code = code.replace(fuel_avg_1_old, fuel_avg_1_new)

fuel_avg_2_old = """.notEnoughHistory("Need more history")"""
fuel_avg_2_new = """.notEnoughHistory("Log more history")"""
code = code.replace(fuel_avg_2_old, fuel_avg_2_new)

fuel_avg_3_old = """.notEnoughHistory("Requires 3 valid fill-ups")"""
fuel_avg_3_new = """.notEnoughHistory("Log 3 full fill-ups")"""
code = code.replace(fuel_avg_3_old, fuel_avg_3_new)

fuel_avg_4_old = """.notEnoughHistory("Requires 6 valid fill-ups")"""
fuel_avg_4_new = """.notEnoughHistory("Log 6 full fill-ups")"""
code = code.replace(fuel_avg_4_old, fuel_avg_4_new)

srv_avg_1_old = """.notEnoughHistory("Needs 2+ services")"""
srv_avg_1_new = """.notEnoughHistory("Log 2+ services")"""
code = code.replace(srv_avg_1_old, srv_avg_1_new)


# 5. In Basic Tracking, make the right-side statuses visually consistent
# We need to update the AnalyticsRow state views
analytics_row_never_old = """            case .neverRecorded:
                Text("No recent record")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .multilineTextAlignment(.trailing)
            case .incompleteRecord:
                Text("Estimate — log more history")
                    .font(.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .multilineTextAlignment(.trailing)"""
analytics_row_never_new = """            case .neverRecorded:
                Text("No recent record")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .multilineTextAlignment(.trailing)
            case .incompleteRecord:
                Text("Estimate — log more")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .multilineTextAlignment(.trailing)"""
code = code.replace(analytics_row_never_old, analytics_row_never_new)


with open("Features/Garage/VehicleAnalyticsView.swift", "w") as f:
    f.write(code)

