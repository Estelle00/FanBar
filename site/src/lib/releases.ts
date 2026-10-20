import { getCollection, type CollectionEntry } from "astro:content";
import type { FullLocale, Locale } from "./i18n";
import { siteUrl } from "./seo";

export type ReleaseEntry = CollectionEntry<"releases">;

export const releasesPath = (locale: FullLocale) => (locale === "zh" ? "/zh/releases" : "/releases");
export const releasePath = (locale: FullLocale, version: string) => `${releasesPath(locale)}/${version}`;
export const releasesFeedPath = "/releases.xml";

/** Newest first. */
export async function getReleases(locale: FullLocale): Promise<ReleaseEntry[]> {
  return (await getCollection("releases", (entry) => entry.data.locale === locale)).sort((a, b) =>
    b.data.publishedAt.localeCompare(a.data.publishedAt),
  );
}

const dateLocales: Record<Locale, string> = {
  en: "en-US",
  zh: "zh-CN",
  "zh-tw": "zh-TW",
  ja: "ja-JP",
  ru: "ru-RU",
  fr: "fr-FR",
};

export function formatReleaseDate(iso: string, locale: Locale): string {
  return new Date(iso).toLocaleDateString(dateLocales[locale], { year: "numeric", month: "long", day: "numeric", timeZone: "UTC" });
}

export function assetLabel(name: string): string {
  if (name.includes("arm64")) return "Apple Silicon";
  if (name.includes("x86_64")) return "Intel";
  return "Universal";
}

export const formatSize = (bytes: number) => `${(bytes / 1_000_000).toFixed(1)} MB`;

export const releaseCopy = {
  en: {
    indexTitle: "FanBar Release Notes — What's New in Each Version",
    indexDescription: "Every FanBar release, newest first: new features, fixes, and downloads for Apple Silicon and Intel Macs.",
    indexHeading: "Release notes",
    indexLede: "What changed in every version of FanBar, newest first. FanBar updates itself, or you can upgrade with Homebrew.",
    label: "Release notes",
    latest: "Latest",
    breadcrumb: "Release notes",
    downloads: "Downloads",
    downloadsNote: "Not sure which one? Universal runs on every supported Mac. Each file has a matching .sha256 checksum on GitHub.",
    viewOnGitHub: "View on GitHub",
    olderNewer: { newer: "Newer", older: "Older" },
    allReleases: "All release notes",
    untranslated: "",
    feed: "RSS feed",
    updating: "Already installed? FanBar checks for updates daily, or run",
  },
  zh: {
    indexTitle: "FanBar 更新日志 — 每个版本的新功能与修复",
    indexDescription: "FanBar 所有版本的更新说明，按时间倒序：新功能、问题修复，以及 Apple Silicon 和 Intel Mac 的下载。",
    indexHeading: "更新日志",
    indexLede: "FanBar 每个版本的变化，最新的在最前面。FanBar 会自动检查更新，也可以用 Homebrew 升级。",
    label: "更新说明",
    latest: "最新版本",
    breadcrumb: "更新日志",
    downloads: "下载",
    downloadsNote: "不确定选哪个？Universal 版本适用于所有支持的 Mac。每个文件在 GitHub 上都有对应的 .sha256 校验文件。",
    viewOnGitHub: "在 GitHub 查看",
    olderNewer: { newer: "较新版本", older: "较旧版本" },
    allReleases: "全部更新日志",
    untranslated: "此版本仅有英文说明。",
    feed: "RSS 订阅",
    updating: "已经安装？FanBar 每天自动检查更新，也可以运行",
  },
} as const;

export function releaseStructuredData(entry: ReleaseEntry, description: string) {
  const { locale, version, publishedAt } = entry.data;
  const url = `${siteUrl}${releasePath(locale, version)}`;
  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "TechArticle",
        "@id": `${url}#article`,
        headline: `FanBar ${version}`,
        description,
        datePublished: publishedAt,
        dateModified: publishedAt,
        inLanguage: locale === "zh" ? "zh-Hans" : "en",
        mainEntityOfPage: url,
        author: { "@id": `${siteUrl}/#publisher` },
        publisher: { "@id": `${siteUrl}/#publisher` },
        about: {
          "@type": "SoftwareApplication",
          name: "FanBar",
          softwareVersion: version,
          operatingSystem: "macOS 11 or later",
          applicationCategory: "UtilitiesApplication",
          offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
          downloadUrl: entry.data.url,
        },
        isBasedOn: entry.data.url,
      },
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "FanBar", item: locale === "zh" ? `${siteUrl}/zh` : siteUrl },
          { "@type": "ListItem", position: 2, name: releaseCopy[locale].breadcrumb, item: `${siteUrl}${releasesPath(locale)}` },
          { "@type": "ListItem", position: 3, name: `FanBar ${version}`, item: url },
        ],
      },
    ],
  };
}
