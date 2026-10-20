import Foundation

struct Verse: Identifiable, Hashable {
    let id: String
    let num: Int
    let text: String
}

struct Passage: Hashable {
    let ref: String
    let verses: [Verse]
}

enum ScriptureError: LocalizedError {
    case badKey
    case service(Int)

    var errorDescription: String? {
        switch self {
        case .badKey: return "The ESV key was rejected. Check it in Settings."
        case .service(let code): return "The Bible service had a problem (\(code)). Try again in a minute."
        }
    }
}

/// ESV from api.esv.org when Amy has a key; otherwise the World English Bible from bible-api.com.
actor Scripture {
    static let shared = Scripture()
    private var cache: [String: Passage] = [:]

    func passage(_ ref: String, esvKey: String) async throws -> Passage {
        let key = esvKey.trimmingCharacters(in: .whitespaces)
        let cacheKey = (key.isEmpty ? "WEB|" : "ESV|") + ref
        if let hit = cache[cacheKey] { return hit }
        let passage = key.isEmpty ? try await web(ref) : try await esv(ref, key: key)
        cache[cacheKey] = passage
        return passage
    }

    func clear() { cache = [:] }

    private func esv(_ ref: String, key: String) async throws -> Passage {
        var c = URLComponents(string: "https://api.esv.org/v3/passage/text/")!
        c.queryItems = [
            .init(name: "q", value: ref),
            .init(name: "include-passage-references", value: "false"),
            .init(name: "include-verse-numbers", value: "true"),
            .init(name: "include-first-verse-numbers", value: "true"),
            .init(name: "include-footnotes", value: "false"),
            .init(name: "include-footnote-body", value: "false"),
            .init(name: "include-headings", value: "false"),
            .init(name: "include-short-copyright", value: "false"),
            .init(name: "include-copyright", value: "false"),
            .init(name: "include-selahs", value: "true"),
            .init(name: "indent-paragraphs", value: "0"),
            .init(name: "indent-poetry", value: "false"),
            .init(name: "indent-declares", value: "0"),
            .init(name: "indent-psalm-doxology", value: "0"),
            .init(name: "line-length", value: "0")
        ]
        var request = URLRequest(url: c.url!)
        request.setValue("Token \(key)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 { throw ScriptureError.badKey }
        guard status == 200 else { throw ScriptureError.service(status) }

        struct Body: Decodable { let passages: [String] }
        let text = try JSONDecoder().decode(Body.self, from: data).passages.first ?? ""
        return Self.parseESV(ref: ref, text: text)
    }

    /// The text endpoint marks verses as "[12] ..."; split on those markers.
    static func parseESV(ref: String, text: String) -> Passage {
        let marker = try! Regex(#"\[(\d+)\]"#)
        let matches = text.matches(of: marker)
        var lead = matches.first.map { clean(String(text[..<$0.range.lowerBound])) } ?? "" // psalm superscription
        var verses: [Verse] = []
        for (i, m) in matches.enumerated() {
            let num = Int(m.output[1].substring ?? "") ?? 0
            let end = i + 1 < matches.count ? matches[i + 1].range.lowerBound : text.endIndex
            var body = clean(String(text[m.range.upperBound..<end]))
            if !lead.isEmpty { body = lead + "\n" + body; lead = "" }
            verses.append(Verse(id: "\(ref)#\(num)", num: num, text: body))
        }
        return Passage(ref: ref, verses: verses)
    }

    private static func clean(_ s: String) -> String {
        s.replacing(try! Regex(#"\(ESV\)\s*$"#), with: "")
            .replacing(try! Regex(#"[ \t]+"#), with: " ")
            .replacing(try! Regex(#"\s*\n\s*"#), with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func web(_ ref: String) async throws -> Passage {
        let path = ref.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ref
        let url = URL(string: "https://bible-api.com/\(path)?translation=webbe")!
        let (data, response) = try await URLSession.shared.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw ScriptureError.service(status) }

        struct Body: Decodable { struct V: Decodable { let verse: Int; let text: String }; let verses: [V] }
        let body = try JSONDecoder().decode(Body.self, from: data)
        return Passage(ref: ref, verses: body.verses.map {
            // WEB hard-wraps lines mid-sentence.
            Verse(id: "\(ref)#\($0.verse)", num: $0.verse,
                  text: $0.text.split(whereSeparator: \.isWhitespace).joined(separator: " "))
        })
    }
}

enum ClaudeLink {
    static func url(for day: StudyDay, study: String, question index: Int? = nil) -> URL {
        let head = "I'm working through a Bible study on \(study) Lesson \(day.lesson), \(day.day). Today's passages: \(day.readings.map(\.ref).joined(separator: "; "))."
        let ask = "Answer from the ESV and cite verse numbers. Keep each answer to a short paragraph. For personal reflection questions, give me something to think about rather than answering for me."
        func text(_ q: Question, _ i: Int) -> String {
            "Question \(i + 1): \(q.text)" + (q.items.map { "\n" + $0.map { "  - \($0)" }.joined(separator: "\n") } ?? "")
        }
        let body: String
        if let index {
            body = "\(head)\n\nPlease help me with this question. \(ask)\n\n\(text(day.questions[index], index))"
        } else {
            body = "\(head)\n\nPlease help me with today's questions. \(ask)\n\n" +
                day.questions.enumerated().map { text($1, $0) }.joined(separator: "\n\n")
        }
        var c = URLComponents(string: "https://claude.ai/new")!
        c.queryItems = [.init(name: "q", value: body)]
        return c.url!
    }
}
