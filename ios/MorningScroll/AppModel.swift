import SwiftUI
import FamilyControls
import DeviceActivity

/// Reading progress, saved on the phone.
struct Progress: Codable {
    var done: [String: String] = [:]   // study day id → date finished
    var readDates: Set<String> = []    // every date the five minutes were finished (for the streak)
    var timerDay: String?
    var timerDate: String?
    var timerSecs = 0
    var pick: String?                  // a day chosen from the list instead of the next one
}

@MainActor @Observable
final class AppModel {
    static let goal = 5 * 60

    var study: Study = StudyLoader.local()
    var progress: Progress
    var readingDay: StudyDay?
    var authError: String?

    var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    var esvKey: String {
        didSet {
            UserDefaults.standard.set(esvKey, forKey: "esvKey")
            Task { await Scripture.shared.clear() }
        }
    }
    var selection: FamilyActivitySelection {
        didSet {
            Shared.selection = selection
            Shared.sync()
            startMonitoring()
        }
    }

    init() {
        let d = UserDefaults.standard
        progress = (d.data(forKey: "progress")).flatMap { try? JSONDecoder().decode(Progress.self, from: $0) } ?? Progress()
        fontSize = d.object(forKey: "fontSize") as? Double ?? 30
        esvKey = d.string(forKey: "esvKey") ?? ""
        selection = Shared.selection
    }

    func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(progress), forKey: "progress")
    }

    // MARK: Days

    var today: String { Shared.todayString }
    var finishedToday: Bool { progress.readDates.contains(today) || progress.done.values.contains(today) }
    var nextDay: StudyDay { study.days.first { progress.done[$0.id] == nil } ?? study.days[study.days.count - 1] }
    var upNext: StudyDay? { study.days.first { progress.done[$0.id] == nil } }
    /// The day Home offers: a picked day, else the next unfinished one (nil once today's reading is done).
    var activeDay: StudyDay? {
        if let pick = progress.pick, let d = study.days.first(where: { $0.id == pick }) { return d }
        return finishedToday ? nil : nextDay
    }

    var streak: Int {
        let dates = progress.readDates.union(progress.done.values)
        var day = Date()
        if !dates.contains(Shared.dayString(day)) { day = Calendar.current.date(byAdding: .day, value: -1, to: day)! }
        var n = 0
        while dates.contains(Shared.dayString(day)) {
            n += 1
            day = Calendar.current.date(byAdding: .day, value: -1, to: day)!
        }
        return n
    }

    func open(_ day: StudyDay) {
        if progress.timerDay != day.id || progress.timerDate != today {
            progress.timerDay = day.id
            progress.timerDate = today
            progress.timerSecs = 0
            save()
        }
        readingDay = day
    }

    func pick(_ day: StudyDay) {
        progress.pick = day.id
        save()
        open(day)
    }

    func secondsRead(_ day: StudyDay) -> Int {
        progress.timerDay == day.id && progress.timerDate == today ? progress.timerSecs : 0
    }

    func secondsLeft(_ day: StudyDay) -> Int { max(0, Self.goal - secondsRead(day)) }

    func tick(_ day: StudyDay) {
        if progress.timerDay != day.id || progress.timerDate != today { open(day) }
        progress.timerSecs += 1
        if progress.timerSecs % 5 == 0 { save() }
    }

    /// Unlocks the held-back apps once the five minutes are up.
    func completeIfReady(_ day: StudyDay) {
        guard secondsRead(day) >= Self.goal else { return }
        if progress.done[day.id] == nil { progress.done[day.id] = today }
        if progress.pick == day.id { progress.pick = nil }
        progress.readDates.insert(today)
        save()
        Shared.doneDate = today
        Shared.unlock()
    }

    func isComplete(_ day: StudyDay) -> Bool { secondsRead(day) >= Self.goal && Shared.readToday }

    func resetProgress() {
        progress = Progress()
        save()
        Shared.doneDate = nil
        Shared.sync()
    }

    // MARK: Blocking

    var hasBlockedApps: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty
    }

    var blockedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    var isAuthorized: Bool { AuthorizationCenter.shared.authorizationStatus == .approved }

    func authorize() async -> Bool {
        if isAuthorized { return true }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authError = nil
            return true
        } catch {
            authError = "Screen Time permission is needed to hold apps back. (\(error.localizedDescription))"
            return false
        }
    }

    /// A daily schedule whose start (midnight) wakes the monitor extension to put the shields back up.
    func startMonitoring() {
        guard hasBlockedApps, isAuthorized else { return }
        let name = DeviceActivityName("morningScroll.daily")
        let center = DeviceActivityCenter()
        guard !center.activities.contains(name) else { return }
        try? center.startMonitoring(name, during: DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true))
    }

    func becameActive() {
        if hasBlockedApps { Shared.sync() }
        startMonitoring()
    }

    func refreshStudy() async {
        if let latest = await StudyLoader.fetchLatest() { study = latest }
    }
}
