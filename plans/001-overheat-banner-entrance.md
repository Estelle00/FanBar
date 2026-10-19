# 001 — Slide the overheat banner in and out instead of popping it

- **Status**: DONE — implemented; interactive feel check still pending
- **Commit**: 102520e (plus the uncommitted menu-panel redesign in the working tree; the excerpts below are from that working tree)
- **Severity**: MEDIUM
- **Category**: Missed opportunities (preventing a jarring change)
- **Estimated scope**: 1 file (`Sources/FanBar/FanMenu.swift`), ~20 lines

## Problem

When a part crosses its hot limit while the menu panel is open, the overheat banner appears instantly and every section below it jumps down by its height. When the temperature drops, it vanishes and everything jumps back up. This is the rarest and most important message in the panel, and it arrives as a layout glitch.

The banner decides internally whether to render, so a `.transition` at the call site has nothing to attach to:

```swift
// Sources/FanBar/FanMenu.swift:132 — current call site
            overheatBanner
                .padding(.horizontal, Self.padding)
                .padding(.bottom, 12)
```

```swift
// Sources/FanBar/FanMenu.swift:669 — current declaration (body abbreviated)
    /// Only for a part past its hot limit: what is happening, and one way to act on it.
    @ViewBuilder private var overheatBanner: some View {
        if let focus, focus.level == .hot {
            HStack(spacing: 10) {
                Text(overheatDetail(focus))
                …
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(palette.hot.opacity(0.08))
            )
            .accessibilityElement(children: .contain)
        }
    }
```

The helper notice a few lines below already declares the right transition, but no animation drives it, so it pops in too:

```swift
// Sources/FanBar/FanMenu.swift:164 — current
            if controller.helperState != .enabled {
                helperNotice
                    .padding(.horizontal, Self.padding)
                    .padding(.bottom, 12)
                    .transition(slideInTransition)
            }
```

A SwiftUI transition only plays when the change that inserts or removes the view happens inside an animation. Neither change does today.

## Target

- The banner enters by fading in and moving down from the top edge, and leaves the same way (symmetric path). Duration is **0.2 s**, easing `.easeOut`.
- The helper notice gets the same animation, keyed on its own condition.
- When panel animation is off or Reduce Motion is on (`animatesPanel == false`), both appear and disappear instantly. This is the panel's existing convention: `slideInTransition` already returns `.identity` in that case.
- The popover's own height still changes instantly. `updateContentHeight` deliberately disables animation; leave that alone.

```swift
// target call sites
            if let focus, focus.level == .hot {
                overheatBanner(focus)
                    .padding(.horizontal, Self.padding)
                    .padding(.bottom, 12)
                    .transition(slideInTransition)
            }
            …
            if controller.helperState != .enabled {
                helperNotice
                    .padding(.horizontal, Self.padding)
                    .padding(.bottom, 12)
                    .transition(slideInTransition)
            }
```

```swift
// target: on the panel's root VStack, after `.frame(width: Self.panelWidth)`
        .animation(animatesPanel ? .easeOut(duration: 0.2) : nil, value: focus?.level == .hot)
        .animation(animatesPanel ? .easeOut(duration: 0.2) : nil, value: controller.helperState != .enabled)
```

## Repo conventions to follow

- The animation gate is `animatesPanel` (`FanMenu.swift:40`): `panelAnimationEnabled && !reduceMotion`. Never check `reduceMotion` directly in this file.
- The transition already exists, so reuse it rather than writing a new one:

```swift
// Sources/FanBar/FanMenu.swift:44 — exemplar, reuse as is
    private var slideInTransition: AnyTransition {
        animatesPanel ? .opacity.combined(with: .move(edge: .top)) : .identity
    }
```

- Value-keyed animations follow the pattern already used for the progress indicator (`FanMenu.swift:533`): `.animation(animatesPanel ? .easeOut(duration: 0.15) : nil, value: inProgressFeedback == nil)`.

## Steps

1. In `FanMenu.swift`, change the declaration `@ViewBuilder private var overheatBanner: some View {` to `private func overheatBanner(_ focus: ThermalFocus) -> some View {`. Delete its opening `if let focus, focus.level == .hot {` line and the matching closing `}`, so the function always returns the `HStack`. Remove `@ViewBuilder`, since the body is now a single expression. Keep the doc comment.
2. At the call site (around line 132), wrap the banner in the condition and add the transition, exactly as shown in **Target**.
3. In `panelContent`, find the end of the root `VStack(alignment: .leading, spacing: 0) { … }` that ends with `.frame(width: Self.panelWidth)`. Directly after that line, add the two `.animation(...)` modifiers from **Target**.
4. Leave the existing `.transition(slideInTransition)` on `helperNotice` unchanged. Step 3 is what makes it start playing.

## Boundaries

- Do NOT touch `updateContentHeight` or the `Transaction`/`disablesAnimations` code. Instant popover resizing is a deliberate decision.
- Do NOT change the banner's text, colors, button, or padding.
- Do NOT add any other `.animation` to `panelContent`. A broader key, such as the whole `controller`, would animate every 2-second data refresh.
- Do NOT add dependencies.
- If the code at the cited lines differs from the excerpts, STOP and report instead of improvising.

## Verification

- **Mechanical**: `swift build` succeeds, and `swift test` passes (230 tests, 3 skipped).
- **Feel check**: launch the app with the panel open (`--show-panel`) and heat the CPU past its hot limit (95 °C), for example by running `yes > /dev/null &` once per core for a minute, then `killall yes`. Confirm:
  - The banner fades in while moving down from under the header. It does not pop.
  - When the temperature falls back, it leaves upward along the same path.
  - The 2-second data refreshes while the banner is visible cause no extra motion: the fan numbers and bars update in place.
  - To see the frames, record the screen with QuickTime and step through the recording with the ← / → keys. The banner should take about 12 frames at 60 Hz.
  - Turn on System Settings → Accessibility → Display → Reduce motion, and also try FanBar's own panel-animation toggle in Settings. In both cases the banner must appear and disappear instantly.
- **Done when**: the banner and the helper notice both slide in and out over 0.2 s when animation is enabled, and appear instantly when it is not.
