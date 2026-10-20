# README screenshots

All PNGs were recaptured on October 20, 2026 from the released FanBar 0.6.3 running macOS 27, in light and dark appearance. Most come from a Mac mini (M4, one fan); the `menu-dual-fan` set comes from a MacBook Pro (M2 Max, two fans). The READMEs show each light capture beside its dark counterpart in a table.

Each language (`en`, `zh-CN`, `zh-TW`, `ja`, `ru`, `fr`) has five captures per appearance (`light`, `dark`):

- `fanbar-menu-{appearance}-{language}.png`: menu-bar popover with real sensor readings and macOS automatic fan control.
- `fanbar-menu-dual-fan-{appearance}-{language}.png`: the same popover on a two-fan MacBook Pro (M2 Max) with the Balanced preset active, so both fan meters show live speeds.
- `fanbar-settings-cooling-{appearance}-{language}.png`: cooling presets and temperature curve editor.
- `fanbar-settings-appearance-{appearance}-{language}.png`: menu-bar appearance and app icon preferences.
- `fanbar-settings-general-{appearance}-{language}.png`: control service, notifications, alert sound, and app preferences.

All final PNGs are real macOS window screenshots, including window chrome and transparent shadows, taken with `screencapture -l` (menu 880×1514, two-fan menu 880×1556–1558, settings 1344×1600 pixels). Settings screenshots show the initial viewport; longer panes scroll. No interface or sensor values were generated or retouched.

The captures ran a copy of the release app under a separate bundle identifier, so the user's saved preferences and the installed FanBar were left unchanged. Its preferences used the Ringed menu bar icon, CPU temperature in the menu bar, the Classic app icon, no custom presets, and Balanced and Extreme in the menu panel; the temperature history was copied from the installed app so the chart shows real data. Launch arguments set the language (`-fanbar.language`), the settings tab (`-fanbar.settingsSelectedTab`) and, for light captures, `-NSRequiresAquaSystemAppearance YES`; `--show-panel` opened the popover. Launch arguments cannot switch FanBar to dark appearance, so the dark captures were taken with macOS itself in Dark Mode, a few minutes after the light ones; their readings differ slightly.

The `menu-dual-fan` captures were taken from the installed FanBar 0.6.3 itself rather than a copy, because only the running app that holds fan control shows the active preset. The user selected Balanced in it so the fans would spin (macOS had stopped both at idle); `screencapture -l` captured the popover in each language, which was switched through `fanbar.language` and set back to English afterwards. The dark set was taken with macOS in Dark Mode about a minute after the light set, so readings differ slightly. That app's other preferences (Propeller icon, temperature over fan speed in the menu bar) affect only the menu bar, not the popover.

The older JPEG files remain for historical references.
