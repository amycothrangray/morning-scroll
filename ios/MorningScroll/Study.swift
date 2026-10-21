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

struct QuizItem: Codable, Hashable {
    let q: String
    let choices: [String]
    let answer: Int
    let why: String
    let refs: [String]?   // verses cited in "why", quoted under it
}

struct Question: Codable, Hashable {
    let text: String
    let items: [String]?
    let answer: String?
    let refs: [String]?   // verses cited in the answer, quoted under it
}

/// Gail's study lives in study.json on the website, so new lessons show up without reinstalling the app.
/// The copy bundled with the app (or the last one downloaded) is used when offline.
enum StudyLoader {
    static let remoteURL = URL(string: "https://amycothrangray.github.io/morning-scroll/study.json")!

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("study.json")
    }

    /// The newer of the bundled copy and the last download.
    static func local() -> Study {
        let url = Bundle.main.url(forResource: "study", withExtension: "json")!
        let bundled = try! JSONDecoder().decode(Study.self, from: Data(contentsOf: url))
        if let data = try? Data(contentsOf: cacheURL), let cached = try? JSONDecoder().decode(Study.self, from: data),
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
              let study = try? JSONDecoder().decode(Study.self, from: data) else { return nil }
        try? data.write(to: cacheURL)
        return study
    }
}
