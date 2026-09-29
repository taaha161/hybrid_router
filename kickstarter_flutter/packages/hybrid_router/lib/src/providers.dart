import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hybrid_router.dart';

/// The app-wide [HybridRouter]. The host app builds it and overrides this
/// provider at the root; feature packages only ever read it:
///
/// ```dart
/// ref.read(routerProvider).push('/reward/42');
/// ```
final routerProvider = Provider<HybridRouter>(
  (ref) => throw UnimplementedError(
    'routerProvider must be overridden at the app root with the '
    'app-configured HybridRouter.',
  ),
);
