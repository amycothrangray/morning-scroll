import Foundation

struct Study: Codable {
    let version: Int?   // bump in study.json whenever lessons, answers or quizzes change
    let title: String
    let days: [StudyDay]
}

struct StudyDay: Codable, Identifiable, Hashable {
    let id: String
    let lesson: String
    let day: String
    let key: String?
    let summary: String?
    let readings: [Reading]
    let questions: [Question]
    let quiz: [QuizItem]?
    let words: [WordOption]?   // Day Six: Word of the Week choices

    var title: String { "Lesson \(lesson) · \(day)" }
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

/// Gail's study lives in study.json on the website, so new lessons show up without reinstalling the app.
/// The copy bundled with the app (or the last one downloaded) is used when offline.
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

enum StudyLoader {
    // study.dat is study.json in base64, so the study's text isn't picked up by search engines.
    static let remoteURL = URL(string: "https://amycothrangray.github.io/morning-scroll/study.dat")!

    static func decode(_ data: Data) -> Study? {
        let text = String(decoding: data, as: UTF8.self).filter { !$0.isWhitespace }
        guard let json = Data(base64Encoded: text) else { return nil }
        return try? JSONDecoder().decode(Study.self, from: json)
    }

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("study.dat")
    }

    /// The newer of the bundled copy and the last download.
    static func local() -> Study {
        let url = Bundle.main.url(forResource: "study", withExtension: "dat")!
        let bundled = decode(try! Data(contentsOf: url))!
        if let data = try? Data(contentsOf: cacheURL), let cached = decode(data),
           (cached.version ?? 0) >= (bundled.version ?? 0) {
            return cached
        }
        return bundled
    }

    static func fetchLatest() async -> Study? {
        // A unique query skips GitHub's 10-minute cache so new lessons show up right away.
        var c = URLComponents(url: remoteURL, resolvingAgainstBaseURL: false)!
        c.queryItems = [.init(name: "t", value: String(Int(Date().timeIntervalSince1970)))]
        var request = URLRequest(url: c.url!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let study = decode(data) else { return nil }
        try? data.write(to: cacheURL)
        return study
    }
}
