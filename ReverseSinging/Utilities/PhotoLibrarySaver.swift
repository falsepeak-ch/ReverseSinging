//
//  PhotoLibrarySaver.swift
//  ReverseSinging
//
//  Writes an image file into the user's photo library.
//

import Photos

/// Saves image files to Photos with add-only access.
///
/// Add-only is deliberate: the app never reads the library, so asking for full
/// access would be asking for more than it needs and would put a bigger, scarier
/// prompt in front of a one-tap save.
enum PhotoLibrarySaver {

    enum SaveError: Error {
        /// The user said no, or Photos is restricted on this device.
        case notAuthorized
        /// Photos accepted the request and then failed to write it.
        case failed(String)
    }

    /// Copies the file at `url` into the photo library, asking for permission first.
    static func save(imageAt url: URL) async throws {
        let status = await requestAddOnlyAuthorization()
        guard status == .authorized || status == .limited else {
            throw SaveError.notAuthorized
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                // The file is handed over as a resource rather than a decoded UIImage:
                // that keeps the original bytes, so the still lands in Photos at the
                // pack's own resolution instead of a re-encoded copy.
                PHAssetCreationRequest.forAsset()
                    .addResource(with: .photo, fileURL: url, options: nil)
            }
        } catch {
            throw SaveError.failed(error.localizedDescription)
        }
    }

    private static func requestAddOnlyAuthorization() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard current == .notDetermined else { return current }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }
}
