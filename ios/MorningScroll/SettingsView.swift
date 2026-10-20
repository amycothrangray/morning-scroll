import SwiftUI
import FamilyControls

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var keyDraft = ""
    @State private var keyStatus: (ok: Bool, text: String)?
    @State private var testing = false
    @State private var showPicker = false
    @State private var confirmReset = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section("Text size") {
                    Slider(value: $model.fontSize, in: 22...46, step: 1)
                    Text("The LORD is my shepherd; I shall not want.")
                        .font(Theme.read(model.fontSize)).lineSpacing(model.fontSize * 0.3)
                        .padding(.vertical, 6)
                }

                Section {
                    Button {
                        Task { if await model.authorize() { showPicker = true } }
                    } label: {
                        HStack {
                            Text(model.hasBlockedApps ? "Change apps" : "Choose apps")
                            Spacer()
                            Text(model.hasBlockedApps ? "\(model.blockedCount) chosen" : "None").foregroundStyle(Theme.muted)
                        }
                    }
                    if let err = model.authError { Text(err).foregroundStyle(Theme.rose) }
                } header: {
                    Text("Apps held back until you read")
                } footer: {
                    Text("These stay locked each morning until you've read for five minutes and reached the end of the day's reading. They lock again at midnight.")
                }

                Section {
                    SecureField("Paste your key", text: $keyDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button(testing ? "Checking…" : "Save and test") { Task { await testKey() } }
                        .disabled(testing)
                    if let keyStatus {
                        Text(keyStatus.text).foregroundStyle(keyStatus.ok ? Theme.sage : Theme.rose)
                    }
                } header: {
                    Text("ESV API key")
                } footer: {
                    Text("Free for personal use: sign up at api.esv.org, create an application, and paste the key here. Until then the app reads from the World English Bible.")
                }

                Section {
                    Button("Reset my progress", role: .destructive) { confirmReset = true }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .familyActivityPicker(isPresented: $showPicker, selection: $model.selection)
            .confirmationDialog("Clear your completed days and streak? Your settings stay.", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset progress", role: .destructive) { model.resetProgress() }
            }
        }
        .onAppear { keyDraft = model.esvKey }
        .preferredColorScheme(.dark)
    }

    private func testKey() async {
        model.esvKey = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.esvKey.isEmpty else {
            keyStatus = (false, "Key removed. Reading from the World English Bible.")
            return
        }
        testing = true
        defer { testing = false }
        await Scripture.shared.clear()
        do {
            let p = try await Scripture.shared.passage("Lamentations 3:22", esvKey: model.esvKey)
            keyStatus = (true, "Works. “\(p.verses.first?.text ?? "")”")
        } catch {
            keyStatus = (false, (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
