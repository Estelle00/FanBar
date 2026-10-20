// Snapshots the public compatibility matrix into src/data so builds stay
// deterministic and every data change shows up in review. Run before a release:
//   npm run data:compatibility
import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

const pathFromHere = (path) => fileURLToPath(new URL(path, import.meta.url));
const endpoint = "https://report.getfanbar.com/api/compatibility";

// The API returns 20 combinations per page; follow nextOffset until it is null.
const groups = [];
let generatedAt;
for (let offset = 0; offset !== null && offset !== undefined; ) {
  const url = `${endpoint}?offset=${offset}`;
  const response = await fetch(url, { headers: { accept: "application/json" } });
  if (!response.ok) throw new Error(`${url} returned ${response.status}`);
  const page = await response.json();
  if (page.schemaVersion !== 1) throw new Error(`Unsupported schemaVersion ${page.schemaVersion}`);
  generatedAt ??= page.generatedAt;
  groups.push(...page.groups);
  if (page.truncated && page.nextOffset === undefined) {
    console.warn("This service version does not paginate; older combinations are missing.");
  }
  offset = page.nextOffset;
}
const matrix = { generatedAt, groups };

const names = JSON.parse(await readFile(pathFromHere("../../contracts/mac-model-names.json"), "utf8"));

const snapshot = {
  source: endpoint,
  generatedAt: matrix.generatedAt,
  modelNames: names,
  groups: matrix.groups,
};

await writeFile(pathFromHere("../src/data/compatibility-matrix.json"), `${JSON.stringify(snapshot, null, 2)}\n`);
console.log(`Saved ${matrix.groups.length} report groups across ${new Set(matrix.groups.map((g) => g.modelIdentifier)).size} models.`);
