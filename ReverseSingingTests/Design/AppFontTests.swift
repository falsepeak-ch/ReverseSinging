//
//  AppFontTests.swift
//  ReverseSingingTests
//
//  The one bundled font, and whether it actually resolves
//

import Testing
import UIKit
import CoreText
@testable import ReverseSinging

@Suite("App Font")
struct AppFontTests {

    /// The name every `Font.custom` call site passes.
    private static let familyName = "Eugello"

    /// `Font.custom` fails silently.
    ///
    /// If the name does not match something CoreText can resolve, SwiftUI substitutes the
    /// system font and says nothing, no exception, no console warning, no visual error. The
    /// display type simply stops being the display type, and the only way to notice is to know
    /// what the screen used to look like. That is a bad failure mode to leave untested when the
    /// name is a string literal repeated at four call sites.
    ///
    /// This resolves the font the way UIKit does, which is the same lookup SwiftUI performs.
    @Test func theBundledFontResolvesByTheNameTheCallSitesUse() {
        let font = UIFont(name: Self.familyName, size: 17)

        #expect(font != nil,
                "\(Self.familyName) did not resolve, every .custom(\"\(Self.familyName)\") call is silently falling back to the system font")
        #expect(font?.familyName == Self.familyName,
                "resolved to \(font?.familyName ?? "nil") rather than \(Self.familyName)")
    }

    /// The font has to be registered by `UIAppFonts`, not merely present in the bundle.
    ///
    /// A file copied into the bundle without the plist entry is invisible to CoreText, which
    /// looks identical to the failure above from the outside.
    @Test func theFontIsRegisteredWithTheSystem() {
        let registered = UIFont.familyNames.contains(Self.familyName)

        #expect(registered,
                "\(Self.familyName) is not in UIFont.familyNames, check UIAppFonts in Info.plist and that the .ttf is in Copy Bundle Resources")
    }

    /// The PostScript name is what a designer replacing this file is most likely to change
    /// without meaning to, and it is the lookup that would break first.
    @Test func thePostScriptNameIsUnchanged() {
        let font = UIFont(name: Self.familyName, size: 17)

        #expect(font?.fontName == "EugelloRegular",
                "PostScript name is \(font?.fontName ?? "nil"); the file may have been re-exported")
    }

    /// Every Latin locale the app ships in must render in the face, accents included.
    ///
    /// A missing accent does not fail loudly. It substitutes that one character from the
    /// system font, so "Última" renders with five serif letters and one grotesque one. That is
    /// the kind of thing nobody sees in English review and every Spanish user sees immediately.
    @Test func theFaceCoversEveryLatinLocaleItRendersIn() throws {
        let font = try #require(UIFont(name: Self.familyName, size: 17))
        let covered = CTFontCopyCharacterSet(font)

        // Accented characters drawn from the six Latin locales' own title strings.
        let required = "áéíóúñüàòïçãõâêôùûœ·ÁÉÍÓÚÑÀÈÌÒÙ"

        for scalar in required.unicodeScalars {
            #expect(covered.hasMember(in: scalar),
                    "\(Self.familyName) has no glyph for '\(scalar)'. It will substitute mid-word")
        }
    }

    /// The face has no ellipsis, so no title may contain one.
    ///
    /// This is the one coverage gap that bites, because a `…` sits *between* letters rather
    /// than replacing a whole string: one grotesque glyph wedged into a serif title. Progress
    /// messages use them freely and that is fine. They render on the system font. This asserts
    /// the gap is real so the constraint documented in `Typography.swift` cannot quietly rot.
    @Test func theFaceHasNoEllipsisSoTitlesMustNotUseOne() throws {
        let font = try #require(UIFont(name: Self.familyName, size: 17))
        let covered = CTFontCopyCharacterSet(font)

        #expect(!covered.hasMember(in: "…"),
                "the face gained an ellipsis. The restriction in Typography.swift can be relaxed")
    }
}

private extension CFCharacterSet {
    func hasMember(in scalar: Unicode.Scalar) -> Bool {
        CFCharacterSetIsLongCharacterMember(self, UTF32Char(scalar.value))
    }
}
