import AVFoundation
import Observation

/// Reads text aloud in a British female voice, the best quality installed on the phone.
@MainActor @Observable
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    var isOn = false

    @ObservationIgnored private let synth = AVSpeechSynthesizer()
    @ObservationIgnored private var onDone: (() -> Void)?

    override init() {
        super.init()
        synth.delegate = self
    }

    /// Premium or Enhanced voices (downloaded in iPhone Settings) sound far more natural than the default.
    static var voice: AVSpeechSynthesisVoice? {
        let british = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-GB" }
        let female = british.filter { $0.gender == .female }
        let pool = female.isEmpty ? british : female
        return pool.max { $0.quality.rawValue < $1.quality.rawValue } ?? AVSpeechSynthesisVoice(language: "en-GB")
    }

    func speak(_ text: String, then done: @escaping () -> Void) {
        synth.stopSpeaking(at: .immediate)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        let u = AVSpeechUtterance(string: text)
        u.voice = Self.voice
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        u.postUtteranceDelay = 0.3
        onDone = done
        synth.speak(u)
    }

    func stop() {
        isOn = false
        onDone = nil
        synth.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            let done = self.onDone
            self.onDone = nil
            done?()
        }
    }
}
