import type { CollectionEntry } from "astro:content";
import { github } from "./links";
import { siteUrl } from "./seo";

export const blogUrl = `${siteUrl}/blog`;
export const postUrl = (id: string) => `${blogUrl}/${id}`;

export function formatPostDate(iso: string): string {
  return new Date(`${iso}T00:00:00Z`).toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
    timeZone: "UTC",
  });
}

// Frontmatter answers may contain `inline code`; escape first, then mark it up.
export function inlineCodeHtml(text: string): string {
  const escaped = text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  return escaped.replace(/`([^`]+)`/g, "<code>$1</code>");
}

const plain = (text: string) => text.replace(/`/g, "");

export function postStructuredData(post: CollectionEntry<"blog">) {
  const url = postUrl(post.id);
  const publisherId = `${siteUrl}/#publisher`;
  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        "@id": publisherId,
        name: "FanBar",
        url: siteUrl,
        logo: { "@type": "ImageObject", url: `${siteUrl}/icon-512.png`, width: 512, height: 512 },
        sameAs: [github],
      },
      {
        "@type": "BlogPosting",
        "@id": `${url}#article`,
        headline: post.data.title,
        description: post.data.description,
        abstract: plain(post.data.answer),
        datePublished: post.data.publishedOn,
        dateModified: post.data.updatedOn,
        inLanguage: "en",
        keywords: post.data.keywords,
        mainEntityOfPage: url,
        author: { "@id": publisherId },
        publisher: { "@id": publisherId },
        image: `${siteUrl}/social/fanbar-og.png`,
      },
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "FanBar", item: siteUrl },
          { "@type": "ListItem", position: 2, name: "Blog", item: blogUrl },
          { "@type": "ListItem", position: 3, name: post.data.title, item: url },
        ],
      },
    ],
  };
}
