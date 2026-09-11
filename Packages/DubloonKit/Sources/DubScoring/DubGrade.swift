//
//  DubGrade.swift
//  DubScoring
//
//  The band a score falls in
//

/// The band a score falls in, and the short badge for it.
///
/// One ladder for the whole dub feature, so the record screen, the line list and the scene
/// summary can never disagree about whether 74 is good. The words and colours for each band
/// belong to whoever shows it.
public enum DubGrade: String, CaseIterable, Sendable {
    case perfect
    case great
    case good
    case close
    case rough

    public static func forScore(_ score: Double) -> DubGrade {
        switch score {
        case 88...:    return .perfect
        case 74..<88:  return .great
        case 58..<74:  return .good
        case 40..<58:  return .close
        default:       return .rough
        }
    }

    /// Two or three characters, for a chip beside a line.
    public var badge: String {
        switch self {
        case .perfect: return "A+"
        case .great:   return "A"
        case .good:    return "B"
        case .close:   return "C"
        case .rough:   return "D"
        }
    }
}
