import SwiftUI

struct ReaderView: View {
    let day: StudyDay
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase

    @State private var keyVerse: Passage?
    @State private var passages: [Passage] = []
    @State private var loadError: String?
    @State private var loading = true
    @State private var reachedEnd = false
    @State private var snap = SnapLayout()
    @State private var position = ScrollPosition(edge: .top)
    @State private var focusedIndex = 0
    @State private var speaker = Speaker()
    @State private var quotes: [String: String] = [:]
    @State private var quotesTask: Task<Void, Never>?
    @State private var scrubLabel: String?

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var fs: CGFloat { model.fontSize }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.bg.ignoresSafeArea()
            if loading {
                ProgressView().tint(Theme.rose).frame(maxHeight: .infinity)
            } else if let loadError {
                VStack(spacing: 20) {
                    Text(loadError).font(.system(size: 18)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                    Button("Try again") { Task { await load() } }.buttonStyle(GhostButtonStyle()).frame(width: 200)
                }
                .padding(24).frame(maxHeight: .infinity)
            } else {
                content
            }
            topBar
        }
        .foregroundStyle(Theme.text)
        .task { await load() }
        .onReceive(ticker) { _ in
            guard phase == .active else { return }
            model.tick(day)
            model.completeIfReady(day) // five minutes unlocks, wherever she is in the reading
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            speaker.stop()
            quotesTask?.cancel()
            model.save()
        }
    }

    private func load() async {
        loading = true
        loadError = nil
        do {
            // One at a time keeps the free fallback API from rate-limiting us.
            if let key = day.key { keyVerse = try await Scripture.shared.passage(key, esvKey: model.esvKey) }
            var loaded: [Passage] = []
            for r in day.readings { loaded.append(try await Scripture.shared.passage(r.ref, esvKey: model.esvKey)) }
            passages = loaded
            quotesTask?.cancel()
            quotesTask = Task { await loadQuotes() }
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? "Couldn't load today's reading. Check your connection and try again."
        }
        loading = false
    }

    // MARK: Top bar

    private var topBar: some View {
        let left = model.secondsLeft(day)
        return HStack(spacing: 10) {
            Circle().fill(left > 0 ? Theme.rose : Theme.sage).frame(width: 8, height: 8)
                .shadow(color: left > 0 ? Theme.rose : Theme.sage, radius: 5)
            Text(left > 0 ? "Your apps unlock when the timer ends" : (model.hasBlockedApps ? "Apps unlocked. Read on as long as you like." : "Time’s up. Read on as long as you like."))
                .font(.system(size: 14)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Button {
                if speaker.isOn { speaker.stop() } else { speaker.isOn = true; speakCurrent() }
            } label: {
                Image(systemName: speaker.isOn ? "speaker.wave.2.fill" : "speaker.wave.2")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(speaker.isOn ? Theme.roseInk : Theme.text)
                    .frame(width: 40, height: 40)
                    .background(speaker.isOn ? Theme.roseDeep : Theme.surface, in: Circle())
                    .overlay(Circle().stroke(speaker.isOn ? Theme.roseDeep : Theme.line))
            }
            .accessibilityLabel(speaker.isOn ? "Stop reading aloud" : "Read aloud")
            Text(left > 0 ? clock(left) : "Done")
                .font(.system(size: 15, weight: .medium).monospacedDigit())
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Theme.surface, in: Capsule()).overlay(Capsule().stroke(Theme.line))
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(Theme.surface, in: Circle()).overlay(Circle().stroke(Theme.line))
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 12)
        .overlay(alignment: .bottom) { scrubber.offset(y: 22) }
        .padding(.bottom, 12)
        .background(LinearGradient(stops: [.init(color: Theme.bg, location: 0.6), .init(color: Theme.bg.opacity(0), location: 1)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea(edges: .top))
    }

    // MARK: Scroll

    /// Everything in the reader, in order. Each is one stop: a small flick moves exactly one item and centers it.
    private enum Item {
        case verseOfTheDay
        case todaysReading
        case verse(passage: Int, verse: Verse, first: Bool)
        case question(Int)
        case quiz(Int)
        case finish
    }

    private var items: [Item] {
        var out: [Item] = []
        if keyVerse != nil { out.append(.verseOfTheDay) }
        out.append(.todaysReading)
        for (pi, p) in passages.enumerated() {
            for (vi, v) in p.verses.enumerated() { out.append(.verse(passage: pi, verse: v, first: vi == 0)) }
        }
        out += day.questions.indices.map { .question($0) }
        out += (day.quiz ?? []).indices.map { .quiz($0) }
        out.append(.finish)
        return out
    }

    private static let space = "readerContent"

    private var content: some View {
        GeometryReader { geo in
            let list = items
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(list.enumerated()), id: \.offset) { i, item in
                            itemView(item)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .focusFade()
                                .contentShape(Rectangle())
                                .id(i)
                                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { snap.frames[i] = $0 }
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(i, anchor: .center) }
                                }
                        }
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, geo.size.height / 2)
                    .coordinateSpace(.named(Self.space))
                }
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, offset in
                    snap.offset = offset
                    snap.height = geo.size.height
                    let now = snap.index(at: offset + geo.size.height / 2)
                    if now != focusedIndex { focusedIndex = now }
                    // The end counts as soon as the finish card is on screen.
                    if !reachedEnd, let finish = snap.frames[list.count - 1], offset + geo.size.height > finish.minY + 80 {
                        reachedEnd = true
                        model.completeIfReady(day)
                    }
                }
                .scrollTargetBehavior(OneAtATime(snap: snap))
                .scrollPosition($position)
                .onAppear { snap.count = list.count; snap.firstFree = firstQuestionIndex(list) }
                .onChange(of: list.count) { _, n in snap.count = n; snap.firstFree = firstQuestionIndex(list) }
                .onChange(of: focusedIndex) { _, _ in if speaker.isOn && scrubLabel == nil { speakCurrent() } }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Progress bar (drag it to rewind or skip ahead)

    private var scrubber: some View {
        let list = items
        let n = max(list.count - 1, 1)
        let fraction = CGFloat(min(focusedIndex, n)) / CGFloat(n)
        return GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surface2).frame(height: scrubLabel == nil ? 4 : 6)
                Capsule().fill(Theme.roseDeep).frame(width: max(4, g.size.width * fraction), height: scrubLabel == nil ? 4 : 6)
                Circle().fill(Theme.rose).frame(width: 16, height: 16)
                    .shadow(color: Theme.rose.opacity(0.3), radius: 4)
                    .offset(x: g.size.width * fraction - 8)
                    .opacity(scrubLabel == nil ? 0 : 1)
                if let scrubLabel {
                    Text(scrubLabel)
                        .font(.system(size: 15)).foregroundStyle(Theme.text)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Theme.surface, in: Capsule()).overlay(Capsule().stroke(Theme.line))
                        .fixedSize()
                        .position(x: min(max(g.size.width * fraction, 70), g.size.width - 70), y: 38)
                }
            }
            .frame(height: 30)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                if scrubLabel == nil { speaker.pause() }
                let f = min(max(v.location.x / g.size.width, 0), 1)
                let i = Int((f * CGFloat(n)).rounded())
                scrubLabel = itemLabel(list[i])
                if let y = snap.offset(for: i, height: snap.height) { position.scrollTo(y: max(0, y)) }
            }.onEnded { _ in
                scrubLabel = nil
                if speaker.isOn { speakCurrent() }
            })
        }
        .frame(height: 30)
        .accessibilityLabel("Reading position")
    }

    private func itemLabel(_ item: Item) -> String {
        switch item {
        case .verseOfTheDay: return "Verse of the Day"
        case .todaysReading: return "Today’s Reading"
        case let .verse(pi, v, _):
            let ref = passages[pi].ref
            if let colon = ref.firstIndex(of: ":") { return "\(ref[..<colon]):\(v.num)" }
            return ref.replacing(try! Regex(#"\s\d+$"#), with: "") + " \(v.num)" // one-chapter books like 3 John
        case .question(let i): return "Question \(i + 1)"
        case .quiz: return "Quiz"
        case .finish: return "The end"
        }
    }

    // MARK: Verse quotes

    @ViewBuilder private func verseQuotes(_ refs: [String]?) -> some View {
        let shown = (refs ?? []).filter { quotes[$0] != nil }
        if !shown.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(shown, id: \.self) { r in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(r).font(.system(size: 13)).foregroundStyle(Theme.rose)
                        Text("“\(quotes[r] ?? "")”").font(Theme.read(fs * 0.64, italic: true)).foregroundStyle(Theme.text)
                            .lineSpacing(fs * 0.22)
                    }
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) { Rectangle().fill(Theme.roseDeep).frame(width: 2) }
                }
            }
            .padding(.top, 12)
        }
    }

    /// Fetch every verse the answers and quiz cite, one at a time (the free fallback is rate-limited).
    private func loadQuotes() async {
        var refs: [String] = []
        for r in day.questions.flatMap({ $0.refs ?? [] }) + (day.quiz ?? []).flatMap({ $0.refs ?? [] }) where !refs.contains(r) {
            refs.append(r)
        }
        for r in refs {
            if Task.isCancelled { return }
            if let p = try? await Scripture.shared.passage(r, esvKey: model.esvKey) {
                quotes[r] = p.verses.map { $0.text.replacingOccurrences(of: "\n", with: " ") }.joined(separator: " ")
            }
            if model.esvKey.isEmpty { try? await Task.sleep(for: .seconds(2.1)) }
        }
    }

    // MARK: Read aloud

    private func spokenText(_ item: Item) -> String? {
        // Parenthetical references read badly aloud ("thirty-eight colon twenty-six"); the quotes cover them.
        func clean(_ s: String) -> String {
            s.replacing(try! Regex(#"\s*\([^)]*\d[^)]*\)"#), with: "").replacingOccurrences(of: "•", with: ".")
        }
        func chapterOf(_ ref: String) -> String {
            ref.replacing(try! Regex(#":.*$"#), with: "").replacing(try! Regex(#"\s(\d+)$"#)) { " chapter \($0.output[1].substring ?? "")" }
        }
        switch item {
        case .verseOfTheDay:
            guard let keyVerse, let ref = day.key else { return nil }
            return "Verse of the day. \(ref.replacingOccurrences(of: ":", with: ", verse ")). " + keyVerse.verses.map(\.text).joined(separator: " ")
        case .todaysReading:
            return "Today's reading. " + (day.summary ?? "")
        case let .verse(pi, v, first):
            return (first ? chapterOf(passages[pi].ref) + ". " : "") + v.text
        case .question(let i):
            let q = day.questions[i]
            return "Question \(i + 1). \(q.text) " + (q.items?.joined(separator: ". ") ?? "") + (q.answer.map { " Answer. " + clean($0) } ?? "")
        case .quiz, .finish:
            return nil
        }
    }

    private func speakCurrent() {
        let list = items
        guard list.indices.contains(focusedIndex), let text = spokenText(list[focusedIndex]) else { speaker.stop(); return }
        let i = focusedIndex
        speaker.speak(text) {
            guard speaker.isOn, focusedIndex == i else { return }
            let next = i + 1
            guard list.indices.contains(next), spokenText(list[next]) != nil,
                  let y = snap.offset(for: next, height: snap.height) else { speaker.stop(); return }
            withAnimation(.easeInOut(duration: 0.6)) { position.scrollTo(y: max(0, y)) }
        }
    }

    private func firstQuestionIndex(_ list: [Item]) -> Int {
        list.firstIndex { if case .question = $0 { return true } else { return false } } ?? Int.max
    }

    @ViewBuilder private func itemView(_ item: Item) -> some View {
        switch item {
        case .verseOfTheDay:
            if let keyVerse, let ref = day.key { verseOfTheDay(keyVerse, ref: ref) }
        case .todaysReading:
            todaysReading
        case let .verse(pi, v, first):
            VStack(alignment: .leading, spacing: 20) {
                if first { passageHead(passages[pi], reading: day.readings[pi]) }
                verseText(v)
            }
        case .question(let i):
            question(day.questions[i], index: i)
        case .quiz(let i):
            quizItem(i)
        case .finish:
            finish
        }
    }

    private func verseOfTheDay(_ p: Passage, ref: String) -> some View {
        VStack(spacing: 0) {
            Text("VERSE OF THE DAY").font(.system(size: 13, weight: .medium)).tracking(1.8).foregroundStyle(Theme.muted)
            Text(ref).font(.system(size: 15)).foregroundStyle(Theme.rose).padding(.top, 6).padding(.bottom, 22)
            Text(p.verses.map(\.text).joined(separator: " "))
                .font(Theme.read(fs * 1.08)).lineSpacing(fs * 0.4).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var todaysReading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today’s Reading").font(Theme.display(fs * 1.15))
            Text("\(day.title)\n\(day.readings.map(\.ref).joined(separator: " · "))")
                .font(.system(size: 16)).foregroundStyle(Theme.rose).lineSpacing(3).padding(.bottom, 10)
            if let s = day.summary {
                Text(s).font(Theme.read(fs * 0.68, italic: true)).foregroundStyle(Theme.muted).lineSpacing(fs * 0.25)
            }
        }
    }

    private func passageHead(_ p: Passage, reading: Reading) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(p.ref).font(Theme.display(fs * 0.95))
            if let qs = reading.forQuestions, !qs.isEmpty {
                Text("for question\(qs.count > 1 ? "s" : "") \(qs.map(String.init).joined(separator: ", "))")
                    .font(.system(size: 13)).foregroundStyle(Theme.muted)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Theme.surface, in: Capsule()).overlay(Capsule().stroke(Theme.line))
            }
        }
    }

    private func verseText(_ v: Verse) -> some View {
        (Text("\(v.num) ").font(.system(size: fs * 0.48, weight: .medium)).baselineOffset(fs * 0.38).foregroundColor(Theme.rose)
         + Text(v.text).font(Theme.read(fs)))
            .lineSpacing(fs * 0.38)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func question(_ q: Question, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if index == 0 {
                Text("Questions").font(Theme.display(fs * 1.15)).padding(.bottom, 18)
            }
            Text("QUESTION \(index + 1)").font(.system(size: 13, weight: .medium)).tracking(1.8).foregroundStyle(Theme.rose)
                .padding(.bottom, 10)
            Text(q.text).font(Theme.read(fs * 0.8)).lineSpacing(fs * 0.3)
            if let items = q.items {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(items, id: \.self) { Text("•  \($0)") }
                }
                .font(Theme.read(fs * 0.7)).foregroundStyle(Theme.muted).padding(.top, 12)
            }
            if let answer = q.answer {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ANSWER").font(.system(size: 12, weight: .medium)).tracking(1.8).foregroundStyle(Theme.sage)
                    Text(answer).font(Theme.read(fs * 0.7)).foregroundStyle(Color(hex: 0xD6CBC6)).lineSpacing(fs * 0.28)
                    verseQuotes(q.refs)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line))
                .padding(.top, 18)
            } else {
                Link(destination: ClaudeLink.url(for: day, study: model.study.title, question: index)) {
                    Text("✦  Ask Claude").font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.text)
                        .padding(.horizontal, 18).padding(.vertical, 11)
                        .background(Theme.surface, in: Capsule()).overlay(Capsule().stroke(Theme.line))
                }
                .padding(.top, 18)
            }
        }
        .padding(.top, index == 0 ? 0 : 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quizItem(_ index: Int) -> some View {
        let items = day.quiz ?? []
        let z = items[index]
        let picks = model.quizPicks(day)
        let chosen = picks[index]
        let allDone = !picks.contains(-1)
        let right = zip(items, picks).filter { $0.answer == $1 }.count
        return VStack(alignment: .leading, spacing: 0) {
            if index == 0 {
                Text("Quiz").font(Theme.display(fs * 1.15))
                Text("\(items.count) quick questions on today’s reading.")
                    .font(.system(size: 16)).foregroundStyle(Theme.muted).padding(.top, 4).padding(.bottom, 22)
            }
            Text("\(index + 1) OF \(items.count)" + (z.from.map { " · ABOUT QUESTION \($0)" } ?? "")).font(.system(size: 13, weight: .medium)).tracking(1.8).foregroundStyle(Theme.rose)
                .padding(.bottom, 10)
            Text(z.q).font(Theme.read(fs * 0.8)).lineSpacing(fs * 0.3).padding(.bottom, 6)
            ForEach(z.choices.indices, id: \.self) { ci in
                let isRight = chosen >= 0 && ci == z.answer
                let isWrong = chosen >= 0 && ci == chosen && ci != z.answer
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { model.answerQuiz(day, item: index, choice: ci) }
                } label: {
                    Text(z.choices[ci])
                        .font(Theme.read(fs * 0.68)).foregroundStyle(Theme.text)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(isRight ? Theme.unlockedBg : isWrong ? Theme.lockedBg : Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isRight ? Theme.sage : isWrong ? Color(hex: 0x8A4F4F) : Theme.line))
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
            if chosen >= 0 {
                (Text(chosen == z.answer ? "That’s right. " : "Not quite. ").foregroundColor(chosen == z.answer ? Theme.sage : Theme.rose)
                 + Text(z.why).foregroundColor(Color(hex: 0xD6CBC6)))
                    .font(Theme.read(fs * 0.64)).lineSpacing(fs * 0.25)
                    .padding(.top, 12)
                verseQuotes(z.refs)
            }
            if index == items.count - 1 && allDone {
                VStack(spacing: 6) {
                    Text("\(right) of \(items.count)").font(Theme.display(34))
                    Text(right == items.count ? "Every one. Well read!" : right >= items.count - 1 ? "Nicely done." : "Scroll up and look again at the verses you missed.")
                        .font(Theme.read(18)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
            }
        }
        .padding(.top, index == 0 ? 60 : 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var finish: some View {
        VStack(spacing: 0) {
            HaloBook().padding(.bottom, 26)
            if model.isComplete(day) {
                Text("Daily reading complete!").font(Theme.display(38)).multilineTextAlignment(.center).padding(.bottom, 10)
                Text(model.hasBlockedApps ? "Your apps are unlocked. Enjoy your day with peace of mind." : "Enjoy your day with peace of mind.")
                    .font(Theme.read(19)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).padding(.bottom, 28)
                Button("Back to home") { dismiss() }.buttonStyle(PrimaryButtonStyle())
            } else {
                Text("Almost there").font(Theme.display(38)).padding(.bottom, 10)
                Text("Stay a little longer. Scroll back up and sit with a verse.")
                    .font(Theme.read(19)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).padding(.bottom, 28)
                Button("Unlock in \(clock(model.secondsLeft(day)))") {}.buttonStyle(PrimaryButtonStyle()).disabled(true)
            }
            Link(destination: ClaudeLink.url(for: day, study: model.study.title)) {
                Text("Ask Claude a follow-up")
            }
            .buttonStyle(GhostButtonStyle())
            .padding(.top, 10)
            Text(model.esvKey.isEmpty
                 ? "Scripture from the World English Bible (public domain)."
                 : "Scripture quotations are from the ESV® Bible (The Holy Bible, English Standard Version®), © 2001 by Crossway, a publishing ministry of Good News Publishers. Used by permission. All rights reserved.")
                .font(.system(size: 12)).foregroundStyle(Theme.faint).multilineTextAlignment(.center).padding(.top, 26)
        }
        .frame(maxWidth: .infinity)
    }

    private func clock(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
}

extension View {
    /// One verse at a time: whatever sits on the reading line is bright, everything else steps back.
    func focusFade() -> some View {
        visualEffect { content, proxy in
            let frame = proxy.frame(in: .scrollView)
            let height = proxy.bounds(of: .scrollView)?.height ?? 800
            let line = height * 0.5
            let distance: CGFloat = (frame.minY <= line && frame.maxY >= line)
                ? 0 : min(abs(frame.minY - line), abs(frame.maxY - line))
            let opacity: Double = max(0.26, 1 - Double(distance) / 70)
            return content.opacity(opacity)
        }
    }
}

/// Item frames and scroll position, shared with the snapping behavior (not observed, so it never re-renders).
final class SnapLayout {
    var frames: [Int: CGRect] = [:]
    var offset: CGFloat = 0
    var count = 0
    var height: CGFloat = 800
    var firstFree = Int.max   // from here on (questions and answers) scrolling is free

    /// The item under content position y (items touch, so this is almost always exact).
    func index(at y: CGFloat) -> Int {
        if let hit = frames.first(where: { $0.value.minY <= y && $0.value.maxY >= y }) { return hit.key }
        return frames.min { abs($0.value.midY - y) < abs($1.value.midY - y) }?.key ?? 0
    }

    func isTall(_ i: Int, height: CGFloat) -> Bool { (frames[i]?.height ?? 0) > height - 180 }

    /// Where to scroll so item i sits in the middle; long items (answers) start near the top instead.
    func offset(for i: Int, height: CGFloat, fromBelow: Bool = false) -> CGFloat? {
        guard let f = frames[i] else { return nil }
        if isTall(i, height: height) { return fromBelow ? f.maxY + 60 - height : f.minY - 100 }
        return f.midY - height / 2
    }
}

/// One small flick = the next item, centered. Long items page through before moving on.
struct OneAtATime: ScrollTargetBehavior {
    let snap: SnapLayout

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let h = context.containerSize.height
        let now = snap.offset
        let natural = target.rect.minY
        let maxOffset = max(0, context.contentSize.height - h)
        let current = snap.index(at: now + h / 2)
        var y = natural

        // Questions and answers are long, so they scroll normally. One flick from the last verse lands on them.
        if current >= snap.firstFree { return }
        if natural > now, current == snap.firstFree - 1, let f = snap.frames[snap.firstFree] {
            target.rect.origin.y = min(max(f.minY - 100, 0), maxOffset)
            return
        }

        if abs(natural - now) < 6 {
            y = snap.offset(for: current, height: h) ?? natural
        } else {
            let down = natural > now
            if snap.isTall(current, height: h), let f = snap.frames[current] {
                if down && now + h < f.maxY + 40 {
                    target.rect.origin.y = min(min(now + h * 0.7, f.maxY + 60 - h), maxOffset)
                    return
                }
                if !down && now > f.minY - 80 {
                    target.rect.origin.y = max(max(now - h * 0.7, f.minY - 100), 0)
                    return
                }
            }
            let next = min(max(current + (down ? 1 : -1), 0), max(snap.count - 1, 0))
            y = snap.offset(for: next, height: h, fromBelow: !down) ?? natural
        }
        target.rect.origin.y = min(max(y, 0), maxOffset)
    }
}
