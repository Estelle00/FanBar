import type { Dictionary } from "../i18n";

// Traditional Chinese (Taiwan): home page only. Mode and menu names match the
// app's Traditional Chinese interface; pages that exist only in English say so.
export const zhTw: Dictionary = {
  meta: {
    title: "FanBar — 免費開源的 Mac 風扇控制",
    description:
      "FanBar 是免費開源的 Mac 選單列風扇控制 App：即時查看 CPU、GPU、SSD 與電池溫度和風扇轉速，可設定固定轉速或依溫度調整的風扇曲線。",
    ogDescription: "免費開源的 Mac 選單列風扇控制：即時溫度、固定轉速，以及可編輯的溫控曲線。",
    keywords: [
      "FanBar",
      "Mac 風扇控制",
      "Mac 溫度監控",
      "選單列溫度工具",
      "MacBook 風扇轉速",
      "AppleSMC",
      "開源 Mac 軟體",
      "Macs Fan Control 替代",
    ],
  },
  nav: {
    highlights: "亮點",
    screenshots: "截圖",
    howItWorks: "使用方式",
    faq: "常見問題",
    compare: "產品比較",
    releases: "更新紀錄",
    compatibility: "相容性",
    safety: "安全性",
    download: "下載",
  },
  a11y: {
    mainNav: "主要導覽",
    footerNav: "頁尾導覽",
    facts: "FanBar 資訊",
    languageMenu: "語言",
  },
  hero: {
    badge: "免費 · 開源 · 原生 macOS",
    titleLead: "讓 Mac 保持涼爽，",
    titleHighlight: "噪音卻降到最低。",
    subtitle:
      "FanBar 是免費開源的 Mac 選單列風扇控制 App。即時查看溫度與風扇轉速，設定固定轉速，或建立依溫度調整的風扇曲線。支援 macOS 11 及更新版本、相容的 Apple 晶片與 Intel Mac。",
    primaryCta: "下載 macOS 版",
    secondaryCta: "在 GitHub 查看",
    compatibilityCta: "查看相容性證據（英文）",
    caption: "MACOS 11 以上 · APPLE 晶片與 INTEL · DMG 與 HOMEBREW",
  },
  stats: [
    { value: "11+", label: "macOS Big Sur 及更新版本" },
    { value: "6", label: "種散熱模式，從自動到極速" },
    { value: "1 h", label: "溫度趨勢，10 分鐘到 1 小時" },
    { value: "6", label: "種介面語言，即時切換" },
  ],
  highlights: {
    badge: "亮點",
    heading: "了解並掌控 Mac 風扇，所需的一切都在這裡。",
    items: {
      status: {
        title: "狀態一目了然",
        description: "選單列可顯示圖像、CPU 溫度、平均風扇 RPM，或並排、上下排列兩者。",
      },
      icons: {
        title: "六款選單列圖像",
        description: "六種圖像可選，隨風扇旋轉，風扇停轉時緩緩靜止。",
      },
      widget: {
        title: "桌面小工具",
        description: "macOS 14 及更新版本可將 FanBar 加入桌面，查看 RPM、各風扇轉速與控制模式。",
      },
      live: {
        title: "即時視覺化",
        description: "每個風扇先顯示轉速，轉速條從 0 到最大值；溫度趨勢可看 10 分鐘到 1 小時。",
      },
      resources: {
        title: "負載一目了然",
        description: "CPU、GPU、記憶體與磁碟集中在一個網格裡，依程度著色並附文字說明。",
      },
      modes: {
        title: "多種散熱模式",
        description: "自動、固定目標轉速，或靜音、均衡、效能、極速預設。",
      },
      curves: {
        title: "智慧溫控曲線",
        description: "每個預設都有獨立可編輯的曲線，將溫度對應到風扇轉速。",
      },
      source: {
        title: "溫度來源可選",
        description: "可選 CPU、GPU 或 SSD 驅動曲線；感測器無法使用時會安全回復。",
      },
      alerts: {
        title: "高溫通知",
        description: "可自訂門檻（60–105°C）與提示音；過熱時一鍵切換到最大散熱。",
      },
      log: {
        title: "CSV 日誌",
        description: "每 2–60 秒將溫度、風扇轉速與控制模式記錄到 CSV 檔案。",
      },
      safe: {
        title: "預設即安全",
        description: "轉速始終限制在硬體範圍內；發生異常時會恢復系統自動控制。",
      },
      language: {
        title: "六種介面語言",
        description: "English、简体中文、繁體中文、日本語、Русский 與 Français——無需重新啟動即可切換。",
      },
    },
  },
  trust: {
    badge: "值得信賴",
    heading: "只有你同意後，才會開放手動控制。",
    body: "FanBar 平時讓 macOS 自行管理散熱，安全又安靜。只有在你明確授權已簽署的特權服務後，才會開放手動風扇控制；首次使用時會說明原因。",
    points: [
      "FanBar.app → 特權 XPC → 已簽署 Helper（root）→ AppleSMC",
      "Helper 只能讀取風扇資料、設定有限範圍內的目標值，從不提供任意 SMC 寫入",
      "預設可在 15 分鐘、30 分鐘或 1 小時後自動恢復「自動」模式",
      "每個版本都經過 Apple 公證；完整原始碼（含 Helper）公開在 GitHub",
    ],
    cta: "FanBar 安全嗎？看看 Helper 能做什麼（英文）",
  },
  screenshots: {
    badge: "介面",
    heading: "沉穩、原生的介面，而不是儀表板。",
    items: {
      popover: {
        alt: "FanBar 選單列面板",
        title: "選單列面板",
        description: "每個風扇的即時轉速、系統負載、溫度與模式切換。",
      },
      cooling: {
        alt: "FanBar 散熱設定",
        title: "溫控曲線",
        description: "每個預設的溫度 → 轉速曲線，可自由編輯。",
      },
      menubar: {
        alt: "FanBar 選單列顯示設定",
        title: "選單列顯示",
        description: "套用前先預覽選單列的顯示效果。",
      },
    },
  },
  howItWorks: {
    badge: "使用方式",
    heading: "從安裝到手動控制，只要三步。",
    steps: [
      {
        step: "01",
        title: "啟動並查看",
        description: "打開 FanBar，選單列就會顯示目前的溫度與轉速。",
      },
      {
        step: "02",
        title: "授權一次",
        description: "第一次切換模式時，完成一次 macOS 授權；不授權也能查看溫度和轉速。",
      },
      {
        step: "03",
        title: "選擇預設",
        description: "選一個預設或固定轉速，隨時都能切回「自動」。",
      },
    ],
  },
  faq: {
    badge: "常見問題",
    heading: "用白話回答常見問題。",
    body: "支援範圍、權限、授權條款，以及手動風扇控制實際做了什麼：簡短具體，不繞圈子。",
    items: [
      {
        question: "FanBar 是什麼？",
        answer:
          "FanBar 是免費開源的 macOS 選單列 App，可即時顯示 CPU、GPU、SSD 與電池溫度，並在需要時手動設定風扇轉速。它支援 macOS 11 Big Sur 及更新版本，以及能透過 AppleSMC 讀取風扇資料的 Apple 晶片與 Intel Mac。日常散熱仍由 macOS 自動管理，手動模式可隨時退回。",
      },
      {
        question: "FanBar 免費嗎？需要註冊帳號嗎？",
        answer:
          "免費且開源，採用 GPL-3.0 授權，無需帳號、訂閱，也沒有廣告。經過公證的安裝檔發布在 GitHub Releases，完整原始碼（包含特權 Helper）公開可查。",
      },
      {
        question: "支援哪些 Mac 與 macOS 版本？",
        answer:
          "macOS 11 Big Sur 及更新版本，Apple 晶片與 Intel Mac 皆可，前提是硬體能透過 AppleSMC 提供可讀取的風扇資料。桌面小工具需要 macOS 14 及更新版本；控制服務在 macOS 13 及更新版本透過 SMAppService 註冊，macOS 11–12 則使用 launchd。",
      },
      {
        question: "FanBar 需要 root 權限或安裝特權服務嗎？",
        answer:
          "只有手動控制風扇時才需要，而且必須由你授權。FanBar.app 透過特權 XPC 與已簽署的 FanBarHelper 溝通：Helper 以 root 執行，但不提供任意 SMC 寫入，只能讀取風扇狀態、設定有限範圍內的目標值，以及恢復自動控制。如果你從不啟用風扇控制，Helper 會一直閒置。",
      },
      {
        question: "FanBar 能讀取哪些溫度與轉速？",
        answer:
          "所有支援的 Mac 都能讀取 CPU 與 GPU 溫度；硬體提供對應感測器時，也會讀取 SSD 與電池溫度。它會讀取每個風扇的目前轉速與硬體上下限，選單列可顯示圖像、CPU 溫度、平均轉速或兩者組合。CPU 或 GPU 達到你設定的門檻（60–105°C，預設 90°C）時，可選擇傳送通知。",
      },
      {
        question: "FanBar 提供哪些散熱模式？",
        answer:
          "共六種：自動（交還 macOS 控制）、固定目標轉速，以及靜音、均衡、效能、極速四個預設曲線。每個預設都有獨立可編輯的溫度 → 轉速曲線，並可固定到選單列面板；預設可在 15 分鐘、30 分鐘或 1 小時後自動恢復「自動」。",
      },
      {
        question: "手動控制失效或 App 結束時會怎樣？",
        answer:
          "目標轉速始終限制在每個風扇回報的硬體範圍內；當預設到期、App 結束或連線中斷、控制服務失敗時，FanBar 會恢復 macOS 自動控制，手動設定不會在背景悄悄持續生效。",
      },
      {
        question: "FanBar 支援哪些語言？",
        answer:
          "英文、簡體中文、繁體中文、日文、俄文與法文。在「設定 → 一般 → 介面語言」中選擇跟隨系統或指定語言，選單列面板、設定視窗、引導流程與狀態提示都會立即切換，無需重新啟動。",
      },
    ],
  },
  finalCta: {
    badge: "下載",
    heading: "讓風扇的工作，從容一點。",
    body: "經過公證的 Apple 晶片、Intel 與通用版安裝檔。免費開源，也坦白說明手動控制的取捨。",
    primaryCta: "下載 .dmg",
    secondaryCta: "在 GitHub 查看",
    caption: "MACOS 11 以上 · APPLE 晶片與 INTEL · GPL-3.0 授權",
    latest: "最新版本：FanBar {version}，發布於 {date}",
    latestLink: "查看更新內容（英文）",
  },
  footer: {
    copyright: "FanBar · GPL-3.0 授權",
    github: "GitHub",
    releases: "更新紀錄（英文）",
  },
};
