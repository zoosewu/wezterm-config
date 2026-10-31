# WezTerm Config — CLAUDE.md

## 專案概覽

WezTerm 終端機設定，使用 Lua 撰寫。最初 fork 自 [KevinSilvester/wezterm-config](https://github.com/KevinSilvester/wezterm-config)，現已獨立維護。

> **重要**：本專案不再追蹤上游，所有檔案（含 `utils/`、`events/`）都可依需求自由修改或重寫，不需為了避免合併衝突而保持最小改動。

---

## 專案結構

```
wezterm.lua            # 主入口，以 Config:init():append() 鏈式組裝所有模組
config/
  appearance.lua       # 外觀（主題、背景透明度、front_end）
  bindings.lua         # 全部快捷鍵定義（keys / key_tables / mouse_bindings）
  domains.lua          # SSH / WSL domain 設定
  fonts.lua            # 字型設定
  general.lua          # 一般設定（滾動行數、游標等）
  init.lua             # Config class（append 合併邏輯）
  launch.lua           # Launch menu 偏好 shell
events/
  gui-startup.lua      # 唯一的 gui-startup handler：spawn（geometry）→ maximize → session restore → 執行 deferred 工作
  new-tab-button.lua   # 新分頁 + 按鈕
  status.lua           # 左右狀態列（單一 update-status：keytable / workspace / 程序；日期 / CWD / 電池），TTL 快取、未變不重送
  tab-title.lua        # Tab 標題：純 render function + memo（unseen 通知、WSL/Admin 偵測、自訂標題存於 tab:set_title）
utils/
  backdrops.lua        # 背景圖片管理（per-window 狀態、隨機 / 循環 / Fuzzy / focus）
  cwd.lua              # pane 工作目錄：get / for_domain（依目標 domain 轉換）/ shorten / is_wsl_domain
  font-installer.lua   # 缺少字型時先用內建 fallback，背景自動下載至 state 目錄的 fonts/ 後 reload
  gpu-adapter.lua      # WebGPU 最佳 GPU+API 自動選擇器（磁碟快取加速啟動）
  health-check.lua     # 啟動自我診斷（F12 Debug Overlay 查看）
  keymap-help.lua      # 快捷鍵速查（SUPER+F1），清單由 bindings.lua 自動產生，中文說明在此維護
  platform.lua         # 平台偵測（is_mac / is_win / is_linux）與快捷鍵 modifier（mods.SUPER / SUPER_REV）
  process-name.lua     # pane 前景程序名稱（優先用 format-tab-title 拿到的快取值，避免 process snapshot）
  scratchpad.lua       # 快速筆記 pane（per-tab 底部 25% 浮動）
  segment.lua          # 產生 wezterm.format FormatItem 的純函式
  startup.lua          # 啟動後背景工作（defer / run_deferred），不阻塞第一個視窗
  state-file.lua       # JSON 狀態檔讀寫（存於 config 目錄外，WEZTERM_STATE_DIR 可覆寫）
  session.lua          # Session 持久化（儲存 / 還原 tab 的 cwd、domain、自訂標題）
  theme-switcher.lua   # 依系統深/淺色選擇配色（Catppuccin Mocha / Latte；外觀改變時 WezTerm 會自動 reload）
  timing.lua           # 啟動計時工具（timing.ENABLED = true 開啟）
  window-geometry.lua  # 估算接近全螢幕的初始視窗大小，避免 maximize 造成啟動閃爍
  window-state.lua     # 跨 reload 保留的 per-window/per-tab 狀態（set_override、namespace），所有 override 都經由這裡
colors/
  custom.lua           # Catppuccin Mocha 深色主題
  catppuccin-latte.lua # Catppuccin Latte 淺色主題
backdrops/             # 背景圖片資源
tests/
  run.lua              # headless 測試（經由各模組 interface），見下方「測試」
```

---

## 修改原則

1. **以程式碼品質為優先**：發現 shallow module、重複邏輯或 bug 時直接重構，不必保留上游原貌。
2. **Lua state 生命週期**：每次 config reload 都會換掉 Lua state，module-local 表會清空，`wezterm.on` handler 也只屬於當次的 state。需要跨 reload 保留的狀態一律使用 `utils/window-state.lua`（per-window/per-tab）或 WezTerm 自身（例如 `tab:set_title()`）。注意：`wezterm.GLOBAL` 的巢狀值讀回來是 `Value` userdata（不能做算術、和 number 比較永遠不相等），指定 `nil` 也刪不掉 key；WezTerm 沒有 `window-closed` event。
3. **新增模組**：設定類模組透過 `wezterm.lua` 的 `:append(require('config.xxx'))` 加入；事件 / 工具模組放在 `events/`、`utils/`，並在 `wezterm.lua` 呼叫 `setup()`。

---

## 測試

修改 `utils/`、`events/`、`config/` 後必須執行 headless 測試（不開視窗，`ls-fonts` 會把檔案當 config 求值）：

```bash
wezterm --config-file tests/run.lua ls-fonts --text a 2>&1 | grep "\[test\]"
```

- 最後一行應為 `[test] N/N passed`；有失敗時會出現 `FAIL` 並觸發 config error。
- 新增純邏輯或修 bug 時，在 `tests/run.lua` 補對應案例（透過模組的公開 interface 測，不要測私有函式）。
- 需要 GUI 的行為（reload、override、spawn）測試時：用包裝 config 指向本 repo、`WEZTERM_STATE_DIR` 指向暫存目錄，且 **log 不可寫進 config 目錄**（WezTerm 會監看並觸發 reload）。

---

## PS Profile 格式規則

更新 `/mnt/PowerShell/Microsoft.PowerShell_profile.ps1` 時，快捷鍵表格須遵守以下排版規則：

- **每行顯示三組**快捷鍵與說明
- **欄位寬度**：key = 15 display chars、desc = 19 display chars
- **欄間距**：4 個空格（約 1.4 倍字元間距）
- **對齊方式**：必須使用 CJK 雙寬字元感知的 `Get-DispWidth` + `Pad` 函式補齊，禁止直接使用 PowerShell 的 `-f` 格式化（CJK 字元計 2 寬，`-f` 不感知導致歪掉）
- 每次 `config/bindings.lua` 有異動時，需同步更新 PS profile 中對應的快捷鍵資料，以及 `utils/keymap-help.lua` 的 `SECTIONS` 中文說明（未加說明的綁定會顯示在「其他」並列出 action 名稱）

---

## PS Profile 備份規則

`/mnt/PowerShell/Microsoft.PowerShell_profile.ps1` 的備份存放於本專案的 `powershell/Microsoft.PowerShell_profile.ps1`，由 git 管理版本。

**每次修改完 PS Profile 後，必須執行以下備份指令：**

```bash
cp /mnt/PowerShell/Microsoft.PowerShell_profile.ps1 /workspace/powershell/Microsoft.PowerShell_profile.ps1
```

---

## 工作結束後的例行檢查

每次工作完成後，**必須**確認以下三處是否需要更新（內容以實際修改為準）：

1. **`README.md`**：確保文件與當前設定一致
2. **`/mnt/PowerShell/Microsoft.PowerShell_profile.ps1`**（若檔案存在）：確保 PS profile 中的說明與設定一致
3. **`powershell/Microsoft.PowerShell_profile.ps1`**：將 PS profile 備份至本專案（執行上方備份指令）

> **注意**：修改 `config/bindings.lua` 時，hook 會自動提醒同步。其他檔案的修改請自行判斷是否影響上述三處。
