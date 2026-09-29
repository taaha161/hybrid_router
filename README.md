# hybrid_router

Companion repo for the FlutterCon talk **"Routing Across the Seam"**: navigation
in Flutter add-to-app that works in both directions across the iOS ↔ Flutter
boundary, with **one warm `FlutterEngine`** and **GoRouter as the only stack**.

The demo is a fork of the open-source [Kickstarter iOS app](https://github.com/kickstarter/ios-oss)
with part of one journey moved to Flutter:

```
Discovery feed  →  Project  →  Reward  →  Backer profile
   (native)       (Flutter)   (native)     (Flutter)
```

Go forward through it, then all the way back. Every back step lands on the
screen underneath, whichever side of the seam it lives on. Each demo screen
carries a **NATIVE SCREEN** or **FLUTTER SCREEN** banner so you can see which is which.

## How it works

- **One engine.** A single warm `FlutterEngine` holds every Flutter page's
  state. Each time native opens Flutter, a new `FlutterViewController` is
  pushed. `returnToNative` pops it. A Flutter view left under a native page
  re-attaches to the engine when you come back to it.
- **One stack.** GoRouter's own stack is the only navigation state. When native
  opens a Flutter page, Flutter pushes an invisible **placeholder** route first.
  Going back onto a placeholder means "a native screen is here", so Flutter
  hands control back to native. There is no mirror stack to keep in sync.
- **A thin wrapper.** `HybridRouter` has `push`, `go` and `pop`, just like
  GoRouter. It checks a `NativeRouteRegistry`: native paths cross the bridge,
  everything else goes straight to GoRouter. When the registry is empty, you
  can delete the wrapper.
- **A typed bridge.** [Pigeon](https://pub.dev/packages/pigeon) generates both
  sides from one schema:

  | API | Direction | Methods |
  |-----|-----------|---------|
  | `ToNative` | Flutter → native | `pushNativeRoute`, `returnToNative`, `popToRoot` |
  | `ToFlutter` | native → Flutter | `pushFlutterRoute`, `handleBack` |

- **Native owns back.** On every back gesture, native asks Flutter first
  (`handleBack`). The in-page AppBar arrow (`HybridBackButton` →
  `HybridRouter.pop()`) runs the same logic.

## Repo layout

```
kickstarter_ios/                  Kickstarter iOS fork (UIKit)
  HybridFlutter/                  HybridNavigator, NavBridge (ToNativeImpl), engine, demo screens
kickstarter_flutter/              Flutter workspace (pub workspaces + Melos)
  packages/hybrid_router/         the plugin: HybridRouter, ToFlutterImpl, placeholders, Pigeon schema
  features/project_details/       Flutter project page
  features/user_profile/          Flutter backer profile
  apps/kickstarter_app/           add-to-app module: builds the GoRouter, owns the native route list
```

More detail:
[`packages/hybrid_router/README.md`](kickstarter_flutter/packages/hybrid_router/README.md) ·
[`HybridFlutter/README.md`](kickstarter_ios/HybridFlutter/README.md)

## Run it

**Flutter side**

```sh
cd kickstarter_flutter
flutter pub get
melos run analyze
melos run test
```

**iOS side.** The app embeds Flutter as prebuilt xcframeworks:

```sh
cd kickstarter_flutter/apps/kickstarter_app
flutter build ios-framework --no-profile --no-release --output=/tmp/ks_fw
cp -R /tmp/ks_fw/Debug/*.xcframework ../../../kickstarter_ios/Frameworks/
```

Then open `kickstarter_ios/Kickstarter.xcodeproj`, run the app, and open the
**Hybrid** tab. If you change the Pigeon schema, regenerate the bridge first
with `kickstarter_flutter/packages/hybrid_router/tool/generate.sh`.

## Try it yourself

- Carry path and query params (`/project/:id?ref=hn`) through `NavRoute`.
- Add more GoRouter APIs: `pushNamed` / `goNamed`, `pushReplacement`, `canPop`.
- Bring it to Android: implement `ToNative` in Kotlin. The schema stays the same, and no Dart changes are needed.

## Trade-off

One engine can't show two Flutter views at the same time. That's the price of
shared state, one warm-up, and one back stack.

## Reference

[flutter.dev/go/multiple-flutters](https://flutter.dev/go/multiple-flutters), the
Flutter design doc on multiple Flutter instances in one app.
