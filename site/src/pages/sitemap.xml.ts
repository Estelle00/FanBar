import type { APIRoute } from "astro";
import { getCollection } from "astro:content";
import { alternativesUpdated } from "@/lib/alternatives";
import { getReleases } from "@/lib/releases";
import { modelPages } from "@/lib/compatibilityModels";
import { HTML_LANG, LOCALE_URLS, siteUrl } from "@/lib/seo";

export const prerender = true;

export const GET: APIRoute = async () => {
  const posts = await getCollection("blog");
  const releases = await getReleases("en");
  const releaseAlternates = (path: string) => `
    <xhtml:link rel="alternate" hreflang="en" href="${siteUrl}${path}" />
    <xhtml:link rel="alternate" hreflang="zh-Hans" href="${siteUrl}/zh${path}" />
    <xhtml:link rel="alternate" hreflang="x-default" href="${siteUrl}${path}" />`;
  const releaseUrls = [
    { path: "/releases", lastmod: releases[0]?.data.publishedAt.slice(0, 10) },
    ...releases.map((entry) => ({ path: `/releases/${entry.data.version}`, lastmod: entry.data.publishedAt.slice(0, 10) })),
  ].flatMap(({ path, lastmod }) => [`${siteUrl}${path}`, `${siteUrl}/zh${path}`].map((loc) => `  <url>
    <loc>${loc}</loc>
    <lastmod>${lastmod}</lastmod>${releaseAlternates(path)}
  </url>
`)).join("");
  const alternates = `
      <xhtml:link rel="alternate" hreflang="${HTML_LANG.en}" href="${LOCALE_URLS.en}" />
      <xhtml:link rel="alternate" hreflang="${HTML_LANG.zh}" href="${LOCALE_URLS.zh}" />
      <xhtml:link rel="alternate" hreflang="${HTML_LANG.ru}" href="${LOCALE_URLS.ru}" />
      <xhtml:link rel="alternate" hreflang="x-default" href="${LOCALE_URLS.en}" />`;
  const body = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
  <url>
    <loc>${LOCALE_URLS.en}</loc>${alternates}
  </url>
  <url>
    <loc>${LOCALE_URLS.zh}</loc>${alternates}
  </url>
  <url>
    <loc>${LOCALE_URLS.ru}</loc>${alternates}
  </url>
  <url>
    <loc>${siteUrl}/is-fanbar-safe</loc>
    <lastmod>2026-10-15</lastmod>
    <xhtml:link rel="alternate" hreflang="en" href="${siteUrl}/is-fanbar-safe" />
    <xhtml:link rel="alternate" hreflang="zh-Hans" href="${siteUrl}/zh/is-fanbar-safe" />
    <xhtml:link rel="alternate" hreflang="x-default" href="${siteUrl}/is-fanbar-safe" />
  </url>
  <url>
    <loc>${siteUrl}/zh/is-fanbar-safe</loc>
    <lastmod>2026-10-15</lastmod>
    <xhtml:link rel="alternate" hreflang="en" href="${siteUrl}/is-fanbar-safe" />
    <xhtml:link rel="alternate" hreflang="zh-Hans" href="${siteUrl}/zh/is-fanbar-safe" />
    <xhtml:link rel="alternate" hreflang="x-default" href="${siteUrl}/is-fanbar-safe" />
  </url>
  <url>
    <loc>${siteUrl}/compare/macs-fan-control</loc>
    <lastmod>2026-10-11</lastmod>
    <xhtml:link rel="alternate" hreflang="en" href="${siteUrl}/compare/macs-fan-control" />
    <xhtml:link rel="alternate" hreflang="zh-Hans" href="${siteUrl}/zh/compare/macs-fan-control" />
    <xhtml:link rel="alternate" hreflang="x-default" href="${siteUrl}/compare/macs-fan-control" />
  </url>
  <url>
    <loc>${siteUrl}/zh/compare/macs-fan-control</loc>
    <lastmod>2026-10-11</lastmod>
    <xhtml:link rel="alternate" hreflang="en" href="${siteUrl}/compare/macs-fan-control" />
    <xhtml:link rel="alternate" hreflang="zh-Hans" href="${siteUrl}/zh/compare/macs-fan-control" />
    <xhtml:link rel="alternate" hreflang="x-default" href="${siteUrl}/compare/macs-fan-control" />
  </url>
  <url>
    <loc>${siteUrl}/compatibility</loc>
    <lastmod>2026-10-11</lastmod>
    <xhtml:link rel="alternate" hreflang="en" href="${siteUrl}/compatibility" />
    <xhtml:link rel="alternate" hreflang="zh-Hans" href="${siteUrl}/zh/compatibility" />
    <xhtml:link rel="alternate" hreflang="x-default" href="${siteUrl}/compatibility" />
  </url>
  <url>
    <loc>${siteUrl}/zh/compatibility</loc>
    <lastmod>2026-10-11</lastmod>
    <xhtml:link rel="alternate" hreflang="en" href="${siteUrl}/compatibility" />
    <xhtml:link rel="alternate" hreflang="zh-Hans" href="${siteUrl}/zh/compatibility" />
    <xhtml:link rel="alternate" hreflang="x-default" href="${siteUrl}/compatibility" />
  </url>
${releaseUrls}  <url>
    <loc>${siteUrl}/alternatives</loc>
    <lastmod>${alternativesUpdated}</lastmod>
  </url>
  <url>
    <loc>${siteUrl}/blog</loc>
    <lastmod>${posts.map((post) => post.data.updatedOn).sort().at(-1)}</lastmod>
  </url>
${posts
  .map((post) => `  <url>
    <loc>${siteUrl}/blog/${post.id}</loc>
    <lastmod>${post.data.updatedOn}</lastmod>
  </url>
`)
  .join("")}${modelPages
  .map((model) => `  <url>
    <loc>${model.url}</loc>
    <lastmod>${model.updatedOn}</lastmod>
  </url>
`)
  .join("")}  <url>
    <loc>${siteUrl}/api</loc>
    <lastmod>2026-10-12</lastmod>
  </url>
</urlset>
`;

  return new Response(body, {
    headers: { "Content-Type": "application/xml; charset=utf-8" },
  });
};
