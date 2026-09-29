# HybridFlutter — iOS integration

The native half of the hybrid router. One warm `FlutterEngine` holds all
Flutter state. A new `FlutterViewController` is created each time native opens
Flutter and destroyed by `returnToNative`; one left under a native page
re-attaches to the engine when revealed. Native talks to Flutter
through the typed Pigeon bridge from the `hybrid_router` plugin
(`kickstarter_flutter/packages/hybrid_router`).

## Files

| File | Role |
|------|------|
| `FlutterEngineManager.swift` | Owns the one warm `FlutterEngine`; `warmUp()` runs it once and registers plugins. |
| `HybridNavigator.swift` | Drives the native stack: `push`, `showFlutter`, `returnToNative`, `popToRoot`, `openFlutter`, `onBackPressed`. |
| `NavBridge.swift` | `ToNativeImpl` — implements the generated `ToNative`, one line per method into `HybridNavigator`; `registerBridge()` wires it up. |
| `NativeRouteFactory.swift` | Maps a native path → `UIViewController` (demo reward/checkout pages). |
| `HybridFeedViewController.swift` | The native feed (Hybrid tab); a row tap calls `openFlutter`. |

## The bridge

| API | Direction | Implemented by | Called by |
|-----|-----------|----------------|-----------|
| `ToNative` — `pushNativeRoute`, `returnToNative`, `popToRoot` | Flutter → native | `ToNativeImpl` (Swift) | `toNative` (Dart) |
| `ToFlutter` — `pushFlutterRoute`, `handleBack` | native → Flutter | `ToFlutterImpl` (Dart) | `toFlutter` (Swift) |

Back navigation: native owns the back gesture and asks Flutter first.
`onBackPressed` (edge-swipe) calls `toFlutter.handleBack()`; if Flutter
returns `false`, native pops. A native page on top just pops itself.

## Building the frameworks

The fork is SPM-based, so Flutter is embedded as prebuilt `.xcframework`s
(gitignored — rebuild them after changing any Dart or plugin code):

```sh
cd kickstarter_flutter/apps/kickstarter_app
flutter build ios-framework --no-profile --no-release --output=/tmp/ks_fw
cp -R /tmp/ks_fw/Debug/*.xcframework ../../../kickstarter_ios/Frameworks/
```

That produces four frameworks, all linked and embedded in the `Kickstarter-iOS`
target: `App`, `Flutter`, `FlutterPluginRegistrant`, and `hybrid_router` (the
plugin, which carries the generated Swift bridge).

If the plugin changes (e.g. the Pigeon schema), regenerate the bridge first with
`kickstarter_flutter/packages/hybrid_router/tool/generate.sh`.

## LLDB init file

Debugging a Flutter module on recent iOS needs an LLDB init file — see Flutter's
"Embed a Flutter module in your iOS app → Use frameworks → Set LLDB Init File".

## Known scope

One engine can't render two Flutter surfaces at the same time — the deliberate
trade-off for shared state, one warm-up, and one back stack.
