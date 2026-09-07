# Talk metrics — baseline vs hybrid

The argument "our router is better" is made by running the **same** Kickstarter
user journey on two branches and measuring. Fill this in during the measurement
pass (build order step 7).

## The journey (identical on both branches)

`Discovery feed (native) → Project details (Flutter) → Reward (native) →
Creator profile (Flutter) → back → back → back`, i.e. the doc's Case 1
`n → f → n → f` chain, then unwind the whole stack.

## Branches under test

| Branch | Approach |
|--------|----------|
| `baseline-naive` | Flutter pages embedded with no router package. Each cross-boundary hop is an ad-hoc method-channel call. Optional variant: a fresh `FlutterEngine` per Flutter page (to expose the memory cost the doc predicts). |
| `main` (hybrid) | Single engine + single FlutterViewController + `hybrid_router`. |

## Metrics

### 1. Memory (Xcode Instruments — Allocations / dirty memory)

Reference from the doc: ~38 MB dirty per Flutter view; ideal second container
≈ +2 MB.

| Point in journey | baseline (engine-per-page) | hybrid (single engine) |
|------------------|----------------------------|------------------------|
| App launched, feed shown | _TBD_ | _TBD_ |
| First Flutter page (project) | _TBD_ | _TBD_ |
| After `n→f→n→f` (2 Flutter pages seen) | _TBD_ | _TBD_ |
| Peak during journey | _TBD_ | _TBD_ |

### 2. Navigation latency (native → Flutter transition, ms)

| | cold (first Flutter nav) | warm (subsequent) |
|--|--------------------------|-------------------|
| baseline | _TBD_ | _TBD_ |
| hybrid | _TBD_ | _TBD_ |

Capture with signposts (`os_signpost`) around the channel call → first frame.

### 3. State preservation (the doc's explicit Case 1 test)

Leave the project page mid-scroll, go `→ native → flutter`, pop back.

| | scroll position restored? | entered text restored? |
|--|---------------------------|------------------------|
| baseline | _TBD (expect: lost)_ | _TBD (expect: lost)_ |
| hybrid | _TBD (expect: kept)_ | _TBD (expect: kept)_ |

### 4. Developer ergonomics

Lines of glue a feature dev writes to add one new cross-boundary route.

| | new native-target route | new Flutter route |
|--|--------------------------|-------------------|
| baseline (hand-wired channel) | _TBD_ | _TBD_ |
| hybrid (registry entry + `push`) | _TBD (expect: ~1 line)_ | _TBD_ |

## Other ways to make the case in the deck

- Live side-by-side demo: same journey, both branches, screen-recorded.
- Show the feature code diff: identical `ref.hybridPush('/reward/…')` vs the
  baseline's bespoke `channel.invokeMethod(...)` plumbing per call site.
- Walk the `docs/multiple-flutters.md` case table to frame the problem.
- Architecture diagram: single engine + one FlutterViewController + GoRouter +
  method-channel bridge + native `UINavigationController`.
