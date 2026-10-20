import type { APIRoute } from "astro";
import { getReleases, releasePath } from "@/lib/releases";
import { siteUrl } from "@/lib/seo";

export const prerender = true;

const escape = (text: string) =>
  text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

export const GET: APIRoute = async () => {
  const releases = await getReleases("en");
  const items = releases
    .map((entry) => {
      const link = `${siteUrl}${releasePath("en", entry.data.version)}`;
      const summary = entry.data.highlights.length ? entry.data.highlights.join("; ") : `FanBar ${entry.data.version}`;
      return `    <item>
      <title>FanBar ${escape(entry.data.version)}</title>
      <link>${link}</link>
      <guid isPermaLink="true">${link}</guid>
      <pubDate>${new Date(entry.data.publishedAt).toUTCString()}</pubDate>
      <description>${escape(summary)}</description>
      <content:encoded><![CDATA[${entry.rendered?.html ?? ""}]]></content:encoded>
    </item>`;
    })
    .join("\n");

  const body = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel>
    <title>FanBar release notes</title>
    <link>${siteUrl}/releases</link>
    <atom:link href="${siteUrl}/releases.xml" rel="self" type="application/rss+xml" />
    <description>New versions of FanBar, the free, open-source Mac fan control app.</description>
    <language>en</language>
    <lastBuildDate>${new Date(releases[0]?.data.publishedAt ?? Date.now()).toUTCString()}</lastBuildDate>
${items}
  </channel>
</rss>
`;
  return new Response(body, { headers: { "Content-Type": "application/rss+xml; charset=utf-8" } });
};
