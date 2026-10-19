# 004 — Give the panel's custom buttons press feedback

- **Status**: DONE — implemented; interactive feel check still pending
- **Commit**: 102520e (plus the uncommitted menu-panel redesign in the working tree; the excerpts below are from that working tree)
- **Severity**: MEDIUM
- **Category**: Missed opportunities (feedback)
- **Estimated scope**: 3 files (`FanMenuSections.swift`, `FanMenu.swift`, `PanelResourceList.swift`), ~60 lines

## Problem

The panel's hand-drawn buttons respond to hover but not to the press itself. Between mouse-down and mouse-up nothing changes, so a click feels unacknowledged until its effect lands. The affected buttons are: settings and quick-start (icon), Activity Monitor and Quit (text), the disk cell, the disk-detail collapse chevron, and the filled action buttons in the overheat banner and the helper notice.

```swift
// Sources/FanBar/FanMenu.swift:839 — current (PanelTextButton at :868 is identical apart from radius 6 and padding)
private struct PanelIconButton: View {
    let systemImage: String
    var size: CGFloat = 26
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        let palette = PanelPalette(colorScheme: colorScheme)
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size > 24 ? 14 : 12))
                .foregroundColor(isHovered ? .primary : palette.secondaryText)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isHovered ? palette.well : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        // Prevent AppKit from drawing a persistent focus ring around this icon-only action.
        .focusable(false)
        .onHover { isHovered = $0 }
    }
}
```

```swift
// Sources/FanBar/FanMenu.swift:779 — current helper action (the overheat banner's button at ~:680 has the same shape)
    private func helperActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(palette.surface)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary))
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        …
```

## Target

macOS buttons acknowledge a press by darkening, not by scaling, so use **no scale**.

- **Borderless buttons (icon and text)**: the well, which today appears only on hover, deepens to `pressedWell` **the instant** the mouse goes down. On release it eases back over **0.1 s `.easeOut`**, to the hover well or to clear.
- **Filled action buttons, the disk cell, and the collapse chevron**: the label drops to **opacity 0.75** the instant it is pressed and eases back over **0.1 s `.easeOut`** on release.
- Press-down is never animated; only the release eases.
- The release ease is a color/opacity change, which Reduce Motion permits, so it stays when Reduce Motion is on. It turns off (instant release) when the user disables FanBar's own panel animation (`PanelAnimationPreferences`).

New palette token in `PanelPalette` (`Sources/FanBar/FanMenuSections.swift`):

```swift
    /// The well while a borderless button is held down: about 1.6× the hover well.
    var pressedWell: Color { isDark ? Color.white.opacity(0.20) : Self.rgb(0x141E2D, 0.15) }
```

New styles, added to `Sources/FanBar/FanMenuSections.swift` directly after `PanelSegmentedControl`:

```swift
/// Borderless panel buttons: the well shows on hover and deepens the instant the button is
/// pressed, easing back on release. No scale; macOS acknowledges a press by darkening.
struct PanelWellButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat
    var isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        PanelPressBody(configuration: configuration) { isPressed, palette in
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isPressed ? palette.pressedWell : isHovered ? palette.well : Color.clear)
                )
        }
    }
}

/// Filled buttons and whole-cell buttons dim while held, then ease back.
struct PanelDimButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PanelPressBody(configuration: configuration) { isPressed, _ in
            configuration.label.opacity(isPressed ? 0.75 : 1)
        }
    }
}

/// Shared timing: instant on press, 0.1 s ease-out on release, instant when panel animation is off.
private struct PanelPressBody<Content: View>: View {
    let configuration: ButtonStyleConfiguration
    @ViewBuilder let content: (Bool, PanelPalette) -> Content

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(PanelAnimationPreferences.preferenceKey) private var panelAnimationEnabled = true

    var body: some View {
        content(configuration.isPressed, PanelPalette(colorScheme: colorScheme))
            .animation(
                configuration.isPressed || !panelAnimationEnabled ? nil : .easeOut(duration: 0.1),
                value: configuration.isPressed
            )
    }
}
```

## Repo conventions to follow

- Colors come only from `PanelPalette` tokens. Add `pressedWell` next to `well` and `track` in the "Empty part of bars" block, and keep the doc-comment style.
- The panel-animation preference is read with `@AppStorage(PanelAnimationPreferences.preferenceKey)`, as `SpinningFanGlyph` does (`FanMenuSections.swift:501`).
- Every custom button keeps `.focusable(false)` and its `.contentShape(...)`. Both are existing conventions for suppressing AppKit focus rings and setting the hit area.
- The project supports macOS 11. `ButtonStyle`, `configuration.isPressed`, and `.animation(_:value:)` are all available there. Do not use `.buttonStyle(.borderless)` or any API that requires macOS 12 or later.

## Steps

1. `FanMenuSections.swift`: add the `pressedWell` token to `PanelPalette` directly after `track`.
2. `FanMenuSections.swift`: add `PanelWellButtonStyle`, `PanelDimButtonStyle`, and `PanelPressBody` exactly as in **Target**, after the closing brace of `PanelSegmentedControl`.
3. `FanMenu.swift` `PanelIconButton`: delete the `.background(RoundedRectangle(cornerRadius: 7 …).fill(isHovered ? palette.well : Color.clear))` modifier from the image. Replace `.buttonStyle(.plain)` with `.buttonStyle(PanelWellButtonStyle(cornerRadius: 7, isHovered: isHovered))`. Keep the foreground color, frame, contentShape, `.focusable(false)`, and `.onHover`.
4. `FanMenu.swift` `PanelTextButton`: same change with `cornerRadius: 6`.
5. `FanMenu.swift` `helperActionButton` and the overheat banner's "切到…" button: replace `.buttonStyle(.plain)` with `.buttonStyle(PanelDimButtonStyle())`.
6. `PanelResourceList.swift`: in `diskCell`, replace `.buttonStyle(.plain)` with `.buttonStyle(PanelDimButtonStyle())`. Do the same for the collapse-chevron button inside `diskDetail`.
7. Leave `PanelSegmentedControl` alone. Its sliding selection highlight is already its feedback.

## Boundaries

- Do NOT add `scaleEffect` or any movement.
- Do NOT animate press-down; only the release eases.
- Do NOT change sizes, paddings, hover colors, or labels.
- Do NOT restyle the system `Slider`, `Menu`, or the segmented control.
- If any cited code differs from the excerpts, STOP and report.

## Verification

- **Mechanical**: `swift build` succeeds with no new warnings, and `swift test` passes.
- **Feel check**: with the panel open, in both light and dark mode:
  - Press and hold the gear: the rounded well appears darker than the hover well at once, with no delay. Release: it eases back to the hover well. Do the same for ⓘ, Activity Monitor, and Quit.
  - Press and hold the disk cell: the whole cell dims at once, and releasing toggles the details and fades back.
  - Hold the helper notice's action button (or the overheat banner's button): it dims. Drag off it before releasing: it undims and nothing fires.
  - Clicking rapidly never leaves a button stuck dark.
  - Turn off FanBar's panel animation in Settings: release becomes instant. With only Reduce Motion on, the 0.1 s fade remains, which is intended.
  - Compare with a native button (for example in System Settings): the darkening should feel similar in strength. If `pressedWell` reads too heavy in dark mode, the only allowed adjustment is the dark opacity, between 0.18 and 0.22.
- **Done when**: every listed button changes visibly on mouse-down, and eases back over 0.1 s on release (instantly when panel animation is off).
