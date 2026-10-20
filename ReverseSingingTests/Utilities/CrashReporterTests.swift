//
//  CrashReporterTests.swift
//  ReverseSingingTests
//
//  What a non-fatal carries, and which failures are left out
//

import Testing
import Foundation
@testable import ReverseSinging

@Suite("Crash Reporter")
struct CrashReporterTests {

    @Test func theCauseUnderneathIsSpelledOut() {
        let posix = NSError(domain: NSPOSIXErrorDomain, code: 2)
        let status = NSError(domain: NSOSStatusErrorDomain, code: -17913, userInfo: [NSUnderlyingErrorKey: posix])
        let failed = NSError(domain: "AVFoundationErrorDomain", code: -11800, userInfo: [NSUnderlyingErrorKey: status])

        #expect(CrashReporter.underlyingChain(of: failed) == "NSOSStatusErrorDomain -17913 < NSPOSIXErrorDomain 2")
        #expect(CrashReporter.underlyingChain(of: posix) == nil)
    }

    @Test func aMixErrorHandsOverWhatFailedUnderIt() {
        let cause = NSError(domain: "AVFoundationErrorDomain", code: -11800)
        let reported = HomeVideoMixer.MixError.exportFailed(cause) as NSError

        #expect(CrashReporter.underlyingChain(of: reported) == "AVFoundationErrorDomain -11800")
        #expect(reported.localizedDescription.hasPrefix("Could not write the video"))
        #expect(CrashReporter.underlyingChain(of: HomeVideoMixer.MixError.tooShort as NSError) == nil)
    }

    #if os(iOS)
    @Test func theHardwareSayingNopeIsTheDevicesMoment() {
        let nope = NSError(domain: "com.apple.coreaudio.avfaudio", code: AudioSessionError.hardwareRefusedCode)
        #expect(AudioSessionError.classify(nope).isEnvironmental)
        #expect(!AudioSessionError.classify(NSError(domain: "com.apple.coreaudio.avfaudio", code: -10868)).isEnvironmental)
    }
    #endif
}
