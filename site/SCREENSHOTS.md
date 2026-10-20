# Landing page screenshots

The hero and interface gallery use the real macOS captures from upstream `main`
at commit [`e1fb03f`](https://github.com/helson-lin/FanBar/tree/e1fb03f4013dcbbe26177527f5eae627ba5d1393/docs/screenshots).
These include the custom-preset entry point in Cooling settings. English,
Simplified Chinese, and Russian pages each use matching native-language captures.

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
