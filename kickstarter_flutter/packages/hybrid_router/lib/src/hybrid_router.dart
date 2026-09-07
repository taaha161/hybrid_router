import 'package:flutter/foundation.dart';

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
        _registry = registry {
    _stack.add(FlutterEntry(initialFlutterPath));
    _flutterNav.add(initialFlutterPath);
    _channel.bind(
      NativeNavigationCallbacks(
        onPushFlutter: (path, args) => push(path, extra: args),
        onPopFlutter: pop,
        onDidPopNative: _onDidPopNative,
      ),
    );
  }

  final FlutterNavigation _flutter;
  final NativeNavigatorChannel _channel;
  final NativeRouteRegistry _registry;

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

  /// Push [path] onto the stack. Mirrors `GoRouter.push`.
  void push(String path, {Object? extra}) {
    if (_registry.isNative(path)) {
      _channel.pushNative(path, extra);
      _stack.add(NativeEntry(path));
      return;
    }
    // Flutter target. If we're currently sitting on a native page, insert a
    // placeholder so a later pop returns to that native page, not past it.
    final top = _top;
    if (top is NativeEntry) {
      final location = NativePlaceholder.locationFor(top.path);
      _flutter.push(location);
      _flutterNav.add(location);
    }
    _flutter.push(path, extra: extra);
    _flutterNav.add(path);
    _stack.add(FlutterEntry(path));
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
      return;
    }

    // top is a Flutter page: pop it from the Flutter navigator.
    _flutter.pop(result);
    _flutterNav.removeLast();
    _stack.removeLast();

    // If we've now uncovered a native page, the Flutter navigator's new top is a
    // placeholder. Hand control back to native (leave the placeholder in place;
    // it is removed when native reports didPopNative).
    final newTop = _top;
    if (newTop is NativeEntry &&
        _flutterNav.isNotEmpty &&
        NativePlaceholder.matches(_flutterNav.last)) {
      _channel.showNative(newTop.path);
    }
  }

  /// Handle a native-originated back (nav-bar back button / iOS edge-swipe) so
  /// the Flutter stack stays in lockstep with the native one.
  void _onDidPopNative(String path) {
    final top = _top;
    if (top is! NativeEntry) return; // out of sync guard; ignore stray signals.
    _stack.removeLast();

    // Drop the placeholder that stood in for this native page, if present.
    if (_flutterNav.isNotEmpty &&
        NativePlaceholder.matches(_flutterNav.last)) {
      _flutter.pop();
      _flutterNav.removeLast();
    }
    // Native has already removed its VC; the FlutterViewController comes forward
    // showing the Flutter page now on top (if any).
  }
}
