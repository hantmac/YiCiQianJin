import AVFoundation

/// On-device text-to-speech for word pronunciation (no network, no data leaves the device).
@MainActor
final class Pronouncer {
    static let shared = Pronouncer()

    private let synthesizer = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(language: "en-US")

    private init() {}

    func speak(_ text: String, slow: Bool = false) {
        let session = AVAudioSession.sharedInstance()
        // .playback so pronunciation is audible with the silent switch on; duck other audio briefly.
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = slow ? 0.32 : 0.45
        synthesizer.speak(utterance)
    }
}
