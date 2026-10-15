//
//  Fold.swift
//  ReverseSinging
//
//  iPhone Duo's fold, while it runs across the screen
//

import SwiftUI

extension GeometryProxy {
    /// The fold in this proxy's space while it runs across it (iPhone Duo half folded as
    /// a table), nil otherwise: no fold, a fold down the middle (book), or older systems.
    var horizontalFold: CGRect? {
        #if os(iOS)
        guard #available(iOS 27.1, *),
              let fold = reservedRegions(kind: .division).first(where: \.isActive)?.frame,
              fold.width > fold.height
        else { return nil }
        return fold
        #else
        return nil
        #endif
    }
}
