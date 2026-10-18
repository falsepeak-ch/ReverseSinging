//
//  DubBoothFrame.swift
//  DubCompositing
//
//  The shapes an export can put the booth in
//

/// How the booth is composited into an export.
public enum DubBoothFrame: String, CaseIterable, Identifiable, Sendable, Codable {
    /// The dub on its own, as it has always exported. The only frame that needs no re-encode.
    case off
    /// A portrait inset in the picture's corner. Output keeps the scene's own shape.
    case corner
    /// Scene above, booth below, rendered 9:16 for a story or a short.
    case stacked
    /// Booth above, scene below, 9:16. The reaction-video order.
    case reaction
    /// Scene and booth side by side, each filling half a landscape frame.
    case split
    /// A 9:16 post: the scene letterboxed at full width, the booth a small rounded
    /// picture-in-picture in one corner. See `DubPipCorner`.
    case vertical

    public var id: String { rawValue }

    /// Whether this frame places the performer at all.
    ///
    /// Every export is re-encoded now, because every export carries the Dubloon mark; this
    /// only says whether booth footage is laid into the picture.
    public var needsCompositing: Bool { self != .off }

    /// Whether this frame reshapes the export to 9:16.
    ///
    /// These are the only frames worth rendering with no booth footage in them: the others
    /// exist purely to place the booth, and without it are just `off` the long way round.
    public var isVertical: Bool {
        switch self {
        case .stacked, .reaction, .vertical: return true
        case .off, .corner, .split: return false
        }
    }

    /// Whether this frame carries the waveform strip along its foot. `vertical` does not:
    /// it is the plain letterboxed post, and its lower bar is where the booth goes.
    public var hasWaveStrip: Bool {
        switch self {
        case .stacked, .reaction: return true
        case .off, .corner, .split, .vertical: return false
        }
    }
}

/// Which corner of a `vertical` export the booth picture-in-picture sits in.
///
/// Three corners, not four: the top-left one belongs to the Dubloon mark in that frame, and a
/// choice that put the two on top of each other is not one worth offering.
public enum DubPipCorner: String, CaseIterable, Identifiable, Sendable, Codable {
    case bottomRight
    case bottomLeft
    case topRight

    public var id: String { rawValue }

    public var isTop: Bool { self == .topRight }
    public var isLeft: Bool { self == .bottomLeft }
}
