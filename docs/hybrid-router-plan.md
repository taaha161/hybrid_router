# Hybrid Router — FlutterCon Add-to-App Talk

## Context

The talk demonstrates **Flutter routing in add-to-app**: embedding Flutter pages into a
native iOS app and making navigation work *across* the iOS↔Flutter boundary, in both
directions, without the memory/latency cost of multiple Flutter engines.

The reference is the canonical Flutter design doc **flutter.dev/go/multiple-flutters**
(xster/gaaclarke). It defines four test cases; we solve **Case 1 (navigation-stack mixing)**
and **Case 4 (reparenting — native bottom bar, Flutter tabs mixed in)**. The doc's key
guidance we adopt: *the navigation stack history is most pragmatically held on the platform
side*, and multiple engines are memory-heavy (~38 MB dirty memory per Flutter view), so a
**single engine** is preferred.

We reproduce the doc's Yelp scenario using **Kickstarter's open-source iOS app**
(`kickstarter/ios-oss`, UIKit + ReactiveSwift, `UITabBarController`). The feed→detail flow
maps cleanly:

| Doc (Yelp)                        | Our app (Kickstarter)                          | Impl    |
|-----------------------------------|------------------------------------------------|---------|
| (1) Home feed                     | Discovery feed                                 | Native  |
| (2) Restaurant details            | Project details page                           | Flutter |
| (3) Food/menu item details        | Reward / pledge detail                         | Native  |
| (4) Reviewer profile              | Creator / backer profile                       | Flutter |
| Bottom tab bar (Case 4)           | Discover / Activity / Search / Profile tabs    | Native  |

**Goal:** a monorepo with (a) the forked native app, (b) a Flutter module split into
`features/*` and a `packages/hybrid_router` GoRouter wrapper, (c) a naive baseline branch to
measure against, and (d) talk collateral (metrics + diagrams).

## Decisions (confirmed with user)

- **App:** fork the real `kickstarter/ios-oss` (UIKit + ReactiveSwift). Build via its OSS
  mock mode (`KsApi.Secrets.isOSS = true`) so no real API secrets are needed.
- **iOS UI:** UIKit (inherited from the fork). SwiftUI only if needed for Flutter-host glue.
- **Engine:** single long-lived `FlutterEngine` (no `FlutterEngineGroup`, no engine-per-page).
- **Router:** thin wrapper around **GoRouter**.
- **Flutter state:** **Riverpod**.
- **Baseline:** separate branch, naive embed + ad-hoc method channels, built first to
  establish the measurement floor.

## Monorepo layout

```
hybrid_router/                       # monorepo root (git init here)
├── kickstarter_ios/                 # fork of kickstarter/ios-oss
│   └── (Xcode workspace; embeds the Flutter module via CocoaPods podhelper)
├── kickstarter_flutter/             # Flutter add-to-app workspace (Melos)
│   ├── melos.yaml
│   ├── packages/
│   │   └── hybrid_router/           # GoRouter-mirroring wrapper + method-channel bridge + Riverpod
│   ├── features/                    # one package per embeddable feature (used by native + app)
│   │   ├── project_details/         # Flutter feature — Kickstarter project page  (doc page 2)
│   │   └── user_profile/            # Flutter feature — creator/backer profile     (doc page 4)
│   └── apps/
│       └── kickstarter_app/         # `flutter create -t module`; pulls features together into
│                                    # one add-to-app module; owns the NATIVE ROUTE REGISTRY
└── docs/
    ├── multiple-flutters.md         # local copy of reference doc + case mapping
    └── talk-metrics.md              # measurement results (baseline vs hybrid)
```

The **native route registry** (list of route paths that are implemented natively) lives in the
root app under `apps/kickstarter_app`, injected into `hybrid_router`. Feature packages stay
unaware of it — they call the router with plain GoRouter-style calls.

## Architecture

### Single engine + reparenting (flutter_boost-style, but with GoRouter)
- Warm **one** `FlutterEngine` at launch, held on the AppDelegate/singleton.
- One long-lived `FlutterViewController(engine:)` embedded in the Kickstarter navigation
  stack. Flutter's internal routes are driven by **GoRouter** inside that one view.
- Cross-boundary navigation reparents/reorders native VCs rather than spinning new engines:
  native pushes native VCs on top of the Flutter VC; returning to Flutter pops back to the
  still-alive Flutter VC (state preserved — the doc's explicit scroll-position test).
- **Authoritative stack lives on the native side** (per doc); the router mirrors a logical
  stack for back handling.

### `packages/hybrid_router` — API mirrors GoRouter (the core of the talk)
Public API is **identical in shape to GoRouter**: `push(path, extra)`, `pop([result])`,
`go(path, extra)` (and `pushReplacement`, etc.). Feature teams write the exact same calls
they'd write in a pure-Flutter app; the wrapper is a drop-in.

Dispatch, on every `push`/`go`:
1. Look the path up in the **native route registry** (owned by `apps/kickstarter_app`).
2. **Native match** → send over the method channel; native pushes the corresponding UIKit VC.
3. **No match** → normal GoRouter navigation inside the single FlutterViewController.

Symmetric for the reverse direction — native asking to show a Flutter route drives GoRouter.

Internals:
- `HybridRouter` wraps one `GoRouter` instance + a `NativeNavigatorChannel`.
- `NativeNavigatorChannel` — `MethodChannel` wrapper (consider **pigeon** for type safety;
  doc mentions it).
- Riverpod providers expose the router + current location; feature widgets consume them.

### Method-channel bridge  (`com.hybridrouter/navigation`)
- **Flutter → Native:** `pushNative(path, args)`, `popNative()`, `popToRoot()`.
- **Native → Flutter:** `pushFlutter(path, args)`, `popFlutter()`.
- **Native → Flutter back signal:** `didPopNative(path)` — see native-triggered back below.

### Single FlutterViewController + interleaved-stack consistency (the hard part)
There is **one** `FlutterEngine` and **one** `FlutterViewController`, so *every* Flutter page
(flutterA, flutterB, …) lives in the **same** GoRouter/Navigator stack — even when a native
page sits logically between them. That desyncs the Flutter stack from the true visual stack.

**Problem case: `flutterA → native → flutterB`.** Naively, Flutter's stack is `[A, B]` and the
native page is invisible to it, so popping B jumps straight back to A and skips the native page.

**Fix — placeholder (dummy) route insertion.** When `hybrid_router` pushes flutterB while the
*current top of the visual stack is native*, it first inserts a lightweight **placeholder route**
into the Flutter Navigator representing the intervening native page, making the Flutter stack
`[A, <native-placeholder>, B]`. On `pop` from B:
- Flutter lands on the `<native-placeholder>` route.
- The router detects the placeholder, does **not** render it, and instead sends `popNative()` /
  a "return to your UIViewController" message so native brings its page forward.
- A subsequent back from the native page then resolves to flutterA normally.

This keeps a single, consistent logical back-stack across the boundary while using only one
FlutterViewController.

### Native-triggered back detection
When the user pops the **native** side (nav-bar back button, iOS edge-swipe) while the logical
predecessor is a Flutter page, native emits `didPopNative(path)`. The router receives it and
calls the matching **`pop()` on the Flutter side** so the GoRouter stack stays in sync with the
native `UINavigationController` — no orphaned Flutter routes, no double-back.

Native holds the authoritative stack (per doc); the placeholder scheme + `didPopNative` signal
are how Flutter's stack is kept faithfully mirrored to it.

**Why wrap GoRouter (rehearse this):** declarative, URL/deep-link based, typed routes,
redirect/guards, official & maintained. Wrapping lets us (1) intercept every navigation to
split Flutter vs native targets, (2) preserve feature-dev ergonomics — plain `push()` calls,
zero native knowledge, no leaks between feature modules (doc's ergonomics requirement),
(3) centralize the channel bridge and analytics/latency logging for the talk's metrics.
Alternatives rejected: raw Navigator 2.0 (verbose), flutter_boost (owns an opaque stack, hard
to teach, not GoRouter), auto_route (codegen-heavy).

## Measurement: baseline vs hybrid (how we prove it's better)

Build **`baseline-naive` branch first**: embed Flutter pages with no router package — every
cross-boundary hop is an ad-hoc method-channel call, and page switching leans on native (and,
for contrast, optionally an engine-per-page variant to expose the memory cost). Then build
`main` with the single-engine + `hybrid_router`. Run the **same** n→f→n→f Kickstarter journey
on both and record in `docs/talk-metrics.md`:

- **Memory** — Instruments; single engine vs multi-engine (~38 MB/view baseline from the doc).
- **Nav latency** — native→Flutter transition time, cold and warm.
- **State preservation** — scroll position / partial text survives the n→f→n→f chain (the
  doc's explicit test); naive approach loses it, ours keeps it.
- **Ergonomics** — lines of glue per new cross-boundary route (registry entry vs hand-wired
  channel plumbing).
- **Known limit (state honestly):** single engine can't render two Flutter views
  concurrently (doc Case 3 / full Case 4). Acknowledge; frame as the multi-engine trade-off.

**Presentation aids:** the multiple-flutters doc (Cases 1 & 4), a side-by-side demo of both
branches on the same journey, the memory graph + latency table, and an architecture diagram
of single-engine + router + channel bridge.

## Build order

1. `git init` monorepo; fork `kickstarter/ios-oss` into `kickstarter_ios/`; get it building in
   OSS mock mode (`Secrets.isOSS = true`, `bundle install`, `pod install`).
2. `kickstarter_flutter/` workspace: Melos; `flutter create -t module apps/kickstarter_app`;
   scaffold `packages/hybrid_router` and `features/{project_details,user_profile}`.
3. Embed the module into the Kickstarter app (CocoaPods `podhelper`); warm the single engine +
   single FlutterViewController; render one Flutter page (project details) in the native stack.
4. Build the method-channel bridge (both directions); wire `hybrid_router` GoRouter-mirroring
   dispatch + native route registry.
5. Implement placeholder-route insertion (interleaved `flutterA→native→flutterB`) and
   `didPopNative` native-triggered back sync.
6. Implement the full n→f→n→f Kickstarter journey (doc pages 1–4) + native bottom bar (Case 4).
7. Cut `baseline-naive` branch (or build it first as the measurement floor); collect metrics.
8. Write `docs/` collateral (case mapping, metrics, diagram).

## Critical files (to create)

- `kickstarter_ios/` — fork; `AppDelegate` engine + single-FlutterViewController warm-up +
  `NavigationChannelHandler` (UIKit push/pop, edge-swipe → `didPopNative`).
- `kickstarter_flutter/melos.yaml`, `kickstarter_flutter/apps/kickstarter_app/` (module +
  native route registry).
- `kickstarter_flutter/packages/hybrid_router/lib/` — `hybrid_router.dart` (GoRouter-mirroring
  API + dispatch), `native_route_registry.dart`, `placeholder_route.dart`,
  `native_navigator_channel.dart`, `providers.dart`.
- `kickstarter_flutter/features/project_details/`, `kickstarter_flutter/features/user_profile/`.
- `docs/multiple-flutters.md`, `docs/talk-metrics.md`.

## Verification

- **Flutter:** `melos bootstrap`; unit tests for `hybrid_router` — native-vs-flutter dispatch
  (mocked `MethodChannel`), placeholder insertion on `flutterA→native→flutterB`, and
  `didPopNative` → Flutter `pop()` sync; `flutter build ios-framework`.
- **iOS:** `bundle install && pod install`; open the workspace, set `Secrets.isOSS = true`,
  run in Simulator.
- **End-to-end:** walk Discovery → project (Flutter) → reward (native) → profile (Flutter);
  pop all the way back and confirm each intervening native page reappears (placeholder works)
  and scroll/UI state is retained; test native back button + edge-swipe both sync Flutter.
- **Metrics:** Instruments memory profile for hybrid vs `baseline-naive`; record latency;
  fill `docs/talk-metrics.md`.

## Open questions (non-blocking, decide during build)

- pigeon vs hand-written `MethodChannel` for the bridge.
- Whether the baseline branch also demos an engine-per-page variant (strongest memory contrast)
  or only naive single-engine channel-switching.
- Deep-link entry (open app directly onto a Flutter route) — nice-to-have talk extension.
