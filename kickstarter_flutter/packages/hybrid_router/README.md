# hybrid_router

A thin GoRouter wrapper for Flutter add-to-app. Feature code calls
`push` / `go` / `pop` exactly like GoRouter; native routes go over a typed
Pigeon bridge, everything else goes to GoRouter in a single warm engine.

GoRouter's own stack plus invisible **placeholder** routes is the only
navigation state — there is no second stack to keep in sync.

## Pieces

| | |
|---|---|
| `HybridRouter` | `push`, `go`, `pop`. Asks the `NativeRouteRegistry` whether a path is native, then dispatches to `toNative` or GoRouter. |
| `NativeRouteRegistry` | The native screens — the migration dial. Delete a line to migrate a screen; when it's empty, delete the wrapper. |
| `ToFlutterImpl` | Implements the generated `ToFlutter`: `pushFlutterRoute` (placeholder + page) and `handleBack`. |
| `placeholder()` / `isPlaceholder()` | A bare marker route meaning "a native screen sits here". |
| `HybridBackButton` | AppBar back arrow that runs the same back logic as native. |
| `routerProvider` | Riverpod provider the host app overrides with its `HybridRouter`. |

## Usage

```dart
// Host app
final toNative = ToNative();                                   // generated caller
ToFlutter.setUp(ToFlutterImpl(goRouter: goRouter, toNative: toNative));
final router = HybridRouter(goRouter: goRouter, toNative: toNative, registry: registry);

// Feature code
ref.read(routerProvider).push('/reward/42'); // native today, Flutter tomorrow
```

## The bridge

The whole bridge is one schema: `pigeons/hybrid_nav.dart`. Regenerate with:

```sh
tool/generate.sh
```

It runs Pigeon and then marks the app-facing Swift types public (Pigeon emits
internal Swift, and the host app lives in a different module than the plugin).

## Try it yourself

- Carry path and query params (`/project/:id?ref=hn`) through `NavRoute`.
- Add `pushNamed` / `goNamed`, `pushReplacement`, `canPop`.
- Add Android: implement `ToNative` in Kotlin — same schema, no Dart changes.
