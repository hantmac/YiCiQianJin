import SwiftUI

/// Shared visual language: a gilt dictionary read at night. Deep ink-blue paper, warm gold
/// reserved for primary actions and rewards (the 「千金」 in the name), English headwords in serif.
enum Theme {
    static let bgTop = Color(red: 0.063, green: 0.086, blue: 0.149)
    static let bgBottom = Color(red: 0.035, green: 0.047, blue: 0.090)

    static let gold = Color(red: 0.93, green: 0.78, blue: 0.50)
    static let goldDeep = Color(red: 0.83, green: 0.62, blue: 0.30)
    /// Text on gold surfaces (dark brown keeps WCAG contrast on the light gold).
    static let onGold = Color(red: 0.17, green: 0.11, blue: 0.03)

    static let correct = Color(red: 0.49, green: 0.82, blue: 0.64)
    static let wrong = Color(red: 0.95, green: 0.53, blue: 0.48)
    static let flame = Color(red: 0.96, green: 0.63, blue: 0.33)
    /// Silver tier in the collection and secondary data in charts.
    static let silver = Color(red: 0.72, green: 0.78, blue: 0.88)

    /// Warm white, like paper under a reading lamp.
    static let textPrimary = Color(red: 0.96, green: 0.94, blue: 0.90)
    static let textSecondary = textPrimary.opacity(0.70)
    static let textTertiary = textPrimary.opacity(0.52)
    static let surface = Color.white.opacity(0.06)
    static let surfaceStrong = Color.white.opacity(0.09)
    static let stroke = Color.white.opacity(0.08)
    static let track = Color.white.opacity(0.10)

    static let goldGradient = LinearGradient(
        colors: [Color(red: 0.95, green: 0.83, blue: 0.57), Color(red: 0.85, green: 0.65, blue: 0.35)],
        startPoint: .top, endPoint: .bottom)

    static let radius: CGFloat = 20
    static let smallRadius: CGFloat = 14

    /// The English word itself is set in a serif, like a dictionary headword.
    static func wordFont(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .serif) }
    /// Display numbers share the headword serif.
    static func number(_ style: Font.TextStyle) -> Font { .system(style, design: .serif).weight(.semibold) }
    /// Small gold label above a title.
    static let eyebrow: Font = .caption.weight(.semibold)
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom], startPoint: .top, endPoint: .bottom)
            // A lamp-like warm glow from the top corner.
            RadialGradient(colors: [Theme.gold.opacity(0.13), .clear], center: .topTrailing, startRadius: 0, endRadius: 420)
            RadialGradient(colors: [Color(red: 0.25, green: 0.35, blue: 0.75).opacity(0.14), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 380)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Card

struct CardModifier: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = Theme.radius
    var fill: Color = Theme.surface

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.stroke))
    }
}

extension View {
    func card(padding: CGFloat = 18, radius: CGFloat = Theme.radius, fill: Color = Theme.surface) -> some View {
        modifier(CardModifier(padding: padding, radius: radius, fill: fill))
    }
}

// MARK: - Buttons

struct GoldButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.onGold)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Theme.goldGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            // Foil edge: a thin highlight along the top.
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center), lineWidth: 1))
            .shadow(color: Theme.goldDeep.opacity(isEnabled ? 0.28 : 0), radius: 14, y: 6)
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// Quiet secondary action.
struct GlassButtonStyle: ButtonStyle {
    var height: CGFloat = 50

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(configuration.isPressed ? Theme.surfaceStrong : Theme.surface,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// Subtle press feedback for custom tappable rows/cards.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Common pieces

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    var tint: AnyShapeStyle = AnyShapeStyle(Theme.goldGradient)

    var body: some View {
        ZStack {
            Circle().stroke(Theme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct CapsuleBar: View {
    let progress: Double
    var height: CGFloat = 8
    var tint: AnyShapeStyle = AnyShapeStyle(Theme.goldGradient)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule().fill(tint)
                    .frame(width: max(height, geo.size.width * min(max(progress, 0), 1)))
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue("\(Int(progress * 100))%")
    }
}

struct SpeakButton: View {
    let text: String
    var size: CGFloat = 40

    var body: some View {
        Button {
            Pronouncer.shared.speak(text)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(Theme.gold)
                .frame(width: size, height: size)
                .background(Theme.surfaceStrong, in: Circle())
                .overlay(Circle().strokeBorder(Theme.stroke))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("朗读 \(text)")
    }
}

/// 小象, the app mascot (rendered from design/mascot.svg by design/build_assets.py).
struct Mascot: View {
    var size: CGFloat = 64

    var body: some View {
        Image("Mascot")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Coin glyph for XP ("金").
struct CoinLabel: View {
    let amount: Int
    var font: Font = .subheadline.weight(.bold)

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "yensign.circle.fill")
                .foregroundStyle(Theme.gold)
            Text("\(amount)")
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
        }
        .font(font)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(amount) 金")
    }
}

extension WordBook {
    /// SF Symbol for the book, keeping icons consistent with the rest of the UI.
    var symbol: String {
        switch id {
        case "primary": return "leaf.fill"
        case "middle": return "book.fill"
        case "gaokao": return "graduationcap.fill"
        case "cet4": return "4.square.fill"
        case "cet6": return "6.square.fill"
        case "kaoyan": return "scope"
        case "ielts": return "globe.europe.africa.fill"
        default: return "globe.americas.fill"
        }
    }

    var tint: Color {
        switch id {
        case "primary": return Color(red: 0.55, green: 0.82, blue: 0.60)
        case "middle": return Color(red: 0.66, green: 0.80, blue: 0.48)
        case "gaokao": return Color(red: 0.93, green: 0.74, blue: 0.47)
        case "cet4": return Color(red: 0.52, green: 0.72, blue: 0.96)
        case "cet6": return Color(red: 0.95, green: 0.66, blue: 0.45)
        case "kaoyan": return Color(red: 0.94, green: 0.56, blue: 0.58)
        case "ielts": return Color(red: 0.50, green: 0.83, blue: 0.82)
        default: return Color(red: 0.70, green: 0.64, blue: 0.95)
        }
    }
}
