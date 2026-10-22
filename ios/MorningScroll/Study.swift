import Foundation

/// A book the app reads through: Gail's Genesis study, or a devotional for the weeks the study is on break.
struct Study: Codable {
    let version: Int?   // bump in the JSON whenever the content changes
    let kind: String?   // "devotional": a book of meditations rather than a study with questions
    let title: String
    let short: String?  // the name on Home's book switcher
    let author: String?
    let days: [StudyDay]

    var isDevotional: Bool { kind == "devotional" }
}

struct StudyDay: Codable, Identifiable, Hashable {
    let id: String
    let lesson: String       // a meditation: the part of the book it belongs to
    let day: String
    let title: String?       // a meditation's title
    let key: String?
    let summary: String?
    private let readingList: [Reading]?
    private let questionList: [Question]?
    let quiz: [QuizItem]?
    let words: [WordOption]?   // Day Six: Word of the Week choices
    let body: [String]?        // a meditation, paragraph by paragraph
    let truth: String?         // the book's truth to hold on to
    let prayer: String?
    let wildflower: Wildflower?

    var readings: [Reading] { readingList ?? [] }
    var questions: [Question] { questionList ?? [] }
    var isMeditation: Bool { body != nil }
    /// The line in the day list: "Lesson 7 · Day Four", or "Day 3 · <title>" for a meditation.
    var label: String { title.map { "\(day) · \($0)" } ?? "Lesson \(lesson) · \(day)" }

    enum CodingKeys: String, CodingKey {
        case id, lesson, day, title, key, summary, quiz, words, body, truth, prayer, wildflower
        case readingList = "readings"
        case questionList = "questions"
    }
}

/// The wildflower each meditation in The Way of the Wildflower is drawn from.
struct Wildflower: Codable, Hashable {
    let name: String
    let fact: String
}

struct Reading: Codable, Hashable {
    let ref: String
    let forQuestions: [Int]?

    enum CodingKeys: String, CodingKey {
        case ref
        case forQuestions = "for"
    }
}

/// A Hebrew word offered for the Day Six word study, with its own answers to questions 1-6.
struct WordOption: Codable, Hashable {
    let word: String
    let verse: String
    let hebrew: String
    let translit: String
    let strongs: String
    let gloss: String?
    let answers: [String]
    let refs: [[String]]?   // verses cited in each answer
}

struct QuizItem: Codable, Hashable {
    let q: String
    let choices: [String]
    let answer: Int
    let why: String
    let refs: [String]?   // verses cited in "why", quoted under it
    let from: Int?        // set when the item tests a study question's answer rather than the passage
}

struct Question: Codable, Hashable {
    let text: String
    let items: [String]?
    let answer: String?
    let refs: [String]?   // verses cited in the answer, quoted under it
    let wordStudy: Int?   // Day Six: the answer comes from the chosen word's answers[wordStudy - 1]
    let section: String?  // heading shown above this question ("Weekly Review")
    let n: Int?           // number shown, when it restarts within a section
}

/// Links that follow the study's own BibleHub steps.
enum BibleHub {
    private static func parts(_ ref: String) -> (book: String, verse: String) {
        let book = ref.replacing(try! Regex(#"\s+\d+(:.*)?$"#), with: "").lowercased()
            .replacingOccurrences(of: " ", with: "_")
        let m = ref.firstMatch(of: try! Regex(#"(\d+):(\d+)"#))
        let verse = m.map { "\($0.output[1].substring ?? "")-\($0.output[2].substring ?? "")" } ?? ""
        return (book == "psalm" ? "psalms" : book, verse)
    }
    static func interlinear(_ ref: String) -> URL { let p = parts(ref); return URL(string: "https://biblehub.com/interlinear/\(p.book)/\(p.verse).htm")! }
    static func commentaries(_ ref: String) -> URL { let p = parts(ref); return URL(string: "https://biblehub.com/commentaries/\(p.book)/\(p.verse).htm")! }
    static func strongs(_ num: String) -> URL { URL(string: "https://biblehub.com/hebrew/\(num.filter(\.isNumber)).htm")! }
}

/// The books live on the website as <name>.dat (their JSON in base64, so the text isn't picked up by search
/// engines), so new lessons and meditations show up without reinstalling the app. The copy bundled with the
/// app, or the last one downloaded, is used when offline.
enum StudyLoader {
    /// Every book, in the order Home offers them: Gail's study, then the devotional for weeks the study is on break.
    static let names = ["study", "wildflower"]
    static let site = URL(string: "https://amycothrangray.github.io/morning-scroll/")!

    static func decode(_ data: Data) -> Study? {
        let text = String(decoding: data, as: UTF8.self).filter { !$0.isWhitespace }
        guard let json = Data(base64Encoded: text) else { return nil }
        return try? JSONDecoder().decode(Study.self, from: json)
    }

    private static func cacheURL(_ name: String) -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(name).dat")
    }

    /// The newer of the bundled copy and the last download; nil for a book the app doesn't have yet.
    static func local(_ name: String) -> Study? {
        let bundled = Bundle.main.url(forResource: name, withExtension: "dat").flatMap { try? Data(contentsOf: $0) }.flatMap(decode)
        let cached = (try? Data(contentsOf: cacheURL(name))).flatMap(decode)
        guard let bundled else { return cached }
        if let cached, (cached.version ?? 0) >= (bundled.version ?? 0) { return cached }
        return bundled
    }

    static func fetchLatest(_ name: String) async -> Study? {
        // A unique query skips GitHub's 10-minute cache so new lessons show up right away.
        var c = URLComponents(url: site.appendingPathComponent("\(name).dat"), resolvingAgainstBaseURL: false)!
        c.queryItems = [.init(name: "t", value: String(Int(Date().timeIntervalSince1970)))]
        var request = URLRequest(url: c.url!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let study = decode(data) else { return nil }
        try? data.write(to: cacheURL(name))
        return study
    }
}
