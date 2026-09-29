import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// An AppBar back arrow that routes through [HybridRouter.pop] — the same
/// back logic native uses — instead of popping GoRouter directly.
///
/// Use it as `AppBar(leading: const HybridBackButton())`.
class HybridBackButton extends ConsumerWidget {
  const HybridBackButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      BackButton(onPressed: () => ref.read(routerProvider).pop());
}
