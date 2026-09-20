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

    /// RAR, as WinRAR writes it. The system knows the identifier but offers no constant for it,
    /// and only declares it on some OS versions, so it is imported the same way.
    static let rarArchive = UTType(importedAs: "com.rarlab.rar-archive", conformingTo: .archive)
}
