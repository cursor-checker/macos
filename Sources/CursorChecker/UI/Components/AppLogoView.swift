import AppKit
import SwiftUI

/// Large app icon for the About pane; falls back to a styled gauge badge.
struct AppLogoView: View {
    var size: CGFloat = 64

    var body: some View {
        Group {
            if let image = AppIcon.loadImage(displaySize: size * 2) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .font(.system(size: size * 0.38, weight: .semibold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}
