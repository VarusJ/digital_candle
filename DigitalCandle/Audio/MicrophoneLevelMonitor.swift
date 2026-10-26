import Accelerate
import AVFoundation

/// Streams the microphone's loudness using AVAudioEngine.
///
/// Nothing is recorded or saved: each audio buffer is reduced to a single number (its RMS level
/// in dBFS) and dropped right away.
final class MicrophoneLevelMonitor {
    typealias LevelHandler = @MainActor (_ decibels: Float, _ duration: TimeInterval) -> Void

    enum MonitorError: Error {
        case noInputAvailable
    }

    private let engine = AVAudioEngine()
    private var handler: LevelHandler?
    private var observers: [NSObjectProtocol] = []

    var isRunning: Bool { handler != nil }

    func start(handler: @escaping LevelHandler) throws {
        guard !isRunning else { return }
        try startEngine(handler: handler)
        self.handler = handler
        observeSystemEvents()
    }

    func stop() {
        guard isRunning else { return }
        handler = nil
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        stopEngine()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startEngine(handler: @escaping LevelHandler) throws {
        let session = AVAudioSession.sharedInstance()
        // Measurement mode turns off automatic gain and voice processing, so the levels are
        // predictable and the wind noise of a blow isn't filtered away.
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw MonitorError.noInputAvailable
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.tapBlock(handler: handler))
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw error
        }
    }

    private func stopEngine() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    /// Picks up again after the audio hardware changed or an interruption (a call, Siri) ended.
    private func restart() {
        guard let handler else { return }
        stopEngine()
        try? startEngine(handler: handler)
    }

    private func observeSystemEvents() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            self?.restart()
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: rawType) == .ended else { return }
            self?.restart()
        })
    }

    /// Built outside of any actor because the tap runs on a real-time audio thread.
    private static func tapBlock(handler: @escaping LevelHandler) -> AVAudioNodeTapBlock {
        { buffer, _ in
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0, let samples = buffer.floatChannelData?[0] else { return }
            var rms: Float = 0
            vDSP_rmsqv(samples, 1, &rms, vDSP_Length(frameCount))
            let decibels = 20 * log10(max(rms, 0.000_001))
            let duration = Double(frameCount) / buffer.format.sampleRate
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    handler(decibels, duration)
                }
            }
        }
    }
}
