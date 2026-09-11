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

    public var id: String { rawValue }

    /// Whether choosing this frame means re-encoding rather than remuxing.
    public var needsCompositing: Bool { self != .off }

    /// Whether this frame reshapes the export to 9:16 and carries the waveform strip.
    ///
    /// These are the only frames worth rendering with no booth footage in them: the others
    /// exist purely to place the booth, and without it are just `off` the long way round.
    public var isVertical: Bool {
        switch self {
        case .stacked, .reaction: return true
        case .off, .corner, .split: return false
        }
    }
}
