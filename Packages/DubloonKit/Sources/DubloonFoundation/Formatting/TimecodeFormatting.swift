//
//  TimecodeFormatting.swift
//  DubloonFoundation
//
//  The three clock formats the interface uses, and the way a frame shape is named
//

public import Foundation
import CoreGraphics

extension TimeInterval {

    /// `mm:ss`, durations and counters, where sub-second precision would only jitter.
    public var rsClock: String {
        String(format: "%02d:%02d", rsMinutes, rsSeconds)
    }

    /// `mm:ss.cc`, a running take, where hundredths show the recorder is live.
    public var rsClockHundredths: String {
        let hundredths = Int((self - floor(self)) * 100)
        return String(format: "%02d:%02d.%02d", rsMinutes, rsSeconds, hundredths)
    }

    /// `mm:ss:ff` at 24 fps, for the playback scrubber, which is dressed as a film editor.
    public var rsClockFrames: String {
        let frames = Int((self - floor(self)) * 24)
        return String(format: "%02d:%02d:%02d", rsMinutes, rsSeconds, frames)
    }

    private var rsMinutes: Int { Int(self) / 60 }
    private var rsSeconds: Int { Int(self) % 60 }
}

extension CGSize {

    /// How a frame of this shape is named on a slate: `16:9`, `4:3`, `9:16`, and so on.
    ///
    /// Matched against the shapes people actually recognise rather than reduced arithmetically:
    /// 1920x1080 reduces to 16:9 on its own, but the 480x360 transfers the public-domain packs
    /// are cut from reduce to 4:3 only because they happen to divide cleanly, and a 1912x1080
    /// crop would reduce to 239:135. Anything that matches nothing is given as a decimal, which
    /// is how an odd aspect is written anyway.
    public var rsAspectLabel: String {
        guard width > 0, height > 0 else { return "—" }

        let ratio = width / height
        let known: [(ratio: CGFloat, name: String)] = [
            (16.0 / 9, "16:9"),
            (9.0 / 16, "9:16"),
            (4.0 / 3, "4:3"),
            (3.0 / 4, "3:4"),
            (3.0 / 2, "3:2"),
            (2.0 / 3, "2:3"),
            (1, "1:1"),
            (1.85, "1.85:1"),
            (2.39, "2.39:1")
        ]

        // A percent of tolerance: enough to absorb the even-number rounding the layout does,
        // not enough to call a 5:4 frame 4:3.
        if let match = known.first(where: { abs(ratio - $0.ratio) / $0.ratio < 0.01 }) {
            return match.name
        }

        return String(format: ratio >= 1 ? "%.2f:1" : "1:%.2f", ratio >= 1 ? ratio : 1 / ratio)
    }
}
