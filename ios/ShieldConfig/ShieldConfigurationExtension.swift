import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen Amy sees when she opens a held-back app before reading.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration { shield }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { shield }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { shield }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { shield }

    private var shield: ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0x18 / 255, green: 0x14 / 255, blue: 0x14 / 255, alpha: 0.92),
            icon: UIImage(systemName: "book")?.withTintColor(UIColor(red: 0xd9 / 255, green: 0xa7 / 255, blue: 0xa7 / 255, alpha: 1), renderingMode: .alwaysOriginal),
            title: .init(text: "Read first", color: UIColor(red: 0xf0 / 255, green: 0xe6 / 255, blue: 0xe2 / 255, alpha: 1)),
            subtitle: .init(text: "Open Morning Scroll and spend five minutes in the Word. Your apps unlock when you finish.",
                            color: UIColor(red: 0xa3 / 255, green: 0x9a / 255, blue: 0x94 / 255, alpha: 1)),
            primaryButtonLabel: .init(text: "OK", color: UIColor(red: 0x20 / 255, green: 0x16 / 255, blue: 0x16 / 255, alpha: 1)),
            primaryButtonBackgroundColor: UIColor(red: 0xb8 / 255, green: 0x8a / 255, blue: 0x8a / 255, alpha: 1)
        )
    }
}
