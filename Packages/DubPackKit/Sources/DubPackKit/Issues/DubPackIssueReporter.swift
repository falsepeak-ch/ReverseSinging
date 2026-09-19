//
//  DubPackIssueReporter.swift
//  DubPackKit
//

/// Where an install sends what it found, typically a crash reporter's non-fatals.
///
/// Called from whatever task the install runs on, so implementations must be thread safe.
public protocol DubPackIssueReporter: Sendable {
    /// A breadcrumb: one step of an install, in order.
    func log(_ breadcrumb: String)

    /// One kind of issue for one pack, or one failed install.
    func record(_ report: DubPackIssueReport)
}
