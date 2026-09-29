//
//  RewindTransition.swift
//  ReverseSinging
//
//  Going back is rewinding the tape: the screen you leave shrinks into a card, tilts away and
//  runs its timecode back to zero while the menu comes up behind it.
//

import SwiftUI

#if os(iOS)
import UIKit

extension View {
    /// Gives the navigation stack this view is the root of the rewind back swipe.
    ///
    /// The swipe starts anywhere on a pushed screen, not just at the edge, and follows the
    /// finger: the screen becomes a card that tilts away with a VHS "REW" badge counting the
    /// time spent on it back to zero. Pushing plays the tape forward, the same card in reverse.
    /// With Reduce Motion on, the system's own swipe and slide come back.
    func rewindNavigationTransition() -> some View {
        background {
            RewindInstaller()
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Installing

/// A view controller with no content, there only to find the `UINavigationController` that
/// SwiftUI's `NavigationStack` is built on.
private struct RewindInstaller: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> RewindInstallerController {
        RewindInstallerController()
    }

    func updateUIViewController(_ controller: RewindInstallerController, context: Context) {
        controller.installIfNeeded()
    }
}

final class RewindInstallerController: UIViewController {
    /// The navigation controller holds its delegate weakly, so this keeps the coordinator alive
    /// for as long as the stack's root is on screen.
    private var coordinator: RewindNavigationCoordinator?

    override func loadView() {
        view = UIView()
        view.isUserInteractionEnabled = false
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        installIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installIfNeeded()
    }

    func installIfNeeded() {
        guard let navigationController else { return }
        coordinator = RewindNavigationCoordinator.attach(to: navigationController, reusing: coordinator)
    }
}

// MARK: - Coordinator

/// Sits in front of SwiftUI's own navigation delegate: it answers for the animations and hands
/// every other delegate call straight through, so the stack's path still hears about each push
/// and pop.
final class RewindNavigationCoordinator: NSObject, UINavigationControllerDelegate, UIGestureRecognizerDelegate {

    /// Past this share of the width, letting go finishes the rewind.
    static let commitProgress: CGFloat = 0.33

    /// The delegate SwiftUI installed. Read from `responds(to:)`, which UIKit only calls on the
    /// main thread.
    nonisolated(unsafe) private weak var forwardee: (any UINavigationControllerDelegate)?

    private weak var navigationController: UINavigationController?
    private let pan = UIPanGestureRecognizer()
    private var interaction: RewindInteraction?
    private var hasPassedCommitPoint = false

    /// When each pushed screen arrived, so the rewind can count the time spent on it back down.
    private var pushedAt: [ObjectIdentifier: Date] = [:]

    static func attach(
        to navigationController: UINavigationController,
        reusing existing: RewindNavigationCoordinator?
    ) -> RewindNavigationCoordinator {
        let coordinator = (navigationController.delegate as? RewindNavigationCoordinator)
            ?? existing ?? RewindNavigationCoordinator()
        if navigationController.delegate !== coordinator {
            coordinator.install(on: navigationController)
        }
        coordinator.stampArrivals()
        return coordinator
    }

    /// Notes when each screen on the stack arrived, so the rewind can count the time spent on
    /// it back down. SwiftUI's push does not ask the delegate for an animation, so this runs
    /// when a screen has finished showing instead.
    private func stampArrivals() {
        guard let stack = navigationController?.viewControllers else { return }
        let ids = Set(stack.map(ObjectIdentifier.init))
        pushedAt = pushedAt.filter { ids.contains($0.key) }
        for id in ids where pushedAt[id] == nil {
            pushedAt[id] = .now
        }
    }

    private func install(on navigationController: UINavigationController) {
        forwardee = navigationController.delegate
        navigationController.delegate = self

        guard self.navigationController !== navigationController else { return }
        self.navigationController = navigationController

        pan.addTarget(self, action: #selector(handlePan(_:)))
        pan.delegate = self
        pan.maximumNumberOfTouches = 1
        navigationController.view.addGestureRecognizer(pan)

        updateSystemGestures()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionDidChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }

    /// One back swipe at a time: ours, or with Reduce Motion the system's.
    private func updateSystemGestures() {
        let usesRewind = !UIAccessibility.isReduceMotionEnabled
        pan.isEnabled = usesRewind
        navigationController?.interactivePopGestureRecognizer?.isEnabled = !usesRewind
        if #available(iOS 26.0, *) {
            navigationController?.interactiveContentPopGestureRecognizer?.isEnabled = !usesRewind
        }
    }

    @objc private func reduceMotionDidChange() {
        updateSystemGestures()
    }

    // MARK: Forwarding

    nonisolated override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || (forwardee?.responds(to: aSelector) ?? false)
    }

    nonisolated override func forwardingTarget(for aSelector: Selector!) -> Any? {
        guard let forwardee, forwardee.responds(to: aSelector) else { return nil }
        return forwardee
    }

    // MARK: Showing

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        forwardee?.navigationController?(navigationController, didShow: viewController, animated: animated)
        stampArrivals()
    }

    // MARK: Animations

    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> (any UIViewControllerAnimatedTransitioning)? {
        // Stamped whoever animates the push, so the rewind knows how long the screen was up.
        var arrived: Date?
        switch operation {
        case .push: pushedAt[ObjectIdentifier(toVC)] = pushedAt[ObjectIdentifier(toVC)] ?? .now
        case .pop: arrived = pushedAt.removeValue(forKey: ObjectIdentifier(fromVC))
        default: break
        }

        // A transition SwiftUI draws itself stays its own: on recent systems that is the push,
        // which it makes interruptible.
        if let theirs = forwardee?.navigationController?(
            navigationController, animationControllerFor: operation, from: fromVC, to: toVC
        ) {
            return theirs
        }
        guard !UIAccessibility.isReduceMotionEnabled else { return nil }

        switch operation {
        case .push:
            return PlayForwardAnimator()
        case .pop:
            let timeOnScreen = arrived.map { Date.now.timeIntervalSince($0) } ?? 0
            interaction?.timeOnScreen = timeOnScreen
            return RewindAnimator(timeOnScreen: timeOnScreen)
        default:
            return nil
        }
    }

    func navigationController(
        _ navigationController: UINavigationController,
        interactionControllerFor animationController: any UIViewControllerAnimatedTransitioning
    ) -> (any UIViewControllerInteractiveTransitioning)? {
        guard animationController is RewindAnimator else {
            return forwardee?.navigationController?(navigationController, interactionControllerFor: animationController)
        }
        return interaction
    }

    // MARK: The swipe

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard let view = pan.view else { return }
        let width = max(view.bounds.width, 1)
        let progress = min(max(pan.translation(in: view).x / width, 0), 1)

        switch pan.state {
        case .began:
            interaction = RewindInteraction()
            hasPassedCommitPoint = false
            navigationController?.popViewController(animated: true)

        case .changed:
            interaction?.update(progress)
            let isPast = progress >= Self.commitProgress
            if isPast != hasPassedCommitPoint {
                hasPassedCommitPoint = isPast
                // One click as the tape catches, the way a deck's transport clunks into rewind.
                if isPast { HapticManager.shared.selection() }
            }

        case .ended, .cancelled, .failed:
            guard let interaction else { return }
            let velocity = pan.velocity(in: view).x / width
            let finishes = pan.state == .ended
                && (velocity > 1.6 || (progress >= Self.commitProgress && velocity > -0.6))
            if finishes {
                interaction.finish(velocity: velocity)
                HapticManager.shared.soft()
            } else {
                interaction.cancel(velocity: velocity)
            }
            self.interaction = nil

        default:
            break
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === pan,
              let navigationController,
              navigationController.viewControllers.count > 1,
              navigationController.transitionCoordinator == nil,
              let view = pan.view else { return false }

        // Rightwards and mostly sideways: a scroll down a list is left alone.
        let velocity = pan.velocity(in: view)
        guard velocity.x > 0, velocity.x > abs(velocity.y) * 1.2 else { return false }

        // A strip that scrolls sideways and still has somewhere to go keeps the swipe.
        return !isInsideLeftScrollableStrip(pan.location(in: view), in: view)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Sliders and switches track the finger themselves; dragging a speed slider right is
        // not asking to leave.
        var view = touch.view
        while let current = view {
            if current is UISlider || current is UISwitch { return false }
            view = current.superview
        }
        return true
    }

    private func isInsideLeftScrollableStrip(_ point: CGPoint, in root: UIView) -> Bool {
        var view = root.hitTest(point, with: nil)
        while let current = view, current !== root {
            if let scroll = current as? UIScrollView,
               scroll.contentSize.width > scroll.bounds.width + 1,
               scroll.contentOffset.x > -scroll.adjustedContentInset.left + 1 {
                return true
            }
            view = current.superview
        }
        return false
    }
}

// MARK: - Rewind (pop)

/// The rewind when the back button asks for it: the whole thing, on the clock.
final class RewindAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    private let timeOnScreen: TimeInterval
    private var scene: RewindScene?

    init(timeOnScreen: TimeInterval) {
        self.timeOnScreen = timeOnScreen
    }

    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        0.6
    }

    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        guard let scene = RewindScene(context: transitionContext, timeOnScreen: timeOnScreen) else {
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            return
        }
        self.scene = scene
        scene.run(to: 1, velocity: 0, duration: transitionDuration(using: transitionContext)) {
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}

/// The rewind under a finger. Every frame is drawn straight from how far the finger has come,
/// so the card's left edge stays under it; letting go springs it the rest of the way, or back.
final class RewindInteraction: NSObject, UIViewControllerInteractiveTransitioning {

    /// Set by the coordinator when it hands out the animator, before the transition starts.
    var timeOnScreen: TimeInterval = 0

    private var context: (any UIViewControllerContextTransitioning)?
    private var scene: RewindScene?
    private var progress: CGFloat = 0
    /// A release that came before UIKit started the transition, kept until it does.
    private var pendingEnd: (finishes: Bool, velocity: CGFloat)?

    var wantsInteractiveStart: Bool { true }

    func startInteractiveTransition(_ transitionContext: any UIViewControllerContextTransitioning) {
        context = transitionContext
        guard let scene = RewindScene(context: transitionContext, timeOnScreen: timeOnScreen) else {
            transitionContext.cancelInteractiveTransition()
            transitionContext.completeTransition(false)
            return
        }
        self.scene = scene
        scene.apply(progress)
        if let pendingEnd {
            end(finishes: pendingEnd.finishes, velocity: pendingEnd.velocity)
        }
    }

    func update(_ progress: CGFloat) {
        self.progress = progress
        scene?.apply(progress)
        context?.updateInteractiveTransition(progress)
    }

    func finish(velocity: CGFloat) { end(finishes: true, velocity: velocity) }

    func cancel(velocity: CGFloat) { end(finishes: false, velocity: velocity) }

    private func end(finishes: Bool, velocity: CGFloat) {
        guard let context, let scene else {
            pendingEnd = (finishes, velocity)
            return
        }
        pendingEnd = nil
        if finishes {
            context.finishInteractiveTransition()
        } else {
            context.cancelInteractiveTransition()
        }
        let distance = max(abs((finishes ? 1 : 0) - progress), 0.05)
        scene.run(to: finishes ? 1 : 0, velocity: velocity / distance, duration: 0.42) {
            context.completeTransition(finishes)
        }
    }
}

/// Everything on stage during a rewind, and where it all sits at a given point in it.
///
/// The screen being left becomes a card: it slides right, shrinks, tilts away and rounds its
/// corners, scan lines roll over it, and a VCR display runs the time spent on it back to zero.
/// The menu comes up underneath out of the dark.
final class RewindScene {

    private let container: UIView
    private let fromView: UIView
    private let toView: UIView
    private let dim = UIView()
    private let shadow: CardShadowView
    private let overlay: RewindOverlayView
    private var current: CGFloat = 0
    private var runner: UIViewPropertyAnimator?
    private var displayLink: CADisplayLink?
    private var runFrom: CGFloat = 0
    private var runTarget: CGFloat = 0

    init?(context: any UIViewControllerContextTransitioning, timeOnScreen: TimeInterval) {
        guard let fromView = context.view(forKey: .from),
              let toView = context.view(forKey: .to),
              let toVC = context.viewController(forKey: .to) else { return nil }
        container = context.containerView
        self.fromView = fromView
        self.toView = toView

        toView.frame = context.finalFrame(for: toVC)
        container.insertSubview(toView, belowSubview: fromView)
        container.backgroundColor = .black

        dim.frame = container.bounds
        dim.backgroundColor = .black
        dim.isUserInteractionEnabled = false
        container.insertSubview(dim, aboveSubview: toView)

        shadow = CardShadowView(frame: fromView.frame)
        container.insertSubview(shadow, belowSubview: fromView)

        overlay = RewindOverlayView(
            frame: fromView.frame,
            topInset: container.safeAreaInsets.top,
            timeOnScreen: timeOnScreen,
            isLight: fromView.traitCollection.userInterfaceStyle == .light
        )
        container.addSubview(overlay)

        fromView.clipsToBounds = true
        fromView.layer.cornerCurve = .continuous

        // The container sorts its layers by depth, and the tilt swings the card's left half
        // behind the flat menu. Lifted well clear of it, the whole card stays in front.
        shadow.layer.zPosition = 300
        fromView.layer.zPosition = 310
        overlay.layer.zPosition = 320
    }

    /// Lays the stage out for `progress`, 0 being the screen as it was and 1 the menu alone.
    func apply(_ progress: CGFloat) {
        current = progress
        let width = container.bounds.width
        let card = RewindCard.transform(width: width, progress: progress)
        let corner = RewindCard.cornerRadius * min(1, progress * 5)
        // The last quarter fades the card as it leaves, so it never pops out of existence.
        let presence = progress < 0.75 ? 1 : max(0, (1 - progress) / 0.25)

        for view in [fromView, shadow, overlay] as [UIView] {
            view.transform3D = card
            view.layer.cornerRadius = corner
        }
        fromView.alpha = 0.45 + 0.55 * presence
        shadow.alpha = min(1, progress * 4) * presence
        overlay.alpha = presence
        overlay.set(progress: progress)

        let menuScale = 0.9 + 0.1 * progress
        toView.transform = CGAffineTransform(scaleX: menuScale, y: menuScale)
        dim.alpha = 0.7 * (1 - progress)
    }

    /// Springs from wherever the stage is to `target`, carrying `velocity` (in stage lengths a
    /// second) into it, then clears up.
    func run(to target: CGFloat, velocity: CGFloat, duration: TimeInterval, completion: @escaping () -> Void) {
        runFrom = current
        runTarget = target
        let animator = UIViewPropertyAnimator(
            duration: duration,
            timingParameters: UISpringTimingParameters(
                dampingRatio: 0.9,
                initialVelocity: CGVector(dx: min(max(velocity, 0), 12), dy: 0)
            )
        )
        // Strong on purpose: the stage keeps itself alive until the tape stops, whoever else
        // lets go of it first. The cycle breaks in `tearDown`.
        animator.addAnimations { self.apply(target) }
        animator.addCompletion { _ in
            self.tearDown()
            completion()
        }
        runner = animator

        // Text does not animate, so the timecode is wound by hand alongside the spring.
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        animator.startAnimation()
    }

    @objc private func tick() {
        guard let runner else { return }
        let progress = runFrom + (runTarget - runFrom) * runner.fractionComplete
        overlay.set(progress: progress, animatesBands: false)
    }

    private func tearDown() {
        displayLink?.invalidate()
        displayLink = nil
        runner = nil
        fromView.transform3D = CATransform3DIdentity
        fromView.layer.cornerRadius = 0
        fromView.layer.zPosition = 0
        fromView.alpha = 1
        fromView.clipsToBounds = false
        toView.transform = .identity
        [dim, shadow, overlay].forEach { $0.removeFromSuperview() }
        container.backgroundColor = nil
    }
}

// MARK: - Play forward (push)

/// The rewind run the other way: the new screen arrives as a card from the right and grows to
/// fill the frame, while the menu sinks back into the dark.
final class PlayForwardAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        0.55
    }

    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        let container = transitionContext.containerView
        guard let fromView = transitionContext.view(forKey: .from),
              let toView = transitionContext.view(forKey: .to),
              let toVC = transitionContext.viewController(forKey: .to) else {
            transitionContext.completeTransition(true)
            return
        }

        let bounds = container.bounds
        container.backgroundColor = .black
        toView.frame = transitionContext.finalFrame(for: toVC)

        let dim = UIView(frame: bounds)
        dim.backgroundColor = .black
        dim.alpha = 0
        container.addSubview(dim)

        let shadow = CardShadowView(frame: toView.frame)
        shadow.alpha = 1
        container.addSubview(shadow)
        container.addSubview(toView)

        let card = RewindCard.transform(width: bounds.width, progress: 0.6)
        toView.clipsToBounds = true
        toView.layer.cornerCurve = .continuous
        toView.layer.cornerRadius = RewindCard.cornerRadius
        toView.transform3D = card
        shadow.transform3D = card
        shadow.layer.cornerRadius = RewindCard.cornerRadius

        let animator = UIViewPropertyAnimator(
            duration: transitionDuration(using: transitionContext),
            timingParameters: UISpringTimingParameters(dampingRatio: 0.9)
        )
        animator.addAnimations {
            toView.transform3D = CATransform3DIdentity
            shadow.transform3D = CATransform3DIdentity
            toView.layer.cornerRadius = 0
            shadow.layer.cornerRadius = 0
            shadow.alpha = 0
            fromView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            dim.alpha = 0.6
        }
        animator.addCompletion { _ in
            fromView.transform = .identity
            toView.transform3D = CATransform3DIdentity
            toView.layer.cornerRadius = 0
            toView.clipsToBounds = false
            [dim, shadow].forEach { $0.removeFromSuperview() }
            container.backgroundColor = nil
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
        animator.startAnimation()
    }
}

// MARK: - The card

private enum RewindCard {
    static let cornerRadius: CGFloat = 38

    /// Where the card sits `progress` of the way out: pushed right, scaled down and swung away
    /// on its vertical axis, its right edge further from the eye than its left. The slide and
    /// the shrink add up so the card's left edge stays under the finger.
    static func transform(width: CGFloat, progress: CGFloat) -> CATransform3D {
        let scale = 1 - 0.2 * progress
        var transform = CATransform3DIdentity
        transform.m34 = -1 / 900
        transform = CATransform3DRotate(transform, -.pi / 11 * progress, 0, 1, 0)
        transform = CATransform3DScale(transform, scale, scale, 1)
        return CATransform3DConcat(transform, CATransform3DMakeTranslation(width * 0.9 * progress, 0, 0))
    }
}

/// A shadow for a card whose own view has to clip its content to round its corners.
private final class CardShadowView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        alpha = 0
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.6
        layer.shadowRadius = 30
        layer.shadowOffset = CGSize(width: -8, height: 16)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
}

// MARK: - The REW overlay

/// Lies over the card with the same geometry: scan lines, three tracking bands that roll down
/// the picture like a tape being wound, and a VCR's on-screen display in the top-left corner,
/// "◀◀ REW" over the timecode, shivering the way a tape's picture does.
private final class RewindOverlayView: UIView {

    private let timeOnScreen: TimeInterval
    private let badge = UIView()
    private let timecode = UILabel()
    private let scanLines = CAReplicatorLayer()
    private var bands: [UIView] = []
    private var bandOrigins: [CGFloat] = []

    private let topInset: CGFloat

    /// Scan lines and tracking bands are drawn in ink on a light screen and in light on a dark
    /// one; either way they have to show against the picture.
    private let isLight: Bool

    init(frame: CGRect, topInset: CGFloat, timeOnScreen: TimeInterval, isLight: Bool) {
        self.timeOnScreen = timeOnScreen
        self.topInset = topInset
        self.isLight = isLight
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        layer.cornerCurve = .continuous

        let line = CALayer()
        line.backgroundColor = (isLight ? UIColor.black.withAlphaComponent(0.07) : UIColor.white.withAlphaComponent(0.06)).cgColor
        line.frame = CGRect(x: 0, y: 0, width: frame.width, height: 1)
        scanLines.addSublayer(line)
        scanLines.instanceCount = Int(frame.height / 3) + 1
        scanLines.instanceTransform = CATransform3DMakeTranslation(0, 3, 0)
        scanLines.frame = bounds
        layer.addSublayer(scanLines)

        for (index, height) in [5.0, 2.0, 9.0].enumerated() {
            let band = UIView(frame: CGRect(x: 0, y: frame.height * (0.2 + 0.25 * CGFloat(index)), width: frame.width, height: height))
            band.backgroundColor = (isLight ? UIColor.black : UIColor.white)
                .withAlphaComponent(index == 1 ? (isLight ? 0.14 : 0.22) : (isLight ? 0.07 : 0.1))
            addSubview(band)
            bands.append(band)
            bandOrigins.append(band.frame.origin.y)
        }

        buildBadge()
        badge.alpha = 0
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func buildBadge() {
        let glyph = UIImageView(image: UIImage(systemName: "backward.fill"))
        glyph.tintColor = .white
        glyph.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24, weight: .heavy)

        let rew = UILabel()
        rew.text = "REW"
        rew.textColor = .white
        rew.font = .monospacedSystemFont(ofSize: 28, weight: .heavy)

        timecode.textColor = .white
        timecode.font = .monospacedDigitSystemFont(ofSize: 20, weight: .bold)
        timecode.text = Self.format(timeOnScreen)

        let top = UIStackView(arrangedSubviews: [glyph, rew])
        top.spacing = 8
        top.alignment = .center
        let stack = UIStackView(arrangedSubviews: [top, timecode])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        // A VCR draws its display straight onto the picture with a hard shadow. Over a light
        // screen that is not enough, so it sits on a smoked plate, the way a deck's display
        // sits behind tinted glass.
        stack.layer.shadowColor = UIColor.black.cgColor
        stack.layer.shadowOpacity = 0.9
        stack.layer.shadowRadius = 0
        stack.layer.shadowOffset = CGSize(width: 2, height: 2)
        badge.backgroundColor = UIColor.black.withAlphaComponent(isLight ? 0.62 : 0.35)
        badge.layer.cornerRadius = 8
        badge.layer.cornerCurve = .continuous
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(stack)
        addSubview(badge)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: badge.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -14),
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            badge.topAnchor.constraint(equalTo: topAnchor, constant: topInset + 84)
        ])
    }

    /// Winds the display to `progress`: the timecode counts the time on screen back to zero and
    /// the tracking bands roll down the picture.
    func set(progress: CGFloat, animatesBands: Bool = true) {
        badge.alpha = min(1, progress * 6)
        timecode.text = Self.format(timeOnScreen * Double(1 - progress))
        // The picture never sits still while a tape winds.
        badge.transform = CGAffineTransform(translationX: .random(in: -1.5...1.5), y: .random(in: -0.5...0.5))
        guard animatesBands else { return }
        for (index, band) in bands.enumerated() {
            band.frame.origin.y = bandOrigins[index] + bounds.height * (0.45 + 0.1 * CGFloat(index)) * progress
        }
    }

    /// Hours, minutes, seconds and frames at 24 fps, the way the app's own transport reads.
    private static func format(_ seconds: TimeInterval) -> String {
        let clamped = max(seconds, 0)
        let whole = Int(clamped)
        let frames = Int((clamped - Double(whole)) * 24)
        return String(format: "%02d:%02d:%02d:%02d", whole / 3600, whole / 60 % 60, whole % 60, frames)
    }
}

#else

extension View {
    /// The Mac's windows have no navigation stack to rewind.
    func rewindNavigationTransition() -> some View { self }
}

#endif
