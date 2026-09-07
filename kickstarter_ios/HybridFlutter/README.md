# HybridFlutter — iOS integration

The native half of the hybrid router: warms the single Flutter engine, hosts the
single `FlutterViewController`, and bridges navigation over the
`com.hybridrouter/navigation` method channel. Mirrors the Dart contract in
`kickstarter_flutter/packages/hybrid_router`.

## Files

| File | Role |
|------|------|
| `FlutterEngineManager.swift` | Owns the one long-lived `FlutterEngine`; `warmUp()` runs it once. |
| `NavigationChannel.swift` | Method-channel handler; method names mirror Dart `NavMethods`. |
| `HybridNavigator.swift` | Drives the host `UINavigationController`; reparents the single `FlutterViewController` for interleaved stacks; reports native back via `didPopNative`. |
| `NativeRouteFactory.swift` | Maps a native path → `UIViewController` (demo reward/checkout pages). |

## Integration steps (into the forked Kickstarter app)

The fork is **SPM-based (no CocoaPods)**, so embed Flutter as prebuilt
`.xcframework`s rather than via `podhelper`.

1. **Build the frameworks** (from the module):
   ```sh
   cd kickstarter_flutter/apps/kickstarter_app
   flutter build ios-framework --xcframework
   # -> build/ios/framework/{Debug,Release,Profile}/{Flutter,App}.xcframework
   ```
2. **Embed** `Flutter.xcframework` and `App.xcframework` in the `Kickstarter iOS`
   target: *General → Frameworks, Libraries, and Embedded Content* →
   *Embed & Sign*. (Add a Debug/Release framework-search-path pointing at the
   matching build dir, or check the generated frameworks into the repo.)
3. **Add the four Swift files** in this folder to the `Kickstarter iOS` target.
4. **Warm the engine** at launch, in the app's `AppDelegate`:
   ```swift
   FlutterEngineManager.shared.warmUp()
   ```
5. **Host the Flutter view** where Kickstarter's project page is shown. Create the
   single `FlutterViewController` from the shared engine and a `HybridNavigator`
   bound to the current `UINavigationController`:
   ```swift
   let engine = FlutterEngineManager.shared.engine
   let flutterVC = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
   let navigator = HybridNavigator(
       navigationController: self.navigationController!,
       flutterVC: flutterVC,
       channel: FlutterEngineManager.shared.navigation
   )
   // From a native list cell (e.g. a project row):
   navigator.showFlutter(path: "/project/42")
   ```
6. **Bottom bar (Case 4):** keep Kickstarter's native `UITabBarController`. One
   tab hosts the `HybridNavigator`/Flutter surface; the others stay native.

## LLDB init file

Debugging a Flutter module on recent iOS needs an LLDB init file — see Flutter's
"Embed a Flutter module in your iOS app → Use frameworks → Set LLDB Init File".

## Known scope

Handles Case 1 (nav-stack mixing) and the reparenting variant of Case 4. A single
engine cannot render two Flutter surfaces at once (doc Case 3 / full Case 4) —
that is the deliberate memory trade-off.
