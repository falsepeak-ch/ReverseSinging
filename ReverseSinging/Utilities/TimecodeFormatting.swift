//
//  TimecodeFormatting.swift
//  ReverseSinging
//
//  The three clock formats the interface uses, in one place
//

import Foundation

extension TimeInterval {

    /// `mm:ss`, durations and counters, where sub-second precision would only jitter.
    var rsClock: String {
        String(format: "%02d:%02d", rsMinutes, rsSeconds)
    }

    /// `mm:ss.cc`, a running take, where hundredths show the recorder is live.
    var rsClockHundredths: String {
        let hundredths = Int((self - floor(self)) * 100)
        return String(format: "%02d:%02d.%02d", rsMinutes, rsSeconds, hundredths)
    }

    /// `mm:ss:ff` at 24 fps, for the playback scrubber, which is dressed as a film editor.
    var rsClockFrames: String {
        let frames = Int((self - floor(self)) * 24)
        return String(format: "%02d:%02d:%02d", rsMinutes, rsSeconds, frames)
    }

    private var rsMinutes: Int { Int(self) / 60 }
    private var rsSeconds: Int { Int(self) % 60 }
}
