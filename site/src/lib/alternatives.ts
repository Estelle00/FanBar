// "Macs Fan Control alternatives" overview. Competitor claims come from each
// product's official page, checked on `alternativesUpdated`; re-check before
// advancing the date. Avoid volatile numbers (prices without a source, stars).

import { github, releases } from "./links";
import { competitorSources } from "./macsFanControlComparison";
import { siteUrl } from "./seo";

export const alternativesUrl = `${siteUrl}/alternatives`;
export const alternativesUpdated = "2026-10-15";

export interface Alternative {
  id: string;
  name: string;
  maker: string;
  bestFor: string;
  price: string;
  fanControl: string;
  source: string;
  macOS: string;
  caveat: string;
  url: string;
  sourceLabel: string;
  isFanBar?: boolean;
}

export const alternatives: Alternative[] = [
  {
    id: "fanbar",
    name: "FanBar",
    maker: "Open-source project (maintained by us)",
    bestFor: "A free, fully open-source fan controller that lives in the menu bar.",
    price: "Free, every feature",
    fanControl: "Fixed RPM, four presets, and editable temperature curves; targets clamped to each fan's range",
    source: "Open source (GPL-3.0), including the root helper",
    macOS: "macOS 11+, Apple Silicon and Intel",
    caveat: "Young project with a shorter track record; fewer per-sensor details than dedicated monitors.",
    url: github,
    sourceLabel: "Source and releases",
    isFanBar: true,
  },
  {
    id: "tg-pro",
    name: "TG Pro",
    maker: "Tunabelly Software",
    bestFor: "Rule-based fan boosts plus diagnostics, for a one-time price.",
    price: "$10 one-time, no subscription",
    fanControl: "Auto Boost rules tie a sensor threshold to a fan speed; Manual and Max modes on supported models",
    source: "Commercial app",
    macOS: "macOS 10.14+, Apple Silicon and Intel",
    caveat: "Manual and Max options vary by Mac model; fanless Macs are monitoring-only.",
    url: "https://www.tunabellysoftware.com/tgpro/",
    sourceLabel: "Official TG Pro page",
  },
  {
    id: "istat-menus",
    name: "iStat Menus",
    maker: "Bjango",
    bestFor: "An all-round system monitor where fan control is one feature among many.",
    price: "Paid one-time license (single or family); also in Setapp",
    fanControl: "Fan speeds can be controlled, and ramped by temperature or battery state",
    source: "Commercial app",
    macOS: "macOS 13.5+",
    caveat: "Much broader than fan control — CPU, memory, network, weather — so it's heavier if fans are all you need.",
    url: "https://bjango.com/mac/istatmenus/",
    sourceLabel: "Official iStat Menus page",
  },
  {
    id: "stats",
    name: "Stats",
    maker: "exelban (open source)",
    bestFor: "A free, open-source menu-bar system monitor.",
    price: "Free",
    fanControl: "Included, but in legacy mode: it no longer receives updates or fixes",
    source: "Open source (MIT)",
    macOS: "macOS 12+",
    caveat: "Excellent for monitoring; its own README says fan control is not maintained.",
    url: "https://github.com/exelban/stats",
    sourceLabel: "Stats on GitHub",
  },
  {
    id: "smcfancontrol",
    name: "smcFanControl",
    maker: "hholtmann (open source)",
    bestFor: "Older Intel Macs that only need a higher minimum fan speed.",
    price: "Free",
    fanControl: "Sets a minimum speed only; cannot go below Apple's defaults",
    source: "Open source (GPL-2.0)",
    macOS: "Built for Intel Macs",
    caveat: "No repository activity since August 2023.",
    url: "https://github.com/hholtmann/smcFanControl",
    sourceLabel: "smcFanControl on GitHub",
  },
];

export const macsFanControlBaseline = {
  name: "Macs Fan Control",
  maker: "CrystalIDEA",
  summary:
    "Free core app with a one-time Pro upgrade, a separate main window with detailed sensor tables, macOS 10.13+, and a Windows build for Intel Macs running Boot Camp.",
  url: competitorSources.overview,
};

export const decisionGuide = [
  { need: "Free and open source, including the part that runs as root", pick: "FanBar", id: "fanbar" },
  { need: "Temperature-triggered boosts and hardware diagnostics", pick: "TG Pro", id: "tg-pro" },
  { need: "One app for every system stat, with fan control included", pick: "iStat Menus", id: "istat-menus" },
  { need: "Free monitoring, with fan control as a bonus", pick: "Stats", id: "stats" },
  { need: "A higher minimum fan speed on an older Intel Mac", pick: "smcFanControl", id: "smcfancontrol" },
];

export const alternativesFaq = [
  {
    question: "What is the best free alternative to Macs Fan Control?",
    answer:
      "For fan control specifically, FanBar is free with every feature included and is fully open source, with fixed RPM, presets, and temperature curves. Stats is a strong free system monitor, but its own documentation says its fan control is in legacy mode and no longer maintained.",
  },
  {
    question: "Which Macs Fan Control alternatives work on Apple Silicon?",
    answer:
      "FanBar and TG Pro both state support for Apple Silicon and Intel Macs. iStat Menus includes fan control but does not list supported models on its product page. smcFanControl was built for Intel Macs.",
  },
  {
    question: "Is there an open-source Macs Fan Control alternative?",
    answer:
      "Yes. FanBar (GPL-3.0), Stats (MIT), and smcFanControl (GPL-2.0) are open source. FanBar is the one whose fan control is actively maintained and whose privileged helper source is published alongside the app.",
  },
  {
    question: "Do I need a fan control app at all?",
    answer:
      "Often not. macOS manages fans automatically and well for most workloads. A fan control app is useful when you want quieter idle behavior, more aggressive cooling during sustained loads, or visibility into temperatures that macOS doesn't show.",
  },
];

export function alternativesStructuredData() {
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
        "@type": "Article",
        "@id": `${alternativesUrl}#article`,
        headline: "Macs Fan Control Alternatives: 5 Fan Control Apps for Mac Compared",
        datePublished: alternativesUpdated,
        dateModified: alternativesUpdated,
        inLanguage: "en",
        mainEntityOfPage: { "@id": `${alternativesUrl}#webpage` },
        author: { "@id": publisherId },
        publisher: { "@id": publisherId },
        citation: [...alternatives.map((a) => a.url), competitorSources.overview, releases],
      },
      {
        "@type": "WebPage",
        "@id": `${alternativesUrl}#webpage`,
        url: alternativesUrl,
        name: "Macs Fan Control alternatives",
        inLanguage: "en",
        isPartOf: { "@id": `${siteUrl}/#website` },
        mainEntity: { "@id": `${alternativesUrl}#article` },
      },
      {
        "@type": "ItemList",
        "@id": `${alternativesUrl}#list`,
        itemListElement: alternatives.map((a, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: a.name,
          url: `${alternativesUrl}#${a.id}`,
        })),
      },
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "FanBar", item: siteUrl },
          { "@type": "ListItem", position: 2, name: "Macs Fan Control alternatives", item: alternativesUrl },
        ],
      },
      {
        "@type": "FAQPage",
        "@id": `${alternativesUrl}#faq`,
        mainEntity: alternativesFaq.map((item) => ({
          "@type": "Question",
          name: item.question,
          acceptedAnswer: { "@type": "Answer", text: item.answer },
        })),
      },
    ],
  };
}
