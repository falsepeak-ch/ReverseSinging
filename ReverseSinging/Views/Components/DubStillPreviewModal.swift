//
//  DubStillPreviewModal.swift
//  ReverseSinging
//
//  The pack still, blown up. Tapping a thumbnail in the library opens this so the
//  frame can actually be looked at — and saved, since it is the one piece of a pack
//  the user might want outside the app.
//

import SwiftUI

struct DubStillPreviewModal: View {
    /// The still on disk.
    let url: URL
    /// Named in the title bar, so a stack of similar frames stays identifiable.
    let title: String
    let onClose: () -> Void

    /// Where the save got to. The button carries this rather than an alert: the
    /// result belongs on the control that caused it.
    private enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }

    @State private var image: UIImage?
    @State private var saveState: SaveState = .idle

    var body: some View {
        ZStack {
            backdrop

            panel
                .padding(.horizontal, EditorMetrics.gutter)
                .padding(.vertical, 24)
                .transition(.opacity)
        }
        .task(id: url) {
            let path = url.path
            image = await Task.detached(priority: .userInitiated) {
                UIImage(contentsOfFile: path)
            }.value
        }
        .onAppear {
            AnalyticsManager.shared.trackDubStillPreviewOpened()
        }
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        Color.rsSurface0
            .opacity(0.92)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { close() }
            .accessibilityHidden(true)
    }

    // MARK: - Panel

    private var panel: some View {
        VStack(spacing: 0) {
            titleBar

            still

            VStack(spacing: 10) {
                downloadButton

                if case .failed(let message) = saveState {
                    Text(message)
                        .font(.rsMeta)
                        .foregroundColor(.rsCaution)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(EditorMetrics.gutter)
        }
        .editorPanel(.rsSurface1, radius: EditorMetrics.radiusLarge)
        .frame(maxWidth: 480)
        .animation(.rsSpring, value: saveState)
    }

    private var titleBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(title)
                    .editorLabelStyle(.rsTextSecondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                EditorToolbarButton(
                    icon: "xmark",
                    label: Strings.Dub.close,
                    action: close
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            EditorRule()
        }
    }

    /// Fit, not fill: the point of the modal is to see the whole frame. The black
    /// bed keeps a portrait still from leaving a bright gap in the panel.
    private var still: some View {
        Color.black
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .transition(.opacity)
                }
            }
            .clipped()
            .overlay(alignment: .bottom) { EditorRule() }
            .animation(.rsSmooth, value: image != nil)
            .accessibilityLabel(title)
    }

    /// The pack's own shape once the file is decoded, 16:9 until then, so the panel
    /// doesn't jump a full frame's height when the image lands.
    private var aspectRatio: CGFloat {
        guard let image, image.size.height > 0 else { return 16.0 / 9.0 }
        return image.size.width / image.size.height
    }

    // MARK: - Download

    private var downloadButton: some View {
        // `isEnabled`/`isLoading` rather than `.disabled` — BigButton greys and spins
        // itself off those, and a plain modifier would leave it looking live.
        BigButton(
            title: downloadTitle,
            icon: saveState == .saved ? "checkmark" : "arrow.down.to.line",
            color: .rsHighlight,
            action: download,
            isEnabled: image != nil && saveState != .saved,
            isLoading: saveState == .saving,
            style: .primary,
            textFont: .rsButtonMedium
        )
    }

    private var downloadTitle: String {
        switch saveState {
        case .idle, .failed: return Strings.Dub.Still.download
        case .saving: return Strings.Dub.Still.saving
        case .saved: return Strings.Dub.Still.saved
        }
    }

    private func download() {
        guard saveState != .saving else { return }
        saveState = .saving

        Task {
            do {
                try await PhotoLibrarySaver.save(imageAt: url)
                HapticManager.shared.success()
                saveState = .saved
                AnalyticsManager.shared.trackDubStillDownloaded()
            } catch PhotoLibrarySaver.SaveError.notAuthorized {
                HapticManager.shared.error()
                saveState = .failed(Strings.Dub.Still.permissionDenied)
            } catch {
                HapticManager.shared.error()
                saveState = .failed(Strings.Dub.Still.saveFailed)
            }
        }
    }

    // MARK: - Behaviour

    private func close() {
        HapticManager.shared.light()
        onClose()
    }
}

// MARK: - Presentation

private struct DubStillPreviewModifier: ViewModifier {
    @Binding var still: DubStillPreview?

    func body(content: Content) -> some View {
        content
            .overlay {
                if let still {
                    DubStillPreviewModal(
                        url: still.url,
                        title: still.title,
                        onClose: { self.still = nil }
                    )
                }
            }
            .animation(.rsSmooth, value: still)
    }
}

/// What the preview modal needs to show one still, and the binding that opens it.
struct DubStillPreview: Identifiable, Equatable {
    let url: URL
    let title: String

    var id: URL { url }
}

extension View {
    /// Presents a full-size, downloadable still over this view.
    func dubStillPreview(_ still: Binding<DubStillPreview?>) -> some View {
        modifier(DubStillPreviewModifier(still: still))
    }
}

// MARK: - Previews

#Preview("Still") {
    ZStack {
        Color.rsSurface0.ignoresSafeArea()
        DubStillPreviewModal(
            url: URL(fileURLWithPath: "/dev/null"),
            title: "The Godfather — Opening",
            onClose: {}
        )
    }
    .preferredColorScheme(.dark)
}
