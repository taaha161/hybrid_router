import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hybrid_router.dart';

/// Exposes the app-wide [HybridRouter].
///
/// The host app (`apps/kickstarter_app`) builds the concrete router (GoRouter +
/// native registry + channel) and overrides this provider at the root:
///
/// ```dart
/// ProviderScope(
///   overrides: [hybridRouterProvider.overrideWithValue(router)],
///   child: const KickstarterFlutterApp(),
/// )
/// ```
///
/// Feature packages only ever read it, never construct it.
final hybridRouterProvider = Provider<HybridRouter>(
  (ref) => throw UnimplementedError(
    'hybridRouterProvider must be overridden at the app root with the '
    'app-configured HybridRouter.',
  ),
);

/// Ergonomic navigation from a widget, mirroring go_router's context extensions.
extension HybridNavigationX on WidgetRef {
  HybridRouter get hybridRouter => read(hybridRouterProvider);

  void hybridPush(String path, {Object? extra}) =>
      hybridRouter.push(path, extra: extra);

  void hybridGo(String path, {Object? extra}) =>
      hybridRouter.go(path, extra: extra);

  void hybridPop([Object? result]) => hybridRouter.pop(result);
}
