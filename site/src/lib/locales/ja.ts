import type { Dictionary } from "../i18n";

// Japanese: home page only. Mode and menu names match the app's Japanese
// interface; pages that exist only in English say so.
export const ja: Dictionary = {
  meta: {
    title: "FanBar — 無料・オープンソースの Mac ファン制御",
    description:
      "FanBar は無料・オープンソースの Mac 用メニューバーアプリです。CPU、GPU、SSD、バッテリーの温度とファン回転数を確認し、回転数の固定や温度に応じたファンカーブを設定できます。",
    ogDescription:
      "メニューバーから使える無料・オープンソースの Mac ファン制御。リアルタイムの温度、回転数の固定、編集できる温度カーブ。",
    keywords: [
      "FanBar",
      "Mac ファン制御",
      "Mac ファン 回転数",
      "Mac 温度 確認",
      "メニューバー 温度",
      "MacBook ファン うるさい",
      "AppleSMC",
      "Macs Fan Control 代替",
    ],
  },
  nav: {
    highlights: "主な機能",
    screenshots: "スクリーンショット",
    howItWorks: "使い方",
    faq: "よくある質問",
    compare: "比較",
    releases: "リリースノート",
    compatibility: "互換性",
    safety: "安全性",
    download: "ダウンロード",
  },
  a11y: {
    mainNav: "メインナビゲーション",
    footerNav: "フッターナビゲーション",
    facts: "FanBar の概要",
    languageMenu: "言語",
  },
  hero: {
    badge: "無料 · オープンソース · ネイティブ macOS",
    titleLead: "Mac のファンを、",
    titleHighlight: "無料で制御。",
    subtitle:
      "FanBar は無料・オープンソースの Mac 用メニューバーアプリです。温度とファン回転数をリアルタイムで確認し、回転数を固定したり、温度に応じたファンカーブを作成したりできます。macOS 11 以降の対応する Apple シリコン搭載 Mac と Intel Mac で動作します。",
    primaryCta: "macOS 版をダウンロード",
    secondaryCta: "GitHub で見る",
    compatibilityCta: "互換性の根拠を見る（英語）",
    caption: "MACOS 11 以降 · APPLE シリコンと INTEL · DMG と HOMEBREW",
  },
  stats: [
    { value: "11+", label: "macOS Big Sur 以降" },
    { value: "6", label: "種類の冷却モード（自動〜最大）" },
    { value: "1 h", label: "温度グラフ、10 分〜1 時間" },
    { value: "6", label: "つの表示言語、再起動なしで切替" },
  ],
  highlights: {
    badge: "主な機能",
    heading: "Mac のファンを理解し、思いどおりに整えるために。",
    items: {
      status: {
        title: "状態をひと目で確認",
        description: "メニューバーにアイコン、CPU 温度、平均回転数、またはその組み合わせを横並びや 2 段で表示。",
      },
      icons: {
        title: "6 種類のメニューバーアイコン",
        description: "ファンの回転に合わせてアイコンが回り、ファンが止まるとゆっくり停止します。",
      },
      widget: {
        title: "デスクトップウィジェット",
        description: "macOS 14 以降では、回転数、ファンごとの速度、制御モードをデスクトップに表示できます。",
      },
      live: {
        title: "リアルタイムの可視化",
        description: "ファンごとの回転数を 0 から最大値までのメーターで表示。温度グラフは 10 分〜1 時間。",
      },
      resources: {
        title: "負荷をひと目で",
        description: "CPU、GPU、メモリ、ディスクを 1 つのグリッドに。程度を色と言葉の両方で示します。",
      },
      modes: {
        title: "複数の冷却モード",
        description: "自動、目標回転数の固定、または静音・バランス・高性能・最大のプリセット。",
      },
      curves: {
        title: "スマートな温度カーブ",
        description: "プリセットごとに編集できるカーブで、温度をファンの出力に対応させます。",
      },
      source: {
        title: "温度ソースを選択",
        description: "カーブを CPU、GPU、SSD のいずれかで制御。センサーがない場合は安全に切り替わります。",
      },
      alerts: {
        title: "高温通知",
        description: "しきい値（60〜105°C）と通知音を選べます。高温時はワンクリックで最大冷却へ。",
      },
      log: {
        title: "CSV ログ",
        description: "温度、ファン回転数、制御モードを 2〜60 秒ごとに CSV ファイルへ記録します。",
      },
      safe: {
        title: "安全が標準",
        description: "回転数は常にハードウェアの範囲内。異常時は macOS の自動制御に戻します。",
      },
      language: {
        title: "6 つの表示言語",
        description: "English、简体中文、繁體中文、日本語、Русский、Français を再起動なしで切り替えられます。",
      },
    },
  },
  trust: {
    badge: "信頼できる設計",
    heading: "手動制御は、あなたが許可したときだけ。",
    body: "ふだんは macOS 自身の自動制御のまま、安全で静かに使えます。手動のファン制御は、署名済みの特権ヘルパーをあなたが明示的に許可したあとにだけ有効になります。初回起動時に、なぜ必要なのかを説明します。",
    points: [
      "FanBar.app → 特権 XPC → 署名済みヘルパー（root）→ AppleSMC",
      "ヘルパーはファンの読み取りと範囲内の目標値の設定だけを行い、任意の SMC 書き込みはしません",
      "プリセットは 15 分、30 分、1 時間後に自動で「自動」に戻せます",
      "すべてのリリースは Apple の公証済み。ヘルパーを含むソースコードはすべて公開されています",
    ],
    cta: "FanBar は安全？ヘルパーにできることを確認する（英語）",
  },
  screenshots: {
    badge: "インターフェイス",
    heading: "落ち着いたネイティブのインターフェイス。ダッシュボードではありません。",
    items: {
      popover: {
        alt: "FanBar のメニューバーパネル",
        title: "メニューバーパネル",
        description: "ファンごとの回転数、システム負荷、温度、モード切り替え。",
      },
      cooling: {
        alt: "FanBar の冷却設定",
        title: "温度カーブ",
        description: "プリセットごとの温度 → 回転数カーブを自由に編集できます。",
      },
      menubar: {
        alt: "FanBar のメニューバー表示設定",
        title: "メニューバーの表示",
        description: "メニューバーに何を表示するか、適用前にプレビューできます。",
      },
    },
  },
  howItWorks: {
    badge: "使い方",
    heading: "インストールから手動制御まで、3 ステップ。",
    steps: [
      {
        step: "01",
        title: "起動して確認",
        description: "FanBar を開くと、現在の温度とファン回転数がメニューバーに表示されます。",
      },
      {
        step: "02",
        title: "一度だけ許可",
        description: "初めてモードを切り替えるときに、macOS の許可を一度だけ行います。温度と回転数は許可なしでも見られます。",
      },
      {
        step: "03",
        title: "プリセットを選ぶ",
        description: "プリセットか固定回転数を選びます。いつでも「自動」に戻せます。",
      },
    ],
  },
  faq: {
    badge: "よくある質問",
    heading: "わかりやすい言葉でお答えします。",
    body: "対応環境、権限、ライセンス、そして手動のファン制御が実際に何をするのか。短く、宣伝抜きで。",
    items: [
      {
        question: "FanBar とは？",
        answer:
          "FanBar は無料・オープンソースの macOS 用メニューバーアプリです。CPU、GPU、SSD、バッテリーの温度をリアルタイムで表示し、必要なときにファン回転数を手動で設定できます。macOS 11 Big Sur 以降で、AppleSMC からファンのデータを読み取れる Apple シリコン搭載 Mac と Intel Mac に対応しています。ふだんの冷却は macOS の自動制御のままで、手動モードは任意でいつでも元に戻せます。",
      },
      {
        question: "無料ですか？アカウントは必要ですか？",
        answer:
          "無料で、GPL-3.0 ライセンスのオープンソースです。アカウント、サブスクリプション、広告はありません。公証済みのビルドは GitHub Releases で公開され、特権ヘルパーを含むソースコードもすべて公開されています。",
      },
      {
        question: "対応している Mac と macOS は？",
        answer:
          "macOS 11 Big Sur 以降で、AppleSMC からファンのデータを読み取れる Apple シリコン搭載 Mac と Intel Mac です。デスクトップウィジェットには macOS 14 以降が必要です。制御サービスは macOS 13 以降では SMAppService、macOS 11〜12 では launchd で登録されます。",
      },
      {
        question: "root 権限や特権ヘルパーのインストールは必要ですか？",
        answer:
          "手動でファンを制御する場合にだけ、あなたの許可のもとで必要になります。FanBar.app は特権 XPC を通じて署名済みの FanBarHelper とやり取りします。ヘルパーは root で動作しますが、任意の SMC 書き込みはできず、ファンの状態の読み取り、範囲内の目標値の設定、自動制御への復帰だけを行います。ファン制御を有効にしなければ、ヘルパーは使われません。",
      },
      {
        question: "どの温度と回転数を読み取れますか？",
        answer:
          "対応するすべての Mac で CPU と GPU の温度を、センサーがあれば SSD とバッテリーの温度も読み取ります。各ファンの現在の回転数とハードウェア上の最小・最大値も取得し、メニューバーにはアイコン、CPU 温度、平均回転数、またはその組み合わせを表示できます。CPU または GPU が設定した温度（60〜105°C、初期値 90°C）に達したときの通知も選べます。",
      },
      {
        question: "どんな冷却モードがありますか？",
        answer:
          "6 種類です。自動（macOS による制御）、目標回転数の固定、そして静音・バランス・高性能・最大の 4 つのプリセットカーブ。各プリセットには編集できる温度 → 回転数カーブがあり、メニューバーのパネルに表示できます。プリセットは 15 分、30 分、1 時間後に自動で「自動」に戻すこともできます。",
      },
      {
        question: "手動制御に失敗したり、アプリが終了したりしたら？",
        answer:
          "目標回転数は常に各ファンが報告するハードウェアの範囲内に制限されます。プリセットの期限切れ、アプリの終了や接続の切断、制御サービスの障害のときには、FanBar は macOS の自動制御に戻します。手動の設定がバックグラウンドで黙って続くことはありません。",
      },
      {
        question: "どの言語に対応していますか？",
        answer:
          "英語、簡体字中国語、繁体字中国語、日本語、ロシア語、フランス語です。「設定 → 一般 → 表示言語」でシステムに合わせるか言語を指定でき、メニューバーパネル、設定、初回ガイド、状態メッセージが再起動なしですぐに切り替わります。",
      },
    ],
  },
  finalCta: {
    badge: "ダウンロード",
    heading: "ファンを、もっと穏やかに。",
    body: "Apple シリコン、Intel、ユニバーサル向けの公証済みビルド。無料・オープンソースで、手動制御のトレードオフも隠しません。",
    primaryCta: ".dmg をダウンロード",
    secondaryCta: "GitHub で見る",
    caption: "MACOS 11 以降 · APPLE シリコンと INTEL · GPL-3.0 ライセンス",
    latest: "最新版：FanBar {version}（{date} 公開）",
    latestLink: "新機能（英語）",
  },
  footer: {
    copyright: "FanBar · GPL-3.0 ライセンス",
    github: "GitHub",
    releases: "リリースノート（英語）",
  },
};
