import AVFoundation
import Observation
import SwiftUI
import UIKit

/// The candle's state and everything that changes it: lighting it, listening for a blow,
/// blowing it out.
@MainActor
@Observable
final class CandleModel {
    enum Phase {
        case unlit, lit, blownOut
    }

    enum MicrophoneState {
        case idle, listening, denied, unavailable
    }

    private(set) var phase = Phase.unlit
    private(set) var microphone = MicrophoneState.idle
    /// How hard someone is blowing: 0 is still air, 1 is enough to put the flame out.
    private(set) var gust = 0.0
    /// Loudness and blow threshold (both 0...1) for the breath meter.
    private(set) var loudness = 0.0
    private(set) var threshold = 0.7
    /// When the candle was last blown out; starts the smoke and the confetti.
    private(set) var blownOutAt: Date?

    var sensitivity = 0.5
    var playsBirthdaySong = true

    private let monitor = MicrophoneLevelMonitor()
    private let song = BirthdaySongPlayer()
    @ObservationIgnored private var analyzer = BlowAnalyzer()
    @ObservationIgnored private var songTask: Task<Void, Never>?

    var isLit: Bool { phase == .lit }

    /// Without a working microphone, tapping the flame is how it goes out.
    var canBlowOutByTapping: Bool {
        microphone == .denied || microphone == .unavailable
    }

    func light(listening: Bool = true) {
        guard phase != .lit else { return }
        songTask?.cancel()
        song.stop()
        song.prepare()
        phase = .lit
        gust = 0
        loudness = 0
        Haptics.ignite()
        UIApplication.shared.isIdleTimerDisabled = true
        if listening {
            startListening()
        }
    }

    func blowOut() {
        guard phase == .lit else { return }
        stopListening()
        withAnimation(.easeIn(duration: 0.2)) {
            phase = .blownOut
            blownOutAt = Date()
        }
        UIApplication.shared.isIdleTimerDisabled = false
        Haptics.blowOut()
        if playsBirthdaySong {
            songTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(700))
                guard let self, !Task.isCancelled, self.phase == .blownOut else { return }
                self.song.play()
            }
        }
    }

    func scenePhaseChanged(to scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            if phase == .lit, microphone != .listening {
                startListening()
            }
        case .background:
            stopListening()
            songTask?.cancel()
            song.stop()
        default:
            break
        }
    }

    #if DEBUG
    /// Screenshots and previews: pretend someone is blowing, without a microphone.
    func simulateGust(_ value: Double) {
        gust = value
        loudness = value * threshold
    }
    #endif

    private func startListening() {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            beginMonitoring()
        case .undetermined:
            Task {
                let granted = await AVAudioApplication.requestRecordPermission()
                if granted {
                    if self.phase == .lit {
                        self.beginMonitoring()
                    }
                } else {
                    self.microphone = .denied
                }
            }
        case .denied:
            microphone = .denied
        @unknown default:
            microphone = .unavailable
        }
    }

    private func beginMonitoring() {
        guard !monitor.isRunning else { return }
        analyzer.restart()
        do {
            try monitor.start { [weak self] decibels, duration in
                self?.process(decibels: decibels, duration: duration)
            }
            microphone = .listening
        } catch {
            microphone = .unavailable
        }
    }

    private func stopListening() {
        monitor.stop()
        if microphone == .listening {
            microphone = .idle
        }
        gust = 0
        loudness = 0
    }

    private func process(decibels: Float, duration: TimeInterval) {
        guard phase == .lit else { return }
        analyzer.sensitivity = sensitivity
        let blown = analyzer.process(decibels: decibels, duration: duration)
        gust = analyzer.gust
        loudness = analyzer.level
        threshold = analyzer.threshold
        if blown {
            blowOut()
        }
    }
}
