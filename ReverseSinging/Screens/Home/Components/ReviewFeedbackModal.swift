//
//  ReviewFeedbackModal.swift
//  ReverseSinging
//
//  What went wrong, asked of someone who gave the menu's review note a low rating.
//

import SwiftUI

/// A text box and a Send button, for the player who is not happy.
///
/// A low rating is more use to us as a sentence than as a number: it says what to fix. The
/// note goes to the developer and nowhere else, and the dialog says so.
struct ReviewFeedbackModal: View {

    /// The rating that opened the dialog, shown back so the note reads as its explanation.
    let stars: Int
    /// Called with the note when the user sends it.
    let onSend: (String) -> Void
    /// Called when the user backs out.
    let onCancel: () -> Void

    @State private var note = ""
    @FocusState private var isWriting: Bool

    private var canSend: Bool {
        !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        EditorModal(title: Strings.ReviewFeedback.slug, onClose: onCancel) {
            HStack(spacing: 4) {
                ForEach(1...ReviewBanner.maximumStars, id: \.self) { star in
                    Image(systemName: star <= stars ? "star.fill" : "star")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(star <= stars ? Color.rsTurquoise : Color.rsTextTertiary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(format: Strings.ReviewBanner.starLabel, stars))

            VStack(spacing: 10) {
                Text(Strings.ReviewFeedback.title)
                    .font(.rsHeadingSmall)
                    .foregroundColor(.rsTextPrimary)
                    .multilineTextAlignment(.center)

                Text(Strings.ReviewFeedback.message)
                    .font(.rsBodySmall)
                    .foregroundColor(.rsTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            editor
        } phoneActions: {
            BigButton(
                title: Strings.ReviewFeedback.send,
                icon: "paperplane.fill",
                color: .rsTurquoise,
                action: send,
                isEnabled: canSend,
                style: .primary,
                textFont: .rsButtonMedium
            )
        } macActions: {
            Button(Strings.ReviewFeedback.send, action: send)
                .keyboardShortcut(.defaultAction)
                .platformProminentButton()
                .disabled(!canSend)
        }
        .onAppear { isWriting = true }
    }

    private var editor: some View {
        TextEditor(text: $note)
            .font(.rsBodySmall)
            .foregroundColor(.rsTextPrimary)
            .scrollContentBackground(.hidden)
            .focused($isWriting)
            .padding(8)
            .frame(height: 120)
            .overlay(alignment: .topLeading) {
                if note.isEmpty {
                    Text(Strings.ReviewFeedback.placeholder)
                        .font(.rsBodySmall)
                        .foregroundColor(.rsTextTertiary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .editorPanel(.rsSurface2)
            .onChange(of: note) { _, text in
                if text.count > ReviewBanner.feedbackCharacterLimit {
                    note = String(text.prefix(ReviewBanner.feedbackCharacterLimit))
                }
            }
    }

    private func send() {
        guard canSend else { return }
        onSend(note)
    }
}

#Preview {
    ZStack {
        Color.rsSurface0.ignoresSafeArea()
        ReviewFeedbackModal(stars: 2, onSend: { _ in }, onCancel: {})
    }
    .preferredColorScheme(.dark)
}
