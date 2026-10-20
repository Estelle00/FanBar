import { downloads } from "./downloads";
import { locales } from "./i18n";
import { github, releases } from "./links";
import { HTML_LANG, LOCALE_URLS, siteUrl } from "./seo";
import releaseSnapshot from "../data/releases.json";

export const apiUpdated = "2026-10-20";

// Read from the same build-time release snapshot as the download buttons.
const latest = [...releaseSnapshot.releases].sort((a, b) => b.publishedAt.localeCompare(a.publishedAt))[0];
export const apiDocsUrl = `${siteUrl}/api`;
export const apiMarkdownUrl = `${siteUrl}/api.md`;
export const apiCatalogUrl = `${siteUrl}/.well-known/api-catalog`;
export const openApiUrl = `${siteUrl}/openapi.json`;
export const productApiUrl = `${siteUrl}/api/product.json`;
export const healthApiUrl = `${siteUrl}/api/health.json`;

export const productFacts = {
  name: "FanBar",
  summary:
    "A free, open-source native macOS menu-bar app for monitoring temperatures and managing fan cooling.",
  homepage: siteUrl,
  repository: github,
  releases,
  license: "GPL-3.0",
  pricing: {
    amount: 0,
    currency: "USD",
    accountRequired: false,
    paidTier: false,
  },
  compatibility: {
    operatingSystem: "macOS",
    minimumVersion: "11 Big Sur",
    architectures: ["Apple Silicon", "Intel"],
    requirement: "The Mac must expose readable fan data through AppleSMC.",
    evidence: `${siteUrl}/compatibility`,
  },
  install: [
    {
      method: "DMG",
      url: releases,
      note: "Notarized builds are published on GitHub Releases.",
    },
    {
      method: "Homebrew",
      commands: [
        "brew tap helson-lin/fanbar https://github.com/helson-lin/FanBar.git",
        "brew install --cask helson-lin/fanbar/fanbar",
      ],
    },
  ],
  latestRelease: {
    version: latest.version,
    publishedAt: latest.publishedAt,
    notes: `${siteUrl}/releases/${latest.version}`,
    url: latest.url,
  },
  downloads: Object.fromEntries(
    Object.entries(downloads).map(([architecture, asset]) => [
      architecture,
      { name: asset.name, url: asset.url, size: asset.size },
    ]),
  ),
  features: [
    "Menu-bar CPU temperature and fan RPM, with six icon styles that spin with the fans",
    "Per-fan RPM on a 0-to-max meter, and a CPU, GPU, memory, and disk load grid",
    "CPU, GPU, SSD, and battery temperatures with a 10-minute to 1-hour history chart",
    "Automatic cooling, fixed target RPM, and editable temperature-to-RPM curves",
    "Silent, Balanced, Performance, and Extreme presets that can restore Automatic after 15 minutes, 30 minutes, or 1 hour",
    "Curve temperature source selectable from CPU, GPU, or SSD",
    "Optional high-temperature notifications at 60-105°C (90°C by default) with a selectable alert sound",
    "CSV logging of temperatures, fan speeds, and control mode every 2-60 seconds",
    "Desktop widget on macOS 14 and later",
  ],
  safety: {
    manualControlOptional: true,
    authorization:
      "Manual fan control requires explicit approval of FanBar's signed privileged helper.",
    limits: "Fan targets are clamped to the hardware-reported fan range.",
    fallback:
      "FanBar attempts to restore macOS automatic fan control when manual control ends, the app quits, the connection is lost, or the helper fails.",
  },
  languages: ["English", "Simplified Chinese", "Traditional Chinese", "Japanese", "Russian", "French"],
  localizedPages: Object.fromEntries(locales.map((locale) => [HTML_LANG[locale], LOCALE_URLS[locale]])),
  updated: apiUpdated,
} as const;

export const apiHealth = {
  status: "ok",
  service: "FanBar Product Facts API",
  updated: apiUpdated,
} as const;

export const openApiDocument = {
  openapi: "3.1.0",
  info: {
    title: "FanBar Product Facts API",
    version: "1.1.0",
    description:
      "A public, read-only API exposing canonical FanBar product, compatibility, installation, and safety facts.",
    license: {
      name: "GPL-3.0",
      identifier: "GPL-3.0-only",
    },
  },
  servers: [{ url: siteUrl }],
  paths: {
    "/api/product.json": {
      get: {
        summary: "Get canonical FanBar product facts",
        operationId: "getFanBarProductFacts",
        responses: {
          "200": {
            description: "Current FanBar product facts",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/ProductFacts" },
              },
            },
          },
        },
      },
    },
    "/api/health.json": {
      get: {
        summary: "Check API publication status",
        operationId: "getFanBarApiHealth",
        responses: {
          "200": {
            description: "The static API is available",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Health" },
              },
            },
          },
        },
      },
    },
  },
  components: {
    schemas: {
      ProductFacts: {
        type: "object",
        required: [
          "name",
          "summary",
          "homepage",
          "repository",
          "releases",
          "license",
          "pricing",
          "compatibility",
          "install",
          "latestRelease",
          "downloads",
          "features",
          "safety",
          "languages",
          "localizedPages",
          "updated",
        ],
        properties: {
          name: { type: "string" },
          summary: { type: "string" },
          homepage: { type: "string", format: "uri" },
          repository: { type: "string", format: "uri" },
          releases: { type: "string", format: "uri" },
          license: { type: "string" },
          pricing: { type: "object", additionalProperties: true },
          compatibility: { type: "object", additionalProperties: true },
          install: {
            type: "array",
            items: { type: "object", additionalProperties: true },
          },
          latestRelease: {
            type: "object",
            required: ["version", "publishedAt", "notes", "url"],
            properties: {
              version: { type: "string" },
              publishedAt: { type: "string", format: "date-time" },
              notes: { type: "string", format: "uri" },
              url: { type: "string", format: "uri" },
            },
          },
          downloads: {
            type: "object",
            description: "Notarized DMGs of the latest release, keyed by architecture: universal, arm64, x86_64.",
            additionalProperties: {
              type: "object",
              required: ["name", "url", "size"],
              properties: {
                name: { type: "string" },
                url: { type: "string", format: "uri" },
                size: { type: "integer", description: "Bytes" },
              },
            },
          },
          features: { type: "array", items: { type: "string" } },
          safety: { type: "object", additionalProperties: true },
          languages: { type: "array", items: { type: "string" } },
          localizedPages: {
            type: "object",
            description: "Product page URL for each BCP 47 language tag.",
            additionalProperties: { type: "string", format: "uri" },
          },
          updated: { type: "string", format: "date" },
        },
      },
      Health: {
        type: "object",
        required: ["status", "service", "updated"],
        properties: {
          status: { type: "string", const: "ok" },
          service: { type: "string" },
          updated: { type: "string", format: "date" },
        },
      },
    },
  },
} as const;

export const apiCatalog = {
  linkset: [
    {
      anchor: productApiUrl,
      "service-desc": [
        {
          href: openApiUrl,
          type: "application/vnd.oai.openapi+json;version=3.1",
        },
      ],
      "service-doc": [{ href: apiDocsUrl, type: "text/html" }],
      status: [{ href: healthApiUrl, type: "application/json" }],
    },
  ],
} as const;
