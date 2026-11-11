import SwiftUI

/// The day's verse teacher: the website's six-step game, shown in a sheet over the reader.
/// The reader stays open underneath, so the five-minute timer keeps going.
struct VerseTeacherView: View {
    let day: StudyDay
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Verse teacher")
                    .font(.system(size: 15, weight: .semibold))
                Spacer(minLength: 4)
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .background(Theme.surface, in: Circle()).overlay(Circle().stroke(Theme.line))
                }
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)
            ReviewWeb(url: url)
        }
        .background(Theme.bg.ignoresSafeArea())
        .foregroundStyle(Theme.text)
    }

    /// index.html?embed=1&teach=<day>&book=<book>, with her ESV key after the # so it never leaves the phone.
    private var url: URL {
        var c = URLComponents(url: StudyLoader.site.appendingPathComponent("index.html"), resolvingAgainstBaseURL: false)!
        c.queryItems = [
            URLQueryItem(name: "embed", value: "1"),
            URLQueryItem(name: "teach", value: day.id),
            URLQueryItem(name: "book", value: model.activeBookName),
        ]
        if !model.esvKey.isEmpty {
            c.fragment = "key=" + (model.esvKey.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")
        }
        return c.url!
    }
}
