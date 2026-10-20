# Is FanBar Safe? What the Mac Fan Control Helper Can and Can't Do

Canonical page: https://getfanbar.com/is-fanbar-safe · Checked against the source on 2026-10-15 · Written by the FanBar maintainers.

**Short answer: yes.** FanBar only reads sensors until you turn on manual control. When you do, a small open-source helper sets fan targets inside each fan's hardware limits and nothing else. Every release is signed with a Developer ID and notarized by Apple.

## Will FanBar damage my fans or overheat my Mac?

- **Speeds stay inside the hardware range.** The helper reads each fan's reported minimum and maximum and clamps every target to that range. The one deliberate exception: a curve's coolest segment can request 0 RPM idle, the same state Apple Silicon Macs use on their own when cool.
- **macOS thermal protection is untouched.** FanBar only writes fan mode and fan target values. macOS performance throttling and the hardware's critical-temperature shutdown keep working whatever the fans are set to.
- **Bad input is rejected at the root boundary.** Negative or non-finite RPM values and curve fractions outside 0–100% are refused, even from a tampered client.
- **Optional high-temperature alerts** at 90 °C for CPU or GPU.

FanBar hands control back to macOS when you choose Automatic or a timed preset expires (15 min, 30 min, 1 hour); when you quit FanBar or the last app connection to the helper closes; when the helper shuts down; and when a write to one of several fans fails (the whole Mac is rolled back).

Running fans at full speed for long periods mostly costs noise and some extra wear. For everyday use, Automatic or a temperature curve is the better choice.

## What the root helper can and cannot do

`FanBar.app → signed XPC → FanBarHelper (root) → AppleSMC fan keys`

Changing fan speed on macOS requires root access to AppleSMC; reading temperatures does not. The helper is installed only when you enable manual control and approve it in macOS.

The helper can:

- Read fan count, current speed, and each fan's minimum and maximum
- Set a target RPM, a preset, or a curve fraction, all clamped to the fan's range
- Restore macOS automatic fan control

The helper cannot:

- Write arbitrary SMC keys (its interface has no general-purpose write)
- Run commands, read files, or reach the network (it has no code for any of them)
- Take orders from other apps (it only accepts clients signed by the same Apple Developer team as FanBar)
- Keep manual control after FanBar disconnects

## Verify it yourself

1. Confirm Apple notarization: `spctl -a -vv /Applications/FanBar.app` should print `accepted` and `source=Notarized Developer ID`, origin `Developer ID Application: JiangLin He (64S5F787T9)`.
2. Read the code that runs as root:
   - https://github.com/helson-lin/FanBar/blob/main/Sources/FanBarHelper/FanBarHelperService.swift
   - https://github.com/helson-lin/FanBar/blob/main/Sources/FanBarHelper/SMCFanDriver.swift
   - https://github.com/helson-lin/FanBar/blob/main/Sources/FanBarShared/FanCoolingTarget.swift
3. Network: the app has no account, ads, or analytics. A daily Sparkle update check against GitHub Releases (updates must pass Apple notarization and FanBar's EdDSA signature), plus compatibility reports only if you review and confirm one.

## How to turn it off or remove it

- **Back to macOS control:** choose Automatic in the menu-bar popover.
- **Disable the helper (macOS 13+):** System Settings → General → Login Items & Extensions → turn FanBar off under “Allow in the Background”.
- **Uninstall (Homebrew):** quit FanBar, then `brew uninstall --cask --zap helson-lin/fanbar/fanbar`. This also unloads the helper.

## FAQ

**Is FanBar safe to use?** Yes. By default FanBar only reads temperatures and fan speeds while macOS manages cooling. Manual control requires explicit approval of a signed helper that can only set fan targets inside each fan's hardware range. FanBar is GPL-3.0 open source and every release is notarized by Apple.

**Can FanBar damage my Mac's fans?** Targets are clamped to each fan's reported minimum and maximum, so FanBar cannot push a fan beyond its rated range. The only exception is an intentional 0 RPM idle on the coolest part of a curve, matching what Apple Silicon Macs do themselves.

**Can a wrong fan setting overheat my Mac?** FanBar does not change macOS thermal management; macOS still throttles and the hardware still shuts down at critical temperatures. Optional alerts fire at 90 °C.

**Why does FanBar need administrator approval?** macOS only allows root processes to change fan speeds through AppleSMC. Approval is requested only when you enable manual control; monitoring works without it.

**Does FanBar collect my data?** The app has no account, analytics, or advertising. Only a daily update check and, if you choose, a reviewed compatibility report without serial numbers or unique identifiers.

**Is FanBar a virus or malware?** No. It is Developer ID-signed, notarized by Apple, and its full source, including the privileged helper, is public on GitHub.

- Download: https://github.com/helson-lin/FanBar/releases/latest
- Source: https://github.com/helson-lin/FanBar
