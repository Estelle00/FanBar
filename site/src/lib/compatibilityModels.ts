// Per-model compatibility pages. A page exists only for a model with real
// evidence — an approved in-app report or a curated, model-certain issue — so
// the site never publishes empty "no data yet" pages for every Mac.

import snapshot from "@/data/compatibility-matrix.json";
import { compatibilityReports, type CompatibilityReport } from "./compatibility";
import { siteUrl } from "./seo";

export type Capability =
  | "fanReadings"
  | "cpuTemperature"
  | "gpuTemperature"
  | "ssdTemperature"
  | "batteryTemperature"
  | "manualControl"
  | "smartCooling";

export type Status =
  | "available"
  | "notApplicable"
  | "notDetected"
  | "temporarilyUnavailable"
  | "requiresAuthorization"
  | "unverified"
  | "requestSucceeded"
  | "requestFailed";

interface CommunityRow {
  capability: Capability;
  status: Status;
  count: number;
  userConfirmedWorking: number;
}

interface Verification {
  capability: Capability;
  status: "verifiedAvailable" | "verifiedUnsupported";
  notes: string;
  source_url: string;
  verified_on: string;
}

export interface ReportGroup {
  modelIdentifier: string;
  macOSVersion: string;
  appVersion: string;
  helperVersion: string;
  updatedOn: string;
  community: CommunityRow[];
  developerVerifications: Verification[];
}

export const capabilityOrder: Capability[] = [
  "fanReadings",
  "manualControl",
  "smartCooling",
  "cpuTemperature",
  "gpuTemperature",
  "ssdTemperature",
  "batteryTemperature",
];

export const capabilityLabels: Record<Capability, string> = {
  fanReadings: "Fan speed readings",
  manualControl: "Fixed RPM control",
  smartCooling: "Temperature-curve control",
  cpuTemperature: "CPU temperature",
  gpuTemperature: "GPU temperature",
  ssdTemperature: "SSD temperature",
  batteryTemperature: "Battery temperature",
};

export type Tone = "positive" | "neutral" | "negative";

export function describeStatus(row: Pick<CommunityRow, "status" | "userConfirmedWorking">): { label: string; tone: Tone } {
  switch (row.status) {
    case "available":
      return { label: "Readable", tone: "positive" };
    case "requestSucceeded":
      return row.userConfirmedWorking > 0
        ? { label: "Worked — confirmed by the reporter", tone: "positive" }
        : { label: "Request accepted, not hands-on confirmed", tone: "neutral" };
    case "notApplicable":
      return { label: "Not applicable on this Mac", tone: "neutral" };
    case "unverified":
      return { label: "Not tested", tone: "neutral" };
    case "requiresAuthorization":
      return { label: "Helper not approved during test", tone: "neutral" };
    case "temporarilyUnavailable":
      return { label: "Temporarily unavailable", tone: "negative" };
    case "notDetected":
      return { label: "Not detected", tone: "negative" };
    case "requestFailed":
      return { label: "Control request failed", tone: "negative" };
  }
}

export type EvidenceLevel = "Developer verified" | "Confirmed by users" | "Partial evidence" | "Retest needed";

export interface ModelPage {
  identifier: string;
  name: string;
  slug: string;
  url: string;
  groups: ReportGroup[];
  issues: CompatibilityReport[];
  level: EvidenceLevel;
  summary: string;
  updatedOn: string;
}

const modelNames = snapshot.modelNames as Record<string, string>;

// Chips confirmed on real hardware (sysctl machdep.cpu.brand_string + hw.model).
// Marketing names alone are ambiguous for laptops, so never guess here.
const verifiedChips: Record<string, string> = {
  "Mac14,6": "M2 Max",
};

function displayName(identifier: string): string {
  const name = modelNames[identifier];
  const chip = verifiedChips[identifier];
  return chip && !name.includes("·") ? `${name} · ${chip}` : name;
}
const groups = snapshot.groups as ReportGroup[];

export const matrixGeneratedAt = snapshot.generatedAt.slice(0, 10);
export const matrixSource = snapshot.source;

function baseSlug(name: string): string {
  return name
    .toLowerCase()
    .replace(/[()·,]/g, " ")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

// Several identifiers share a marketing name (e.g. two "MacBook Pro (14-inch,
// Nov 2023)" configurations), so append the identifier only when needed.
function slugFor(identifier: string, name: string): string {
  const shared = !verifiedChips[identifier] &&
    Object.entries(modelNames).filter(([, other]) => other === modelNames[identifier]).length > 1;
  const slug = baseSlug(name);
  return shared ? `${slug}-${identifier.toLowerCase().replace(/,/g, "-")}` : slug;
}

function hasConfirmedControl(group: ReportGroup): boolean {
  return group.community.some(
    (row) => (row.capability === "manualControl" || row.capability === "smartCooling") &&
      row.status === "requestSucceeded" && row.userConfirmedWorking > 0,
  );
}

function evidenceLevel(modelGroups: ReportGroup[], issues: CompatibilityReport[]): EvidenceLevel {
  if (modelGroups.some((g) => g.developerVerifications.some((v) => v.status === "verifiedAvailable"))) {
    return "Developer verified";
  }
  if (modelGroups.some(hasConfirmedControl)) return "Confirmed by users";
  if (modelGroups.length === 0 && issues.every((issue) => issue.status === "Retest needed")) return "Retest needed";
  return "Partial evidence";
}

function summaryFor(level: EvidenceLevel, name: string, modelGroups: ReportGroup[]): string {
  const latest = modelGroups[0];
  switch (level) {
    case "Developer verified":
      return `The FanBar maintainers have verified fan control on the ${name}.`;
    case "Confirmed by users":
      return `A FanBar user ran the in-app compatibility check on the ${name} (macOS ${latest.macOSVersion}, FanBar ${latest.appVersion}) and confirmed that fixed-RPM and temperature-curve control changed the fans.`;
    case "Retest needed":
      return `An older FanBar version was reported on the ${name}, but the current release still needs a standardized retest on this model.`;
    case "Partial evidence":
      return `FanBar has been reported running on the ${name}, but fan control has not yet been confirmed hands-on with the current release.`;
  }
}

function buildPages(): ModelPage[] {
  const identifiers = new Set<string>([
    ...groups.map((g) => g.modelIdentifier),
    ...compatibilityReports.flatMap((r) => (r.modelIdentifier ? [r.modelIdentifier] : [])),
  ]);

  return [...identifiers]
    .filter((identifier) => identifier !== "unknown" && modelNames[identifier])
    .map((identifier) => {
      const name = displayName(identifier);
      const modelGroups = groups
        .filter((g) => g.modelIdentifier === identifier)
        .sort((a, b) => b.updatedOn.localeCompare(a.updatedOn));
      const issues = compatibilityReports.filter((r) => r.modelIdentifier === identifier);
      const level = evidenceLevel(modelGroups, issues);
      const slug = slugFor(identifier, name);
      // Parse as UTC so a local build in another time zone can't shift the day.
      const issueDates = issues.map((issue) => new Date(`${issue.date} UTC`).toISOString().slice(0, 10));
      return {
        identifier,
        name,
        slug,
        url: `${siteUrl}/compatibility/${slug}`,
        groups: modelGroups,
        issues,
        level,
        summary: summaryFor(level, name, modelGroups),
        updatedOn: [...modelGroups.map((g) => g.updatedOn), ...issueDates].sort().at(-1) ?? matrixGeneratedAt,
      };
    })
    .sort((a, b) => a.name.localeCompare(b.name));
}

export const modelPages: ModelPage[] = buildPages();

export function modelStructuredData(page: ModelPage) {
  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        "@id": `${page.url}#webpage`,
        url: page.url,
        name: `FanBar compatibility: ${page.name}`,
        description: page.summary,
        inLanguage: "en",
        dateModified: page.updatedOn,
        isPartOf: { "@id": `${siteUrl}/#website` },
        about: [{ "@id": `${siteUrl}/#app` }, { "@type": "Product", name: page.name, brand: { "@type": "Brand", name: "Apple" } }],
      },
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "FanBar", item: siteUrl },
          { "@type": "ListItem", position: 2, name: "Compatibility", item: `${siteUrl}/compatibility` },
          { "@type": "ListItem", position: 3, name: page.name, item: page.url },
        ],
      },
    ],
  };
}
