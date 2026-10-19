# 002 — Cross-fade the mode-failure banner with the control strip

- **Status**: DONE — implemented; interactive feel check still pending
- **Commit**: 102520e (plus the uncommitted menu-panel redesign in the working tree; the excerpts below are from that working tree)
- **Severity**: LOW
- **Category**: Missed opportunities (state indication), cohesion
- **Estimated scope**: 1 file (`Sources/FanBar/FanMenu.swift`), ~5 lines

## Problem

When a mode switch fails, an error banner instantly covers the mode control. At the same moment the control strip underneath snaps to opacity 0. When the user dismisses the banner, both snap back. Right next to it, the in-progress indicator already fades over 0.15 s, so the two halves of the same feedback flow behave differently.

```swift
// Sources/FanBar/FanMenu.swift:381 — current
            PanelSegmentedControl(options: modeOptions, selection: selectedMode, systemImage: modeIcon) { option in
                select(option)
            }
            .disabled(controller.isBusy || controller.helperState != .enabled)
            .animation(
                animatesPanel ? .spring(response: 0.3, dampingFraction: 1) : .easeOut(duration: 0.15),
                value: selectedMode
            )
            // The failure banner covers the strip without changing popover size;
            // hide the strip (not remove it) so its labels can't show through.
            .opacity(isShowingModeFailureBanner ? 0 : 1)
            .allowsHitTesting(!isShowingModeFailureBanner)
            .accessibilityHidden(isShowingModeFailureBanner)
            .overlay(
                Group {
                    if let feedback = controller.modeActionFeedback, feedback.kind == .failure {
                        modeActionFeedbackBanner(feedback)
                    }
                }
            )
```

## Target

A cross-fade: the banner fades in as the strip fades out, and the reverse on dismiss. Use **opacity only**, with **0.15 s `.easeOut`**. There is no movement, because the banner sits on top of a fixed-height control. Under `animatesPanel == false`, the change is instant.

```swift
// target (only the changed lines)
            .opacity(isShowingModeFailureBanner ? 0 : 1)
            .allowsHitTesting(!isShowingModeFailureBanner)
            .accessibilityHidden(isShowingModeFailureBanner)
            .overlay(
                Group {
                    if let feedback = controller.modeActionFeedback, feedback.kind == .failure {
                        modeActionFeedbackBanner(feedback)
                            .transition(.opacity)
                    }
                }
            )
            .animation(animatesPanel ? .easeOut(duration: 0.15) : nil, value: isShowingModeFailureBanner)
```

## Repo conventions to follow

- Gate: `animatesPanel` (`FanMenu.swift:40`).
- Exemplar, the sibling indicator's fade (`FanMenu.swift:533`):

```swift
        .opacity(inProgressFeedback == nil ? 0 : 1)
        .animation(animatesPanel ? .easeOut(duration: 0.15) : nil, value: inProgressFeedback == nil)
```

## Steps

1. Inside the `.overlay(Group { … })` of `modeSection`, append `.transition(.opacity)` to `modeActionFeedbackBanner(feedback)`.
2. Directly after that `.overlay(...)` closes, and before the next `.overlay(modeProgressIndicator…)`, add `.animation(animatesPanel ? .easeOut(duration: 0.15) : nil, value: isShowingModeFailureBanner)`.

## Boundaries

- Do NOT change the existing `.animation(…, value: selectedMode)`. It drives the selection highlight.
- Do NOT add movement or scale. This must be opacity only.
- Do NOT change the banner's layout, text, or buttons.
- If the code differs from the excerpt, STOP and report.

## Verification

- **Mechanical**: `swift build` succeeds, and `swift test` passes.
- **Feel check**: trigger a failure. The easiest way is to remove the control service's approval in System Settings → General → Login Items & Extensions, then pick 极速 / Boost in the panel. Confirm:
  - The strip and the banner cross-fade, and at no frame are both fully opaque at once. Check this by stepping through a QuickTime recording frame by frame (about 9 frames at 60 Hz).
  - Dismissing with × fades the banner out and the strip back in.
  - Clicking × again mid-fade reverses smoothly from the current opacity. It must not restart from zero.
  - With Reduce Motion on, or FanBar's panel animation off, the swap is instant.
- **Done when**: both directions cross-fade over 0.15 s when animation is enabled, and are instant otherwise.
