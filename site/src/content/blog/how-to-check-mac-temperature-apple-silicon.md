---
title: "How to Check Mac Temperature on Apple Silicon (What Actually Works)"
description: "macOS doesn't show CPU temperature, and the old powermetrics smc command doesn't exist on Apple Silicon. Here's what the built-in tools can tell you, how to read real CPU, GPU, SSD, and battery temperatures, and what the numbers mean."
answer: "macOS has no built-in temperature readout, and the often-quoted `sudo powermetrics --samplers smc` doesn't exist on Apple Silicon. Built-in tools only report thermal pressure. To see actual CPU, GPU, SSD, and battery temperatures, use a menu-bar utility that reads the Mac's sensors, such as the free, open-source FanBar."
publishedOn: "2026-10-15"
updatedOn: "2026-10-15"
keywords:
  - how to check mac temperature apple silicon
  - check cpu temperature mac m1 m2 m3 m4
  - mac temperature monitor
  - powermetrics temperature apple silicon
  - macbook temperature check
---

Search for how to check your Mac's temperature and you'll find the same command copied across years of guides: `sudo powermetrics --samplers smc`. On an Apple Silicon Mac it doesn't work. Here's what does, tested on an M2 Max MacBook Pro running macOS 27.

## Why the old command fails

`powermetrics` is a real Apple tool, but on Apple Silicon it has no `smc` sampler. Run `powermetrics -h` and the list of samplers includes `cpu_power`, `gpu_power`, and `thermal`, but not `smc`. That sampler only existed on Intel Macs, which is where those guides came from.

## What the built-in tools can tell you

macOS doesn't show temperatures in Activity Monitor or System Settings. What it does expose is **thermal pressure**: whether the system is under enough heat stress to start limiting performance.

### `powermetrics --samplers thermal`

```sh
sudo powermetrics --samplers thermal -n 1
```

This prints the current thermal pressure level, such as `Nominal`. It doesn't give degrees, but it answers the question you usually care about: is my Mac hot enough to slow down?

### `pmset -g therm`

```sh
pmset -g therm
```

No administrator password needed. On a Mac that hasn't hit thermal limits, it reports that no thermal warning level has been recorded. If you see a performance warning here during heavy work, the Mac was throttling.

## How to see actual temperatures

To read degrees, you need an app that reads the Mac's sensors directly. Apple doesn't document the sensor names, and they differ between chip generations, so these apps maintain their own mappings.

With [FanBar](/), which is free and open source:

1. [Download the latest release](https://github.com/helson-lin/FanBar/releases/latest) and open it. It lives in the menu bar.
2. Click the menu-bar item. The popover shows **CPU, GPU, SSD, and battery** temperatures with a history chart that spans 10 minutes to an hour, alongside each fan's speed.
3. To keep a temperature visible at all times, choose what the menu-bar item shows in **Settings → Appearance**.

Reading temperatures needs no special permission. FanBar only asks for administrator approval if you later choose to control the fans yourself, and you can [see exactly what that permission allows](/is-fanbar-safe).

Other options exist: Stats is a free, open-source system monitor, and TG Pro and iStat Menus are paid apps with broader features. We compare them in [Macs Fan Control alternatives](/alternatives).

## What the numbers mean

Temperatures depend on the chip, the workload, and the room, so treat any single number with caution. For reference, here's one of our own readings from a 16-inch MacBook Pro with M2 Max during light use (browser, editor, chat):

| Sensor | Reading |
| --- | --- |
| CPU | 54 °C |
| GPU | 51 °C |
| SSD | 32 °C |
| Battery | 31 °C |

Some general guidance:

- **CPU and GPU** rise quickly under load and fall quickly after. High readings during an export, a game, or a compile are expected. Apple Silicon is designed to run hot under sustained work, and macOS slows the chip down before heat becomes harmful.
- **The trend matters more than the peak.** A chip that's hot while idle points to a background process; check Activity Monitor.
- **Battery** temperature moves slowly and is worth watching while charging. Sustained heat is hard on battery health over time.
- **SSD** temperature mostly tracks long file transfers and the temperature inside the case.

If thermal pressure regularly leaves `Nominal` during work you care about, raising the fan speed before the heavy task can help the Mac hold its performance. That's the kind of control FanBar adds on top of monitoring, within each fan's hardware limits.

## FAQ

**Can I check Mac CPU temperature without installing anything?**
Not in degrees. Built-in tools (`powermetrics --samplers thermal` and `pmset -g therm`) report thermal pressure and thermal warnings, not temperatures.

**Does Activity Monitor show temperature?**
No. It shows CPU, GPU, memory, energy, disk, and network usage, which helps you find the cause of heat, but not the temperature itself.

**Why do different apps show different temperatures?**
Each app chooses which of the many sensors to show, and some average several of them. Compare trends within one app rather than exact numbers across apps.

**Do I need to grant permissions to read temperatures?**
Not with FanBar. Monitoring works without approval; the privileged helper is only needed for fan control.
