//
//  Fold.swift
//  ReverseSinging
//
//  iPhone Duo's fold, while it runs across the screen
//

import SwiftUI

extension GeometryProxy {
    /// The fold in this proxy's space while it runs across it (iPhone Duo half folded as
    /// a table), nil otherwise: no fold, a fold down the middle (book), or older systems.
    var horizontalFold: CGRect? {
        #if os(iOS)
        guard #available(iOS 27.1, *),
              let fold = reservedRegions(kind: .division).first(where: \.isActive)?.frame,
              fold.width > fold.height
        else { return nil }
        return fold
        #else
        return nil
        #endif
    }
}

// MARK: - The middle of the window

extension View {
    /// Writes where the middle of the window falls across this view, as a fraction of its
    /// width: 0.5 when the safe area is even, more when a trailing strip narrows it (iPhone
    /// Duo open flat in landscape keeps its status items in one). A split given this ratio
    /// divides on the seam, which is the middle of the display, rather than left of it.
    func readWindowMiddleRatio(into ratio: Binding<CGFloat>) -> some View {
        modifier(WindowMiddleRatioReader(ratio: ratio))
    }

    /// Pads the leading edge so this view is centred on the middle of the window rather than
    /// on its safe area (no change when the safe area is even): a two-column grid then keeps
    /// its gutter on iPhone Duo's seam.
    /// Only where `isEnabled` (a regular size): on a compact display, such as the outer one
    /// with its side bar, the safe area is the space to centre in.
    func centredOnWindowMiddle(_ isEnabled: Bool = true) -> some View {
        modifier(WindowMiddleCentring(isEnabled: isEnabled))
    }
}

/// The ratio from the *leading* edge, which is what a split's ratio measures: right to left
/// the leading edge is the right one, and the middle measured from the left put the
/// leading pane across the seam.
private struct WindowMiddleRatioReader: ViewModifier {
    @Binding var ratio: CGFloat
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        content.modifier(WindowMiddleReader { frame, window in
            let fromLeft = (window.midX - frame.minX) / frame.width
            let fromLeading = layoutDirection == .rightToLeft ? 1 - fromLeft : fromLeft
            let value = min(max(fromLeading, 0.35), 0.65)
            if abs(value - ratio) > 0.002 { ratio = value }
        })
    }
}

private struct WindowMiddleReader: ViewModifier {
    let update: (_ frame: CGRect, _ window: CGRect) -> Void
    @State private var frame: CGRect = .zero
    @State private var window: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                frame = $0
                report()
            }
            #if os(iOS)
            // The window's bounds, from UIKit: a background ignoring the safe area does not
            // reach under the status strip from inside a navigation stack.
            .background {
                WindowBoundsProbe { bounds in
                    window = bounds
                    report()
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            #endif
    }

    private func report() {
        guard frame.width > 0, window.width > 0 else { return }
        update(frame, window)
    }
}

#if os(iOS)
/// Reports the bounds of the window it is in (in window space, which `.global` matches).
private struct WindowBoundsProbe: UIViewRepresentable {
    let onChange: (CGRect) -> Void

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        view.onChange = onChange
    }

    final class ProbeView: UIView {
        var onChange: ((CGRect) -> Void)?
        private var last: CGRect = .zero

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        private func report() {
            guard let bounds = window?.bounds, bounds != last else { return }
            last = bounds
            DispatchQueue.main.async { [onChange] in onChange?(bounds) }
        }
    }
}
#endif

private struct WindowMiddleCentring: ViewModifier {
    let isEnabled: Bool
    @State private var leading: CGFloat = 0
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        // The pad goes on the physical left (the strip, and so the offset, does not mirror):
        // the leading edge left to right, the trailing edge right to left.
        content
            .padding(layoutDirection == .rightToLeft ? .trailing : .leading, isEnabled ? leading : 0)
            .modifier(WindowMiddleReader { frame, window in
                let value = max(0, (2 * (window.midX - frame.midX)).rounded())
                if abs(value - leading) > 0.5 { leading = value }
            })
    }
}
