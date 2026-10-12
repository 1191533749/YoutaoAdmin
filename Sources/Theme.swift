import SwiftUI

// 全局配色 + 通用组件
extension Color {
    static let appAccent = Color(red: 0.33, green: 0.30, blue: 0.90)   // 靛蓝
    static let appViolet = Color(red: 0.52, green: 0.29, blue: 0.92)   // 紫
    static let appGreen  = Color(red: 0.16, green: 0.72, blue: 0.48)   // 绿
    static let appRed    = Color(red: 0.92, green: 0.31, blue: 0.31)   // 红
    static let appOrange = Color(red: 0.95, green: 0.60, blue: 0.14)   // 橙
    static let appBlue   = Color(red: 0.20, green: 0.52, blue: 0.96)   // 蓝
    static let appTeal   = Color(red: 0.11, green: 0.64, blue: 0.64)   // 青
}

struct AppGradient: View {
    var body: some View {
        LinearGradient(colors: [.appAccent, .appViolet],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension View {
    func appCard() -> some View {
        self.padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground)))
    }
}

// 状态胶囊徽章
struct StatusBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.14)))
            .foregroundColor(color)
    }
}

// 统计卡片
struct StatTile: View {
    let icon: String
    let tint: Color
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint))
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 24, weight: .bold)).minimumScaleFactor(0.5).lineLimit(1)
                Text(title).font(.caption).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

// 主按钮样式
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [.appAccent, .appViolet], startPoint: .leading, endPoint: .trailing))
                .opacity(configuration.isPressed ? 0.8 : 1))
    }
}
