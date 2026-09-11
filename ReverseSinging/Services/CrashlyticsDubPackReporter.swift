//
//  CrashlyticsDubPackReporter.swift
//  ReverseSinging
//
//  Sends what a dub-pack install found to Crashlytics
//

import DubPackKit
import Foundation

/// What `CrashlyticsDubPackReporter` needs from a crash reporter. A seam, so tests can see
/// what would have been sent without Firebase.
nonisolated protocol CrashReportingSink: Sendable {
    func log(_ message: String)
    func record(_ error: Error, context: String, keys: [String: Any])
}

nonisolated extension CrashReporter: CrashReportingSink {}

/// Reports every pack that installed only in part, and every pack that did not install, as a
/// Crashlytics non-fatal.
///
/// One non-fatal per kind of issue per pack, each with its own error code, so Crashlytics
/// groups them by the thing that has to be fixed: dropped lines, stills that went missing, a
/// backing track that will not decode. The context names match the ones reported before the
/// import moved into DubPackKit, so existing issues keep collecting.
///
/// Installs run off the main actor; this only forwards, so it is safe from any thread.
nonisolated struct CrashlyticsDubPackReporter: DubPackIssueReporter {

    static let errorDomain = "com.falsepeak.dubloon.dub_pack"

    private let sink: any CrashReportingSink

    init(sink: any CrashReportingSink = CrashReporter.shared) {
        self.sink = sink
    }

    func log(_ breadcrumb: String) {
        sink.log(breadcrumb)
    }

    func record(_ report: DubPackIssueReport) {
        let error = NSError(
            domain: Self.errorDomain,
            code: report.kind.code,
            userInfo: [NSLocalizedDescriptionKey: report.reason]
        )
        sink.record(error, context: report.context, keys: report.keys.mapValues(\.crashReportValue))
    }
}

private nonisolated extension DubPackIssueReport.Value {
    var crashReportValue: Any {
        switch self {
        case .string(let value): value
        case .int(let value): value
        case .double(let value): value
        case .bool(let value): value
        }
    }
}
