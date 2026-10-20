---
title: "Mac Fan Running Constantly at Idle? How to Tell Normal From a Problem"
description: "Is your Mac fan running all the time, even when idle? Learn which Macs keep their fans spinning by design, how to compare the current speed with the fan's minimum, and what to check when it's genuinely too high."
answer: "It depends on the Mac. Intel Macs and many desktop Macs keep their fans turning slowly all the time, so that part is normal. It's a problem when the speed at idle is well above the fan's own minimum — then look for background work, a warm environment, or a fan app that left a raised speed in place."
publishedOn: "2026-10-15"
updatedOn: "2026-10-15"
keywords:
  - mac fan running constantly
  - mac fan running at idle
  - macbook fan always on
  - mac fan won't stop
  - mac mini fan always running
---

"My fan never stops" can describe a perfectly healthy Mac or a real problem. The way to tell them apart is to stop listening and start measuring.

## First: should your fan ever stop?

Not every Mac turns its fans off.

- **Apple Silicon MacBook Pro.** Fans can drop to 0 RPM when the chip is cool, so a completely silent idle is normal. Fans that never stop on these models are worth checking.
- **Intel Macs.** The fans always run at a minimum speed. A constant low hum is expected.
- **Desktop Macs** such as Mac mini and Mac Studio. Many keep a fan turning slowly all the time to keep air moving through a small enclosure.
- **MacBook Air with Apple Silicon.** No fan at all.

So "running constantly" on its own isn't a symptom. **Running constantly well above its minimum speed** is.

## Compare the current speed with the fan's minimum

Every Mac fan reports a minimum and maximum speed to macOS. On the 16-inch MacBook Pro we test on, for example, the two fans report ranges of 1,350–5,349 RPM and 1,522–5,777 RPM.

The rule of thumb:

- **At or near the minimum** (or 0 on a MacBook Pro that can stop): normal idle behavior. If it bothers you, it's a noise preference, not a fault.
- **Clearly above the minimum while you're doing nothing:** something is producing heat or holding the fan up. Keep reading.

macOS doesn't show fan speeds anywhere. You need a utility that reads them; [FanBar](/) shows each fan's current speed next to its range, and it's free.

## If the fan is above its minimum at idle

### 1. Background work you can't see

Idle doesn't always mean idle. Open **Activity Monitor**, choose the **CPU** tab, and sort by **% CPU**. Common hidden workloads:

- Spotlight indexing (`mds_stores`, `mdworker`) after an update or migration
- Photos analysis (`photoanalysisd`, `mediaanalysisd`) after importing photos
- Time Machine (`backupd`), cloud sync clients, and antivirus scans
- A browser tab still running video or a web app in the background

These usually finish on their own. Leave the Mac awake and plugged in, and the fan should settle.

### 2. A fan app that left a speed in place

This is one we see as fan-control developers. Some fan utilities apply a **raised minimum speed** that stays in effect until the app is told to stop, even after you forget it's installed. If you've ever used a fan control app:

1. Open it and switch back to automatic or system control.
2. If you no longer use it, quit and uninstall it.
3. Restart. On Intel Macs, [resetting the SMC](https://support.apple.com/102605) also clears leftover fan settings; on Apple Silicon, Apple says the SMC resets automatically, so a restart is enough.

FanBar is designed not to leave anything behind. It hands control back to macOS when you quit it, when its connection drops, or when a timed preset ends. You can see [exactly what its helper can and can't do](/is-fanbar-safe).

### 3. Heat from outside the chip

- A warm room, direct sunlight, or a desk under a window
- Vents blocked by a soft surface or by the Mac sitting flush against a wall
- Charging while in use
- External displays keeping the GPU busy

### 4. A sensor or hardware fault

If the fan stays high after a restart, in a cool room, with nothing in Activity Monitor and no fan apps running, the Mac may be reacting to a faulty temperature reading or a failing fan. Run **Apple Diagnostics**. On Apple Silicon, shut down, press and hold the power button until startup options appear, then press Command-D. On Intel, hold D during startup. Book a repair if it reports a problem or if you hear grinding or clicking.

## Want it quieter at idle anyway?

If your fan is at its minimum and you'd still prefer silence, that's where fan control becomes a choice rather than a fix. On a MacBook Pro that supports 0 RPM, a temperature curve in FanBar can keep the fans stopped while the chip is cool and bring them in gently as it warms. Targets always stay inside each fan's reported range, and macOS keeps its own thermal protection regardless of the setting.

## FAQ

**Is it bad if my Mac fan runs all the time?**
Not if it's at its minimum speed. Fans are designed to run continuously. Constantly high speeds are worth investigating because they usually point to heat you could remove.

**Why does my Mac mini fan never stop?**
Many desktop Macs keep a fan turning slowly as normal behavior. Check that the speed is near the fan's reported minimum; if it is, nothing is wrong.

**My MacBook Pro fan used to stop and now it doesn't. Why?**
Most often a background task is keeping the chip warm, such as indexing after an update, or a previously used fan app left a raised minimum. Work through the steps above in order.
