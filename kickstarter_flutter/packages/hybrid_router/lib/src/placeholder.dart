import 'package:flutter/widgets.dart';

/// A route pushed into the Flutter [Navigator] to *stand in* for an intervening
/// native page in an interleaved stack (`flutterA -> native -> flutterB`).
///
/// It is never meant to be seen: it sits below the currently-active Flutter page
/// and, when a pop lands on it, the [HybridRouter] hands control back to native
/// instead of rendering it. The transparent widget is a safety net for the split
/// second it might otherwise be visible during a transition.
abstract final class NativePlaceholder {
  /// The GoRouter path used for placeholder routes.
  static const path = '/__hybrid_native_placeholder__';

  /// Query key carrying the native path this placeholder represents.
  static const forPathKey = 'native';

  /// Build the placeholder location for the native route [nativePath].
  static String locationFor(String nativePath) =>
      '$path?$forPathKey=${Uri.encodeQueryComponent(nativePath)}';

  /// Whether [location] (a full path, possibly with a query) is a placeholder.
  static bool matches(String location) {
    final q = location.indexOf('?');
    final base = q == -1 ? location : location.substring(0, q);
    return base == path;
  }

  /// The native path a placeholder [location] stands in for, or `null`.
  static String? nativePathOf(String location) =>
      Uri.parse(location).queryParameters[forPathKey];
}

/// The (invisible) widget rendered for a placeholder route.
class NativePlaceholderPage extends StatelessWidget {
  const NativePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
