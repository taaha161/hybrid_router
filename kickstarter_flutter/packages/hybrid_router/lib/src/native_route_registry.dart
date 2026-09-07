import 'package:meta/meta.dart';

/// The set of route paths that are implemented on the **native** (iOS) side.
///
/// The registry is owned by the host app (`apps/kickstarter_app`) and injected
/// into the [HybridRouter]. Feature packages never see it: they call the router
/// with plain paths and the router decides, per path, whether the destination is
/// a Flutter route (driven by GoRouter) or a native route (driven over the
/// method channel).
///
/// Matching supports exact paths and a single trailing `*` wildcard so a family
/// of native routes can be declared in one entry, e.g. `/reward/*`.
@immutable
class NativeRouteRegistry {
  const NativeRouteRegistry(this._patterns);

  /// Convenience for the common case of a literal list of native paths.
  factory NativeRouteRegistry.of(Iterable<String> paths) =>
      NativeRouteRegistry(paths.toSet());

  final Set<String> _patterns;

  /// All registered native route patterns.
  Set<String> get patterns => Set.unmodifiable(_patterns);

  /// Whether [path] resolves to a natively-implemented page.
  ///
  /// The query string is ignored for matching; only the path portion counts.
  bool isNative(String path) {
    final normalized = _stripQuery(path);
    for (final pattern in _patterns) {
      if (_matches(pattern, normalized)) return true;
    }
    return false;
  }

  bool _matches(String pattern, String path) {
    if (pattern == path) return true;
    if (pattern.endsWith('/*')) {
      final prefix = pattern.substring(0, pattern.length - 1); // keep trailing '/'
      return path.startsWith(prefix);
    }
    return false;
  }

  static String _stripQuery(String path) {
    final q = path.indexOf('?');
    return q == -1 ? path : path.substring(0, q);
  }
}
