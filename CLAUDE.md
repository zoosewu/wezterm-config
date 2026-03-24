# WezTerm Config — CLAUDE.md

## 專案概覽

Clone 自 [KevinSilvester/wezterm-config](https://github.com/KevinSilvester/wezterm-config) 的 WezTerm 終端機設定，使用 Lua 撰寫。

> **重要**：本專案隨時會從上游 main branch 拉取更新。所有客製化改動必須保持最小化，以降低合併衝突風險。

---

## 專案結構

```
wezterm.lua            # 主入口，以 Config:init():append() 鏈式組裝所有模組
config/
  appearance.lua       # 外觀（主題、背景透明度、front_end）
  bindings.lua         # 全部快捷鍵定義（keys / key_tables / mouse_bindings）
  domains.lua          # SSH / WSL domain 設定 ← 客製化優先修改這裡
  fonts.lua            # 字型設定
  general.lua          # 一般設定（滾動行數、游標等）
  init.lua             # Config class（append 合併邏輯）
  launch.lua           # Launch menu 偏好 shell ← 客製化優先修改這裡
events/
  gui-startup.lua      # GUI 啟動事件（session restore、maximize）
  left-status.lua      # 左側狀態列（keytable / workspace / pane 程序）
  right-status.lua     # 右側狀態列（日期時間、CWD）
  new-tab-button.lua   # 新分頁 + 按鈕
  tab-title.lua        # Tab 標題（含 unseen 通知、WSL/Admin 偵測）
utils/
  backdrops.lua        # 背景圖片管理（per-window 狀態、隨機 / 循環 / Fuzzy / focus）
  cells.lua            # 狀態列 cell 工具
  gpu-adapter.lua      # WebGPU 最佳 GPU+API 自動選擇器（磁碟快取加速啟動）
  health-check.lua     # 啟動自我診斷（F12 Debug Overlay 查看）
  math.lua             # 數學工具
  opts-validator.lua   # 選項型別驗證
  platform.lua         # 平台偵測（is_mac / is_win / is_linux）
  scratchpad.lua       # 快速筆記 pane（per-tab 底部 25% 浮動）
  session.lua          # Session 持久化（儲存 / 還原 tab CWD）
  theme-switcher.lua   # 自動深/淺色主題切換（Catppuccin Mocha / Latte）
  timing.lua           # 啟動計時工具（timing.ENABLED = true 開啟）
  window-overrides.lua # 集中式 per-window config override 管理器
colors/
  custom.lua           # Catppuccin Mocha 深色主題
  catppuccin-latte.lua # Catppuccin Latte 淺色主題
backdrops/             # 背景圖片資源
```

---

## 修改原則（upstream 安全策略）

1. **不改核心邏輯**：`utils/`、`events/` 盡量不動，避免 upstream 更新時產生衝突。
2. **客製化入口**：優先修改 `config/domains.lua`（WSL/SSH）與 `config/launch.lua`（shell 路徑）。
3. **新增功能**：透過 `wezterm.lua` 的 `:append(require('config.xxx'))` 鏈式加入新模組，不覆蓋既有檔案。
4. **拉取前確認**：
   ```bash
   git status && git diff    # 確認本地改動
   git pull origin main      # 拉取 upstream
   ```

---

## PS Profile 格式規則

更新 `/mnt/PowerShell/Microsoft.PowerShell_profile.ps1` 時，快捷鍵表格須遵守以下排版規則：

- **每行顯示三組**快捷鍵與說明
- **欄位寬度**：key = 15 display chars、desc = 19 display chars
- **欄間距**：4 個空格（約 1.4 倍字元間距）
- **對齊方式**：必須使用 CJK 雙寬字元感知的 `Get-DispWidth` + `Pad` 函式補齊，禁止直接使用 PowerShell 的 `-f` 格式化（CJK 字元計 2 寬，`-f` 不感知導致歪掉）
- 每次 `config/bindings.lua` 有異動時，需同步更新 PS profile 中對應的快捷鍵資料

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
