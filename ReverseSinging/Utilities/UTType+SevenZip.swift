//
//  UTType+SevenZip.swift
//  ReverseSinging
//

import UniformTypeIdentifiers

extension UTType {
    /// `.7z`. Declared by the app in Info.plist (`UTImportedTypeDeclarations`), because iOS has
    /// no type for the extension, and a file the system cannot type is one the document picker
    /// greys out.
    static let sevenZipArchive = UTType(importedAs: "org.7-zip.7z-archive", conformingTo: .archive)
}
