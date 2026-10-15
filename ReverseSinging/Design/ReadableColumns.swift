import SwiftUI

/// Grid columns for a list of cards: one on a compact width (every iPhone, the iPhone Duo
/// outer display), two on a regular width (iPhone Duo open, a Mac window), so cards keep a
/// phone-like width and the even count leaves the fold between them.
enum ReadableColumns {
    static func columns(for sizeClass: UserInterfaceSizeClass?, spacing: CGFloat) -> [GridItem] {
        let count = sizeClass == .regular ? 2 : 1
        return Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top), count: count)
    }
}
