import 'package:flutter/widgets.dart';

import 'flutter_navigation.dart';
import 'native_navigator_channel.dart';
import 'native_route_registry.dart';
import 'placeholder.dart';

/// One entry in the router's logical, cross-boundary visual stack.
@immutable
sealed class HybridStackEntry {
  const HybridStackEntry(this.path);
  final String path;
}

/// A Flutter page currently in the single FlutterViewController's GoRouter stack.
final class FlutterEntry extends HybridStackEntry {
  const FlutterEntry(super.path);
  @override
  String toString() => 'Flutter($path)';
}

/// A native (UIKit) page currently in the host UINavigationController.
final class NativeEntry extends HybridStackEntry {
  const NativeEntry(super.path);
  @override
  String toString() => 'Native($path)';
}

/// A GoRouter-mirroring navigation facade that spans the iOS<->Flutter boundary
/// using a **single Flutter engine and a single FlutterViewController**.
///
/// Feature code calls [push]/[pop]/[go]/[pushReplacement] exactly as it would
/// with GoRouter. The router looks each path up in the [NativeRouteRegistry]:
///
///  * native match  -> a method-channel call drives the native navigation stack;
///  * otherwise      -> the call is delegated to GoRouter inside the one engine.
///
/// Because every Flutter page lives in the *same* GoRouter stack, a native page
/// pushed between two Flutter pages (`flutterA -> native -> flutterB`) is
/// represented in the Flutter stack by an invisible [NativePlaceholder]. When a
/// pop lands on that placeholder the router hands control back to native instead
/// of skipping the native page — keeping one consistent logical back-stack.
///
/// See the plan (`docs/hybrid-router-plan.md`) for the full rationale.
class HybridRouter {
  HybridRouter({
    required FlutterNavigation flutter,
    required NativeNavigatorChannel channel,
    required NativeRouteRegistry registry,
    String initialFlutterPath = '/',
  })  : _flutter = flutter,
        _channel = channel,
        _registry = registry,
        _initialFlutterPath = initialFlutterPath {
    _stack.add(FlutterEntry(initialFlutterPath));
    _flutterNav.add(initialFlutterPath);
    _channel.bind(
      NativeNavigationCallbacks(
        onPushFlutter: (path, args, reset) =>
            reset ? enterFlutter(path, extra: args) : push(path, extra: args),
        onPopFlutter: pop,
        onDidPopNative: _onDidPopNative,
      ),
    );
  }

  final FlutterNavigation _flutter;
  final NativeNavigatorChannel _channel;
  final NativeRouteRegistry _registry;

  /// The GoRouter base route. When the Flutter navigator unwinds back to just
  /// this, the current Flutter segment is done and the container is closed.
  final String _initialFlutterPath;

  /// Count of Flutter-navigator pops the router itself initiated (via [pop] or
  /// [_onDidPopNative]). The [HybridPopObserver] uses this to tell a pop the
  /// router already reconciled from a *user gesture* (AppBar back / iOS
  /// swipe-back) that bypassed [pop] entirely.
  int _programmaticPops = 0;

  /// Visual, cross-boundary stack (bottom -> top). Native holds the authoritative
  /// copy; this mirror is what the router reasons about locally.
  final List<HybridStackEntry> _stack = [];

  /// Paths currently living in the Flutter Navigator (incl. placeholders),
  /// mirroring every [FlutterNavigation] call so tests can assert it.
  final List<String> _flutterNav = [];

  /// Snapshot of the logical stack (bottom -> top), for tests and diagnostics.
  List<HybridStackEntry> get stack => List.unmodifiable(_stack);

  /// Snapshot of the Flutter Navigator contents (incl. placeholders).
  List<String> get flutterNavStack => List.unmodifiable(_flutterNav);

  HybridStackEntry? get _top => _stack.isEmpty ? null : _stack.last;

  /// When true, boundary crossings are logged with a `[hybrid]` tag so the demo
  /// journey can be traced in the device log alongside the native side.
  bool logEnabled = true;

  void _log(String action) {
    if (!logEnabled) return;
    final stack = _stack.map((e) => e.toString()).join(' > ');
    debugPrint('[hybrid] dart $action  ::  $stack');
  }

  /// Push [path] onto the stack. Mirrors `GoRouter.push`.
  void push(String path, {Object? extra}) {
    if (_registry.isNative(path)) {
      _channel.pushNative(path, extra);
      _stack.add(NativeEntry(path));
      _log('push native $path');
      return;
    }
    // Flutter target. If we're currently sitting on a native page, insert a
    // placeholder so a later pop returns to that native page, not past it.
    final top = _top;
    if (top is NativeEntry) {
      final location = NativePlaceholder.locationFor(top.path);
      _flutter.push(location);
      _flutterNav.add(location);
      _log('inserted placeholder for ${top.path}');
    }
    _flutter.push(path, extra: extra);
    _flutterNav.add(path);
    _stack.add(FlutterEntry(path));
    _log('push flutter $path');
  }

  /// Open a **fresh** Flutter journey from a native root (e.g. a feed row tap).
  ///
  /// Discards any stale Flutter history first so re-entering Flutter never
  /// stacks duplicates on top of a previous, abandoned journey. The base route
  /// is kept beneath so a later back at [path] closes the container cleanly.
  void enterFlutter(String path, {Object? extra}) {
    if (_registry.isNative(path)) {
      // Defensive: a native path can't be a fresh Flutter entry; fall back.
      push(path, extra: extra);
      return;
    }
    _flutter.go(_initialFlutterPath);
    _flutterNav
      ..clear()
      ..add(_initialFlutterPath);
    _stack
      ..clear()
      ..add(FlutterEntry(_initialFlutterPath));
    _log('enterFlutter reset -> base');
    push(path, extra: extra);
  }

  /// Replace the current top with [path]. Mirrors `GoRouter.pushReplacement`.
  ///
  /// Only meaningful when the top is a Flutter page; a native top is replaced by
  /// popping it and pushing the new destination.
  void pushReplacement(String path, {Object? extra}) {
    if (_top is FlutterEntry && !_registry.isNative(path)) {
      _flutter.pushReplacement(path, extra: extra);
      _flutterNav
        ..removeLast()
        ..add(path);
      _stack
        ..removeLast()
        ..add(FlutterEntry(path));
      return;
    }
    pop();
    push(path, extra: extra);
  }

  /// Reset to [path] as the sole Flutter destination. Mirrors `GoRouter.go`.
  ///
  /// Used for tab switches / deep links where prior history is discarded.
  void go(String path, {Object? extra}) {
    if (_registry.isNative(path)) {
      _channel.popToRoot();
      _channel.pushNative(path, extra);
      _stack
        ..clear()
        ..add(NativeEntry(path));
      // The Flutter navigator is left showing whatever it had; it is covered.
      return;
    }
    _flutter.go(path, extra: extra);
    _flutterNav
      ..clear()
      ..add(path);
    _stack
      ..clear()
      ..add(FlutterEntry(path));
  }

  /// Pop the current top. Mirrors `GoRouter.pop`.
  void pop([Object? result]) {
    final top = _top;
    if (top == null) return;

    if (top is NativeEntry) {
      _channel.popNative();
      _stack.removeLast();
      _log('pop native ${top.path}');
      return;
    }

    // top is a Flutter page: pop it from the Flutter navigator, then reconcile.
    // The pop triggers the observer, but we mark it programmatic so the observer
    // doesn't reconcile a second time (see [handleFlutterNavigatorPop]).
    _popFlutterNavigator(result);
    _reconcileFlutterPop();
  }

  /// Pop the Flutter navigator ourselves, tagging it so the observer callback
  /// treats the resulting signal as already-reconciled.
  void _popFlutterNavigator([Object? result]) {
    _programmaticPops++;
    _flutter.pop(result);
  }

  /// Called by [HybridPopObserver] on **every** Flutter Navigator pop, whatever
  /// triggered it. If the router initiated the pop it's already reconciled —
  /// consume the signal. Otherwise it was a user gesture (Material AppBar back
  /// button, iOS edge-swipe, Android system back) that bypassed [pop]; reconcile
  /// now so the logical stack and the native side stay in lockstep.
  void handleFlutterNavigatorPop() {
    if (_programmaticPops > 0) {
      _programmaticPops--;
      return;
    }
    _log('flutter gesture back');
    _reconcileFlutterPop();
  }

  /// Bring the logical + native stacks back in line after one Flutter page has
  /// left the Flutter navigator.
  void _reconcileFlutterPop() {
    if (_flutterNav.isEmpty) return;
    _flutterNav.removeLast();
    if (_stack.isNotEmpty && _stack.last is FlutterEntry) _stack.removeLast();

    // Uncovered an intervening native page? Its placeholder is now on top: hand
    // control back to native (the placeholder stays until didPopNative).
    final newTop = _top;
    if (newTop is NativeEntry &&
        _flutterNav.isNotEmpty &&
        NativePlaceholder.matches(_flutterNav.last)) {
      _channel.showNative(newTop.path);
      _log('pop flutter -> showNative ${newTop.path}');
      return;
    }

    // Flutter segment exhausted (only the base route remains): the whole Flutter
    // container must leave the native stack, revealing the native page beneath.
    if (_isAtFlutterRoot) {
      _channel.closeFlutter();
      _log('pop flutter -> closeFlutter (container closed)');
      return;
    }
    _log('pop flutter');
  }

  /// True when the Flutter navigator holds nothing but its base route.
  bool get _isAtFlutterRoot =>
      _flutterNav.length == 1 && _flutterNav.single == _initialFlutterPath;

  /// Handle a native-originated back (nav-bar back button / iOS edge-swipe) so
  /// the Flutter stack stays in lockstep with the native one.
  void _onDidPopNative(String path) {
    final top = _top;
    if (top is! NativeEntry) return; // out of sync guard; ignore stray signals.
    _stack.removeLast();

    // Drop the placeholder that stood in for this native page, if present. The
    // observer removes it from _flutterNav (marked programmatic).
    if (_flutterNav.isNotEmpty &&
        NativePlaceholder.matches(_flutterNav.last)) {
      _popFlutterNavigator();
      _flutterNav.removeLast();
    }
    _log('didPopNative $path');
    // Native has already removed its VC; the FlutterViewController comes forward
    // showing the Flutter page now on top (if any).
  }
}

/// A [NavigatorObserver] that reports every Flutter Navigator pop to a
/// [HybridRouter], so that Flutter's *own* back affordances — the Material
/// AppBar back button, the iOS edge-swipe, the Android system back — flow
/// through the same reconciliation path as a programmatic [HybridRouter.pop].
///
/// Attach it to the app's single GoRouter (`GoRouter(observers: [observer])`)
/// and wire [onFlutterPop] to [HybridRouter.handleFlutterNavigatorPop].
class HybridPopObserver extends NavigatorObserver {
  /// Invoked after any route is popped from the observed navigator.
  void Function()? onFlutterPop;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    onFlutterPop?.call();
  }
}
