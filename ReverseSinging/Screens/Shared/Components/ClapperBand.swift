//
//  ClapperBand.swift
//  ReverseSinging
//
//  The clapperboard stripe across the head of a one-time note
//

import SwiftUI

/// The diagonal stripe off the top of a clapperboard, as a rule across the head of
/// the screen.
///
/// Drawn rather than shipped as an asset so it stretches to any width without
/// resampling, and so the two colours stay the ones in `Colors.swift` plus the
/// single cream the illustrations use. Purely decorative, and hidden from
/// VoiceOver accordingly.
///
/// Shared with `BoothCamAnnouncementView`, which is the same kind of screen: a
/// fact about the app, told once.
struct ClapperBand: View {

    var height: CGFloat = 8

    /// The cream in the clapperboard and the medal. It is the one warm value in the
    /// app and lives here rather than in `Colors.swift` because nothing else in the
    /// interface is allowed to use it.
    private static let cream = Color(red: 0.871, green: 0.843, blue: 0.780)

    private static let bandWidth: CGFloat = 20

    var body: some View {
        Canvas { context, size in
            // Lean the bands by a little over half their height, which is the rake
            // on the app icon's clapper.
            let rake = size.height * 0.65
            var x = -rake
            var isCream = true

            while x < size.width + rake {
                var band = Path()
                band.move(to: CGPoint(x: x, y: size.height))
                band.addLine(to: CGPoint(x: x + rake, y: 0))
                band.addLine(to: CGPoint(x: x + rake + Self.bandWidth, y: 0))
                band.addLine(to: CGPoint(x: x + Self.bandWidth, y: size.height))
                band.closeSubpath()

                context.fill(band, with: .color(isCream ? Self.cream : .rsRecord))

                x += Self.bandWidth
                isCream.toggle()
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
