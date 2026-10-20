// Refreshes src/data/releases.json from GitHub Releases. Runs before every
// build so a release published on GitHub reaches the site on the next deploy
// (the release workflow triggers one). If GitHub is unreachable or rate-limits
// us, the committed snapshot is kept and the build continues.
import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

const repository = process.env.FANBAR_REPOSITORY ?? "helson-lin/FanBar";
const output = fileURLToPath(new URL("../src/data/releases.json", import.meta.url));
const strict = process.argv.includes("--strict");

async function fetchReleases() {
  const headers = { accept: "application/vnd.github+json", "x-github-api-version": "2022-11-28" };
  const token = process.env.GITHUB_TOKEN ?? process.env.GH_TOKEN;
  if (token) headers.authorization = `Bearer ${token}`;
  const response = await fetch(`https://api.github.com/repos/${repository}/releases?per_page=100`, {
    headers,
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) throw new Error(`GitHub API returned ${response.status}`);
  return response.json();
}

try {
  const releases = (await fetchReleases())
    .filter((release) => !release.draft && !release.prerelease && release.published_at)
    .map((release) => ({
      tag: release.tag_name,
      version: release.tag_name.replace(/^v/, ""),
      name: release.name || release.tag_name,
      publishedAt: release.published_at,
      url: release.html_url,
      body: (release.body ?? "").replace(/\r\n/g, "\n").trim(),
      assets: release.assets
        .filter((asset) => asset.name.endsWith(".dmg"))
        .map((asset) => ({ name: asset.name, size: asset.size, url: asset.browser_download_url })),
    }))
    .sort((a, b) => b.publishedAt.localeCompare(a.publishedAt));

  const next = `${JSON.stringify({ repository, releases }, null, 2)}\n`;
  const previous = await readFile(output, "utf8").catch(() => "");
  if (next !== previous) await writeFile(output, next);
  console.log(`Release notes: ${releases.length} releases, latest ${releases[0]?.tag ?? "none"}${next === previous ? " (unchanged)" : ""}.`);
} catch (error) {
  if (strict) throw error;
  console.warn(`Release notes: keeping the committed snapshot (${error.message}).`);
}
