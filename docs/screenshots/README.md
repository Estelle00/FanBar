# README screenshots

The menu, Cooling, and General PNGs were recaptured on October 19, 2026 from a local build of the `codex/menu-panel-glass` branch, so they show the redesigned menu panel (fan status header, speed bands, level-colored resources) and the matching settings. The Appearance PNGs are from the October 16, 2026 capture of `feature/custom-presets`; that pane did not change.

Each language (`en`, `zh-CN`, `zh-TW`, `ja`, `ru`) has four captures:

- `fanbar-menu-light-{language}.png`: menu-bar popover with real sensor readings and macOS automatic fan control.
- `fanbar-settings-cooling-light-{language}.png`: cooling presets and temperature curve editor.
- `fanbar-settings-appearance-light-{language}.png`: menu-bar appearance and app icon preferences.
- `fanbar-settings-general-light-{language}.png`: device compatibility, control service, notifications, and app preferences.

All final PNGs are real macOS window screenshots, including window chrome and transparent shadows. Settings screenshots show the initial viewport; longer panes scroll. No interface or sensor values were generated or retouched.

Capture processes used temporary launch arguments (`-fanbar.language`, `-fanbar.settingsSelectedTab`) with light appearance and the classic app icon. The October 19 menu captures show live sensor history, so the temperature chart can include short gaps where the app was relaunched. They also hid saved custom presets and showed the default Balanced selection with Balanced and Extreme in the menu panel, so every language shows the same state. The user's saved preferences and the installed FanBar instance were left unchanged. The older JPEG files remain for historical references.
