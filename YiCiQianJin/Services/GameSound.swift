import AudioToolbox
import Foundation

/// Short game sound effects, synthesized at first use (no audio files are bundled).
/// Played as system sounds, so they stay quiet when the ring/silent switch is on silent
/// and never interrupt the pronunciation audio session. Used from the main thread only.
final class GameSound {
    static let shared = GameSound()

    enum Effect: CaseIterable {
        case correct1, correct2, correct3, correct4, correct5
        case wrong, bonus, fever, tick, pair, star, rank
    }

    /// Mirrors the user setting; set by the view model.
    var enabled = true

    private var ids: [Effect: SystemSoundID] = [:]
    private var prepared = false

    private init() {}

    func play(_ effect: Effect) {
        guard enabled else { return }
        prepareIfNeeded()
        if let id = ids[effect] { AudioServicesPlaySystemSound(id) }
    }

    /// Correct-answer chime that climbs with the combo.
    func correct(combo: Int) {
        let steps: [Effect] = [.correct1, .correct2, .correct3, .correct4, .correct5]
        play(steps[min(max(combo - 1, 0) / 2, steps.count - 1)])
    }

    func prepareIfNeeded() {
        guard !prepared else { return }
        prepared = true
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("game-sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for effect in Effect.allCases {
            let url = dir.appendingPathComponent("\(effect)-v1.wav")
            if !FileManager.default.fileExists(atPath: url.path) {
                try? Synth.wav(Self.notes(for: effect)).write(to: url)
            }
            var id: SystemSoundID = 0
            if AudioServicesCreateSystemSoundID(url as CFURL, &id) == noErr { ids[effect] = id }
        }
    }

    // MARK: - Sound design

    /// (frequency Hz, start s, length s, volume)
    typealias Note = (freq: Double, start: Double, length: Double, volume: Double)

    private static func notes(for effect: Effect) -> [Note] {
        // Pentatonic steps so the combo climb always sounds consonant.
        let base = [783.99, 880.0, 1046.5, 1174.66, 1318.51]
        switch effect {
        case .correct1: return chime(base[0])
        case .correct2: return chime(base[1])
        case .correct3: return chime(base[2])
        case .correct4: return chime(base[3])
        case .correct5: return chime(base[4])
        case .wrong: return [(196, 0, 0.22, 0.5), (155.56, 0.07, 0.24, 0.45)]
        case .bonus: return [(1318.51, 0, 0.12, 0.35), (1760, 0.06, 0.18, 0.35)]
        case .fever: return [(523.25, 0, 0.16, 0.4), (659.25, 0.07, 0.16, 0.4), (783.99, 0.14, 0.16, 0.4), (1046.5, 0.21, 0.4, 0.45)]
        case .tick: return [(1600, 0, 0.04, 0.25)]
        case .pair: return [(987.77, 0, 0.09, 0.4), (1479.98, 0.05, 0.14, 0.35)]
        case .star: return [(1567.98, 0, 0.18, 0.35)]
        case .rank: return [(392, 0, 0.2, 0.4), (523.25, 0.1, 0.2, 0.4), (659.25, 0.2, 0.2, 0.4), (783.99, 0.3, 0.55, 0.5), (1046.5, 0.3, 0.55, 0.3)]
        }
    }

    private static func chime(_ f: Double) -> [Note] {
        [(f, 0, 0.16, 0.42), (f * 1.5, 0.045, 0.2, 0.28)]
    }

    // MARK: - Synthesis

    enum Synth {
        static let rate = 44_100.0

        /// Mono 16-bit PCM WAV of soft bell-like notes.
        static func wav(_ notes: [Note]) -> Data {
            let duration = (notes.map { $0.start + $0.length }.max() ?? 0.1) + 0.02
            let count = Int(duration * rate)
            var samples = [Double](repeating: 0, count: count)
            for note in notes {
                let start = Int(note.start * rate)
                let length = Int(note.length * rate)
                for i in 0..<length where start + i < count {
                    let t = Double(i) / rate
                    let attack = min(1, t / 0.004)
                    let decay = exp(-t * 5.5 / note.length)
                    let wave = sin(2 * .pi * note.freq * t) + 0.25 * sin(4 * .pi * note.freq * t)
                    samples[start + i] += wave * attack * decay * note.volume
                }
            }
            let peak = max(samples.map(abs).max() ?? 1, 1)
            var pcm = Data(capacity: count * 2)
            for s in samples {
                var v = Int16(max(-1, min(1, s / peak * 0.9)) * Double(Int16.max)).littleEndian
                withUnsafeBytes(of: &v) { pcm.append(contentsOf: $0) }
            }
            return header(dataSize: pcm.count) + pcm
        }

        private static func header(dataSize: Int) -> Data {
            var d = Data()
            func u32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
            func u16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
            d.append(contentsOf: Array("RIFF".utf8)); u32(UInt32(36 + dataSize))
            d.append(contentsOf: Array("WAVE".utf8))
            d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1)
            u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
            d.append(contentsOf: Array("data".utf8)); u32(UInt32(dataSize))
            return d
        }
    }
}
