import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_router/hybrid_router.dart';

/// Records every navigation the router performs on the Flutter side and keeps a
/// simple in-memory stack, standing in for a real GoRouter + Navigator.
class _FakeFlutterNavigation implements FlutterNavigation {
  final List<String> stack = ['/'];
  final List<String> log = [];

  @override
  void push(String location, {Object? extra}) {
    log.add('push $location');
    stack.add(location);
  }

  @override
  void go(String location, {Object? extra}) {
    log.add('go $location');
    stack
      ..clear()
      ..add(location);
  }

  @override
  void pushReplacement(String location, {Object? extra}) {
    log.add('pushReplacement $location');
    if (stack.isNotEmpty) stack.removeLast();
    stack.add(location);
  }

  @override
  void pop([Object? result]) {
    log.add('pop');
    if (stack.length > 1) stack.removeLast();
  }
}

/// Captures the Flutter -> Native method-channel traffic without a platform.
class _RecordingChannel extends NativeNavigatorChannel {
  _RecordingChannel() : super(channel: const MethodChannel('test/nav'));

  final List<String> calls = [];
  NativeNavigationCallbacks? callbacks;

  @override
  void bind(NativeNavigationCallbacks cb) => callbacks = cb;

  @override
  Future<void> pushNative(String path, Object? args) async =>
      calls.add('pushNative $path');

  @override
  Future<void> popNative() async => calls.add('popNative');

  @override
  Future<void> showNative(String path) async => calls.add('showNative $path');

  @override
  Future<void> popToRoot() async => calls.add('popToRoot');
}

void main() {
  late _FakeFlutterNavigation flutter;
  late _RecordingChannel channel;
  late HybridRouter router;

  // Native routes for the Kickstarter demo: reward/pledge detail is native.
  final registry = NativeRouteRegistry.of({'/reward', '/reward/*', '/checkout'});

  setUp(() {
    flutter = _FakeFlutterNavigation();
    channel = _RecordingChannel();
    router = HybridRouter(
      flutter: flutter,
      channel: channel,
      registry: registry,
      initialFlutterPath: '/',
    );
  });

  String stackString() => router.stack.map((e) => e.toString()).join(' > ');

  group('dispatch: native vs flutter', () {
    test('flutter path is delegated to GoRouter', () {
      router.push('/project/42');
      expect(flutter.log, contains('push /project/42'));
      expect(channel.calls, isEmpty);
      expect(router.stack.last, isA<FlutterEntry>());
    });

    test('native path is dispatched over the channel, not to GoRouter', () {
      router.push('/reward/7');
      expect(channel.calls, contains('pushNative /reward/7'));
      expect(flutter.log, isEmpty);
      expect(router.stack.last, isA<NativeEntry>());
    });

    test('wildcard native pattern matches a family of routes', () {
      expect(registry.isNative('/reward/7?ref=x'), isTrue);
      expect(registry.isNative('/project/1'), isFalse);
    });
  });

  group('interleaved stack: flutterA -> native -> flutterB', () {
    setUp(() {
      router.push('/project/42'); // flutterA
      router.push('/reward/7'); // native
      router.push('/backer/9'); // flutterB
    });

    test('a placeholder is inserted for the intervening native page', () {
      // Flutter navigator: /, flutterA, placeholder(native), flutterB
      expect(flutter.stack.length, 4);
      expect(NativePlaceholder.matches(flutter.stack[2]), isTrue);
      expect(
        NativePlaceholder.nativePathOf(flutter.stack[2]),
        '/reward/7',
      );
      expect(flutter.stack.last, '/backer/9');
    });

    test('logical stack reflects the true visual order', () {
      expect(
        stackString(),
        'Flutter(/) > Flutter(/project/42) > Native(/reward/7) > Flutter(/backer/9)',
      );
    });

    test('popping flutterB hands control back to the native page', () {
      channel.calls.clear();
      router.pop(); // pop flutterB
      // GoRouter pops flutterB; the placeholder is now top -> ask native to show.
      expect(flutter.log.last, 'pop');
      expect(channel.calls, contains('showNative /reward/7'));
      // Placeholder stays in the Flutter navigator until native reports back.
      expect(NativePlaceholder.matches(flutter.stack.last), isTrue);
      expect(router.stack.last, isA<NativeEntry>());
    });

    test('native back after that resolves to flutterA and clears placeholder',
        () {
      router.pop(); // flutterB -> native shown
      channel.calls.clear();
      // User taps back on the native page; native notifies Flutter.
      channel.callbacks!.onDidPopNative('/reward/7');
      expect(flutter.stack.last, '/project/42'); // placeholder removed
      expect(router.stack.last, isA<FlutterEntry>());
      expect((router.stack.last as FlutterEntry).path, '/project/42');
    });
  });

  group('native-triggered back on a plain native top', () {
    test('didPopNative pops the native entry without touching Flutter', () {
      router.push('/project/42');
      router.push('/reward/7'); // native on top of a flutter page (no placeholder)
      final flutterLenBefore = flutter.stack.length;
      channel.callbacks!.onDidPopNative('/reward/7');
      // No placeholder was inserted (flutter -> native), so Flutter is untouched.
      expect(flutter.stack.length, flutterLenBefore);
      expect(router.stack.last, isA<FlutterEntry>());
      expect((router.stack.last as FlutterEntry).path, '/project/42');
    });
  });

  group('go() resets the flutter history', () {
    test('go to a flutter route clears the stack', () {
      router.push('/project/42');
      router.push('/backer/9');
      router.go('/');
      expect(flutter.stack, ['/']);
      expect(router.stack.length, 1);
      expect(router.stack.single, isA<FlutterEntry>());
    });
  });

  group('pushReplacement', () {
    test('replaces a flutter top in place', () {
      router.push('/project/42');
      router.pushReplacement('/project/99');
      expect(flutter.stack.last, '/project/99');
      expect(router.stack.last, isA<FlutterEntry>());
      expect((router.stack.last as FlutterEntry).path, '/project/99');
    });
  });
}
