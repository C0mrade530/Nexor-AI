import SwiftUI

// MARK: - Color Palette

/// Nexor minimal color system — monochrome base with single accent.
extension Color {
    // Core
    static let loBackground = Color("LOBackground", bundle: nil)
    static let loSurface = Color("LOSurface", bundle: nil)
    static let loSurfaceElevated = Color("LOSurfaceElevated", bundle: nil)

    // Text
    static let loPrimary = Color("LOPrimary", bundle: nil)
    static let loSecondary = Color("LOSecondary", bundle: nil)
    static let loTertiary = Color("LOTertiary", bundle: nil)

    // Accent — single warm tone, the only "color" in the app
    static let loAccent = Color("LOAccent", bundle: nil)

    // Semantic
    static let loDestructive = Color(red: 0.95, green: 0.3, blue: 0.3)

    // Fallback initializers (used when color assets aren't set up yet)
    static let loBackgroundFallback = Color(light: .white, dark: Color(hex: "0A0A0A"))
    static let loSurfaceFallback = Color(light: Color(hex: "F5F5F5"), dark: Color(hex: "141414"))
    static let loSurfaceElevatedFallback = Color(light: .white, dark: Color(hex: "1C1C1E"))
    static let loPrimaryFallback = Color(light: Color(hex: "0A0A0A"), dark: Color(hex: "F5F5F5"))
    static let loSecondaryFallback = Color(light: Color(hex: "6E6E73"), dark: Color(hex: "8E8E93"))
    static let loTertiaryFallback = Color(light: Color(hex: "AEAEB2"), dark: Color(hex: "48484A"))
    static let loAccentFallback = Color(hex: "FF6B35")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

// MARK: - Typography

/// Minimal type scale — few sizes, consistent weight.
extension Font {
    static let loLargeTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let loTitle = Font.system(size: 24, weight: .semibold, design: .default)
    static let loHeadline = Font.system(size: 17, weight: .semibold, design: .default)
    static let loBody = Font.system(size: 15, weight: .regular, design: .default)
    static let loCaption = Font.system(size: 13, weight: .regular, design: .default)
    static let loMicro = Font.system(size: 11, weight: .medium, design: .default)
    static let loMono = Font.system(size: 48, weight: .thin, design: .monospaced)
    static let loMonoSmall = Font.system(size: 15, weight: .regular, design: .monospaced)
}

// MARK: - Spacing

enum Spacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

// MARK: - Reusable Components

/// Minimal divider — hairline, barely visible.
struct LODivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.loTertiaryFallback.opacity(0.3))
            .frame(height: 0.5)
    }
}

/// Minimal chip / tag.
struct LOChip: View {
    let text: String
    var isActive: Bool = false

    var body: some View {
        Text(text)
            .font(.loMicro)
            .tracking(0.5)
            .textCase(.uppercase)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs + 2)
            .background(isActive ? Color.loAccentFallback.opacity(0.12) : Color.loSurfaceFallback)
            .foregroundColor(isActive ? Color.loAccentFallback : Color.loSecondaryFallback)
            .clipShape(Capsule())
    }
}

/// Minimal icon badge for event types.
struct LOEventIcon: View {
    let type: String

    private var symbol: String {
        switch type {
        case "meeting": return "circle.grid.2x1"
        case "sales_call": return "phone.arrow.up.right"
        case "idea": return "sparkle"
        case "task": return "square"
        case "commitment": return "arrow.triangle.2.circlepath"
        case "decision": return "arrow.branch"
        case "follow_up": return "arrow.turn.up.right"
        case "personal_thought": return "cloud"
        case "planning": return "calendar"
        case "emotional_episode": return "heart"
        default: return "circle"
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .light))
            .foregroundColor(Color.loAccentFallback)
            .frame(width: 28, height: 28)
    }
}

/// Minimal section header.
struct LOSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.loMicro)
            .tracking(1.2)
            .foregroundColor(Color.loTertiaryFallback)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xs)
    }
}

/// Minimal card container.
struct LOCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(Spacing.md)
            .background(Color.loSurfaceElevatedFallback)
            .cornerRadius(12)
    }
}

/// Minimal button.
struct LOButton: View {
    let title: String
    let style: Style
    let action: () -> Void

    enum Style {
        case primary, secondary, ghost
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.loCaption)
                .tracking(0.3)
                .frame(maxWidth: style == .ghost ? nil : .infinity)
                .padding(.vertical, style == .ghost ? Spacing.xxs : Spacing.sm)
                .padding(.horizontal, Spacing.md)
                .background(backgroundColor)
                .foregroundColor(foregroundColor)
                .cornerRadius(8)
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return Color.loAccentFallback
        case .secondary: return Color.loSurfaceFallback
        case .ghost: return .clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return Color.loPrimaryFallback
        case .ghost: return Color.loAccentFallback
        }
    }
}

// MARK: - View Extensions

extension View {
    func loCardStyle() -> some View {
        self
            .padding(Spacing.md)
            .background(Color.loSurfaceElevatedFallback)
            .cornerRadius(12)
    }
}
