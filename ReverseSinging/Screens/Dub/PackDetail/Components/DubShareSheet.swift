//
//  DubShareSheet.swift
//  ReverseSinging
//
//  The system share sheet for a finished dub
//

import SwiftUI
#if os(iOS)
import LinkPresentation
#endif

// MARK: - Caption

/// The words that travel with a shared video: one line in the app's voice, the hashtag, and
/// where to get the app.
///
/// The hashtag is never translated (it is how posts find each other across languages), and
/// the link is the plain App Store one: the app has no campaign token or share URL of its own
/// to reuse.
nonisolated enum DubShareCaption {
    static let hashtag = "#dubloon"
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6754534073")!

    static func text(line: String = Strings.DubShare.caption) -> String {
        "\(line) \(hashtag) \(appStoreURL.absoluteString)"
    }
}

#if os(iOS)
/// The caption as a share-sheet item that knows where it is not wanted.
///
/// Messages, Mail, WhatsApp, X and the like take the text beside the video. Saving to Photos,
/// AirDrop and printing would turn it into a second, separate thing (a note file, a printed
/// page), so they get nothing. Apps that ignore text altogether (TikTok, Instagram) simply
/// drop it and still get the video.
final class DubShareCaptionItem: NSObject, UIActivityItemSource {
    let caption: String

    init(caption: String) {
        self.caption = caption
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        caption
    }

    func activityViewController(_ controller: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        switch activityType {
        case .saveToCameraRoll?, .airDrop?, .print?, .assignToContact?, .addToReadingList?, .openInIBooks?:
            return nil
        default:
            return caption
        }
    }

    func activityViewController(_ controller: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        "Dubloon"
    }
}

/// The video as a share-sheet item, so the sheet's header shows the clip and the app's name
/// rather than a bare file name, and the caption is not repeated as the preview's title.
final class DubShareVideoItem: NSObject, UIActivityItemSource {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(_ controller: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        url
    }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = "Dubloon"
        metadata.originalURL = url
        metadata.url = url
        return metadata
    }
}

struct DubShareSheet: UIViewControllerRepresentable {
    let url: URL
    /// Text shared beside the video. Nil shares the file alone.
    var caption: String? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        var items: [Any] = [DubShareVideoItem(url: url)]
        if let caption { items.append(DubShareCaptionItem(caption: caption)) }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // Only a dub that actually left the app counts. Opening the sheet and backing out
        // is not the finished thing we would be asking someone to rate.
        controller.completionWithItemsHandler = { _, completed, _, _ in
            guard completed else { return }
            Task { @MainActor in ReviewPrompt.shared.registerVideoShared() }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#else
/// The Mac has no share sheet to slide up, so the finished dub gets a small panel instead: the
/// file itself, to drag straight into Finder, Mail or Messages, and the system's Share menu and a
/// save panel beside it.
struct DubShareSheet: View {
    let url: URL
    /// Text shared beside the video. Nil shares the file alone.
    var caption: String? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // The file, as the Finder draws it, and as something to drag: dropping it
                // anywhere copies the video there.
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 72, height: 72)
                    .draggable(url) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .frame(width: 64, height: 64)
                    }
                    .help(MacDragHint.text)

                VStack(alignment: .leading, spacing: 4) {
                    Text(url.lastPathComponent)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.rsTextPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(MacDragHint.text)
                        .font(.system(size: 11))
                        .foregroundColor(.rsTextTertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(22)

            HStack(spacing: 10) {
                Group {
                    if let caption {
                        ShareLink(item: url, subject: Text("Dubloon"), message: Text(caption)) {
                            Label(Strings.DubShare.share, systemImage: "square.and.arrow.up")
                        }
                    } else {
                        ShareLink(item: url) {
                            Label(Strings.DubShare.share, systemImage: "square.and.arrow.up")
                        }
                    }
                }
                .simultaneousGesture(TapGesture().onEnded {
                    ReviewPrompt.shared.registerVideoShared()
                })

                Button {
                    isSaving = true
                } label: {
                    Label(Strings.DubShare.save, systemImage: "square.and.arrow.down")
                }

                Spacer()

                Button(Strings.Main.Alert.ok) { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .platformProminentButton()
            }
            .controlSize(.large)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.rsSurface2)
            .overlay(alignment: .top) { EditorRule() }
        }
        .frame(width: 460)
        .background(Color.rsSurface1)
        .fileMover(isPresented: $isSaving, file: url) { result in
            if case .success = result {
                ReviewPrompt.shared.registerVideoShared()
                dismiss()
            }
        }
    }
}

/// The hint under the dragged file, in the Mac's own strings table entry.
private enum MacDragHint {
    static let text = NSLocalizedString("mac.export.dragHint", comment: "Under the exported video's icon: it can be dragged out to save it")
}
#endif
