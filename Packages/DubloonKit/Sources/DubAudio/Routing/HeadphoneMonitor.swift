//
//  HeadphoneMonitor.swift
//  DubAudio
//
//  Whether the original can be fed to the performer while the mic is open
//

#if os(iOS)
import AVFoundation
public import Combine

/// Decides whether the original audio can play to the performer during a take.
///
/// Through the speaker it can't: the reference would land straight in the recording, which is
/// why every record path silences everything first. Through headphones it can, and that is
/// how dubbing is actually done, matching a line you are hearing rather than one you are
/// remembering. The preference exists because some people would rather perform against
/// silence, and because a route can be a headphone-shaped thing that is really a speaker.
@MainActor
public final class HeadphoneMonitor: ObservableObject {

    public static let shared = HeadphoneMonitor()

    private static let enabledKey = "playOriginalInHeadphones"

    /// True while the current output route is something worn on the head.
    @Published public private(set) var isHeadphonesConnected = false

    @Published public var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }

    /// The question every record path actually asks.
    public var shouldPlayOriginalWhileRecording: Bool { isEnabled && isHeadphonesConnected }

    private var routeObserver: (any NSObjectProtocol)?

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
    public func refresh() {
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
#endif

#if os(macOS)
import CoreAudio
public import Combine

/// The Mac's answer to the same question: is the default output something worn on the head?
///
/// A Mac has no audio session to ask. The default output device is read through Core Audio
/// instead. Headphones count if they are Bluetooth or USB, or if they are plugged into the
/// built-in jack, which the built-in device reports as its "headphones" data source.
@MainActor
public final class HeadphoneMonitor: ObservableObject {

    public static let shared = HeadphoneMonitor()

    private static let enabledKey = "playOriginalInHeadphones"

    @Published public private(set) var isHeadphonesConnected = false

    @Published public var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }

    public var shouldPlayOriginalWhileRecording: Bool { isEnabled && isHeadphonesConnected }

    private init() {
        isEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
        isHeadphonesConnected = Self.outputIsHeadphones()

        // The default output changes when headphones connect; the built-in device's data
        // source changes when a plug goes into the jack. Both are watched for the life of
        // the app, so neither listener is ever removed.
        var defaultOutput = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &defaultOutput, .main
        ) { _, _ in
            Task { @MainActor in HeadphoneMonitor.shared.refresh() }
        }
        if let device = Self.defaultOutputDevice() {
            var dataSource = Self.address(kAudioDevicePropertyDataSource, scope: kAudioDevicePropertyScopeOutput)
            AudioObjectAddPropertyListenerBlock(device, &dataSource, .main) { _, _ in
                Task { @MainActor in HeadphoneMonitor.shared.refresh() }
            }
        }
    }

    public func refresh() {
        isHeadphonesConnected = Self.outputIsHeadphones()
    }

    private static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func defaultOutputDevice() -> AudioObjectID? {
        var address = address(kAudioHardwarePropertyDefaultOutputDevice)
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device
        )
        return status == noErr && device != kAudioObjectUnknown ? device : nil
    }

    private static func uint32(_ selector: AudioObjectPropertySelector, of device: AudioObjectID, scope: AudioObjectPropertyScope) -> UInt32? {
        var address = address(selector, scope: scope)
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    private static func outputIsHeadphones() -> Bool {
        guard let device = defaultOutputDevice() else { return false }
        let transport = uint32(kAudioDevicePropertyTransportType, of: device, scope: kAudioObjectPropertyScopeGlobal)
        switch transport {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE, kAudioDeviceTransportTypeUSB:
            return true
        case kAudioDeviceTransportTypeBuiltIn:
            // 'hdpn' is the built-in output's headphone-jack data source.
            return uint32(kAudioDevicePropertyDataSource, of: device, scope: kAudioDevicePropertyScopeOutput) == 0x6864_706E
        default:
            return false
        }
    }
}
#endif
