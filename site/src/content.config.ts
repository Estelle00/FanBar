import { defineCollection } from "astro:content";
import { glob } from "astro/loaders";
import { z } from "astro/zod";
import releaseSnapshot from "./data/releases.json";
import { highlightTitles, splitReleaseNotes } from "./lib/releaseNotes";

const blog = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/content/blog" }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    /** One- or two-sentence answer shown above the article and in structured data. */
    answer: z.string(),
    publishedOn: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    updatedOn: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    keywords: z.array(z.string()).default([]),
  }),
});

// One entry per release and language ("en/0.5.1", "zh/0.5.1"), rendered with
// the site's Markdown pipeline. Source: src/data/releases.json (scripts/sync-releases.mjs).
const releases = defineCollection({
  loader: {
    name: "github-releases",
    load: async ({ store, renderMarkdown, generateDigest }) => {
      store.clear();
      for (const release of releaseSnapshot.releases) {
        const notes = splitReleaseNotes(release.body, releaseSnapshot.repository);
        for (const locale of ["en", "zh"] as const) {
          const markdown = notes[locale];
          const data = {
            locale,
            tag: release.tag,
            version: release.version,
            publishedAt: release.publishedAt,
            url: release.url,
            assets: release.assets,
            translated: notes.translated,
            highlights: highlightTitles(markdown),
          };
          store.set({
            id: `${locale}/${release.version}`,
            data,
            body: markdown,
            rendered: await renderMarkdown(markdown),
            digest: generateDigest({ data, markdown }),
          });
        }
      }
    },
  },
  schema: z.object({
    locale: z.enum(["en", "zh"]),
    tag: z.string(),
    version: z.string(),
    publishedAt: z.string(),
    url: z.url(),
    assets: z.array(z.object({ name: z.string(), size: z.number(), url: z.url() })),
    translated: z.boolean(),
    highlights: z.array(z.string()),
  }),
});

export const collections = { blog, releases };
