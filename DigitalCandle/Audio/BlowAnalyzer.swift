import Foundation

/// Decides, from a stream of microphone loudness readings, when someone is blowing on the phone.
///
/// Blowing at a phone makes loud wind noise right at the microphone that lasts a moment, while
/// talking, singing, claps and taps are either quieter or much shorter. So a blow is a level above
/// the threshold held for `requiredDuration`. The threshold also rises with the background noise,
/// so a noisy party doesn't put the candle out on its own.
struct BlowAnalyzer {
    /// Loudness (dBFS) mapped to 0 (quiet room) and to 1 (blowing straight into the microphone).
    static let quietDecibels: Float = -60
    static let loudDecibels: Float = -5

    /// 0 needs a strong blow, 1 reacts to a gentle breath.
    var sensitivity = 0.5
    /// How long the level has to stay above the threshold to count as blowing.
    var requiredDuration: TimeInterval = 0.25
    /// Readings right after the microphone starts only calibrate the background level.
    var warmUpDuration: TimeInterval = 0.6

    /// Smoothed loudness, 0...1.
    private(set) var level = 0.0
    /// Estimated background loudness, 0...1.
    private(set) var ambient = 0.15
    private var sustained: TimeInterval = 0
    private var elapsed: TimeInterval = 0

    /// Loudness that counts as blowing, 0...1.
    var threshold: Double {
        let base = 0.86 - 0.32 * min(max(sensitivity, 0), 1)
        return min(0.96, max(base, ambient + 0.2))
    }

    /// How close the current breath is to blowing the candle out: 0 is still air, 1 is the threshold.
    var gust: Double {
        let start = ambient + 0.06
        let span = max(threshold - start, 0.05)
        return min(max((level - start) / span, 0), 1)
    }

    static func normalized(decibels: Float) -> Double {
        let value = (decibels - quietDecibels) / (loudDecibels - quietDecibels)
        return Double(min(max(value, 0), 1))
    }

    /// Starts a new listening session, keeping what was learned about the background noise.
    mutating func restart() {
        level = 0
        sustained = 0
        elapsed = 0
    }

    /// Feeds one loudness reading covering `duration` seconds of audio.
    /// Returns `true` once a blow has been detected.
    mutating func process(decibels: Float, duration: TimeInterval) -> Bool {
        let instant = Self.normalized(decibels: decibels)
        let dt = max(duration, 0.001)
        elapsed += dt

        // Rise quickly and settle gently, so the flame reacts at once but doesn't jitter.
        let smoothing = instant > level ? 0.04 : 0.2
        level += (instant - level) * (1 - exp(-dt / smoothing))

        // Track the background: follow it down quickly, up slowly, and ignore the blow itself.
        let warmingUp = elapsed < warmUpDuration
        if warmingUp || instant < threshold - 0.08 {
            let falling = instant < ambient
            let timeConstant = warmingUp ? (falling ? 0.1 : 0.3) : (falling ? 0.5 : 4)
            ambient += (instant - ambient) * (1 - exp(-dt / timeConstant))
        }
        if warmingUp {
            return false
        }

        if instant >= threshold {
            sustained += dt
        } else {
            sustained = max(0, sustained - 2 * dt)
        }
        return sustained >= requiredDuration
    }
}
