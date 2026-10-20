# Landing page screenshots

The hero and interface gallery use the real macOS captures of FanBar 0.6.3 from
upstream `main` at commit [`3e7d3a7`](https://github.com/helson-lin/FanBar/tree/3e7d3a7525b429a30b957d7f690a245e8e61f651/docs/screenshots).
The popover is the two-fan MacBook Pro capture with Balanced active, so both fan
meters show live speeds; Cooling and Appearance come from the Mac mini set. Every
locale (English, Simplified and Traditional Chinese, Japanese, Russian, French)
uses its own native-language captures.

Run `npm run assets:optimize` from `site/` to regenerate the published WebP images
and responsive AVIF/WebP hero variants. `src/data/screenshots.json` records the
source commit, Git blob hashes, original dimensions, and published paths. The
script reuses local PNGs only when their hashes match, otherwise it fetches the
originals at the pinned upstream commit. It preserves the transparent window
shadows and never alters interface text or sensor readings.

Published filenames include the source revision so browsers cannot reuse older
screenshots after an update. Generated assets live in `public/screenshots/`, so
deployment only needs the `site/` directory and does not fetch screenshots.

`src/lib/links.ts` shares the image paths and dimensions between the hero, gallery,
image preload, and search metadata. To update screenshots again, refresh the
manifest from the latest upstream `main` and regenerate the assets.
