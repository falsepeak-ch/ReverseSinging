//
//  MacSidebar.swift
//  DubloonMac
//
//  The libraries: the games, the dub packs, and the archive of reverse-singing sessions
//

import SwiftUI

struct MacSidebar: View {
    @ObservedObject var workspace: MacWorkspaceViewModel
    @Environment(\.openURL) private var openURL

    @State private var isDropTargeted = false

    private var home: HomeViewModel { workspace.home }

    @AppStorage("mac.sidebar.reverseExpanded") private var isReverseExpanded = true
    @AppStorage("mac.sidebar.dubExpanded") private var isDubExpanded = true

    var body: some View {
        // The three games at one level; what belongs to a game, its saved sessions or its
        // packs, folds out underneath it.
        List(selection: workspace.selectionBinding) {
            Section(MacStrings.Sidebar.games) {
                if workspace.sessions.isEmpty {
                    gameRow(.reverse).tag(MacDestination.reverse)
                } else {
                    DisclosureGroup(isExpanded: $isReverseExpanded) {
                        ForEach(workspace.sessions) { session in
                            sessionRow(session)
                                .tag(MacDestination.session(session.id))
                                .contextMenu {
                                    Button(Strings.Dub.delete, role: .destructive) {
                                        workspace.deleteSession(session)
                                    }
                                }
                        }
                    } label: {
                        gameRow(.reverse)
                    }
                    .tag(MacDestination.reverse)
                }

                DisclosureGroup(isExpanded: $isDubExpanded) {
                    ForEach(workspace.packs) { pack in
                        packRow(pack)
                            .tag(MacDestination.pack(pack.id))
                            .contextMenu {
                                Button(Strings.Dub.delete, role: .destructive) {
                                    workspace.delete(pack)
                                }
                            }
                    }

                } label: {
                    gameRow(.dub)
                }
                .tag(MacDestination.dubLibrary)
                .dropDestination(for: URL.self) { urls, _ in
                    guard let url = urls.first else { return false }
                    Task { await workspace.importPack(from: url) }
                    return true
                } isTargeted: { isDropTargeted = $0 }

                gameRow(.imitate).tag(MacDestination.imitate)
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
    }

    // MARK: - Rows

    private func gameRow(_ mode: GameMode) -> some View {
        HStack(spacing: 10) {
            Image(mode.image)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)

            Text(mode.title)
                .lineLimit(1)

            Spacer(minLength: 4)

            if home.isLocked(mode) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else if home.isFree(mode) {
                Text(Strings.Main.Mode.free)
                    .font(.system(size: 9, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundColor(.rsGood)
            }
        }
        .padding(.vertical, 2)
    }

    private func packRow(_ pack: DubPack) -> some View {
        let recorded = workspace.dubLibrary.recordedCount(for: pack)

        return HStack(spacing: 9) {
            DubStillImage(url: pack.iconURL)
                .frame(width: 40, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )

            Text(pack.title)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text("\(recorded)/\(pack.lines.count)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 1)
    }

    private func sessionRow(_ session: AudioSession) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "waveform")
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(session.name)
                    .lineLimit(1)
                Text(session.createdAt, format: .dateTime.day().month(.abbreviated).hour().minute())
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if home.showsReviewBanner {
                reviewNote
            }

            if home.areGamesLocked {
                Button {
                    home.showPaywall(from: .trialEndedCard)
                } label: {
                    Label(home.lockedCardTitle, systemImage: "sparkles")
                        .font(.rsCaption)
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            } else if let days = home.trialDaysRemaining {
                TrialBadge(daysRemaining: days) { home.showPaywall(from: .trialBadge) }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reviewNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Strings.ReviewBanner.title)
                .font(.rsCaption)
                .foregroundColor(.rsTextPrimary)

            HStack(spacing: 8) {
                Button(Strings.ReviewBanner.rate) {
                    openURL(home.reviewBannerWentToStore())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(Strings.ReviewBanner.later) {
                    home.dismissReviewBanner()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
        .onAppear { home.reviewBannerDidAppear() }
    }
}
