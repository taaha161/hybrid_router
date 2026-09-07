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
      appBar: AppBar(title: Text('@$userId')),
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
          const SizedBox(height: 4),
          const Center(child: Text('FLUTTER · user_profile')),
          const SizedBox(height: 24),
          FilledButton(
            // Jump to another Flutter project page (Flutter -> Flutter).
            onPressed: () => ref.hybridPush('/project/77'),
            child: const Text('Open a project by this creator'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => ref.hybridPop(),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}
