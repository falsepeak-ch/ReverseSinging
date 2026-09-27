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
/// The Mac has no share sheet to slide up, so the finished dub gets a small panel instead:
/// share it through the system's services, or save it somewhere with the file panel.
struct DubShareSheet: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(url.lastPathComponent, systemImage: "film")
                .font(.rsButtonMedium)
                .foregroundStyle(Color.rsTextPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

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
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
        .frame(width: 420)
        .background(Color.rsSurface1)
        .fileMover(isPresented: $isSaving, file: url) { result in
            if case .success = result {
                ReviewPrompt.shared.registerVideoShared()
                dismiss()
            }
        }
    }
}
#endif
