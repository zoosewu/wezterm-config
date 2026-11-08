# 架構重構：穩健度 + 執行期效能

依 architecture review 的候選依序進行（2026-10-30）。

## 1. per-window state module
- [x] 新增 `utils/window-state.lua`：`set_override`（以 `get_config_overrides()` 為準）+ `namespace(name, 'window'|'tab')`（存在 `wezterm.GLOBAL`，set 時清理已關閉的 id）
- [x] backdrops 改用 window-state；預設桌布 index 存 GLOBAL（reload 不重抽）；無圖片時的 guard
- [x] scratchpad 改用 tab namespace（reload 後不重複建立）
- [x] tab-title 的 toggle-tab-bar 改用 `set_override`
- [x] theme-switcher 移除 override 路徑（appearance 改變本來就會 reload config）
- [x] 移除不存在的 `window-closed` handler 與 `utils/window-overrides.lua`
- [x] 驗證：reload 後背景 / tab bar override 不被蓋掉、桌布不重抽、scratchpad 不重複

### Review
- 驗證（wrapper config + 實際 GUI）：reload 後背景 override、`enable_tab_bar` override、桌布 index 都保留；預設桌布不重抽；scratchpad toggle 不再重複建立 pane。
- 過程中發現：GLOBAL 巢狀值是 `Value` userdata（算術失敗、`==` 永遠 false），改為每個 namespace 存一個 JSON 字串。
- `effective_config()` 非同步更新，toggle-tab-bar 改為優先讀 override。
- 行為微調：切換 / 隨機桌布時會自動退出 focus mode（原本 focus 旗標會殘留，下次 toggle 狀態錯亂）。

## 2. tab title：純 render function + memo
- [x] 移除 Tab class / tab_list / cells 依賴，改為 `facts()` → `render()` + memo（上限 256）
- [x] 自訂標題改存 `tab:set_title()`（mux 保存，reload 不遺失）
- [x] 寬度改用 `column_width` / `truncate_right`（CJK、emoji 不再亂碼）
- [x] 修 is_admin 恆為 true

### Review
- benchmark（同一組 4 tab × 5000 次）：9.85 µs → 1.70 µs / call（約 5.8×）
- 輸出對照：舊版每個 tab 都有 admin 圖示、中文被 byte 截斷；新版正確且寬度一致
- GUI：自訂中文標題 reload 後保留

## 3. status bar 合併、移除 cells / opts-validator
- [x] `events/status.lua`：單一 `update-status` 處理左右兩側，未變不重送
- [x] `utils/segment.lua` 取代 cells；刪除 cells / opts-validator / math / left-status / right-status
- [x] `utils/process-name.lua`：程序名稱優先取 format-tab-title 的快取值
- [x] `cwd.shorten()`：Windows `~` 縮寫修正（12 個案例 headless 測試通過）
- [x] new-tab-button 改用 segment，選取結果 nil 檢查

### Review
- 發現 `update-left-status` 不是 WezTerm event（3 秒內觸發 0 次）：**左側狀態列先前從未顯示**，現已顯示
- 實測 `get_foreground_process_name` / `get_current_working_dir`（無 OSC 7）每次約 5ms，於 GUI 執行緒
- 穩定狀態 update-status 每次 0–1ms（與 HEAD 相同，但多渲染了左側）；每個新 Lua state 首次呼叫約 15ms（冷啟動）
- fancy tab bar 右側狀態會被截掉尾端（HEAD 也有），結尾補 3 格空白解決
## 4. persisted state module（JSON）
- [x] `utils/state-file.lua`：read / write（版本相容 JSON、未變不寫、tmp+rename、錯誤回傳），存於 config dir 以外（`WEZTERM_STATE_DIR` 可覆寫）
- [x] gpu-adapter、session 改用 state-file
- [x] session：cwd 正規化、記錄 domain、還原自訂標題；`--cwd` / 指定程式時不覆蓋
- [x] gui-startup：`gui_window()` nil 防護

### Review
- 端到端：存 3 tab（含 WSL、中文標題）→ 重啟 → 3 tab 正確還原；state dir 自動建立；config dir 無寫入、無 reload

## 5. startup module
- [x] `utils/startup.lua`：`defer(name, fn)` + `run_deferred()`（視窗出現 1 秒後、逐一 pcall）
- [x] health-check / gpu-adapter / font-installer 改用 defer；全專案只剩一個 gui-startup handler
- [x] window-geometry：`wezterm.gui` 不存在時直接回傳

### Review
- 實測順序：spawn + restore → 約 1 秒後 health-check；無錯誤

## 6. cwd module 擁有路徑與 WSL 知識
- [x] `cwd.for_domain(pane, domain)` 取代呼叫端自行挑 getter；`get_local` / `to_wsl` 改為私有
- [x] `cwd.is_wsl_domain()`；bindings 不再寫死 `wsl:ubuntu-fish`（無 WSL 時退回預設 domain）
- [x] bindings 5 個 spawn callback 收斂為 `spawn_here()`；new-tab-button 移除 `kind`

### Review
- headless：for_domain 10 個組合全通過；GUI：分割 / 新 tab / WSL tab 實際觸發正常
## 7. headless 測試
- [x] `tests/run.lua`：cwd / process-name / segment / tab-title（攔截 handler）/ state-file / 整份 config 載入，共 33 項
- [x] ROOT 由 `wezterm.config_file` 推算，並斷言模組確實從 repo 載入（否則會靜默測到 `~/.config/wezterm`）
- [x] CLAUDE.md / README 加入測試指令

### Review
- 相對 / 絕對路徑執行皆 33/33 通過
- 突變測試：放回 is_admin bug → `FAIL tab-title plain tab has no admin icon`（32/33），已還原

## 8. 收尾（子代理報告剩餘項目）
- [x] 字型改下載到 state 目錄（config 目錄外）：下載不再觸發多次 reload，repo 不再有 `fonts/`
- [x] SUPER / SUPER_REV 對應移到 `platform.mods`，bindings 與 keymap-help 共用
- [x] health-check 改讀 backdrops 已載入的清單，不再重複 glob
- [x] tests 補 3 項（state / font 目錄在 repo 外、mods 一致），共 36 項
- 不處理：淺色主題 tab bar 配色（titlebar 固定 `#090909`，兩種主題下 tab bar 都是深色，現有配色正確）
- 不處理：session 只存目前視窗（多視窗還原複雜度高、效益低）

### Review
- 字型下載實測：config 求值 3 次（啟動 2 + 下載完成 1），config 目錄無寫入，切換為 Nerd Font
- 突變測試：FONT_DIR 指回 repo → 相對 / 絕對路徑執行皆 FAIL，已還原
- GUI 冒煙測試：health 10 項通過、快捷鍵速查開啟、無 WARN / ERROR

## 9. 自動更新（utils/updater.lua）
- [x] 啟動後（startup.defer）檢查 config 目錄：git repo + 有 upstream 才處理
- [x] 間隔節流（預設 6 小時，存 state 目錄 `updater.json`，跨 process 共用）；F2「Config: 檢查更新」強制檢查
- [x] fetch 不等待互動輸入（`credential.interactive=never`、SSH `BatchMode=yes`、HTTP 低速逾時）
- [x] 只在 behind > 0、無本地 commit、工作目錄乾淨（`core.fileMode=false`，忽略權限變更）時 `merge --ff-only`
- [x] 更新 / 略過時 toast + log；merge 改寫 config 目錄 → WezTerm 自動 reload
- [x] tests：暫存 bare remote + 兩個 clone，涵蓋 not-repo / up-to-date / throttled / updated / dirty / diverged（共 44 項）
- [x] 可選更新來源：`setup({ repo, branch, interval_hours, enabled })`；`repo` 為 URL / 路徑 / remote 名，fetch 後以 FETCH_HEAD 比較；未設定時沿用 upstream
- [x] tests 補 4 項：無 upstream 時略過、指定 repo+branch 拉取、指定 repo 預設分支（共 48 項）

### Review
- headless 44/44；突變測試（移除 dirty 檢查）→ FAIL，已還原
- GUI 實測：落後 1 commit 的暫存 clone 當 config 目錄 → 啟動約 4 秒後 `updated 1 commit(s) from origin/main`，檔案更新為 v2，config 自動重新求值

## 10. UI 調整
- [x] 快捷鍵速查（SUPER+F1）改為每行兩組（同 section），寬度不足時以「…」截斷；移除 Enter 執行（一行兩組無法判斷要執行哪個）
- [x] 左側狀態列改為填滿高度的平面色塊，以直線 `│` 分隔（原本是半圓膠囊）；顏色與 icon 不變

### Review
- headless 48/48；GUI 截圖確認兩欄對齊（含中文）、狀態列色塊與分隔線正常
- 備註：左側狀態列原本掛在不存在的 `update-left-status` event，從未顯示；d70fc52 合併進 `update-status` 後才出現

## 11. Unix domain（GUI 關閉後程序持續執行）
實測（20240203）：connect 模式不觸發 gui-startup；server 觸發 mux-startup、GUI 觸發 gui-attached；
GUI 預設 domain 變成 unix；GUI 開的 WSL 分頁屬於 GUI 本地（關閉即消失）；unix pane 的 foreground process name 為 nil、cwd 正常；
socket 路徑上限 108 字元。
- [x] domains.lua：`unix_domains = { { name = 'unix' } }` + `default_gui_startup_args = { 'connect', 'unix' }`，可用開關停用
- [x] gui-startup.lua：gui-startup（非 mux 模式）只負責 spawn；mux-startup（server 首次啟動）還原 session；gui-attached（兩種模式）maximize + run_deferred
- [x] 防閃爍：實測 connect 模式的終端機視窗直接以全螢幕大小出現，不需處理（小視窗是 WezTerm 的 Connecting... 進度視窗）；在 config 求值時呼叫 gui.screens() 會卡死 GUI，已放棄 initial_cols 方案
- [x] session：unix domain 視同本地 domain；WSL / SSH 分頁經 `session-pending.json` 交給 GUI 還原（server 端 WSL pane 在 GUI 看來是 unix，分割 / icon / 儲存都會錯）
- [x] gui-attached 在一般模式不觸發 → 收尾邏輯改為 gui-startup 結尾與 gui-attached 共用（只執行一次）
- [x] process-name：mux pane 沒有程序名稱，改用 pane 標題推估（狀態列綠色區塊）
- [x] tests：session.spawn_args 對 unix domain 的對應
- [x] GUI 實測：關閉重開保留分頁、server 首次啟動還原 session、非 mux 模式行為不變、無閃爍
- [x] 文件：README、CLAUDE.md（GUI 測試必須覆寫 socket_path，否則會接到真正的 server）

### Review
- headless 55/55（新增 session.spawn_args / partition、process-name 標題 fallback）
- GUI（獨立 socket）：關閉 GUI 後 server 存活、重開接回原分頁；server 首次啟動還原 3 分頁（2 本機在 server、WSL 交給 GUI，domain 正確，pending 檔用完即刪，作用中分頁回到第 1 個）；再次接回不重複還原
- 一般模式（PERSISTENT_SESSIONS=false 等效）：gui-startup 還原 3 分頁、背景工作執行、不啟動 server
- 已知限制：server 首次啟動約 3 秒顯示 Connecting... 視窗；WSL / SSH 分頁不持久

## 12. 管理員指令（gsudo）
- [x] `utils/gsudo.lua`：`path()` 以 io.open 偵測（scoop `apps/gsudo/current`、Program Files、PATH；執行中的 WezTerm PATH 不會更新）
- [x] 缺少時背景安裝：scoop（免 UAC）優先，否則 winget（MSI，一次 UAC）；失敗 24 小時內不重試；成功後 reload + 通知
- [x] Launch menu 加入「PowerShell (Admin)」（gsudo 絕對路徑），只在找得到 gsudo 時出現
- [x] tests：path 格式、admin 選單與 gsudo 一致（共 57 項）

### Review
- GUI 實測（獨立 socket）：未安裝 → 啟動後以 scoop 安裝成功、通知、重新載入；headless 之後偵測到 gsudo 並出現 admin 選單
- 第一版誤判失敗：scoop 不建 gsudo shim（裝在 apps/gsudo/current 並加入 PATH），已修正搜尋路徑；失敗訊息改含 stdout（scoop 錯誤輸出在 stdout）
- `where sudo` 先找到 Windows 內建 sudo（停用中），所以文件只寫 `gsudo`
- 待使用者實測：「PowerShell (Admin)」分頁的 UAC 與提升（需要人按 UAC）
