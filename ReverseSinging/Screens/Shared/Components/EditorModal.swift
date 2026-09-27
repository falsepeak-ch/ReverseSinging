//
//  EditorModal.swift
//  ReverseSinging
//
//  The frame every in-app modal sits in: a card over the screen on the iPhone, a window sheet
//  on the Mac
//

import SwiftUI

/// One modal's chrome, drawn the way each platform draws a modal.
///
/// On the iPhone: a card over a dimmed screen, with a title strip, a close key, and the
/// modal's own full-width buttons under its content. On the Mac: the content on a window
/// sheet, which the system dims and animates, and a footer the way every Mac sheet has one:
/// Back on the left where there are steps, Cancel on Esc and the default button on Return on
/// the right. So a modal says what it shows once, and each platform frames it.
struct EditorModal<Content: View, PhoneActions: View, MacActions: View>: View {
    /// The strip at the top of the iPhone card. The Mac sheet has no title bar.
    let title: String
    var width: CGFloat = 460
    /// Where a modal has steps, the way back to the first.
    var onBack: (() -> Void)?
    let onClose: () -> Void
    @ViewBuilder var content: () -> Content
    @ViewBuilder var phoneActions: () -> PhoneActions
    @ViewBuilder var macActions: () -> MacActions

    var body: some View {
        #if os(macOS)
        macSheet
        #else
        phoneCard
        #endif
    }

    // MARK: - Mac

    private var macSheet: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                content()
            }
            .padding(.horizontal, 30)
            .padding(.top, 28)
            .padding(.bottom, 22)

            HStack(spacing: 12) {
                if let onBack {
                    Button(action: onBack) {
                        Label(Strings.DubGate.downloadBack, systemImage: "chevron.left")
                    }
                    .platformGlassButton()
                    .controlSize(.large)
                }

                Spacer(minLength: 8)

                Button(Strings.Main.Alert.cancel, action: onClose)
                    .keyboardShortcut(.cancelAction)
                    .platformGlassButton()
                    .controlSize(.large)

                macActions()
                    .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.rsSurface2)
            .overlay(alignment: .top) { EditorRule() }
        }
        .frame(width: width)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.rsSurface1)
    }

    // MARK: - iPhone

    private var phoneCard: some View {
        ZStack {
            Color.rsSurface0
                .opacity(0.88)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }
                .accessibilityHidden(true)

            ViewThatFits(in: .vertical) {
                phoneContent
                ScrollView { phoneContent }
                    .scrollBounceBehavior(.basedOnSize)
            }
            .editorPanel(.rsSurface1, radius: EditorMetrics.radiusLarge)
            .frame(maxWidth: 400)
            .padding(.horizontal, EditorMetrics.gutter)
            .padding(.vertical, 24)
            .transition(.opacity)
        }
    }

    private var phoneContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    if let onBack {
                        EditorToolbarButton(icon: "chevron.left", label: Strings.DubGate.downloadBack, action: onBack)
                    }

                    Text(title)
                        .editorLabelStyle(.rsTextSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    EditorToolbarButton(icon: "xmark", label: Strings.DubGate.close) {
                        HapticManager.shared.light()
                        onClose()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                EditorRule()
            }

            VStack(spacing: 20) {
                content()
                phoneActions()
            }
            .padding(EditorMetrics.gutter)
        }
    }
}

extension View {
    /// Presents a modal the way the platform does: laid over this view on the iPhone, as a
    /// sheet on the window on the Mac.
    func editorModal<Modal: View>(isPresented: Binding<Bool>, @ViewBuilder modal: @escaping () -> Modal) -> some View {
        #if os(macOS)
        sheet(isPresented: isPresented, content: modal)
        #else
        overlay {
            if isPresented.wrappedValue { modal() }
        }
        .animation(.rsSmooth, value: isPresented.wrappedValue)
        #endif
    }
}

// MARK: - Glass

extension View {
    /// The default action's button: Liquid Glass where the system draws it, bordered before.
    @ViewBuilder
    func platformProminentButton() -> some View {
        if #available(iOS 26, macOS 26, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

    /// Any other button that sits on its own: glass where the system draws it.
    @ViewBuilder
    func platformGlassButton() -> some View {
        if #available(iOS 26, macOS 26, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    /// An on/off switch the way the system draws it: on macOS 26 and later a full-size Liquid
    /// Glass switch, whose knob turns to glass under the pointer. A small control size would
    /// draw the older flat switch, so every switch keeps the regular size.
    func platformSwitch(tint: Color = .accentColor) -> some View {
        toggleStyle(.switch)
            .controlSize(.regular)
            .tint(tint)
    }

    /// Liquid Glass behind a control drawn by hand, in its own shape; the fallback is the fill
    /// the control used before glass existed.
    @ViewBuilder
    func platformGlass<S: Shape>(in shape: S, tint: Color? = nil, fallback: Color) -> some View {
        if #available(iOS 26, macOS 26, *) {
            glassEffect(tint.map { Glass.regular.tint($0).interactive() } ?? Glass.regular.interactive(), in: shape)
        } else {
            background(shape.fill(fallback))
        }
    }
}
