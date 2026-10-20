# FanBar — 免費開源的 Mac 風扇控制

正式頁面：https://getfanbar.com/zh-tw · English: https://getfanbar.com/

FanBar 是免費開源（GPL-3.0）的 macOS 選單列 App，可顯示 CPU、GPU、SSD 與電池溫度和風扇轉速，並可設定固定轉速或「溫度 → 轉速」曲線。支援 macOS 11 Big Sur 及更新版本，以及能透過 AppleSMC 提供風扇資料的 Apple 晶片與 Intel Mac。

介面語言：English、简体中文、繁體中文、日本語、Русский、Français。可在「設定 → 一般 → 介面語言」中切換，無需重新啟動。

## 功能

- 選單列顯示溫度與轉速；六款選單列圖像會隨風扇旋轉；macOS 14 及更新版本可使用桌面小工具
- 每個風扇以 0 到最大值的轉速條顯示轉速，CPU、GPU、記憶體與磁碟負載網格，以及 10 分鐘到 1 小時的溫度趨勢
- 模式：自動、固定轉速，以及可編輯曲線的靜音、均衡、效能、極速預設
- 曲線溫度來源可選 CPU、GPU 或 SSD
- 可選的高溫通知：門檻 60–105°C（預設 90°C），可選提示音；過熱時一鍵切換到最大散熱
- CSV 日誌：每 2–60 秒記錄溫度、轉速與控制模式

## 安全性

- 只有在 macOS 中明確授權已簽署的 Helper 後，才會開放手動控制；監控不需要 Helper。
- Helper（root）只能讀取風扇資料、在每個風扇的範圍內設定轉速，以及恢復自動控制，不提供任意 SMC 寫入。
- App 結束、連線中斷、Helper 失敗或預設到期時，會恢復 macOS 自動控制。
- 詳細說明（英文）：https://getfanbar.com/is-fanbar-safe

## 下載

請只從 GitHub Releases（https://github.com/helson-lin/FanBar/releases/latest）或 Homebrew 安裝：

```sh
brew tap helson-lin/fanbar https://github.com/helson-lin/FanBar.git
brew install --cask helson-lin/fanbar/fanbar
```

文件：https://github.com/helson-lin/FanBar/blob/main/README.zh-TW.md
