//
//  HeadphoneMonitor.swift
//  ReverseSinging
//
//  Whether the original can be fed to the performer while the mic is open
//

import AVFoundation
import Combine

/// Decides whether the original audio can play to the performer during a take.
///
/// Through the speaker it can't: the reference would land straight in the recording, which is
/// why every record path silences everything first. Through headphones it can, and that is
/// how dubbing is actually done, matching a line you are hearing rather than one you are
/// remembering. The preference exists because some people would rather perform against
/// silence, and because a route can be a headphone-shaped thing that is really a speaker.
@MainActor
final class HeadphoneMonitor: ObservableObject {

    static let shared = HeadphoneMonitor()

    private static let enabledKey = "playOriginalInHeadphones"

    /// True while the current output route is something worn on the head.
    @Published private(set) var isHeadphonesConnected = false

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }

    /// The question every record path actually asks.
    var shouldPlayOriginalWhileRecording: Bool { isEnabled && isHeadphonesConnected }

    private var routeObserver: NSObjectProtocol?

    private init() {
        isEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
        isHeadphonesConnected = Self.routeHasHeadphones()

        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Delivered on the main queue but not typed as isolated, and the refresh has to
            // land before the next take is armed rather than a hop later.
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    /// Re-reads the route. Called on every route change, and again just before a take is
    /// armed. The session may have been activated or reconfigured since the last one.
    func refresh() {
        isHeadphonesConnected = Self.routeHasHeadphones()
    }

    private static func routeHasHeadphones() -> Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs.contains { output in
            switch output.portType {
            case .headphones,          // wired, including the USB-C EarPods
                 .bluetoothA2DP,       // AirPods and most bluetooth headphones
                 .bluetoothLE,
                 .bluetoothHFP,        // the low-quality call route bluetooth mics fall back to
                 .usbAudio:
                return true
            default:
                return false
            }
        }
    }
}
