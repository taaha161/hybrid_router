import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A bare marker route that means "a native screen sits here".
///
/// When native opens a Flutter page we push one of these first, so GoRouter's
/// own stack records every native boundary. It never needs to know *which*
/// native screen it stands for: when a back lands on it, we just hand control
/// back to native with `returnToNative()`.
abstract final class NativePlaceholder {
  /// The GoRouter path used for placeholder routes.
  static const path = '/__native_placeholder__';
}

/// The location to push for a placeholder.
String placeholder() => NativePlaceholder.path;

/// Whether [location] (a path, possibly with a query) is a placeholder.
bool isPlaceholder(String location) =>
    Uri.parse(location).path == NativePlaceholder.path;

/// The GoRoute the host app registers so placeholders can be pushed.
GoRoute nativePlaceholderRoute() => GoRoute(
  path: NativePlaceholder.path,
  builder: (context, state) => const NativePlaceholderPage(),
);

/// A placeholder renders nothing — native covers it before it is ever seen.
class NativePlaceholderPage extends StatelessWidget {
  const NativePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
