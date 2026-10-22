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
    var quiz: [String: [Int]]?         // study day id → chosen answer per quiz item (-1 = not yet)
    var words: [String: Int]?          // Day Six: study day id → chosen Word of the Week
}

/// Seconds read today. Kept apart from `progress` so the once-a-second tick only redraws the timer.
struct ReadingTimer {
    var day: String?
    var date: String?
    var secs = 0
}

@MainActor @Observable
final class AppModel {
    static let goal = 5 * 60

    /// Every book the app has (bundled or downloaded), by file name.
    var books: [String: Study]
    /// The book she's reading: Gail's study unless she switched to the devotional on Home.
    var bookName: String {
        didSet { UserDefaults.standard.set(bookName, forKey: "book") }
    }
    var progress: Progress
    var timer: ReadingTimer
    var readingDay: StudyDay?
    var authError: String?

    var study: Study { books[activeBookName]! }
    /// `bookName`, unless that book is missing or empty; the study is always bundled.
    var activeBookName: String { books[bookName]?.days.isEmpty == false ? bookName : "study" }
    /// The books with something in them, in order, for Home's switcher.
    var shelfNames: [String] { StudyLoader.names.filter { books[$0]?.days.isEmpty == false } }

    /// First name for the greeting; asked for on first launch.
    var name: String {
        didSet { UserDefaults.standard.set(name, forKey: "name") }
    }
    var askedName: Bool {
        didSet { UserDefaults.standard.set(askedName, forKey: "askedName") }
    }

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
        let saved = (d.data(forKey: "progress")).flatMap { try? JSONDecoder().decode(Progress.self, from: $0) } ?? Progress()
        books = Dictionary(uniqueKeysWithValues: StudyLoader.names.compactMap { name in StudyLoader.local(name).map { (name, $0) } })
        bookName = d.string(forKey: "book") ?? "study"
        progress = saved
        timer = ReadingTimer(day: saved.timerDay, date: saved.timerDate, secs: saved.timerSecs)
        name = d.string(forKey: "name") ?? ""
        askedName = d.bool(forKey: "askedName")
        fontSize = d.object(forKey: "fontSize") as? Double ?? 30
        esvKey = d.string(forKey: "esvKey") ?? ""
        selection = Shared.selection
    }

    func save() {
        var p = progress // a copy, so saving doesn't count as a change to `progress`
        p.timerDay = timer.day
        p.timerDate = timer.date
        p.timerSecs = timer.secs
        UserDefaults.standard.set(try? JSONEncoder().encode(p), forKey: "progress")
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
        startTimer(day)
        readingDay = day
    }

    private func startTimer(_ day: StudyDay) {
        guard timer.day != day.id || timer.date != today else { return }
        timer = ReadingTimer(day: day.id, date: today, secs: 0)
        save()
    }

    func choose(book name: String) {
        guard name != bookName else { return }
        bookName = name
        progress.pick = nil
        save()
    }

    func pick(_ day: StudyDay) {
        progress.pick = day.id
        save()
        open(day)
    }

    func secondsRead(_ day: StudyDay) -> Int {
        timer.day == day.id && timer.date == today ? timer.secs : 0
    }

    func secondsLeft(_ day: StudyDay) -> Int { max(0, Self.goal - secondsRead(day)) }

    func tick(_ day: StudyDay) {
        startTimer(day)
        timer.secs += 1
        if timer.secs % 5 == 0 { save() }
    }

    /// Unlocks the held-back apps once the five minutes are up.
    func completeIfReady(_ day: StudyDay) {
        guard secondsRead(day) >= Self.goal else { return }
        // Already recorded: don't touch `progress` again (every write redraws the reader).
        if progress.done[day.id] != nil, progress.readDates.contains(today), progress.pick != day.id, Shared.readToday { return }
        if progress.done[day.id] == nil { progress.done[day.id] = today }
        if progress.pick == day.id { progress.pick = nil }
        progress.readDates.insert(today)
        save()
        Shared.doneDate = today
        Shared.unlock()
    }

    func isComplete(_ day: StudyDay) -> Bool { secondsRead(day) >= Self.goal && Shared.readToday }

    func quizPicks(_ day: StudyDay) -> [Int] {
        let n = day.quiz?.count ?? 0
        let saved = progress.quiz?[day.id] ?? []
        return Array((saved + Array(repeating: -1, count: n)).prefix(n))
    }

    func answerQuiz(_ day: StudyDay, item: Int, choice: Int) {
        var picks = quizPicks(day)
        guard picks.indices.contains(item), picks[item] < 0 else { return }
        picks[item] = choice
        var all = progress.quiz ?? [:]
        all[day.id] = picks
        progress.quiz = all
        save()
    }

    func chosenWord(_ day: StudyDay) -> WordOption? {
        guard let i = progress.words?[day.id], let words = day.words, words.indices.contains(i) else { return nil }
        return words[i]
    }

    func chooseWord(_ day: StudyDay, _ index: Int) {
        var all = progress.words ?? [:]
        all[day.id] = index
        progress.words = all
        save()
    }

    func resetProgress() {
        progress = Progress()
        timer = ReadingTimer()
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
        for name in StudyLoader.names {
            if let latest = await StudyLoader.fetchLatest(name), (latest.version ?? 0) >= (books[name]?.version ?? 0) { books[name] = latest }
        }
    }
}
