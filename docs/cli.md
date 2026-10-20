# `fanbar` command-line tool

`fanbar` lets terminals and scripts switch FanBar modes and read its status.
It ships inside the app at `FanBar.app/Contents/Helpers/fanbar`.

```sh
fanbar status                     # mode, preset, fans, temperatures
fanbar temps                      # CPU / GPU / SSD only
fanbar preset list                # * marks the selected preset
fanbar preset set performance     # built-in key, custom name, or token
fanbar preset set "Late Night"
fanbar mode curve                 # run the selected preset's curve
fanbar mode fixed 3200            # every fan at 3,200 RPM
fanbar mode auto                  # hand the fans back to macOS
```

## Options

| Option | Effect |
|---|---|
| `--hold` | For `preset set`, `mode curve` and `mode fixed`: keep the mode until it is changed again. Without it, macOS control comes back after the **Restore automatic control** timer in Settings, like a switch from the menu panel. |
| `--json` | Print the app's reply as JSON (`ok`, `message`, `status`, `presets`). |
| `--no-launch` | Fail with exit code 3 instead of starting FanBar when it is not running. |

By default `fanbar` starts FanBar in the background (`open -g`) when it is not
running, then waits up to 20 seconds for the app to accept the command.

Exit codes: `0` success · `1` FanBar refused or failed the command ·
`2` usage error · `3` FanBar could not be reached.

Built-in presets always answer to their English keys (`silent`, `balanced`,
`performance`, `extreme`) whatever the interface language, so scripts keep
working after a language change. CLI messages are English for the same reason.
Failures reported by the app itself (for example a control service that has not
been approved) keep the app's wording.

## Installing on `PATH`

- **Settings:** open **Settings › General › FanBar › Command-line tool** and
  click **Install…**. This links `/usr/local/bin/fanbar` to the tool inside
  the app. FanBar first tries without privileges, because Intel Homebrew
  leaves `/usr/local/bin` writable by the user. If that fails, macOS asks once
  for an administrator password. The same row offers **Uninstall…**, and
  **Update Link…** when the link points to another copy of FanBar. FanBar
  never replaces a `fanbar` it did not create. The row asks you to move FanBar
  to Applications first when it runs from a disk image or a translocated copy,
  and it is hidden in builds without the tool (`swift run`).
- **By hand:**

  ```sh
  sudo mkdir -p /usr/local/bin
  sudo ln -sf /Applications/FanBar.app/Contents/Helpers/fanbar /usr/local/bin/fanbar
  ```

- **Homebrew:** once a release that contains the tool is published, add this
  line to `Casks/fanbar.rb`. Adding it earlier breaks installs of releases
  without it:

  ```ruby
  binary "#{appdir}/FanBar.app/Contents/Helpers/fanbar"
  ```

Every method links into the app rather than copying the tool, so Sparkle
updates the CLI together with the app.

## Design

```
fanbar ──JSON over ~/Library/Application Support/FanBar/cli.sock──▶ FanBar.app ──XPC──▶ root helper
```

- **The tool never talks to the root helper.** The helper only trusts the
  signed app, restores macOS control when its last client disconnects, and has
  no notion of curves. A CLI that connected to it directly would lose control
  the moment it exited.
- **One request per connection.** Each side writes one newline-terminated JSON
  message, capped at 64 KB (`FanBarCLIContract` in `FanBarShared`). Requests
  carry a protocol version, and the app refuses a version it does not speak.
- **Access control.** The socket's directory is created `0700` and the socket
  `0600`. Every connection's peer must also be the app's own user
  (`getpeereid`), so the CLI can do nothing that user could not already do from
  the menu panel.
- **Same code path as the panel.** `CLICommandHandler` calls the controller's
  own entry points (`setCoolingPreset`, `setCustomFixedRPM`, …), waits for the
  switch to finish, and only then reports success. `--hold` sets the session's
  restore duration to *Never*. Without it, the session returns to the Settings
  default.
- **Naming.** The executable cannot sit at `Contents/MacOS/fanbar`, because it
  would be the same file as `Contents/MacOS/FanBar` on a case-insensitive
  volume. For the same reason the SwiftPM product is `FanBarCLI`.
