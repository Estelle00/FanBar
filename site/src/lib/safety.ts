// "Is FanBar safe?" trust page. Every claim here is checked against the helper
// source (Sources/FanBarHelper) and the shipped Info.plist; update `safetyUpdated`
// only after re-checking them.

import type { FullLocale } from "./i18n";
import { github, releases } from "./links";
import { siteUrl } from "./seo";

export const safetyUrls: Record<FullLocale, string> = {
  en: `${siteUrl}/is-fanbar-safe`,
  zh: `${siteUrl}/zh/is-fanbar-safe`,
};
export const safetyMarkdownUrls: Record<FullLocale, string> = {
  en: `${siteUrl}/is-fanbar-safe.md`,
  zh: `${siteUrl}/zh/is-fanbar-safe.md`,
};
export const safetyUpdated = "2026-10-15";

const sourceBase = `${github}/blob/main`;
export const safetySources = {
  helperService: `${sourceBase}/Sources/FanBarHelper/FanBarHelperService.swift`,
  fanDriver: `${sourceBase}/Sources/FanBarHelper/SMCFanDriver.swift`,
  coolingTarget: `${sourceBase}/Sources/FanBarShared/FanCoolingTarget.swift`,
  releases,
};

interface QA {
  question: string;
  answer: string;
}

interface SafetyCopy {
  title: string;
  description: string;
  ogDescription: string;
  keywords: string[];
  breadcrumb: string;
  label: string;
  headingLead: string;
  headingHighlight: string;
  lede: string;
  updatedLabel: string;
  updatedText: string;
  verifyLink: string;
  disclosure: string;
  shortAnswers: { label: string; heading: string; items: (QA & { href: string })[] };
  fans: {
    label: string;
    heading: string;
    intro: string;
    points: { title: string; body: string }[];
    restoreHeading: string;
    restoreItems: string[];
    advice: string;
  };
  helper: {
    label: string;
    heading: string;
    intro: string;
    chain: string[];
    chainCaption: string;
    canHeading: string;
    can: string[];
    cannotHeading: string;
    cannot: string[];
    sourceLabel: string;
  };
  verify: {
    label: string;
    heading: string;
    intro: string;
    steps: { title: string; body: string; command?: string; output?: string; links?: { label: string; href: string }[] }[];
  };
  off: {
    label: string;
    heading: string;
    items: { title: string; body: string; command?: string }[];
  };
  faqLabel: string;
  faqHeading: string;
  faq: QA[];
  cta: { label: string; heading: string; body: string; primary: string; secondary: string };
}

const en: SafetyCopy = {
  title: "Is FanBar Safe? What the Mac Fan Control Helper Can and Can't Do",
  description:
    "Is FanBar safe to install? How FanBar limits fan speeds, what its root helper can and cannot do, and how to verify Apple notarization and the open-source code yourself.",
  ogDescription: "Fan limits, the root helper's exact permissions, Apple notarization, and how to check it all yourself.",
  keywords: [
    "is FanBar safe",
    "FanBar safety",
    "is Mac fan control safe",
    "can fan control damage Mac",
    "FanBar helper root",
    "FanBar notarized",
  ],
  breadcrumb: "Is FanBar safe?",
  label: "Safety & trust",
  headingLead: "Is FanBar safe?",
  headingHighlight: "Here's exactly what it can touch.",
  lede:
    "Yes. FanBar only reads sensors until you turn on manual control. When you do, a small open-source helper sets fan targets inside each fan's hardware limits — and nothing else. Every release is notarized by Apple, and you can check all of it yourself.",
  updatedLabel: "Checked against the source on",
  updatedText: "October 15, 2026",
  verifyLink: "Verify it yourself",
  disclosure:
    "We maintain FanBar, so treat this page as our claims — then check them. Each one links to the exact source file, and the commands below run on your own Mac.",
  shortAnswers: {
    label: "Short answers",
    heading: "The four questions people ask first",
    items: [
      {
        question: "Can it damage my fans?",
        answer: "No. Targets stay inside the minimum and maximum each fan reports to macOS.",
        href: "#fans",
      },
      {
        question: "What does the root helper do?",
        answer: "Reads fans, sets a bounded target, and hands control back to macOS. Nothing else.",
        href: "#helper",
      },
      {
        question: "Can I read the code?",
        answer: "Yes. The app and the helper are GPL-3.0 on GitHub — about 700 lines for the helper.",
        href: "#verify",
      },
      {
        question: "Is it notarized?",
        answer: "Yes. Every release is signed with a Developer ID and notarized by Apple.",
        href: "#verify",
      },
    ],
  },
  fans: {
    label: "Hardware",
    heading: "Will FanBar damage my fans or overheat my Mac?",
    intro:
      "Manual fan control is not risk-free in general, so FanBar is built to stay inside limits that the Mac itself defines.",
    points: [
      {
        title: "Speeds stay inside the hardware range",
        body: "Before writing, the helper reads each fan's reported minimum and maximum and clamps every target to that range. The one exception is deliberate: a curve's coolest segment can ask for 0 RPM idle — the same state Apple Silicon Macs use on their own when cool.",
      },
      {
        title: "macOS thermal protection is untouched",
        body: "FanBar only writes fan mode and fan target values. It does not change macOS performance throttling or the hardware's critical-temperature shutdown, which keep working whatever the fans are set to.",
      },
      {
        title: "Bad input is rejected at the root boundary",
        body: "The helper refuses RPM values that are negative or not finite, and curve fractions outside 0–100%, even if the request comes from a tampered client.",
      },
      {
        title: "Optional high-temperature alerts",
        body: "FanBar can notify you when the CPU or GPU reaches 90 °C, so a too-quiet setting doesn't go unnoticed.",
      },
    ],
    restoreHeading: "FanBar hands control back to macOS when…",
    restoreItems: [
      "you choose Automatic, or a timed preset expires (15 min, 30 min, or 1 hour)",
      "you quit FanBar, or the last app connection to the helper closes",
      "the helper is shutting down",
      "a write to one of several fans fails — the whole Mac is rolled back, never left half-configured",
    ],
    advice:
      "Running fans at full speed for long periods mostly costs noise and some extra wear. For everyday use, Automatic or a temperature curve is the better choice.",
  },
  helper: {
    label: "The root helper",
    heading: "What the helper does — and what it can't",
    intro:
      "Changing fan speed on macOS requires root access to AppleSMC. Reading temperatures doesn't, so the helper is installed only when you enable manual control and approve it in macOS.",
    chain: ["FanBar.app", "Signed XPC", "FanBarHelper (root)", "AppleSMC fan keys"],
    chainCaption: "The menu-bar app never touches hardware directly. It asks the helper over XPC.",
    canHeading: "The helper can",
    can: [
      "Read fan count, current speed, and each fan's minimum and maximum",
      "Set a target RPM, a preset, or a curve fraction — all clamped to the fan's range",
      "Restore macOS automatic fan control",
    ],
    cannotHeading: "The helper cannot",
    cannot: [
      "Write arbitrary SMC keys — its interface has no general-purpose write",
      "Run commands, read files, or reach the network — it has no code for any of them",
      "Take orders from other apps — it accepts only clients signed by the same Apple Developer team as FanBar",
      "Keep manual control after FanBar disconnects",
    ],
    sourceLabel: "Read the helper source",
  },
  verify: {
    label: "Verify it yourself",
    heading: "Don't take our word for it",
    intro: "Three checks you can run in a few minutes, without trusting this page.",
    steps: [
      {
        title: "1. Confirm Apple notarization",
        body: "Run this in Terminal after installing. macOS should report a notarized Developer ID build.",
        command: "spctl -a -vv /Applications/FanBar.app",
        output: "/Applications/FanBar.app: accepted\nsource=Notarized Developer ID\norigin=Developer ID Application: JiangLin He (64S5F787T9)",
      },
      {
        title: "2. Read the code that runs as root",
        body: "The whole privileged surface is two short files. Look for the client signature check, the input guards, and the range clamping.",
        links: [
          { label: "FanBarHelperService.swift", href: safetySources.helperService },
          { label: "SMCFanDriver.swift", href: safetySources.fanDriver },
          { label: "FanCoolingTarget.swift", href: safetySources.coolingTarget },
        ],
      },
      {
        title: "3. Check what the app sends over the network",
        body: "The FanBar app has no account, ads, or analytics. It checks GitHub Releases for updates once a day through Sparkle, and every update must pass Apple notarization plus FanBar's own EdDSA signature. Compatibility reports are sent only if you review and confirm one.",
      },
    ],
  },
  off: {
    label: "Off switch",
    heading: "How to turn it off or remove it",
    items: [
      {
        title: "Go back to macOS control",
        body: "Choose Automatic in the menu-bar popover. The helper stops steering the fans immediately.",
      },
      {
        title: "Disable the helper",
        body: "On macOS 13 or later, open System Settings → General → Login Items & Extensions and turn FanBar off under “Allow in the Background”.",
      },
      {
        title: "Uninstall completely",
        body: "Quit FanBar first. If you installed it with Homebrew, this command also unloads the helper and removes preferences and caches.",
        command: "brew uninstall --cask --zap helson-lin/fanbar/fanbar",
      },
    ],
  },
  faqLabel: "FAQ",
  faqHeading: "Safety questions, answered plainly",
  faq: [
    {
      question: "Is FanBar safe to use?",
      answer:
        "Yes. By default FanBar only reads temperatures and fan speeds while macOS manages cooling. Manual control requires your explicit approval of a signed helper that can only set fan targets inside each fan's hardware range. FanBar is open source under GPL-3.0 and every release is notarized by Apple.",
    },
    {
      question: "Can FanBar damage my Mac's fans?",
      answer:
        "FanBar clamps every target to the minimum and maximum speed each fan reports, so it cannot push a fan beyond its rated range. The only exception is an intentional 0 RPM idle on the coolest part of a temperature curve, which matches what Apple Silicon Macs do on their own. Long periods at full speed mainly cost noise and extra wear.",
    },
    {
      question: "Can a wrong fan setting overheat my Mac?",
      answer:
        "FanBar does not change macOS thermal management. If temperatures climb, macOS still throttles performance and the hardware still shuts down at critical temperatures, whatever the fan target is. FanBar can also notify you when the CPU or GPU reaches 90 °C.",
    },
    {
      question: "Why does FanBar need administrator approval?",
      answer:
        "macOS only allows root processes to change fan speeds through AppleSMC. FanBar asks for approval only when you enable manual control; monitoring works without it. The helper is limited to reading fans, setting bounded targets, and restoring automatic control.",
    },
    {
      question: "Does FanBar collect my data?",
      answer:
        "No. The FanBar app has no account, analytics, or advertising. Its only network activity is a daily Sparkle update check against GitHub Releases and, only if you choose to send one, a reviewed compatibility report that excludes serial numbers and other unique identifiers.",
    },
    {
      question: "Is FanBar a virus or malware?",
      answer:
        "No. FanBar is signed with an Apple Developer ID, notarized by Apple, and its full source — including the privileged helper — is public on GitHub, so anyone can audit what it does.",
    },
  ],
  cta: {
    label: "Try FanBar",
    heading: "Inspect first. Install when you're ready.",
    body: "The complete app is free. Read the helper source, then download the notarized build.",
    primary: "Download FanBar",
    secondary: "Read the source",
  },
};

const zh: SafetyCopy = {
  title: "FanBar 安全吗？Mac 风扇控制 Helper 能做什么、不能做什么",
  description:
    "FanBar 安全吗？了解 FanBar 如何限制风扇转速、特权 Helper 的确切权限，以及如何自行验证 Apple 公证和开源代码。",
  ogDescription: "风扇转速上下限、root Helper 的确切权限、Apple 公证，以及如何亲自核实。",
  keywords: ["FanBar 安全吗", "FanBar 安全", "Mac 风扇控制安全吗", "风扇控制会损坏 Mac 吗", "FanBar Helper", "FanBar 公证"],
  breadcrumb: "FanBar 安全吗？",
  label: "安全与信任",
  headingLead: "FanBar 安全吗？",
  headingHighlight: "它能碰什么，这里写清楚。",
  lede:
    "安全。在你开启手动控制之前，FanBar 只读取传感器。开启之后，一个开源的小型 Helper 只在每个风扇的硬件上下限之内设置目标转速，不做其他任何事。每个版本都经过 Apple 公证，所有说法你都可以亲自核实。",
  updatedLabel: "已对照源码核实于",
  updatedText: "2026 年 10 月 15 日",
  verifyLink: "亲自验证",
  disclosure:
    "FanBar 由我们维护，所以请把本页当作我们的说法，然后去核实。每条说法都链接到对应的源码文件，下面的命令可以直接在你的 Mac 上运行。",
  shortAnswers: {
    label: "简短回答",
    heading: "大家最先问的四个问题",
    items: [
      { question: "会损坏风扇吗？", answer: "不会。目标转速始终在风扇向 macOS 报告的最低与最高转速之间。", href: "#fans" },
      { question: "root Helper 做什么？", answer: "读取风扇、设置有上下限的目标值、把控制权交还 macOS，仅此而已。", href: "#helper" },
      { question: "能看源码吗？", answer: "能。App 和 Helper 都以 GPL-3.0 开源在 GitHub，Helper 约 700 行。", href: "#verify" },
      { question: "经过公证吗？", answer: "是。每个版本都使用 Developer ID 签名并经过 Apple 公证。", href: "#verify" },
    ],
  },
  fans: {
    label: "硬件",
    heading: "FanBar 会损坏风扇或让 Mac 过热吗？",
    intro: "手动风扇控制本身并非没有风险，所以 FanBar 的设计是始终停留在 Mac 自己定义的范围之内。",
    points: [
      {
        title: "转速始终在硬件范围内",
        body: "写入前，Helper 会读取每个风扇报告的最低和最高转速，并把所有目标值限制在这个范围内。唯一的例外是有意为之：温度曲线最低温的一段可以请求 0 RPM 静止，这和 Apple Silicon Mac 在温度较低时自己的做法一致。",
      },
      {
        title: "不改动 macOS 的过热保护",
        body: "FanBar 只写入风扇模式和目标转速。macOS 的降频和硬件的临界温度关机机制都不受影响，无论风扇设成什么都照常工作。",
      },
      {
        title: "在 root 边界拒绝异常输入",
        body: "即使请求来自被篡改的客户端，Helper 也会拒绝负数或非有限的转速值，以及超出 0–100% 的曲线比例。",
      },
      {
        title: "可选的高温提醒",
        body: "CPU 或 GPU 达到 90 °C 时，FanBar 可以发送通知，避免过于安静的设置被忽视。",
      },
    ],
    restoreHeading: "以下情况 FanBar 会把控制权交还 macOS：",
    restoreItems: [
      "你选择「自动」，或定时预设到期（15 分钟、30 分钟或 1 小时）",
      "你退出 FanBar，或最后一个连接 Helper 的 App 断开",
      "Helper 正在退出",
      "多风扇写入中任意一个失败——整机回滚，绝不停留在一半设置的状态",
    ],
    advice: "长时间全速运行主要带来噪音和额外磨损。日常使用建议选择「自动」或温度曲线。",
  },
  helper: {
    label: "特权 Helper",
    heading: "Helper 能做什么，不能做什么",
    intro:
      "在 macOS 上修改风扇转速需要以 root 身份访问 AppleSMC；读取温度则不需要。所以只有在你开启手动控制并在 macOS 中批准后，才会安装 Helper。",
    chain: ["FanBar.app", "签名 XPC", "FanBarHelper（root）", "AppleSMC 风扇键"],
    chainCaption: "菜单栏 App 从不直接接触硬件，而是通过 XPC 请求 Helper。",
    canHeading: "Helper 可以",
    can: [
      "读取风扇数量、当前转速，以及每个风扇的最低和最高转速",
      "设置目标转速、预设或曲线比例——都会限制在风扇范围之内",
      "恢复 macOS 自动风扇控制",
    ],
    cannotHeading: "Helper 不能",
    cannot: [
      "写入任意 SMC 键——接口中没有通用写入",
      "执行命令、读取文件或访问网络——这些功能的代码根本不存在",
      "接受其他 App 的指令——只接受与 FanBar 同一 Apple 开发者团队签名的客户端",
      "在 FanBar 断开后继续保持手动控制",
    ],
    sourceLabel: "阅读 Helper 源码",
  },
  verify: {
    label: "亲自验证",
    heading: "不必只听我们说",
    intro: "三项检查，几分钟就能完成，无需信任本页。",
    steps: [
      {
        title: "1. 确认 Apple 公证",
        body: "安装后在终端运行以下命令，macOS 应显示这是经过公证的 Developer ID 版本。",
        command: "spctl -a -vv /Applications/FanBar.app",
        output: "/Applications/FanBar.app: accepted\nsource=Notarized Developer ID\norigin=Developer ID Application: JiangLin He (64S5F787T9)",
      },
      {
        title: "2. 阅读以 root 运行的代码",
        body: "整个特权部分只有两个短文件。重点看客户端签名校验、输入检查和范围限制。",
        links: [
          { label: "FanBarHelperService.swift", href: safetySources.helperService },
          { label: "SMCFanDriver.swift", href: safetySources.fanDriver },
          { label: "FanCoolingTarget.swift", href: safetySources.coolingTarget },
        ],
      },
      {
        title: "3. 检查 App 的网络请求",
        body: "FanBar App 没有账号、广告或统计。它每天通过 Sparkle 向 GitHub Releases 检查一次更新，每个更新都必须通过 Apple 公证和 FanBar 自己的 EdDSA 签名校验。兼容性报告只有在你查看并确认后才会发送。",
      },
    ],
  },
  off: {
    label: "关闭方式",
    heading: "如何关闭或移除",
    items: [
      { title: "交还 macOS 控制", body: "在菜单栏弹窗中选择「自动」，Helper 会立即停止控制风扇。" },
      {
        title: "停用 Helper",
        body: "macOS 13 及以上：打开「系统设置 → 通用 → 登录项与扩展」，在「允许在后台」中关闭 FanBar。",
      },
      {
        title: "完全卸载",
        body: "先退出 FanBar。通过 Homebrew 安装的，以下命令会同时卸载 Helper，并删除偏好设置和缓存。",
        command: "brew uninstall --cask --zap helson-lin/fanbar/fanbar",
      },
    ],
  },
  faqLabel: "常见问题",
  faqHeading: "关于安全，直接回答",
  faq: [
    {
      question: "FanBar 安全吗？",
      answer:
        "安全。默认情况下 FanBar 只读取温度和风扇转速，散热由 macOS 管理。手动控制需要你明确批准一个签名 Helper，它只能在每个风扇的硬件范围内设置目标转速。FanBar 以 GPL-3.0 开源，每个版本都经过 Apple 公证。",
    },
    {
      question: "FanBar 会损坏 Mac 的风扇吗？",
      answer:
        "FanBar 会把所有目标值限制在每个风扇报告的最低和最高转速之间，无法让风扇超出额定范围。唯一的例外是温度曲线最低温一段有意设置的 0 RPM 静止，这和 Apple Silicon Mac 自己的做法一致。长时间全速运行主要带来噪音和额外磨损。",
    },
    {
      question: "风扇设错了会让 Mac 过热吗？",
      answer:
        "FanBar 不改动 macOS 的散热管理。温度升高时，无论风扇目标是多少，macOS 仍会降频，硬件仍会在临界温度时关机。FanBar 还可以在 CPU 或 GPU 达到 90 °C 时通知你。",
    },
    {
      question: "为什么 FanBar 需要管理员批准？",
      answer:
        "macOS 只允许 root 进程通过 AppleSMC 修改风扇转速。只有在你开启手动控制时 FanBar 才会请求批准，监控功能不需要。Helper 仅限于读取风扇、设置有上下限的目标值和恢复自动控制。",
    },
    {
      question: "FanBar 会收集我的数据吗？",
      answer:
        "不会。FanBar App 没有账号、统计或广告。唯一的网络活动是每天一次通过 Sparkle 向 GitHub Releases 检查更新，以及你主动选择发送、并经过你查看的兼容性报告，其中不含序列号等唯一标识。",
    },
    {
      question: "FanBar 是病毒或恶意软件吗？",
      answer:
        "不是。FanBar 使用 Apple Developer ID 签名并经过 Apple 公证，完整源码（包括特权 Helper）公开在 GitHub，任何人都可以审计。",
    },
  ],
  cta: {
    label: "试用 FanBar",
    heading: "先审查，准备好再安装。",
    body: "完整 App 免费。先读 Helper 源码，再下载经过公证的版本。",
    primary: "下载 FanBar",
    secondary: "阅读源码",
  },
};

export const safetyCopy: Record<FullLocale, SafetyCopy> = { en, zh };

export function safetyStructuredData(locale: FullLocale) {
  const copy = safetyCopy[locale];
  const url = safetyUrls[locale];
  const publisherId = `${siteUrl}/#publisher`;
  const lang = locale === "zh" ? "zh-Hans" : "en";

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
        "@id": `${url}#article`,
        headline: copy.title,
        description: copy.description,
        datePublished: safetyUpdated,
        dateModified: safetyUpdated,
        inLanguage: lang,
        mainEntityOfPage: { "@id": `${url}#webpage` },
        author: { "@id": publisherId },
        publisher: { "@id": publisherId },
        citation: Object.values(safetySources),
      },
      {
        "@type": "WebPage",
        "@id": `${url}#webpage`,
        url,
        name: copy.breadcrumb,
        inLanguage: lang,
        isPartOf: { "@id": `${siteUrl}/#website` },
        mainEntity: { "@id": `${url}#article` },
      },
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "FanBar", item: locale === "zh" ? `${siteUrl}/zh` : siteUrl },
          { "@type": "ListItem", position: 2, name: copy.breadcrumb, item: url },
        ],
      },
      {
        "@type": "FAQPage",
        "@id": `${url}#faq`,
        mainEntity: copy.faq.map((item) => ({
          "@type": "Question",
          name: item.question,
          acceptedAnswer: { "@type": "Answer", text: item.answer },
        })),
      },
    ],
  };
}
