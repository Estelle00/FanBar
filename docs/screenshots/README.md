# README screenshots

All PNGs were recaptured on October 20, 2026 from the released FanBar 0.6.3 on a Mac mini (M4, one fan) running macOS 27, in light and dark appearance. The READMEs show each light capture beside its dark counterpart in a table.

Each language (`en`, `zh-CN`, `zh-TW`, `ja`, `ru`, `fr`) has four captures per appearance (`light`, `dark`):

- `fanbar-menu-{appearance}-{language}.png`: menu-bar popover with real sensor readings and macOS automatic fan control.
- `fanbar-settings-cooling-{appearance}-{language}.png`: cooling presets and temperature curve editor.
- `fanbar-settings-appearance-{appearance}-{language}.png`: menu-bar appearance and app icon preferences.
- `fanbar-settings-general-{appearance}-{language}.png`: control service, notifications, alert sound, and app preferences.

All final PNGs are real macOS window screenshots, including window chrome and transparent shadows, taken with `screencapture -l` (menu 880×1514, settings 1344×1600 pixels). Settings screenshots show the initial viewport; longer panes scroll. No interface or sensor values were generated or retouched.

The captures ran a copy of the release app under a separate bundle identifier, so the user's saved preferences and the installed FanBar were left unchanged. Its preferences used the Ringed menu bar icon, CPU temperature in the menu bar, the Classic app icon, no custom presets, and Balanced and Extreme in the menu panel; the temperature history was copied from the installed app so the chart shows real data. Launch arguments set the language (`-fanbar.language`), the settings tab (`-fanbar.settingsSelectedTab`) and, for light captures, `-NSRequiresAquaSystemAppearance YES`; `--show-panel` opened the popover. Launch arguments cannot switch FanBar to dark appearance, so the dark captures were taken with macOS itself in Dark Mode, a few minutes after the light ones; their readings differ slightly.

The older JPEG files remain for historical references.
