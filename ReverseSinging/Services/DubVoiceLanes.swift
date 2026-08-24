//
//  DubVoiceLanes.swift
//  ReverseSinging
//
//  Splitting a scene's lines so overlapping dialogue can be heard at once
//

import Foundation

/// Groups a scene's lines into lanes, so lines that overlap in time end up in different ones.
///
/// An `AVAudioPlayerNode` renders one buffer at a time. It honours the start time of every
/// buffer scheduled on it, so overlapping lines are not pushed late — but where two of them
/// cover the same stretch, only one is heard. Measured offline: two 0.4-amplitude tones
/// overlapping on one node peak at 0.28 through the overlap, exactly as they do on their own,
/// where the same pair across two nodes peaks at 0.57. Half the interruption goes missing and
/// nothing reports it.
///
/// One node per lane is what actually sums them. Used by both the export mixer and the in-app
/// scene player, so what you hear while playing back is what lands in the file.
nonisolated enum DubVoiceLanes {

    /// The most voices mixed at once.
    ///
    /// Real dialogue rarely stacks more than two or three deep. The cap is there for a
    /// malformed pack that puts every line at the same timestamp, which would otherwise ask
    /// the engine for one node per line.
    static let maximumLanes = 8

    /// Assigns each item to the first lane free at its start time.
    ///
    /// - Parameters:
    ///   - start: when the item begins on the scene's timeline.
    ///   - end: when it finishes. Taken from the audio rather than the line's nominal length,
    ///     so a take recorded before takes were length-matched is still given the room it needs.
    /// - Returns: lanes, each holding its items in start order. Empty in, empty out.
    static func assign<Item>(
        _ items: [Item],
        start: (Item) -> TimeInterval,
        end: (Item) -> TimeInterval
    ) -> [[Item]] {
        var lanes: [[Item]] = []
        var laneEnds: [TimeInterval] = []

        for item in items.sorted(by: { start($0) < start($1) }) {
            let itemStart = start(item)
            let itemEnd = end(item)

            if let free = laneEnds.firstIndex(where: { $0 <= itemStart }) {
                lanes[free].append(item)
                laneEnds[free] = max(laneEnds[free], itemEnd)
            } else if lanes.count < maximumLanes {
                lanes.append([item])
                laneEnds.append(itemEnd)
            } else if let soonest = laneEnds.indices.min(by: { laneEnds[$0] < laneEnds[$1] }) {
                // Past the cap, pile onto whichever lane frees up first. Those two lose their
                // overlap to each other — the old behaviour — which beats an engine that will
                // not start.
                lanes[soonest].append(item)
                laneEnds[soonest] = max(laneEnds[soonest], itemEnd)
            }
        }

        return lanes
    }
}
