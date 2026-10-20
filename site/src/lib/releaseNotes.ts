// Turns FanBar's bilingual GitHub release bodies into one Markdown document per
// language. Release notes pair each Chinese line with an English line:
//
//   ### 修复 / Fixes
//   - **中文标题** — 中文说明 (#64)
//     **English title** — English description (#64)
//
// Early releases are English-only; those are returned unchanged for both
// languages with `translated: false`.

import type { FullLocale } from "./i18n";

export interface SplitNotes {
  en: string;
  zh: string;
  translated: boolean;
}

const cjk = /[㐀-鿿豈-﫿]/g;

// Lines with a Chinese name inside English prose ("Thanks to **倾藏**") must
// still count as English, so classify by the share of CJK characters.
function isChinese(line: string): boolean {
  const letters = line.replace(/[\s\p{P}\p{S}\d]/gu, "");
  if (!letters) return false;
  return (line.match(cjk)?.length ?? 0) / letters.length > 0.3;
}

function linkReferences(markdown: string, repository: string): string {
  return markdown
    .replace(/(^|[\s(（])#(\d+)\b/g, `$1[#$2](https://github.com/${repository}/issues/$2)`)
    .replace(/(^|[\s(（])@([A-Za-z0-9-]{1,39})\b/g, `$1[@$2](https://github.com/$2)`);
}

const dropHeading = /^#{2,3}\s*(安装|Install)/i;
const dropLine = /^\*\*Full Changelog\*\*/;

export function splitReleaseNotes(body: string, repository: string): SplitNotes {
  const lines = body.split("\n");
  const translated = lines.some((line) => /^#{2,3}\s.+\s\/\s.+/.test(line) || /^ {2}\S/.test(line));

  if (!translated) {
    const kept = lines.filter((line) => !dropLine.test(line)).join("\n").trim();
    const markdown = linkReferences(kept.replace(/^## /gm, "### ").replace(/^### /gm, "## "), repository);
    return { en: markdown, zh: markdown, translated: false };
  }

  const en: string[] = [];
  const zh: string[] = [];
  let skipping = false;

  for (let index = 0; index < lines.length; index++) {
    const line = lines[index];

    const heading = line.match(/^#{2,3}\s+(.+?)\s*\/\s*(.+)$/);
    if (heading || /^#{2,3}\s/.test(line)) {
      skipping = dropHeading.test(line);
      if (skipping) continue;
      if (heading) {
        zh.push("", `## ${heading[1]}`, "");
        en.push("", `## ${heading[2]}`, "");
      } else {
        const text = line.replace(/^#+\s*/, "");
        en.push("", `## ${text}`, "");
        zh.push("", `## ${text}`, "");
      }
      continue;
    }
    if (skipping || dropLine.test(line)) continue;
    if (!line.trim()) continue;

    // A Chinese bullet followed by its indented English translation.
    if (line.startsWith("- ") && /^ {2}\S/.test(lines[index + 1] ?? "")) {
      zh.push(line);
      en.push(`- ${lines[index + 1].trim()}`);
      index++;
      continue;
    }

    (isChinese(line) ? zh : en).push(line);
  }

  const tidy = (out: string[]) => linkReferences(out.join("\n").replace(/\n{3,}/g, "\n\n").trim(), repository);
  return { en: tidy(en), zh: tidy(zh), translated: true };
}

/** Bold item titles ("**Lower memory use** — …"), for summaries and meta descriptions. */
export function highlightTitles(markdown: string, limit = 4): string[] {
  return [...markdown.matchAll(/^- \*\*(.+?)\*\*/gm)].map((match) => match[1]).slice(0, limit);
}

export function releaseDescription(locale: FullLocale, version: string, markdown: string): string {
  const titles = highlightTitles(markdown, 3);
  if (locale === "zh") {
    return titles.length
      ? `FanBar ${version} 更新内容：${titles.join("；")}。查看完整说明与下载。`
      : `FanBar ${version} 更新说明与下载。`;
  }
  return titles.length
    ? `What's new in FanBar ${version}: ${titles.join("; ")}. Full release notes and downloads.`
    : `FanBar ${version} release notes and downloads.`;
}
