//
//  OnboardingPageView.swift
//  ReverseSinging
//
//  One onboarding page: the illustration, the title and the message
//

import SwiftUI

struct OnboardingPage {
    let imageName: String
    let title: String
    let description: String
    let matteColor: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    @Environment(\.colorScheme) var colorScheme
    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var titleOpacity: Double = 0
    @State private var descriptionOffset: CGFloat = 20
    @State private var descriptionOpacity: Double = 0

    var body: some View {
        GeometryReader { geometry in
            // The illustration gives way before the words do. A page that does not fit, on a
            // small phone or with large text, is tried again with a smaller picture, and only
            // scrolls, with its scroll bar showing, once the picture cannot shrink further.
            // Words cut off mid-sentence with nothing to say there is more read as a bug.
            ViewThatFits(in: .vertical) {
                pageContent(in: geometry.size, imageScale: 1)
                pageContent(in: geometry.size, imageScale: 0.75)
                pageContent(in: geometry.size, imageScale: 0.5)
                ScrollView(.vertical) {
                    pageContent(in: geometry.size, imageScale: 0.5)
                        .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            // Icon animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }

            // Title animation
            withAnimation(.rsSpring.delay(0.15)) {
                titleOffset = 0
                titleOpacity = 1.0
            }

            // Description animation
            withAnimation(.rsSpring.delay(0.25)) {
                descriptionOffset = 0
                descriptionOpacity = 1.0
            }
        }
    }

    private func pageContent(in size: CGSize, imageScale: CGFloat) -> some View {
        VStack(spacing: adaptiveSpacing(for: size.height)) {
            Image(page.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: imageSize(for: size) * imageScale, height: imageSize(for: size) * imageScale)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
                .accessibilityHidden(true)

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.rsDisplay(titleSize(for: size.height)))
                    .foregroundColor(Color.rsTextAdaptive(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, horizontalPadding(for: size.width))
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)

                Text(page.description)
                    .font(.rsBodyLarge)
                    .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, horizontalPadding(for: size.width))
                    .offset(y: descriptionOffset)
                    .opacity(descriptionOpacity)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Dynamic Layout Helpers (Percentage-Based)

    private func imageSize(for size: CGSize) -> CGFloat {
        // Dynamic sizing: 30-42% of height OR 52% of width, whichever is smaller
        // Works for any screen size and aspect ratio
        let isLandscape = size.width > size.height

        let heightBased = size.height * (isLandscape ? 0.42 : 0.35)
        let widthBased = size.width * 0.52

        let dynamicSize = min(heightBased, widthBased)

        // Cap between 140pt (tiny windows) and 450pt (iPad Pro)
        return min(450, max(140, dynamicSize))
    }

    private func titleSize(for height: CGFloat) -> CGFloat {
        // Dynamic: 4-5% of screen height
        let dynamicSize = height * 0.045
        // Cap between 20pt and 48pt
        return min(48, max(20, dynamicSize))
    }

    private func adaptiveSpacing(for height: CGFloat) -> CGFloat {
        // Dynamic: 3% of screen height for content spacing
        let spacing = height * 0.03
        return min(40, max(12, spacing))
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        // Dynamic: 6-8% of screen width
        let padding = width * 0.07
        return min(60, max(20, padding))
    }
}
