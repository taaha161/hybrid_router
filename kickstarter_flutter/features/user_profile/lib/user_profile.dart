import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hybrid_router/hybrid_router.dart';

/// GoRoutes contributed by this feature.
List<RouteBase> userProfileRoutes() => [
  GoRoute(
    path: '/backer/:id',
    builder: (context, state) =>
        UserProfilePage(userId: state.pathParameters['id'] ?? '?'),
  ),
];

/// Creator / backer profile — the Flutter analogue of the doc's Yelp "reviewer
/// profile" page (case page 4). Reached from either a Flutter or a native page;
/// the feature neither knows nor cares.
class UserProfilePage extends ConsumerWidget {
  const UserProfilePage({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E9AAA),
        foregroundColor: Colors.white,
        leading: const HybridBackButton(),
        title: Text('@$userId'),
        bottom: const _FlutterBanner(feature: 'user_profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 36)),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '@$userId',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            // Jump to another Flutter project page (Flutter -> Flutter).
            onPressed: () => ref.read(routerProvider).push('/project/77'),
            child: const Text('Open a project by this creator'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => ref.read(routerProvider).pop(),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}

/// Big "this is Flutter" strip under the AppBar, so a screen recording shows
/// which side of the seam each screen lives on.
class _FlutterBanner extends StatelessWidget implements PreferredSizeWidget {
  const _FlutterBanner({required this.feature});
  final String feature;

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    color: const Color(0xFF0B6E79),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        const FlutterLogo(size: 20),
        const SizedBox(width: 10),
        const Text(
          'FLUTTER SCREEN',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const Spacer(),
        Text(
          feature,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );
}
