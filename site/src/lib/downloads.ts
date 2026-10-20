import releaseSnapshot from "../data/releases.json";

export const downloadArchitectures = ["arm64", "x86_64", "universal"] as const;
export type DownloadArchitecture = (typeof downloadArchitectures)[number];

export function downloadArchitecture(name: string): DownloadArchitecture {
  if (name.includes("arm64")) return "arm64";
  if (name.includes("x86_64")) return "x86_64";
  return "universal";
}

// Use the same build-time snapshot as release notes. No browser API request,
// hardware guess, or hard-coded version is needed before a download can start.
const latest = [...releaseSnapshot.releases].sort((a, b) =>
  b.publishedAt.localeCompare(a.publishedAt),
)[0];

if (!latest) throw new Error("A published FanBar release is required for downloads.");

export const downloads = Object.fromEntries(downloadArchitectures.map((architecture) => {
  const asset = latest.assets.find((asset) =>
    asset.name.endsWith(".dmg") && downloadArchitecture(asset.name) === architecture,
  );
  if (!asset) throw new Error(`FanBar ${latest.version} is missing its ${architecture} DMG.`);
  return [architecture, { ...asset, architecture, version: latest.version }];
})) as Record<DownloadArchitecture, {
  name: string;
  size: number;
  url: string;
  architecture: DownloadArchitecture;
  version: string;
}>;

export const downloadCopy = {
  en: {
    choose: "Choose your Mac chip",
    arm64: "Apple Silicon",
    x86_64: "Intel",
    universal: "Universal",
    universalNote: "Default: Universal DMG for Apple Silicon and Intel. Choose a chip for a smaller download.",
  },
  zh: {
    choose: "选择 Mac 芯片",
    arm64: "Apple 芯片",
    x86_64: "Intel 芯片",
    universal: "通用版",
    universalNote: "默认下载兼容 Apple 芯片与 Intel 的通用版 DMG，也可选择更小的芯片专用版本。",
  },
  "zh-tw": {
    choose: "選擇 Mac 晶片",
    arm64: "Apple 晶片",
    x86_64: "Intel 晶片",
    universal: "通用版",
    universalNote: "預設下載同時支援 Apple 晶片與 Intel 的通用版 DMG，也可選擇檔案較小的晶片專用版本。",
  },
  ja: {
    choose: "Mac のチップを選択",
    arm64: "Apple シリコン",
    x86_64: "Intel",
    universal: "ユニバーサル",
    universalNote: "既定では Apple シリコンと Intel の両方に対応するユニバーサル DMG をダウンロードします。チップを選ぶとより小さいファイルになります。",
  },
  fr: {
    choose: "Choisir la puce du Mac",
    arm64: "Apple Silicon",
    x86_64: "Intel",
    universal: "Universelle",
    universalNote: "Par défaut : DMG universel pour Apple Silicon et Intel. Choisissez une puce pour un téléchargement plus léger.",
  },
  ru: {
    choose: "Выберите процессор Mac",
    arm64: "Apple Silicon",
    x86_64: "Intel",
    universal: "Универсальная",
    universalNote: "По умолчанию: универсальный DMG для Apple Silicon и Intel. Выберите процессор, чтобы скачать файл меньшего размера.",
  },
} as const;
