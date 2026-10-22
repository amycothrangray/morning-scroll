import SwiftUI
import FamilyControls

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showSettings = false
    @State private var showPicker = false
    @State private var showDays = false
    @State private var nameDraft = ""

    var body: some View {
        @Bindable var model = model
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    topBar
                    if model.shelfNames.count > 1 { bookTabs.padding(.top, 18) }
                    Spacer(minLength: 40)
                    hero
                    Spacer(minLength: 40)
                    actionCard
                    daysList
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.bg.ignoresSafeArea())
        .foregroundStyle(Theme.text)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .familyActivityPicker(isPresented: $showPicker, selection: $model.selection)
        .fullScreenCover(item: $model.readingDay) { day in ReaderView(day: day) }
        .sheet(isPresented: Binding(get: { !model.askedName }, set: { _ in })) { welcome }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Welcome").font(Theme.display(34))
            Text("What’s your first name?").font(.system(size: 17, weight: .medium))
            TextField("First name", text: $nameDraft)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .font(.system(size: 19))
                .padding(14)
                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
                .submitLabel(.done)
                .onSubmit(saveName)
            Text("So the app can say good morning to you. You can change it later in Settings.")
                .font(.system(size: 14)).foregroundStyle(Theme.muted)
            Spacer()
            Button("Start reading", action: saveName).buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .foregroundStyle(Theme.text)
        .presentationDetents([.medium])
        .presentationBackground(Theme.surface)
        .interactiveDismissDisabled()
        .preferredColorScheme(.dark)
    }

    private func saveName() {
        model.name = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        model.askedName = true
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "book")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.roseInk)
                    .frame(width: 34, height: 34)
                    .background(Theme.roseDeep, in: RoundedRectangle(cornerRadius: 9))
                Text("Morning Scroll").font(Theme.display(27))
            }
            Spacer()
            Text("🔥 \(model.streak)")
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(Theme.line))
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .frame(width: 40, height: 40)
                    .background(Theme.surface, in: Circle())
                    .overlay(Circle().stroke(Theme.line))
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }

    /// Which book: Gail's study, or the devotional read while the study is on break.
    private var bookTabs: some View {
        HStack(spacing: 8) {
            ForEach(model.shelfNames, id: \.self) { name in
                let on = name == model.activeBookName
                Button { withAnimation(.easeOut(duration: 0.2)) { model.choose(book: name) } } label: {
                    Text(model.books[name].map { $0.short ?? $0.title } ?? name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(on ? Theme.roseInk : Theme.muted)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(on ? Theme.roseDeep : Theme.surface, in: Capsule())
                        .overlay(Capsule().stroke(on ? Theme.roseDeep : Theme.line))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var hero: some View {
        VStack(spacing: 0) {
            HaloBook().padding(.bottom, 26)
            if let day = model.activeDay {
                Text(greeting).font(Theme.display(23, weight: 500, italic: true)).foregroundStyle(Theme.rose)
                    .padding(.bottom, 6)
                if day.isMeditation {
                    Text("\(model.study.title) · \(day.day)".uppercased())
                        .font(.system(size: 13, weight: .medium)).tracking(1.8).foregroundStyle(Theme.muted)
                    Text(day.title ?? day.day).font(Theme.display(40)).multilineTextAlignment(.center).padding(.top, 6).padding(.bottom, 10)
                    Text([day.lesson, day.key].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 17)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                } else {
                    Text("\(model.study.title) · Lesson \(day.lesson)".uppercased())
                        .font(.system(size: 13, weight: .medium)).tracking(1.8).foregroundStyle(Theme.muted)
                    Text(day.day).font(Theme.display(46)).padding(.top, 6).padding(.bottom, 10)
                    Text(day.readings.map(\.ref).joined(separator: " · "))
                        .font(.system(size: 17)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                }
            } else {
                Text("Daily reading complete!").font(Theme.display(40)).multilineTextAlignment(.center).padding(.bottom, 10)
                Text("Enjoy your day with peace of mind.")
                    .font(Theme.read(20)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                Text(model.upNext.map { "Tomorrow: \($0.label)" } ?? "You've finished every day in \(model.study.title).")
                    .font(.system(size: 17)).foregroundStyle(Theme.muted).padding(.top, 12)
            }
        }
    }

    private var actionCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                lockStatus
                if !model.hasBlockedApps {
                    Button("Choose apps to hold back") {
                        Task { if await model.authorize() { showPicker = true } }
                    }
                    .buttonStyle(GhostButtonStyle())
                    if let err = model.authError {
                        Text(err).font(.system(size: 14)).foregroundStyle(Theme.rose)
                    }
                }
                Button(model.activeDay == nil ? "Read again" : (isResuming ? "Continue Daily Reading" : "Open Daily Reading")) {
                    if let day = model.activeDay {
                        model.open(day)
                    } else if let last = model.study.days.last(where: { model.progress.done[$0.id] == model.today }) {
                        model.pick(last)
                    } else {
                        model.open(model.nextDay)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line))

            Text(model.esvKey.isEmpty ? "Reading from the World English Bible. Add your ESV key in Settings." : "English Standard Version")
                .font(.system(size: 14)).foregroundStyle(Theme.faint).multilineTextAlignment(.center)
                .padding(.top, 14)
        }
    }

    @ViewBuilder private var lockStatus: some View {
        HStack(spacing: 10) {
            if !model.hasBlockedApps {
                Text("No apps held back yet").foregroundStyle(Theme.muted)
            } else if model.finishedToday {
                tag("Unlocked", fg: Theme.sage, bg: Theme.unlockedBg)
                Text("until tomorrow").foregroundStyle(Theme.muted)
            } else {
                tag("Locked", fg: Theme.rose, bg: Theme.lockedBg)
                Text("\(model.blockedCount) held back · 5 min to unlock").foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 15))
    }

    private func tag(_ s: String, fg: Color, bg: Color) -> some View {
        Text(s).font(.system(size: 14, weight: .medium)).foregroundStyle(fg)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(bg, in: Capsule())
    }

    private var daysList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation { showDays.toggle() } } label: {
                Text(showDays ? "\(listTitle) ⌄" : "\(listTitle) ›").font(.system(size: 16)).foregroundStyle(Theme.muted)
                    .padding(.vertical, 10).padding(.horizontal, 4)
            }
            if showDays {
                ForEach(model.study.days) { day in
                    let done = model.progress.done[day.id]
                    let current = day == model.upNext
                    Button { model.pick(day) } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().stroke(done != nil ? Theme.sage : Theme.line, lineWidth: 2)
                                if done != nil {
                                    Circle().fill(Theme.sage)
                                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.roseInk)
                                }
                            }
                            .frame(width: 24, height: 24)
                            Text(day.label).foregroundStyle(current ? Theme.rose : Theme.text)
                            Spacer()
                            Text(done.map(shortDate) ?? (current ? "Up next" : ""))
                                .font(.system(size: 14)).foregroundStyle(Theme.faint)
                        }
                        .font(.system(size: 17))
                        .padding(.vertical, 15).padding(.horizontal, 4)
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 26)
    }

    private var listTitle: String { model.study.isDevotional ? "All meditations" : "All lessons" }

    private var isResuming: Bool {
        guard let day = model.activeDay else { return false }
        return model.secondsRead(day) > 0
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let hello = h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening"
        return model.name.isEmpty ? hello : "\(hello), \(model.name)"
    }

    private func shortDate(_ s: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: s) else { return s }
        return d.formatted(.dateTime.month(.abbreviated).day())
    }
}
