import 'package:flutter/services.dart';

/// Method names exchanged over the navigation channel. Kept as constants so the
/// Dart and Swift sides stay in lockstep (mirror these in `NavigationChannelHandler`).
abstract final class NavMethods {
  // Flutter -> Native
  static const pushNative = 'pushNative';
  static const popNative = 'popNative';
  static const showNative = 'showNative';
  static const popToRoot = 'popToRoot';

  // Native -> Flutter
  static const pushFlutter = 'pushFlutter';
  static const popFlutter = 'popFlutter';
  static const didPopNative = 'didPopNative';
}

/// Callbacks the [HybridRouter] registers to react to navigation the **native**
/// side originated (e.g. a nav-bar back button or an iOS edge-swipe).
class NativeNavigationCallbacks {
  const NativeNavigationCallbacks({
    required this.onPushFlutter,
    required this.onPopFlutter,
    required this.onDidPopNative,
  });

  /// Native asked to show a Flutter route (e.g. tapping a Flutter cell in a
  /// native list).
  final void Function(String path, Object? args) onPushFlutter;

  /// Native asked Flutter to pop its top route.
  final void Function() onPopFlutter;

  /// The user popped a native page (back button / edge-swipe). The router uses
  /// this to keep the Flutter/GoRouter stack in sync with the native one.
  final void Function(String path) onDidPopNative;
}

/// Thin wrapper over the `com.hybridrouter/navigation` [MethodChannel].
///
/// Flutter -> Native calls are plain method invocations. Native -> Flutter calls
/// arrive as incoming method calls and are fanned out to [NativeNavigationCallbacks].
///
/// This is intentionally hand-written for the talk; a pigeon-generated bridge is
/// a drop-in replacement (see the plan's open questions).
class NativeNavigatorChannel {
  NativeNavigatorChannel({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.hybridrouter/navigation';

  final MethodChannel _channel;

  /// Wire incoming native-originated navigation to [callbacks].
  void bind(NativeNavigationCallbacks callbacks) {
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments;
      switch (call.method) {
        case NavMethods.pushFlutter:
          callbacks.onPushFlutter(
            _pathOf(args),
            (args is Map) ? args['args'] : null,
          );
        case NavMethods.popFlutter:
          callbacks.onPopFlutter();
        case NavMethods.didPopNative:
          callbacks.onDidPopNative(_pathOf(args));
        default:
          throw MissingPluginException(
            'Unhandled native->flutter method: ${call.method}',
          );
      }
      return null;
    });
  }

  /// Ask native to push the UIKit view controller registered for [path].
  Future<void> pushNative(String path, Object? args) =>
      _channel.invokeMethod<void>(NavMethods.pushNative, {
        'path': path,
        'args': args,
      });

  /// Ask native to pop its current top view controller.
  Future<void> popNative() => _channel.invokeMethod<void>(NavMethods.popNative);

  /// Ask native to bring the (already-existing) native page for [path] back to
  /// the front. Used when a Flutter pop lands on a placeholder that stands in
  /// for an intervening native page.
  Future<void> showNative(String path) =>
      _channel.invokeMethod<void>(NavMethods.showNative, {'path': path});

  /// Ask native to unwind its navigation stack to the root.
  Future<void> popToRoot() =>
      _channel.invokeMethod<void>(NavMethods.popToRoot);

  static String _pathOf(Object? args) {
    if (args is String) return args;
    if (args is Map && args['path'] is String) return args['path'] as String;
    throw ArgumentError('Navigation call missing a "path": $args');
  }
}
