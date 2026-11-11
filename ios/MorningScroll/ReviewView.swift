import SwiftUI
import WebKit

/// The full-screen reader. Stays open while she switches between days and reviews,
/// so the five-minute timer never stops or resets.
struct ReaderHost: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.page {
        case .day(let d)?: ReaderView(day: d).id(d.id)
        case .review(let r)?: ReviewView(review: r).id(r.id)
        case nil: Theme.bg.ignoresSafeArea()
        }
    }
}

/// The button in the reader's top bar that lists every day and review, lesson by lesson.
struct SwitchMenu: View {
    let current: String
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            Text("Your timer keeps going")
            ForEach(model.lessons.reversed(), id: \.self) { lesson in
                Section("Lesson \(lesson)") {
                    ForEach(model.entries(lesson)) { entry in
                        Button { model.switchTo(entry) } label: {
                            let done = model.progress.done[entry.id] != nil
                            if entry.id == current {
                                Label(rowTitle(entry), systemImage: "book.fill")
                            } else if done {
                                Label(rowTitle(entry), systemImage: "checkmark")
                            } else {
                                Text(rowTitle(entry))
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "calendar").font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 40, height: 40)
                .background(Theme.surface, in: Circle()).overlay(Circle().stroke(Theme.line))
        }
        .accessibilityLabel("Switch days")
    }

    private func rowTitle(_ entry: ReaderPage) -> String {
        switch entry {
        case .day(let d): d.title.map { "\(d.day) · \($0)" } ?? d.day
        case .review(let r): r.part == 2 ? "★ Review 4–6" : "★ Review 1–3"
        }
    }
}

/// A review bank: the website's review games, shown inside the app. The app keeps the timer.
struct ReviewView: View {
    let review: ReviewBank
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            ReviewTopBar(review: review, close: { dismiss() })
            ReviewWeb(url: url)
        }
        .background(Theme.bg.ignoresSafeArea())
        .foregroundStyle(Theme.text)
        .onReceive(ticker) { _ in
            guard phase == .active else { return }
            model.tick(id: review.id)
            model.completeIfReady(id: review.id)
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            model.save()
        }
    }

    /// index.html?embed=1&review=<id>, with her ESV key after the # so it never leaves the phone.
    private var url: URL {
        var c = URLComponents(url: StudyLoader.site.appendingPathComponent("index.html"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "embed", value: "1"), URLQueryItem(name: "review", value: review.id)]
        if !model.esvKey.isEmpty {
            c.fragment = "key=" + (model.esvKey.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")
        }
        return c.url!
    }
}

private struct ReviewTopBar: View {
    let review: ReviewBank
    let close: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        let left = model.secondsLeftToday
        HStack(spacing: 10) {
            Circle().fill(left > 0 ? Theme.rose : Theme.sage).frame(width: 8, height: 8)
                .shadow(color: left > 0 ? Theme.rose : Theme.sage, radius: 5)
            Text(review.label)
                .font(.system(size: 14)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            SwitchMenu(current: review.id)
            Text(left > 0 ? clock(left) : "Done")
                .font(.system(size: 15, weight: .medium).monospacedDigit())
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Theme.surface, in: Capsule()).overlay(Capsule().stroke(Theme.line))
            Button(action: close) {
                Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(Theme.surface, in: Circle()).overlay(Circle().stroke(Theme.line))
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 8)
    }
}

private struct ReviewWeb: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}
}
