import SwiftUI

/// A wooden match standing upright, head at the top.
struct MatchStick: View {
    static let size = CGSize(width: 14, height: 100)
    /// Distance from the top of the view to the middle of the head.
    static let headCenterY: CGFloat = 8

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(LinearGradient(
                    colors: [Color(red: 0.95, green: 0.83, blue: 0.62), Color(red: 0.78, green: 0.62, blue: 0.4)],
                    startPoint: .leading, endPoint: .trailing))
                .frame(width: 5.5, height: Self.size.height - 10)
                .offset(y: 10)
            Ellipse()
                .fill(RadialGradient(
                    colors: [Color(red: 0.92, green: 0.3, blue: 0.22), Color(red: 0.5, green: 0.08, blue: 0.06)],
                    center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 9))
                .frame(width: 10, height: 15)
                .offset(y: Self.headCenterY - 7.5)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .top)
    }
}
