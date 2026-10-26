import AVFoundation

/// Plays a little music-box "Happy Birthday to You", synthesized in code (no audio files needed).
final class BirthdaySongPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var song: AVAudioPCMBuffer?
    private var isConnected = false
    private var isRendering = false
    private var playbackID = 0

    /// The melody as (MIDI note, length in beats), in 3/4 time.
    private static let melody: [(note: Int, beats: Double)] = [
        (67, 0.75), (67, 0.25), (69, 1), (67, 1), (72, 1), (71, 2),
        (67, 0.75), (67, 0.25), (69, 1), (67, 1), (74, 1), (72, 2),
        (67, 0.75), (67, 0.25), (79, 1), (76, 1), (72, 1), (71, 1), (69, 2),
        (77, 0.75), (77, 0.25), (76, 1), (72, 1), (74, 1), (72, 3),
    ]

    /// Renders the song in the background so it's ready by the time the candle goes out.
    func prepare() {
        guard song == nil, !isRendering else { return }
        isRendering = true
        DispatchQueue.global(qos: .userInitiated).async {
            let rendered = BirthdaySongPlayer.render()
            DispatchQueue.main.async { [weak self] in
                self?.song = rendered
                self?.isRendering = false
            }
        }
    }

    func play() {
        guard let song else { return }
        do {
            // Ambient audio mixes with other apps and stays quiet when the phone is on silent.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient)
            try session.setActive(true)
            if !isConnected {
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: song.format)
                isConnected = true
            }
            if !engine.isRunning {
                try engine.start()
            }
        } catch {
            return // The song is a bonus; skip it if audio isn't available.
        }
        playbackID += 1
        let id = playbackID
        player.stop()
        player.scheduleBuffer(song, at: nil, options: [], completionCallbackType: .dataPlayedBack) { [weak self] _ in
            DispatchQueue.main.async {
                self?.finishPlayback(id)
            }
        }
        player.play()
    }

    func stop() {
        playbackID += 1
        player.stop()
        if engine.isRunning {
            engine.stop()
        }
    }

    private func finishPlayback(_ id: Int) {
        guard id == playbackID, engine.isRunning else { return }
        engine.stop()
    }

    private static func render(sampleRate: Double = 44_100) -> AVAudioPCMBuffer? {
        let secondsPerBeat = 0.5
        let ringSeconds = 1.6
        let totalBeats = melody.reduce(0.0) { $0 + $1.beats }
        let frameCount = AVAudioFrameCount((totalBeats * secondsPerBeat + ringSeconds) * sampleRate)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        let totalFrames = Int(frameCount)
        samples.initialize(repeating: 0, count: totalFrames)

        let attackFrames = 0.004 * sampleRate
        let decayStep = exp(-3.0 / sampleRate)
        let overtoneDecayStep = exp(-9.0 / sampleRate)
        var beat = 0.0
        for (note, beats) in melody {
            let frequency = 440 * pow(2, Double(note - 69) / 12)
            let phaseStep = 2 * Double.pi * frequency / sampleRate
            let firstFrame = Int(beat * secondsPerBeat * sampleRate)
            let length = min(Int(ringSeconds * sampleRate), totalFrames - firstFrame)
            // A soft bell: the fundamental plus overtones that fade faster.
            var decay = 1.0
            var overtoneDecay = 1.0
            for n in 0..<max(length, 0) {
                let phase = phaseStep * Double(n)
                let attack = min(1, Double(n) / attackFrames)
                let tone = sin(phase) + overtoneDecay * (0.45 * sin(2 * phase) + 0.18 * sin(3 * phase))
                samples[firstFrame + n] += Float(0.15 * attack * decay * tone)
                decay *= decayStep
                overtoneDecay *= overtoneDecayStep
            }
            beat += beats
        }
        return buffer
    }
}
