import Foundation
import FamilyControls
import ManagedSettings

/// State shared between the app and the midnight monitor extension (via the App Group),
/// plus the shield on/off switch both of them use.
enum Shared {
    static let appGroup = "group.net.amygray.morningscroll"
    static let defaults = UserDefaults(suiteName: appGroup) ?? .standard
    static let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("morningScroll"))

    private static let selectionKey = "blockedSelection"
    private static let doneKey = "doneDate"

    static var todayString: String { dayString(Date()) }

    static func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// The apps, categories and websites Amy chose to hold back until she reads.
    static var selection: FamilyActivitySelection {
        get {
            guard let data = defaults.data(forKey: selectionKey),
                  let s = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
                return FamilyActivitySelection()
            }
            return s
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: selectionKey) }
    }

    /// The last day (yyyy-MM-dd) the five minutes were finished.
    static var doneDate: String? {
        get { defaults.string(forKey: doneKey) }
        set { defaults.set(newValue, forKey: doneKey) }
    }

    static var readToday: Bool { doneDate == todayString }

    static func lock() {
        let s = selection
        store.shield.applications = s.applicationTokens.isEmpty ? nil : s.applicationTokens
        store.shield.applicationCategories = s.categoryTokens.isEmpty ? nil : .specific(s.categoryTokens)
        store.shield.webDomains = s.webDomainTokens.isEmpty ? nil : s.webDomainTokens
        store.shield.webDomainCategories = s.categoryTokens.isEmpty ? nil : .specific(s.categoryTokens)
    }

    static func unlock() { store.clearAllSettings() }

    /// Shields up until today's reading is done.
    static func sync() {
        if readToday { unlock() } else { lock() }
    }
}
