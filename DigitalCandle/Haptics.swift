import UIKit

@MainActor
enum Haptics {
    /// Striking the match.
    static func strike() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// The wick catching fire.
    static func ignite() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// The candle going out.
    static func blowOut() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
