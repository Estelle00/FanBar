# Animation plans

Written by `improve-animations` for the FanBar menu panel. Each plan is self-contained and can be executed by any agent. Line numbers refer to the working tree on top of commit `102520e`, including the uncommitted panel redesign. Commit that redesign first, then re-check line references (`improve-animations reconcile`).

| # | Plan | Severity | Status |
| --- | --- | --- | --- |
| 001 | [Slide the overheat banner in and out](001-overheat-banner-entrance.md) | MEDIUM | DONE (unfelt) |
| 002 | [Cross-fade the mode-failure banner](002-mode-failure-banner-fade.md) | LOW | DONE (unfelt) |
| 003 | [Fade the disk detail rows in](003-disk-detail-reveal.md) | LOW | DONE (unfelt) |
| 004 | [Press feedback for custom panel buttons](004-panel-press-feedback.md) | MEDIUM | DONE (unfelt) |

## Recommended order

1. **004**: feedback on every click, so the widest benefit. It adds the shared `PanelDimButtonStyle` that the banner buttons in 001 use.
2. **001**: the most important moment. It also makes the helper notice's existing transition actually play.
3. **002**: a small cohesion fix in the same file as 001.
4. **003**: an independent change in `PanelResourceList.swift`.

## Dependencies

- 001 and 004 both edit the overheat banner in `FanMenu.swift`: 001 changes its declaration, and 004 changes its button style. Run them one after the other, not in parallel.
- 002 and 001 touch different parts of `FanMenu.swift`. They are safe in either order, but not concurrently.
- 003 is independent.

## Deliberately not planned

- Rolling digits for RPM and percentages, smoothing bar widths on the 2-second refresh, and morphing curves when the chart range changes: all three would move data the user is reading.
- Animating the popover's height: `FanMenu.updateContentHeight` intentionally resizes without interpolation because NSPopover resizing stutters.
