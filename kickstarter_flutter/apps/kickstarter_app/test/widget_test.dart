import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hybrid_router/hybrid_router.dart';
import 'package:kickstarter_app/main.dart';

void main() {
  test('GoRouter wires the placeholder and feature routes', () {
    final router = buildGoRouter();
    final paths = router.configuration.routes
        .whereType<GoRoute>()
        .map((r) => r.path)
        .toList();

    expect(paths, contains('/'));
    expect(paths, contains(NativePlaceholder.path));
    expect(paths, contains('/project/:id'));
    expect(paths, contains('/backer/:id'));
  });

  test('native registry marks reward/checkout paths as native only', () {
    expect(kNativeRoutes.isNative('/reward/7'), isTrue);
    expect(kNativeRoutes.isNative('/checkout'), isTrue);
    expect(kNativeRoutes.isNative('/project/42'), isFalse);
    expect(kNativeRoutes.isNative('/backer/ada'), isFalse);
  });
}
