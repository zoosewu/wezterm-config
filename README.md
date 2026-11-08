<h2 align="center">My WezTerm Config</h2>

<p align="center">
  <a href="https://github.com/KevinSilvester/wezterm-config/stargazers">
    <img alt="Stargazers" src="https://img.shields.io/github/stars/KevinSilvester/wezterm-config?style=for-the-badge&logo=starship&color=C9CBFF&logoColor=D9E0EE&labelColor=302D41">
  </a>
  <a href="https://github.com/KevinSilvester/wezterm-config/issues">
    <img alt="Issues" src="https://img.shields.io/github/issues/KevinSilvester/wezterm-config?style=for-the-badge&logo=gitbook&color=B5E8E0&logoColor=D9E0EE&labelColor=302D41">
  </a>
  <a href="https://github.com/KevinSilvester/wezterm-config/actions/workflows/lint.yml">
    <img alt="Build" src="https://img.shields.io/github/actions/workflow/status/KevinSilvester/wezterm-config/lint.yml?&style=for-the-badge&logo=githubactions&label=CI&color=A6E3A1&logoColor=D9E0EE&labelColor=302D41">
  </a>
</p>

![screenshot](./.github/screenshots/wezterm.gif)

---

### Features

- [**Background Image Selector**](https://github.com/KevinSilvester/wezterm-config/blob/master/utils/backdrops.lua)

  - Cycle images
  - Fuzzy search for image
  - Toggle background image

  > See: [key bindings](#background-images) for usage

- [**GPU Adapter Selector**](https://github.com/KevinSilvester/wezterm-config/blob/master/utils/gpu_adapter.lua)

  > :bulb: Only works if the [`front_end`](https://github.com/KevinSilvester/wezterm-config/blob/master/config/appearance.lua#L8) option is set to `WebGpu`.

  A small utility to select the best GPU + Adapter (graphics API) combo for your machine.

  GPU + Adapter combo is selected based on the following criteria:

  1.  <details>
      <summary>Best GPU available</summary>

      `Discrete` > `Integrated` > `Other` (for `wgpu`'s OpenGl implementation on Discrete GPU) > `Cpu`
      </details>

  2.  <details>
      <summary>Best graphics API available (based off my very scientific scroll a big log file in Neovim test 😁)</summary>

      > :bulb:<br>
      > The available graphics API choices change based on your OS.<br>
      > These options correspond to the APIs the `wgpu` crate (which powers WezTerm's gui in `WebGpu` mode)<br>
      > currently has support implemented for.<br>
      > See: <https://github.com/gfx-rs/wgpu#supported-platforms> for more info

      - Windows: `Dx12` > `Vulkan` > `OpenGl`
      - Linux: `Vulkan` > `OpenGl`
      - Mac: `Metal`

      </details>

- [**CWD Inheritance**](https://github.com/KevinSilvester/wezterm-config/blob/master/utils/cwd.lua)

  新 Tab、新分割、新視窗，以及新分頁按鈕右鍵的 Launch Menu，都會以**當前 pane 的工作目錄**為起點。

  跨 domain 時會自動處理：

  | 目標 domain            | 行為                                                    |
  | ---------------------- | ------------------------------------------------------- |
  | 同一個 domain（分割）  | 直接沿用當前目錄                                        |
  | DefaultDomain（本機）  | 沿用當前目錄；若當前 pane 是 WSL/SSH 則略過（路徑不通用）|
  | WSL domain             | `C:\Users\x` 自動轉換為 `/mnt/c/Users/x`                |
  | SSH / Unix domain      | 不帶目錄（本機路徑在遠端無意義）                        |

  > :warning: **PowerShell 使用者必讀**
  >
  > PowerShell 的 `Set-Location` 只改變 provider location，**不會**改變 process 的實際
  > working directory，因此 WezTerm 無法自行推得 CWD。本專案的
  > [`powershell/Microsoft.PowerShell_profile.ps1`](./powershell/Microsoft.PowerShell_profile.ps1)
  > 內含 OSC 7 prompt hook 來主動回報目錄，請確保它已套用至你的 `$PROFILE`。
  >
  > bash / zsh / fish 通常已內建 OSC 7 支援，無須額外設定。

- [**Persistent Sessions**](./config/domains.lua)

  WezTerm 視窗連到背景的 mux server（unix domain），**關掉視窗後裡面的程式繼續執行**
  （build、server、SSH、vim…），下次開 WezTerm 會直接接回原本的分頁與捲動紀錄。
  第一次啟動時 server 會自動在背景啟動（約 3 秒，期間顯示 WezTerm 的 `Connecting...` 視窗）。

  - 只有本機（Windows / macOS / Linux 原生）分頁會保留；WSL / SSH 分頁屬於視窗本身，關掉即結束
  - server 重新啟動（例如重開機）後才會還原儲存的 session（<kbd>SUPER_REV</kbd>+<kbd>s</kbd>）：
    本機分頁由 server 還原，WSL / SSH 分頁由接上的視窗還原
  - 完全結束所有程式：關閉 server（Windows：`taskkill /IM wezterm-mux-server.exe /F`；
    macOS / Linux：`pkill wezterm-mux-server`）。修改 shell 等開新分頁相關設定後若未生效，也請重啟 server
  - 不需要時把 `config/domains.lua` 的 `PERSISTENT_SESSIONS` 改成 `false`，回到一般模式

- [**Admin Commands (Windows)**](./utils/gsudo.lua)

  透過 [gsudo](https://github.com/gerardog/gsudo) 只對需要的指令或分頁提升權限（不必以系統管理員身分開整個 WezTerm）：

  - `gsudo <指令>`：在目前分頁以管理員執行一個指令（會跳 UAC），可直接用 PowerShell cmdlet
  - `gsudo`：把目前的 shell 提升為管理員，`exit` 回到一般權限
  - Launch Menu（<kbd>F3</kbd> 或右鍵 `+`）→ `PowerShell (Admin)`：開一個管理員分頁

  找不到 gsudo 時會在啟動後背景自動安裝（有 scoop 用 scoop，免 UAC；否則用 winget，會跳一次 UAC），
  失敗 24 小時內不重試。剛裝好時，已開啟的 shell 還沒有新的 PATH，`gsudo` 指令要在 WezTerm
  與 mux server 重啟後才找得到（`PowerShell (Admin)` 使用絕對路徑，立即可用）。
  不想自動安裝：`wezterm.lua` 裡改為 `gsudo.setup({ auto_install = false })`。

- [**Auto Update**](./utils/updater.lua)

  若 config 目錄是 git clone，WezTerm 啟動後會在背景 `git fetch` 更新來源（最多每 6 小時一次），
  有新 commit 時以 fast-forward 拉取，WezTerm 偵測到檔案變動會自動 reload，並跳出通知。

  在 [`wezterm.lua`](./wezterm.lua) 的 `updater.setup()` 選擇要追蹤的 repo：

  ```lua
  require('utils.updater').setup({
     repo = 'git@github.com:<you>/wezterm-config.git', -- nil = 跟隨 clone 的 upstream
     branch = 'master',                                -- nil = repo 的預設分支
     interval_hours = 6,                               -- 自動檢查的最短間隔
     enabled = true,                                   -- false = 關閉啟動時檢查
  })
  ```

  `repo` 可以是 URL、本機路徑或 remote 名稱（如 `'origin'`），適合 fork 後追蹤自己的 repo。

  - 有未提交的改動（只改檔案權限不算）或本地 commit 時**不會動任何檔案**，只通知略過
  - fetch 不會等待密碼 / passphrase 輸入（SSH 用 `BatchMode`），失敗只記在 log（<kbd>F12</kbd>）
  - Command Palette（<kbd>F2</kbd>）→ `Config: 檢查更新` 可立即檢查（忽略間隔）
  - 非 git 目錄或分支沒有 upstream 時自動略過

---

### Getting Started

- ##### Requirements:

  - <details>
      <summary><b>WezTerm</b></summary>

    Minimum Version: `20240127-113634-bbcac864`<br>
    Recommended Version: [`Nightly`](https://github.com/wez/wezterm/releases/nightly)

    [Official Installation Page](https://wezfurlong.org/wezterm/installation.html)

    **Windows**

    - <details>
      <summary>Install Stable</summary>

      - Install with Scoop (non-portable)

        ```sh
        scoop bucket add extras
        scoop install wezterm
        ```

      - Install with Scoop (portable)

        ```sh
        scoop bucket add k https://github.com/KevinSilvester/scoop-bucket
        scoop install k/wezterm
        ```

      - Install with winget

        ```sh
        winget install wez.wezterm
        ```

      - Install with choco

        ```sh
        choco install wezterm -y
        ```
      </details>

    - <details>
      <summary>Install Nightly</summary>

      - Install with Scoop (non-portable)

        ```sh
        scoop bucket add versions
        scoop install wezterm-nightly
        ```

      - Install with Scoop (portable)

        ```sh
        scoop bucket add k https://github.com/KevinSilvester/scoop-bucket
        scoop install k/wezterm-nightly
        ```
      </details>

    > :bulb:<br>
    > Toast notifications don't work in non-portable installations.<br>
    > See issue <https://github.com/wez/wezterm/issues/5166> for more details
  
    ---

    **MacOS**

    - <details>
      <summary>Install Stable</summary>

      - Install with Homebrew

        ```sh
        brew install --cask wezterm
        ```

      - Install with MacPort

        ```sh
        sudo port selfupdate
        sudo port install wezterm
        ```
      </details>

    - <details>
      <summary>Install Nighlty</summary>

      - Install with Homebrew

        ```sh
        brew install --cask wezterm@nightly
        ```

      - Upgrade with Homebrew

        ```sh
        brew install --cask wezterm@nightly --no-quarantine --greedy-latest
        ```
      </details>

    ---

    **Linux**

    Refer to the Linux installation page.<br>
    <https://wezfurlong.org/wezterm/install/linux.html>

    </details>

  - <details>
    <summary>JetBrainsMono Nerd Font</summary>

    > 可選：若系統未安裝，啟動時會先以 WezTerm 內建的 `JetBrains Mono` 顯示（不跳錯誤），
    > 並於背景以 `curl` 自動下載 Medium / Bold（含 Italic）至 state 目錄的 `fonts/`（Windows：`%LOCALAPPDATA%\wezterm-config\fonts`），
    > 完成後自動 reload 套用。詳見 `utils/font-installer.lua`。

    Install with Homebrew (Macos)

    ```sh
    brew install --cask font-jetbrains-mono-nerd-font
    ```

    Install with Scoop (Windows)

    ```sh
    scoop bucket add nerd-fonts
    scoop install JetBrainsMono-NF
    ```

    > More Info:
    >
    > - <https://www.nerdfonts.com/#home>
    > - <https://github.com/ryanoasis/nerd-fonts?#font-installation>
    </details/>

&nbsp;

- ##### Steps:

  1.  ```sh
      # On Windows and Unix systems
      git clone https://github.com/KevinSilvester/wezterm-config.git ~/.config/wezterm
      ```
  2.  And Done!!! 🎉🎉

&nbsp;

- ##### Things You Might Want to Change:

  - [./config/domains.lua](./config/domains.lua) for custom SSH/WSL domains
  - [./config/launch.lua](./config/launch.lua) for preferred shells and its paths

---

### All Key Bindings

Most of the key bindings revolve around a <kbd>SUPER</kbd> and <kbd>SUPER_REV</kbd>(super reversed) keys.<br>

- On MacOs:
  - <kbd>SUPER</kbd> ⇨ <kbd>Super</kbd>
  - <kbd>SUPER_REV</kbd> ⇨ <kbd>Super</kbd>+<kbd>Ctrl</kbd>
- On Windows and Linux
  - <kbd>SUPER</kbd> ⇨ <kbd>Alt</kbd>
  - <kbd>SUPER_REV</kbd> ⇨ <kbd>Alt</kbd>+<kbd>Ctrl</kbd>

> To avoid confusion when switching between different OS and to avoid conflicting<br>
> with OS's built-in keyboard shortcuts.

- On all platforms: <kbd>LEADER</kbd> ⇨ <kbd>SUPER_REV</kbd>+<kbd>Space</kbd>

#### Miscellaneous/Useful

| Keys                              | Action                                      |
| --------------------------------- | ------------------------------------------- |
| <kbd>F1</kbd>                     | `ActivateCopyMode`                          |
| <kbd>F2</kbd>                     | `ActivateCommandPalette`                    |
| <kbd>F3</kbd>                     | `ShowLauncher`                              |
| <kbd>F4</kbd>                     | `ShowLauncher` <sub>(tabs only)</sub>       |
| <kbd>F5</kbd>                     | `ShowLauncher` <sub>(workspaces only)</sub> |
| <kbd>F11</kbd>                    | `ToggleFullScreen`                          |
| <kbd>F12</kbd>                    | `ShowDebugOverlay`                          |
| <kbd>SUPER</kbd>+<kbd>F1</kbd>    | 快捷鍵速查 <sub>(可搜尋，Enter 直接執行)</sub> |
| <kbd>SUPER</kbd>+<kbd>f</kbd>     | Search Text                                 |
| <kbd>SUPER_REV</kbd>+<kbd>u</kbd> | Open URL                                    |

&nbsp;

#### Copy+Paste

| Keys                                          | Action               |
| --------------------------------------------- | -------------------- |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>c</kbd> | Copy to Clipboard    |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>v</kbd> | Paste from Clipboard |

&nbsp;

#### Cursor Movements

| Keys                                   | Action                                                     |
| -------------------------------------- | ---------------------------------------------------------- |
| <kbd>SUPER</kbd>+<kbd>LeftArrow</kbd>  | Move cursor to Line Start                                  |
| <kbd>SUPER</kbd>+<kbd>RightArrow</kbd> | Move cursor to Line End                                    |
| <kbd>SUPER</kbd>+<kbd>Backspace</kbd>  | Clear Line <sub>(does not work in PowerShell or cmd)</sub> |

&nbsp;

#### Tabs

##### Tabs: Spawn+Close

| Keys                              | Action                                                          |
| --------------------------------- | --------------------------------------------------------------- |
| <kbd>SUPER</kbd>+<kbd>t</kbd>     | `SpawnTab` <sub>(DefaultDomain, inherits current CWD)</sub>     |
| <kbd>SUPER_REV</kbd>+<kbd>t</kbd> | `SpawnTab` <sub>(wsl:ubuntu-fish, inherits current CWD as `/mnt/<drive>/…`)</sub> |
| <kbd>SUPER_REV</kbd>+<kbd>w</kbd> | `CloseCurrentTab`                                               |

##### Tabs: Navigation

| Keys                              | Action         |
| --------------------------------- | -------------- |
| <kbd>SUPER</kbd>+<kbd>[</kbd>     | Previous Tab   |
| <kbd>SUPER</kbd>+<kbd>]</kbd>     | Next Tab       |
| <kbd>SUPER_REV</kbd>+<kbd>[</kbd> | Move Tab Left  |
| <kbd>SUPER_REV</kbd>+<kbd>]</kbd> | Move Tab Right |

##### Tabs: Toggle Tab-bar

| Keys                          | Action         |
| ----------------------------- | -------------- |
| <kbd>SUPER</kbd>+<kbd>9</kbd> | Toggle tab bar |

##### Tabs: Title

| Keys                              | Action             |
| --------------------------------- | ------------------ |
| <kbd>SUPER</kbd>+<kbd>0</kbd>     | Rename Current Tab |
| <kbd>SUPER_REV</kbd>+<kbd>0</kbd> | Undo Rename        |

&nbsp;

#### Windows

| Keys                              | Action               |
| --------------------------------- | -------------------- |
| <kbd>SUPER</kbd>+<kbd>n</kbd>     | `SpawnWindow` <sub>(DefaultDomain, inherits current CWD)</sub> |
| <kbd>SUPER</kbd>+<kbd>=</kbd>     | Increase Window Size |
| <kbd>SUPER</kbd>+<kbd>-</kbd>     | Decrease Window Size |
| <kbd>SUPER_REV</kbd>+<kbd>Enter</kbd> | Maximize Window  |

&nbsp;

#### Panes

##### Panes: Split Panes

| Keys                               | Action                                                               |
| ---------------------------------- | -------------------------------------------------------------------- |
| <kbd>SUPER</kbd>+<kbd>\\</kbd>     | `SplitVertical` <sub>(CurrentPaneDomain, inherits current CWD)</sub> |
| <kbd>SUPER_REV</kbd>+<kbd>\\</kbd> | `SplitHorizontal` <sub>(CurrentPaneDomain, inherits current CWD)</sub> |

##### Panes: Zoom+Close Pane

| Keys                              | Action                |
| --------------------------------- | --------------------- |
| <kbd>SUPER</kbd>+<kbd>Enter</kbd> | `TogglePaneZoomState` |
| <kbd>SUPER</kbd>+<kbd>w</kbd>     | `CloseCurrentPane`    |

##### Panes: Navigation

| Keys                              | Action                  |
| --------------------------------- | ----------------------- |
| <kbd>SUPER_REV</kbd>+<kbd>k</kbd> | Move to Pane (Up)       |
| <kbd>SUPER_REV</kbd>+<kbd>j</kbd> | Move to Pane (Down)     |
| <kbd>SUPER_REV</kbd>+<kbd>h</kbd> | Move to Pane (Left)     |
| <kbd>SUPER_REV</kbd>+<kbd>l</kbd> | Move to Pane (Right)    |
| <kbd>SUPER_REV</kbd>+<kbd>p</kbd> | Swap with selected Pane |

##### Panes: Scroll Pane

| Keys                          | Action                               |
| ----------------------------- | ------------------------------------ |
| <kbd>SUPER</kbd>+<kbd>u</kbd> | Scroll Lines up <sub>5 lines</sub>   |
| <kbd>SUPER</kbd>+<kbd>d</kbd> | Scroll Lines down <sub>5 lines</sub> |
| <kbd>PageUp</kbd>             | Scroll Page up                       |
| <kbd>PageDown</kbd>           | Scroll Page down                     |

##### Panes: Scratchpad

| Keys                                | Action                                              |
| ----------------------------------- | --------------------------------------------------- |
| <kbd>SUPER_REV</kbd>+<kbd>`</kbd>   | Toggle Scratchpad Pane <sub>(25% bottom split)</sub> |

&nbsp;

#### Session

| Keys                              | Action                                        |
| --------------------------------- | --------------------------------------------- |
| <kbd>SUPER_REV</kbd>+<kbd>s</kbd> | Save Session <sub>(records each tab's CWD, domain and custom title)</sub> |

> 啟用 [Persistent Sessions](#features) 時，session 只在 mux server 啟動時還原（平常重開視窗會直接接回仍在執行的分頁）。
>
> Session 與 GPU 快取存在 config 目錄以外（Windows：`%LOCALAPPDATA%\wezterm-config`），避免寫檔觸發 config reload；可用環境變數 `WEZTERM_STATE_DIR` 覆寫位置。

&nbsp;

#### Background Images

| Keys                              | Action                       |
| --------------------------------- | ---------------------------- |
| <kbd>SUPER</kbd>+<kbd>/</kbd>     | Select Random Image          |
| <kbd>SUPER</kbd>+<kbd>,</kbd>     | Cycle to previous Image      |
| <kbd>SUPER</kbd>+<kbd>.</kbd>     | Cycle to next Image          |
| <kbd>SUPER_REV</kbd>+<kbd>/</kbd> | Fuzzy select Image           |
| <kbd>SUPER</kbd>+<kbd>b</kbd>     | Toggle background focus mode |

&nbsp;

#### Key Tables

> See: <https://wezfurlong.org/wezterm/config/key-tables.html>

| Keys                           | Action      |
| ------------------------------ | ----------- |
| <kbd>LEADER</kbd>+<kbd>f</kbd> | `resize_font` |
| <kbd>LEADER</kbd>+<kbd>p</kbd> | `resize_pane` |
| <kbd>LEADER</kbd>+<kbd>w</kbd> | `workspace` |

##### Key Table: `resize_font`

| Keys           | Action                          |
| -------------- | ------------------------------- |
| <kbd>k</kbd>   | `IncreaseFontSize`              |
| <kbd>j</kbd>   | `DecreaseFontSize`              |
| <kbd>r</kbd>   | `ResetFontSize`                 |
| <kbd>q</kbd>   | `PopKeyTable` <sub>(exit)</sub> |
| <kbd>Esc</kbd> | `PopKeyTable` <sub>(exit)</sub> |

##### Key Table: `resize_pane`

| Keys           | Action                                         |
| -------------- | ---------------------------------------------- |
| <kbd>k</kbd>   | `AdjustPaneSize` <sub>(Direction: Up)</sub>    |
| <kbd>j</kbd>   | `AdjustPaneSize` <sub>(Direction: Down)</sub>  |
| <kbd>h</kbd>   | `AdjustPaneSize` <sub>(Direction: Left)</sub>  |
| <kbd>l</kbd>   | `AdjustPaneSize` <sub>(Direction: Right)</sub> |
| <kbd>q</kbd>   | `PopKeyTable` <sub>(exit)</sub>                |
| <kbd>Esc</kbd> | `PopKeyTable` <sub>(exit)</sub>                |

##### Key Table: `workspace` <sub>(timeout: 5s)</sub>

| Keys           | Action                          |
| -------------- | ------------------------------- |
| <kbd>n</kbd>   | New named Workspace             |
| <kbd>r</kbd>   | Rename current Workspace        |
| <kbd>q</kbd>   | `PopKeyTable` <sub>(exit)</sub> |
| <kbd>Esc</kbd> | `PopKeyTable` <sub>(exit)</sub> |

---

### Tests

Headless（不開視窗）執行所有模組測試：

```sh
wezterm --config-file tests/run.lua ls-fonts --text a 2>&1 | grep "\[test\]"
```

最後一行應為 `[test] N/N passed`。

&nbsp;

### References/Inspirations

- <https://github.com/rxi/lume>
- <https://github.com/catppuccin/wezterm>
- <https://github.com/wez/wezterm/discussions/628#discussioncomment-1874614>
- <https://github.com/wez/wezterm/discussions/628#discussioncomment-5942139>
