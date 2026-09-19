//
//  LaunchDecision.swift
//  DubloonFoundation
//
//  A question about an install, answered on the first launch that asks it
//

public import Foundation

/// A question about this install that is answered once and then remembered.
///
/// The questions worth asking this way are about history: was the app in use before the build
/// that asks? At the first launch of that build, an old install and a brand-new one differ only
/// in what earlier versions left in `UserDefaults`. Minutes later they no longer differ at all,
/// because the new install has written the same markers on its own, and asking again would give
/// the wrong answer to exactly the people the question was about. So it is asked on that first
/// launch, and the fact that it was asked is written down.
public struct LaunchDecision {

    private let key: String
    private let defaults: UserDefaults

    /// - Parameter key: where the fact that the question was asked is kept.
    public init(key: String, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
    }

    /// Whether the question has been asked on this install.
    public var isMade: Bool { defaults.bool(forKey: key) }

    /// Runs `decide` unless the question has been asked before, and records that it has.
    ///
    /// Recorded before `decide` runs, so nothing `decide` writes can bring the question back.
    ///
    /// - Returns: whether `decide` ran.
    @discardableResult
    public func makeOnce(_ decide: () -> Void) -> Bool {
        guard !isMade else { return false }
        defaults.set(true, forKey: key)
        decide()
        return true
    }

    /// Forgets that the question was asked, so the next launch asks it again.
    public func reset() {
        defaults.removeObject(forKey: key)
    }
}

extension UserDefaults {

    /// Whether anything is stored under any of `keys`, `false` and `0` included.
    public func containsValue(forAnyOf keys: [String]) -> Bool {
        keys.contains { object(forKey: $0) != nil }
    }
}
