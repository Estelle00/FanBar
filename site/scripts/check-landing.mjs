// Run after `npm run build`. Checks the actual generated download links.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const { releases } = JSON.parse(await readFile(new URL("../src/data/releases.json", import.meta.url), "utf8"));
const latest = [...releases].sort((a, b) => b.publishedAt.localeCompare(a.publishedAt))[0];
const assets = Object.fromEntries(latest.assets.map((asset) => [
  asset.name.includes("arm64") ? "arm64" : asset.name.includes("x86_64") ? "x86_64" : "universal",
  asset,
]));

for (const [locale, path] of [["en", "index.html"], ["zh", "zh/index.html"], ["zh-tw", "zh-tw/index.html"], ["ja", "ja/index.html"], ["ru", "ru/index.html"], ["fr", "fr/index.html"]]) {
  const html = await readFile(new URL(`../dist/${path}`, import.meta.url), "utf8");
  const anchors = [...html.matchAll(/<a\b[^>]*>/g)].map(([tag]) => Object.fromEntries(
    [...tag.matchAll(/([\w-]+)="([^"]*)"/g)].map(([, name, value]) => [name, value]),
  ));
  const downloads = anchors.filter((anchor) => anchor["data-track-event"] === "download-dmg");
  assert.equal(downloads.length, 12, `${locale}: expected three download pickers`);
  for (const location of ["nav", "hero", "final-cta"]) {
    const links = downloads.filter((anchor) => anchor["data-track-location"] === location);
    assert.deepEqual(links.map((anchor) => anchor["data-track-architecture"]), ["universal", "arm64", "x86_64", "universal"]);
    for (const link of links) {
      const asset = assets[link["data-track-architecture"]];
      assert.equal(link.href, asset.url);
      assert.equal(link.download, asset.name);
      assert.equal(link["data-track-locale"], locale);
      assert.equal(link["data-track-version"], latest.version);
      assert.equal(link.target, undefined);
    }
  }
  for (const name of ["view-source", "view-release-notes", "change-language"]) {
    assert(anchors.some((anchor) => anchor["data-track-event"] === name), `${locale}: missing ${name}`);
  }
  const notesPath = locale === "zh" ? "/zh/releases" : "/releases";
  for (const location of ["nav", "hero", "footer"]) {
    assert(anchors.some((anchor) => anchor.href === notesPath && anchor["data-track-event"] === "view-release-notes" && anchor["data-track-location"] === location), `${locale}: missing ${location} release notes entry`);
  }
  assert(html.includes('data-domains="getfanbar.com,www.getfanbar.com"'));
  assert(!html.includes("data-umami-event"), "Avoid duplicate automatic and manual events");
  console.log(`${locale}: direct DMGs, architecture choices, and event metadata passed (${latest.version}).`);
}

for (const locale of ["en", "zh"]) {
  const prefix = locale === "zh" ? "zh/" : "";
  const index = await readFile(new URL(`../dist/${prefix}releases/index.html`, import.meta.url), "utf8");
  assert(index.includes("<h1") && index.includes("<ol"), `${locale}: missing release history`);
  for (const release of releases) {
    const path = `/${prefix}releases/${release.version}`;
    assert(index.includes(`href="${path}"`), `${locale}: release missing from history`);
    const detail = await readFile(new URL(`../dist/${prefix}releases/${release.version}/index.html`, import.meta.url), "utf8");
    assert(detail.includes(`https://getfanbar.com${path}`));
    assert(detail.includes(`<time datetime="${release.publishedAt}">`), `${locale}: missing release date`);
    for (const asset of release.assets) {
      assert(detail.includes(`href="${asset.url}" download="${asset.name}"`), `${locale}: incorrect version download`);
    }
  }
  console.log(`${locale}: release index and ${releases.length} standalone version pages passed.`);
}
