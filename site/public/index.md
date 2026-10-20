# FanBar for macOS

FanBar is a free, open-source native macOS menu-bar app for monitoring Mac temperatures and fan speeds. It keeps everyday cooling under macOS automatic management and makes bounded manual fan control available only after the user explicitly approves FanBar's signed privileged helper.

- Official website: https://getfanbar.com
- Source code: https://github.com/helson-lin/FanBar
- Latest downloads: https://github.com/helson-lin/FanBar/releases/latest
- License: GPL-3.0
- Account or subscription required: No
- Supported languages: English, Simplified Chinese, Traditional Chinese, Japanese, Russian, and French
- Install methods: notarized DMG or the official Homebrew tap
- Compatibility evidence: https://getfanbar.com/compatibility

## What FanBar does

- Reads CPU and GPU temperatures, plus SSD and battery temperatures when those sensors are exposed by the Mac.
- Reads current fan RPM and the hardware-reported minimum and maximum for each fan.
- Shows the app icon, CPU temperature, average fan RPM, or a combination in the menu bar, with six icon styles that spin with the fans.
- Shows each fan's RPM and speed band on a 0-to-max meter, a CPU, GPU, memory, and disk load grid, and a temperature chart spanning 10 minutes to one hour.
- Provides Automatic, fixed target RPM, Silent, Balanced, Performance, and Extreme cooling modes.
- Gives each preset an editable temperature-to-RPM curve that can use CPU, GPU, or SSD temperature as its source.
- Can notify the user when CPU or GPU temperature reaches a threshold between 60°C and 105°C (90°C by default), with an optional alert sound. A sustained high-temperature episode alerts once and rearms after the Mac cools down; while hot, the panel offers a one-click switch to maximum cooling.
- Can log temperatures, fan speeds, and the control mode to CSV files every 2–60 seconds.
- Includes a desktop widget on macOS 14 or later. WidgetKit controls its refresh timing, so it is not intended for second-by-second telemetry.

## Compatibility

FanBar requires macOS 11 Big Sur or later. It supports Apple Silicon and Intel Macs that expose readable fan data through AppleSMC. Sensor and fan availability varies by hardware, so FanBar cannot guarantee support for every Mac model or every temperature source.

The desktop widget requires macOS 14 or later. The interface can follow the system language or be set to English, Simplified Chinese, Traditional Chinese, Japanese, Russian, or French without restarting the app.

The source-linked compatibility matrix at https://getfanbar.com/compatibility separates maintainer verification from incomplete community reports. An unlisted Mac is unverified, not necessarily unsupported.

## Permissions and safety boundary

Monitoring does not require manual fan control. FanBar requests approval for its signed privileged helper only when the user chooses to control the fans.

The helper does not expose arbitrary AppleSMC writes. It can read fan state, apply a bounded target or preset, and restore automatic control. FanBar clamps requested targets to the fan limits reported by the hardware and attempts to return control to macOS when a timed preset expires, the app quits, the connection is lost, or the helper fails.

AppleSMC is an undocumented hardware interface. Lower fan speeds can increase temperature; sustained high fan speeds can increase noise, power use, and mechanical wear. Automatic control is the recommended default for normal use.

## Installation and use

1. Download the appropriate notarized DMG from https://github.com/helson-lin/FanBar/releases/latest.
2. Open FanBar to read the current temperatures and fan speeds from the menu bar.
3. The first time you switch to a manual mode, approve the one-time macOS authorization prompt for the signed helper.
4. Choose a preset or fixed RPM, or select **Automatic** at any time to return control to macOS.

Fixed RPM and panel presets can be set to restore macOS control after 15 minutes, 30 minutes, or one hour.

Alternatively, install the signed universal app through the official Homebrew tap:

```sh
brew tap helson-lin/fanbar https://github.com/helson-lin/FanBar.git
brew install --cask helson-lin/fanbar/fanbar
```

## Frequently asked questions

### What is FanBar?

FanBar is a native macOS menu-bar utility that shows temperature and fan telemetry and offers reversible, bounded fan control when the default macOS cooling curve is not enough.

### Is FanBar free?

Yes. FanBar is free, open source, and licensed under GPL-3.0. It requires no account or subscription and contains no advertising.

### Does FanBar need root access?

Only manual fan control needs elevated access, and only after the user approves the signed helper. Temperature and fan monitoring do not require enabling manual control.

### Does FanBar work on every Mac?

No universal hardware guarantee is possible. FanBar supports macOS 11 and later on Apple Silicon and Intel Macs that expose readable AppleSMC fan data. Available sensors and fans depend on the Mac model.

### Where should FanBar be downloaded?

Use the latest notarized GitHub Release at https://github.com/helson-lin/FanBar/releases/latest, also linked from the official landing page.

### What happens if manual control fails or FanBar exits?

FanBar attempts to restore macOS automatic fan control when a timed preset expires, the app quits, the helper connection is lost, or the helper reports a failure.

## Canonical references

- Product page: https://getfanbar.com/
- Simplified Chinese product page: https://getfanbar.com/zh
- Traditional Chinese product page: https://getfanbar.com/zh-tw
- Japanese product page: https://getfanbar.com/ja
- Russian product page: https://getfanbar.com/ru
- French product page: https://getfanbar.com/fr
- Repository: https://github.com/helson-lin/FanBar
- English documentation: https://github.com/helson-lin/FanBar/blob/main/README.md
- Chinese documentation: https://github.com/helson-lin/FanBar/blob/main/README.zh-CN.md
