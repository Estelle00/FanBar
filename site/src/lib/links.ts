// Shared URLs and localized image assets. Text lives in src/lib/i18n.ts.
import type { Locale } from "./i18n";
import screenshotSnapshot from "../data/screenshots.json";

export const github = "https://github.com/helson-lin/FanBar";
export const releases = "https://github.com/helson-lin/FanBar/releases/latest";

export function getHeroScreenshot(locale: Locale) {
  const asset = getScreenshotAssets(locale).popover;
  const base = asset.src.replace(/\.webp$/, "");
  return {
    ...asset,
    avifSrcSet: `${base}-456.avif 456w, ${base}.avif ${asset.width}w`,
    webpSrcSet: `${base}-456.webp 456w, ${asset.src} ${asset.width}w`,
    sizes: "(max-width: 767px) 300px, 430px",
    preloadSrc: `${base}.avif`,
  };
}

export const highlightKeys = [
  "status",
  "icons",
  "widget",
  "live",
  "resources",
  "modes",
  "curves",
  "source",
  "alerts",
  "log",
  "safe",
  "language",
] as const;

export type HighlightKey = (typeof highlightKeys)[number];

export const highlightIcons = {
  status: "activity",
  icons: "fan",
  widget: "layoutGrid",
  live: "activityChart",
  resources: "gauge",
  modes: "slidersHorizontal",
  curves: "waypoints",
  source: "thermometer",
  alerts: "bellRing",
  log: "fileSpreadsheet",
  safe: "shieldCheck",
  language: "languages",
} as const satisfies Record<HighlightKey, string>;

export const screenshotKeys = ["popover", "cooling", "menubar"] as const;

export type ScreenshotKey = (typeof screenshotKeys)[number];

export function getScreenshotAssets(locale: Locale): Record<
  ScreenshotKey,
  { src: string; width: number; height: number }
> {
  return screenshotSnapshot.images[locale];
}
