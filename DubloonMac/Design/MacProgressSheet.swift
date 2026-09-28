//
//  MacProgressSheet.swift
//  DubloonMac
//
//  Long work as a Mac shows it: a sheet with what is happening and a progress bar
//

import SwiftUI

/// The Mac's way to wait: a sheet on the window naming the job, what it is doing now, and a
/// native progress bar. The iPhone's spinner card is the phone's way.
struct MacProgressSheet: View {
    let image: String
    let title: String
    let message: String
    /// 0...1, or nil while the work cannot say how far it has got.
    var progress: Double?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.rsTextPrimary)

                Group {
                    if let progress {
                        ProgressView(value: min(max(progress, 0), 1))
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                    }
                }
                .frame(width: 300)

                Text(message)
                    .font(.system(size: 11))
                    .foregroundColor(.rsTextSecondary)
                    .monospacedDigit()
            }
        }
        .padding(22)
        .frame(width: 420, alignment: .leading)
        .background(Color.rsSurface1)
        .interactiveDismissDisabled()
    }
}

extension View {
    /// Shows long work on a sheet while `isPresented` holds.
    func macProgressSheet(
        isPresented: Bool,
        image: String,
        title: String,
        message: String,
        progress: Double?
    ) -> some View {
        sheet(isPresented: .constant(isPresented)) {
            MacProgressSheet(image: image, title: title, message: message, progress: progress)
        }
    }
}
