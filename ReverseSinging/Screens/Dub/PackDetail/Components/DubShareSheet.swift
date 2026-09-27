//
//  DubShareSheet.swift
//  ReverseSinging
//
//  The system share sheet for a finished dub
//

import SwiftUI

#if os(iOS)
struct DubShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
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
                ShareLink(item: url) {
                    Label(Strings.DubShare.share, systemImage: "square.and.arrow.up")
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
                    .buttonStyle(.borderedProminent)
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
