//
//  TrialState.swift
//  DubloonFoundation
//

public import Foundation

/// Where a trial stands right now.
public enum TrialState: Equatable, Sendable {
    /// Still running. `daysRemaining` is what the counter shows, and it counts the
    /// day in progress: it reads `1` right up until the window actually closes,
    /// never `0` while the app is still usable.
    case active(daysRemaining: Int, endsAt: Date)
    /// The window has closed.
    case expired
}
