# 003 — Fade the disk detail rows in once the panel has grown

- **Status**: DONE — implemented; interactive feel check still pending
- **Commit**: 102520e (plus the uncommitted menu-panel redesign in the working tree; the excerpts below are from that working tree)
- **Severity**: LOW
- **Category**: Missed opportunities (preventing a jarring change)
- **Estimated scope**: 1 file (`Sources/FanBar/PanelResourceList.swift`), ~15 lines

## Problem

Tapping the disk cell grows the popover and shows the per-disk rows in the same frame, so the list appears out of nowhere. The instant height change is **deliberate**, so do not animate it. `setExpanded` disables animation because animating the layout would make the popover re-measure on every frame and resize in visible steps:

```swift
// Sources/FanBar/PanelResourceList.swift:29 — current
    var body: some View {
        VStack(spacing: 0) {
            resourceGrid
                .padding(.vertical, 7)
            if expanded == .disk {
                PanelDivider()
                diskDetail
                    .padding(.vertical, PanelLayout.rowVerticalPadding)
            }
        }
    }

    private func setExpanded(_ resource: Resource?) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { expanded = resource }
    }
```

## Target

- Layout and height stay instant, exactly as today.
- Only the detail block's **rendering** animates, using modifiers that do not affect layout. On open it goes from `opacity 0, scale 0.98` (anchor `.top`) to `opacity 1, scale 1` over **0.15 s `.easeOut`**.
- Collapsing is instant, with no exit animation. The space collapses immediately, so a fade-out would draw over empty space.
- When `animates` is false (panel animation off or Reduce Motion on), the block appears fully drawn immediately.

```swift
// target
    @State private var isDiskDetailRevealed = false

    var body: some View {
        VStack(spacing: 0) {
            resourceGrid
                .padding(.vertical, 7)
            if expanded == .disk {
                PanelDivider()
                diskDetail
                    .padding(.vertical, PanelLayout.rowVerticalPadding)
                    // Height changes instantly (see setExpanded); only the drawing eases in.
                    .opacity(isDiskDetailRevealed ? 1 : 0)
                    .scaleEffect(isDiskDetailRevealed ? 1 : 0.98, anchor: .top)
                    .onAppear {
                        guard animates else {
                            isDiskDetailRevealed = true
                            return
                        }
                        withAnimation(.easeOut(duration: 0.15)) { isDiskDetailRevealed = true }
                    }
                    .onDisappear { isDiskDetailRevealed = false }
            }
        }
    }
```

## Repo conventions to follow

- `PanelResourceList` already receives the gate as `let animates: Bool`. `FanMenu` passes `animatesPanel`, which is `panelAnimationEnabled && !reduceMotion`. Use it, and do not read the environment again.
- `scaleEffect` and `opacity` do not change layout, which is what keeps the popover's measured height stable. Never use `.frame`, `.padding`, or `.transition` with `.move` here.
- Exemplar of a value-driven ease in this codebase: `OnboardingCard.swift:96` uses `withAnimation(.easeOut(duration: 0.28)) { … }`.

## Steps

1. In `PanelResourceList`, add `@State private var isDiskDetailRevealed = false` next to the existing `@Environment(\.colorScheme)` property.
2. Replace the `diskDetail.padding(…)` lines inside `body` with the target block above. Keep `PanelDivider()` unanimated.
3. Do not edit `setExpanded`.

## Boundaries

- Do NOT animate `expanded` itself, and do NOT remove the `Transaction` in `setExpanded`.
- Do NOT touch `FanMenu.updateContentHeight`.
- Do NOT add an exit animation.
- If the code differs from the excerpt, STOP and report.

## Verification

- **Mechanical**: `swift build` succeeds, and `swift test` passes.
- **Feel check**: open the panel and tap the disk cell several times. Confirm:
  - The popover grows in one step, with no stair-stepping or wobble in its height.
  - The disk rows then ease in from very slightly smaller, anchored at the top. The scale should be barely perceptible, and only the fade should be obvious.
  - Collapsing is instant.
  - Double-clicking quickly (open, close, open) never leaves the rows stuck invisible. If it does, the `onDisappear` reset is missing.
  - Step through a QuickTime recording frame by frame: the rows reach full opacity in about 9 frames.
  - With Reduce Motion on, the rows appear fully drawn in the same frame as the height change.
- **Done when**: opening fades and scales the rows in over 0.15 s with the height still instant, and closing is instant.
