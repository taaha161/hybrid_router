# Multiple Flutters — reference & case mapping

Condensed from the canonical Flutter design doc **"Multiple Flutters"**
(go link: `flutter.dev/go/multiple-flutters`, authors @xster / @gaaclarke),
which frames the add-to-app navigation problem this talk solves. Kept here so
the talk narrative and the code stay anchored to the same source. Original doc
is the authority; this is a working summary.

## The problem

Embedding Flutter into an existing native app means Flutter and native pages
interleave on one navigation stack. The community work-arounds (flutter_boost et
al.) are heavy for the "torso" market. Two forces pull against each other:

- **Ergonomics** — feature teams should write ordinary Flutter code with no
  routing glue, and modules must not leak UI into each other (webview-like
  isolation between containers).
- **Performance** — a Flutter view costs ~**38 MB** of dirty memory on iOS
  (4 MB pthreads, 10 MB GPU drivers, 1 MB Dart VM, 5 MB font maps, 16 MB
  graphics buffers). A `native → flutter → native → flutter …` chain must **not**
  grow at ~38 MB per hop. A second co-existing container should cost closer to
  ~38 MB + 1 MB (new isolate VM) + 1 MB (new Dart/UI pthread), not 38 MB × 2.

Guidance we adopt directly: **the navigation stack history is most pragmatically
held on the platform (native) side**, since Flutter's `Navigator` is unaware of
platform routes.

## The four test cases (doc uses Yelp)

| # | Case | Description | This project |
|---|------|-------------|--------------|
| 1 | **Navigation-stack mixing** | `native(feed) → flutter(detail) → native(item) → flutter(profile)`. Each page keeps independent UI state (scroll position, entered text). History lives on the platform side. | **Solved.** Core of the talk. |
| 2 | **Tabs** | Flutter screens reached in parallel via tabs; each tab keeps its own nav stack + UI state. | Native tab bar (Case 4 covers the reparenting variant). |
| 3 | **Concurrent partial views** | A native list whose cells are independently native or Flutter, toggled by A/B tests; multiple Flutter surfaces render at once. | **Out of scope** — single engine can't render two Flutter views concurrently. Acknowledged as the trade-off. |
| 4 | **Reparenting** | Android-pattern bottom bar *inside* a page: the bottom tab and most tabs are native, one tab is Flutter; a modal push covers the whole screen incl. the bar. | **Partially solved** — native bottom bar with a Flutter tab + full-screen native pushes. |

### Case 1 detail — the state-preservation test

Leaving flutter page (2) at some scroll position, navigating to (3) and (4), then
popping back to (2) **must** return to the same scroll position — its `State`
tree and Dart objects must survive. A second instance of the same page keeps its
own independent state. Some Dart state (current-user object, image cache) may
still be shared across containers.

## How our design maps to the doc

- **Single engine + single FlutterViewController** → keeps the `n→f→n→f` chain
  near the doc's ideal memory curve (one fixed ~38 MB, no per-hop engine cost).
- **Platform-authoritative stack** → the native `UINavigationController` owns the
  real history; `hybrid_router` mirrors it locally.
- **Placeholder routes** → represent an intervening native page inside the one
  Flutter `Navigator` so a Flutter pop returns *to* the native page (Case 1),
  instead of skipping it. See `packages/hybrid_router/lib/src/placeholder.dart`.
- **`didPopNative` sync** → native-originated back (button / edge-swipe) is
  reflected into GoRouter so the two stacks never diverge.
- **Registry-based dispatch + plain GoRouter API** → satisfies the doc's
  ergonomics bar: feature teams call `push`/`go`/`pop` and never branch on
  native-vs-Flutter.

## Known limitation (state it honestly in the talk)

The doc's Case 3 and the full Case 4 require **simultaneous rendering** of
multiple Flutter surfaces. A single engine + single view cannot do that. This is
the deliberate trade-off for the memory win; the multi-engine
(`FlutterEngineGroup`) approach buys concurrency at the cost the doc measures.
