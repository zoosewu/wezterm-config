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
  gui-startup.lua      # GUI 啟動事件
  left-status.lua      # 左側狀態列
  right-status.lua     # 右側狀態列（顯示日期時間）
  new-tab-button.lua   # 新分頁 + 按鈕
  tab-title.lua        # Tab 標題（含 unseen 通知）
utils/
  backdrops.lua        # 背景圖片管理（隨機 / 循環 / Fuzzy 搜尋 / toggle focus）
  cells.lua            # 狀態列 cell 工具
  gpu-adapter.lua      # WebGPU 最佳 GPU+API 自動選擇器
  math.lua             # 數學工具
  opts-validator.lua   # 選項型別驗證
  platform.lua         # 平台偵測（is_mac / is_win / is_linux）
colors/                # 自訂色彩主題 (.toml)
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

## 快捷鍵速查（Windows / Linux）

> macOS：SUPER = `Super`，SUPER_REV = `Super+Ctrl`
> Windows/Linux：SUPER = `Alt`，SUPER_REV = `Alt+Ctrl`
> LEADER = `SUPER_REV + Space`（即 `Alt+Ctrl+Space`）

### 功能鍵
| 按鍵 | 功能 |
|------|------|
| F1 | Copy Mode |
| F2 | Command Palette |
| F3 | Launcher |
| F4 | Launcher（Tabs only）|
| F5 | Launcher（Workspaces only）|
| F11 | Toggle Full Screen |
| F12 | Debug Overlay |

### 常用操作
| 按鍵 | 功能 |
|------|------|
| SUPER + f | 搜尋文字 |
| SUPER_REV + u | 開啟 URL |
| Ctrl+Shift+C | 複製 |
| Ctrl+Shift+V | 貼上 |

### Tab 管理
| 按鍵 | 功能 |
|------|------|
| SUPER + t | 新 Tab（預設 Domain）|
| SUPER_REV + t | 新 Tab（WSL:Ubuntu）|
| SUPER_REV + w | 關閉 Tab |
| SUPER + [ / ] | 切換 Tab（上一個 / 下一個）|
| SUPER_REV + [ / ] | 移動 Tab 位置 |
| SUPER + 9 | 顯示 / 隱藏 Tab Bar |
| SUPER + 0 | 重新命名 Tab |
| SUPER_REV + 0 | 取消重新命名 |

### Pane 管理
| 按鍵 | 功能 |
|------|------|
| SUPER + \ | 垂直分割 |
| SUPER_REV + \ | 水平分割 |
| SUPER + Enter | Toggle Pane Zoom |
| SUPER + w | 關閉 Pane |
| SUPER_REV + h/j/k/l | 切換 Pane（左/下/上/右）|
| SUPER_REV + p | 選擇並 Swap Pane |
| SUPER + u / d | 捲動 5 行（上/下）|
| PageUp / PageDown | 捲動 0.75 頁 |

### 視窗控制
| 按鍵 | 功能 |
|------|------|
| SUPER + n | 新視窗 |
| SUPER + = | 視窗放大 50px |
| SUPER + - | 視窗縮小 50px |
| SUPER_REV + Enter | 最大化視窗 |

### 背景圖片
| 按鍵 | 功能 |
|------|------|
| SUPER + / | 隨機背景 |
| SUPER + , | 上一張背景 |
| SUPER + . | 下一張背景 |
| SUPER_REV + / | Fuzzy 選擇背景 |
| SUPER + b | Toggle 背景 Focus 模式 |

### Key Tables（LEADER 模式）
| 按鍵 | 功能 |
|------|------|
| LEADER + f | 進入 resize_font 模式 |
| LEADER + p | 進入 resize_pane 模式 |

**resize_font / resize_pane 模式**（按 `q` 或 `Esc` 離開）

| 按鍵 | resize_font | resize_pane |
|------|-------------|-------------|
| k | 增加字體大小 | Pane 向上擴大 |
| j | 減少字體大小 | Pane 向下擴大 |
| h | — | Pane 向左擴大 |
| l | — | Pane 向右擴大 |
| r | 重置字體大小 | — |

---

## PS Profile 格式規則

更新 `/mnt/PowerShell/Microsoft.PowerShell_profile.ps1` 時，快捷鍵表格須遵守以下排版規則：

- **每行顯示三組**快捷鍵與說明
- **欄位寬度**：key = 15 display chars、desc = 19 display chars
- **欄間距**：4 個空格（約 1.4 倍字元間距）
- **對齊方式**：必須使用 CJK 雙寬字元感知的 `Get-DispWidth` + `Pad` 函式補齊，禁止直接使用 PowerShell 的 `-f` 格式化（CJK 字元計 2 寬，`-f` 不感知導致歪掉）
- 每次 `config/bindings.lua` 有異動時，需同步更新 PS profile 中對應的快捷鍵資料

---

## 工作結束後的例行檢查

每次工作完成後，**必須**執行：

```bash
# 檢查 PowerShell profile 是否存在，若存在則同步更新快捷鍵清單
[ -f /mnt/PowerShell/Microsoft.PowerShell_profile.ps1 ] && echo "需更新 PS profile"
```

- PS profile 路徑：`/mnt/PowerShell/Microsoft.PowerShell_profile.ps1`
- 更新內容：PS profile 中的 WezTerm 快捷鍵說明需與 `config/bindings.lua` 保持一致
