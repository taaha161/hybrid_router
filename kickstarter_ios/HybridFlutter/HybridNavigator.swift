import Flutter
import UIKit

/// Drives the host `UINavigationController` in response to the navigation
/// channel, and reports native-originated pops back to Flutter.
///
/// ## The single-FlutterViewController model
///
/// There is exactly one `FlutterViewController` (`flutterVC`) bound to the one
/// engine. It hosts *every* Flutter page via GoRouter. Native pages are ordinary
/// `UIViewController`s. Because `flutterVC` is a single instance, an interleaved
/// stack (`flutterA → native → flutterB`) is handled by **reordering** who sits
/// on top, not by creating a second Flutter view:
///
/// ```
/// push /project (flutter)   nav = [discovery, flutterVC(A)]
/// push /reward  (native)    nav = [discovery, flutterVC(A), rewardVC]
/// push /backer  (flutter)   Dart inserts a placeholder + shows B in GoRouter;
///                           native reorders -> [discovery, rewardVC, flutterVC(B)]
/// pop  (from B)             Dart pops B -> lands on placeholder -> showNative:
///                           native reorders -> [discovery, flutterVC, rewardVC]
/// pop  (from rewardVC)      native back -> didPopNative -> Dart pops placeholder
///                           -> flutterVC shows A -> [discovery, flutterVC(A)]
/// ```
final class HybridNavigator: NSObject {
    private unowned let navigationController: UINavigationController
    private let flutterVC: FlutterViewController
    private let channel: NavigationChannel
    private let routeFactory: NativeRouteFactory

    /// Native pages currently live, oldest → newest.
    private var nativeStack: [(path: String, vc: UIViewController)] = []

    /// Number of pending `didShow` callbacks that come from *our own*
    /// programmatic stack mutations (reorders, programmatic pops). Each such
    /// mutation changes the top VC and therefore yields exactly one `didShow`.
    /// The delegate consumes one per callback and skips back-detection for it,
    /// so only a *genuine* user back (nav-bar back button / edge-swipe) — which
    /// we never initiate — is reported to Flutter as `didPopNative`.
    private var pendingProgrammaticTransitions = 0

    /// Run a stack mutation that will trigger one `didShow` we must not mistake
    /// for a user-initiated back.
    private func programmatic(_ mutate: () -> Void) {
        pendingProgrammaticTransitions += 1
        mutate()
    }

    init(
        navigationController: UINavigationController,
        flutterVC: FlutterViewController,
        channel: NavigationChannel,
        routeFactory: NativeRouteFactory = .init()
    ) {
        self.navigationController = navigationController
        self.flutterVC = flutterVC
        self.channel = channel
        self.routeFactory = routeFactory
        super.init()
        channel.navigator = self
        navigationController.delegate = self
    }

    // MARK: Flutter -> Native

    /// Push a native page for `path` on top of the current stack.
    func pushNative(path: String, args: Any?) {
        NSLog("[hybrid] ios pushNative %@", path)
        guard let vc = routeFactory.makeViewController(path: path, args: args) else { return }
        vc.hybridPath = path
        // Let a demo native page trigger a native -> Flutter push (interleaving).
        (vc as? DemoNativePageViewController)?.onOpenFlutter = { [weak self] target in
            self?.showFlutter(path: target)
        }
        nativeStack.append((path, vc))
        navigationController.pushViewController(vc, animated: true)
    }

    /// Pop the top native page (programmatic Flutter-initiated pop).
    func popNative() {
        guard nativeStack.last != nil else { return }
        nativeStack.removeLast()
        programmatic { navigationController.popViewController(animated: true) }
    }

    /// Bring the (already-existing) native page for `path` back to the front,
    /// stepping `flutterVC` behind it. Used when a Flutter pop lands on a
    /// placeholder standing in for this native page.
    func showNative(path: String) {
        NSLog("[hybrid] ios showNative %@ (reparent flutterVC behind native)", path)
        guard let target = nativeStack.last(where: { $0.path == path })?.vc else { return }
        var vcs = navigationController.viewControllers
        // Move flutterVC directly beneath the target native page.
        vcs.removeAll { $0 === flutterVC || $0 === target }
        vcs.append(flutterVC)
        vcs.append(target)
        programmatic { navigationController.setViewControllers(vcs, animated: true) }
    }

    func popToRoot() {
        nativeStack.removeAll()
        programmatic { navigationController.popToRootViewController(animated: true) }
    }

    /// The Flutter/GoRouter stack unwound to its base route: remove the single
    /// `flutterVC` from the host stack so the native page beneath (e.g. the
    /// Hybrid Feed) comes back. Only acts when `flutterVC` is actually frontmost,
    /// so a stray signal can't pop an unrelated native page.
    func closeFlutter() {
        NSLog("[hybrid] ios closeFlutter (pop flutterVC container)")
        guard navigationController.topViewController === flutterVC else { return }
        programmatic { navigationController.popViewController(animated: true) }
    }

    /// Show a Flutter route: ensure `flutterVC` is frontmost, then let GoRouter
    /// (via the channel) navigate. If a native page is currently on top, reorder
    /// so `flutterVC` sits above it (the interleaved case).
    func showFlutter(path: String, args: Any? = nil) {
        // Fresh entry (flutterVC not yet in the stack, e.g. a feed row tap) vs an
        // interleaved push (flutterVC already embedded behind a native page). A
        // fresh entry resets the Flutter stack so stale history can't pile up.
        let alreadyEmbedded = navigationController.viewControllers.contains { $0 === flutterVC }
        NSLog("[hybrid] ios showFlutter %@ (reset=%@)", path, alreadyEmbedded ? "false" : "true")
        if navigationController.topViewController !== flutterVC {
            var vcs = navigationController.viewControllers
            if alreadyEmbedded {
                vcs.removeAll { $0 === flutterVC }
                vcs.append(flutterVC)
                programmatic { navigationController.setViewControllers(vcs, animated: true) }
            } else {
                programmatic { navigationController.pushViewController(flutterVC, animated: true) }
            }
        }
        channel.pushFlutter(path: path, args: args, reset: !alreadyEmbedded)
    }
}

// MARK: - Native-originated back detection

extension HybridNavigator: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        // Skip callbacks caused by our own reorders/programmatic pops — otherwise
        // a reparent's animated `didShow` looks like a native back and wrongly
        // evicts a tracked page from `nativeStack` (which then breaks `showNative`).
        if pendingProgrammaticTransitions > 0 {
            pendingProgrammaticTransitions -= 1
            return
        }
        // A native page that we tracked is no longer in the stack => the user
        // popped it (back button / edge-swipe). Tell Flutter so GoRouter syncs.
        let liveVCs = Set(navigationController.viewControllers.map { ObjectIdentifier($0) })
        for entry in nativeStack.reversed() where !liveVCs.contains(ObjectIdentifier(entry.vc)) {
            nativeStack.removeAll { $0.vc === entry.vc }
            NSLog("[hybrid] ios native back -> didPopNative %@", entry.path)
            channel.didPopNative(path: entry.path)
        }
    }
}

private var kHybridPathKey: UInt8 = 0

extension UIViewController {
    /// The hybrid route path this native VC represents (for diagnostics).
    var hybridPath: String? {
        get { objc_getAssociatedObject(self, &kHybridPathKey) as? String }
        set { objc_setAssociatedObject(self, &kHybridPathKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
