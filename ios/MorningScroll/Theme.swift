import SwiftUI
import CoreText

/// Amy Gray Photography palette (dusty rose + warm gray), turned down for early-morning eyes.
enum Theme {
    static let bg = Color(hex: 0x181414)
    static let surface = Color(hex: 0x221D1D)
    static let surface2 = Color(hex: 0x2D2626)
    static let line = Color(hex: 0x3A3131)
    static let text = Color(hex: 0xF0E6E2)
    static let muted = Color(hex: 0xA39A94)
    static let faint = Color(hex: 0x6F6663)
    static let rose = Color(hex: 0xD9A7A7)
    static let roseDeep = Color(hex: 0xB88A8A)
    static let roseInk = Color(hex: 0x201616)
    static let sage = Color(hex: 0xAABCBD)
    static let lockedBg = Color(hex: 0x3A2626)
    static let unlockedBg = Color(hex: 0x233032)

    static func registerFonts() {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        for url in urls { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
    }

    /// Lora, for reading Scripture.
    static func read(_ size: CGFloat, italic: Bool = false) -> Font {
        variable(italic ? "Lora-Italic" : "Lora-Regular", size: size, weight: 400)
    }

    /// Cormorant Garamond, for titles.
    static func display(_ size: CGFloat, weight: CGFloat = 600, italic: Bool = false) -> Font {
        variable(italic ? "CormorantGaramond-LightItalic" : "CormorantGaramond-Light", size: size, weight: weight)
    }

    /// The bundled fonts are variable fonts; pick the weight on the 'wght' axis.
    private static func variable(_ name: String, size: CGFloat, weight: CGFloat) -> Font {
        let wghtAxis = 0x7767_6874 // 'wght'
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: name,
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wghtAxis: weight]
        ])
        return Font(UIFont(descriptor: descriptor, size: size) as CTFont)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 19, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(enabled ? Theme.roseDeep : Theme.surface2, in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(enabled ? Theme.roseInk : Theme.faint)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(Theme.text)
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.line))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// The book-with-halo mark used on Home and the finish screen.
struct HaloBook: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0x33292A), Color(hex: 0x272020)], center: .center, startRadius: 0, endRadius: 58))
                .frame(width: 116, height: 116)
                .shadow(color: Theme.rose.opacity(0.14), radius: 35)
            Image(systemName: "book")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.rose)
            Capsule()
                .stroke(Theme.rose, lineWidth: 1.2)
                .frame(width: 22, height: 6)
                .offset(y: -34)
        }
    }
}
