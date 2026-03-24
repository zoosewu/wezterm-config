# =============================================================================
# PowerShell Profile
# =============================================================================

function Show-WeztermHelp {
    $cyan    = [System.ConsoleColor]::Cyan
    $yellow  = [System.ConsoleColor]::Yellow
    $green   = [System.ConsoleColor]::Green
    $magenta = [System.ConsoleColor]::Magenta
    $white   = [System.ConsoleColor]::White
    $gray    = [System.ConsoleColor]::DarkGray

    # CJK 雙寬字元感知的 display width 計算
    function Get-DispWidth($s) {
        $w = 0
        foreach ($c in $s.ToCharArray()) {
            $cp = [int][char]$c
            if (($cp -ge 0x1100 -and $cp -le 0x115F) -or
                ($cp -ge 0x2E80 -and $cp -le 0x303F) -or
                ($cp -ge 0x3040 -and $cp -le 0x33FF) -or
                ($cp -ge 0x3400 -and $cp -le 0x4DBF) -or
                ($cp -ge 0x4E00 -and $cp -le 0xA4FF) -or
                ($cp -ge 0xAC00 -and $cp -le 0xD7FF) -or
                ($cp -ge 0xF900 -and $cp -le 0xFAFF) -or
                ($cp -ge 0xFE10 -and $cp -le 0xFE6F) -or
                ($cp -ge 0xFF00 -and $cp -le 0xFF60) -or
                ($cp -ge 0xFFE0 -and $cp -le 0xFFE6)) { $w += 2 }
            else { $w += 1 }
        }
        return $w
    }

    # 依 display width 補空格對齊
    function Pad($s, $width) {
        $pad = [Math]::Max(0, $width - (Get-DispWidth $s))
        return $s + (' ' * $pad)
    }

    # 欄位設定：key=15  desc=19  欄間距=4（約1.4倍字元間距）
    $KW = 15; $DW = 19; $GAP = '    '

    function header($text) {
        Write-Host ''
        Write-Host "  $text" -ForegroundColor $yellow
        Write-Host ("  " + [string]('─' * 82)) -ForegroundColor $gray
    }

    # 每行三組快捷鍵，對齊依 CJK display width
    function row3($k1,$d1, $k2,$d2, $k3,$d3) {
        $c1 = (Pad $k1 $KW) + '  ' + (Pad $d1 $DW)
        $c2 = (Pad $k2 $KW) + '  ' + (Pad $d2 $DW)
        $c3 = if ($k3 -ne '') { (Pad $k3 $KW) + '  ' + $d3 } else { '' }
        Write-Host ("  $c1$GAP$c2$GAP$c3") -ForegroundColor $white
    }

    function note($text) { Write-Host "  $text" -ForegroundColor $gray }

    Write-Host ''
    Write-Host ' ╔══════════════════════════════════════════════════════════════════════════════╗' -ForegroundColor $cyan
    Write-Host ' ║                    WezTerm Config  —  快捷鍵速查手冊                        ║' -ForegroundColor $cyan
    Write-Host ' ╚══════════════════════════════════════════════════════════════════════════════╝' -ForegroundColor $cyan
    note 'Windows/Linux : SUPER = Alt  │  SUPER_REV = Alt+Ctrl  │  LEADER = Alt+Ctrl+Space'
    note 'macOS         : SUPER = Super  │  SUPER_REV = Super+Ctrl'

    header '功能鍵'
    row3 'F1'           'Copy Mode'         'F2'            'Command Palette'    'F3'            'Launcher'
    row3 'F4'           'Launcher (Tabs)'   'F5'            'Launcher (WS)'      'F11'           'Toggle FullScreen'
    row3 'F12'          'Debug Overlay'     ''              ''                   ''              ''

    header '常用操作'
    row3 'SUPER+f'      '搜尋文字'          'SUPER_REV+u'   '開啟 URL'           'Ctrl+Shift+C'  '複製'
    row3 'Ctrl+Shift+V' '貼上'              'SUPER+←'       '游標移至行首'       'SUPER+→'       '游標移至行尾'
    row3 'SUPER+BS'     '清除整行 *'        ''              ''                   ''              ''

    header 'Tab 管理'
    row3 'SUPER+t'      '新 Tab (預設)'     'SUPER_REV+t'   '新 Tab (WSL)'       'SUPER_REV+w'   '關閉 Tab'
    row3 'SUPER+['      '上一個 Tab'        'SUPER+]'       '下一個 Tab'         'SUPER+9'       '顯示/隱藏 Tab Bar'
    row3 'SUPER_REV+['  'Tab 左移'          'SUPER_REV+]'   'Tab 右移'           'SUPER+0'       '重新命名 Tab'
    row3 'SUPER_REV+0'  '取消命名'          ''              ''                   ''              ''

    header 'Pane 管理'
    row3 'SUPER+\'      '垂直分割'          'SUPER_REV+\'   '水平分割'           'SUPER+Enter'   'Zoom Pane'
    row3 'SUPER+w'      '關閉 Pane'         'SUPER_REV+h'   '切換左側 Pane'      'SUPER_REV+l'   '切換右側 Pane'
    row3 'SUPER_REV+k'  '切換上方 Pane'     'SUPER_REV+j'   '切換下方 Pane'      'SUPER_REV+p'   'Swap Pane'
    row3 'SUPER+u'      '捲動 5 行上'       'SUPER+d'       '捲動 5 行下'        'PageUp/Down'   '捲動 0.75 頁'

    header '視窗控制'
    row3 'SUPER+n'      '開新視窗'          'SUPER_REV+Enter' '最大化視窗'        'SUPER+='       '視窗放大 50px'
    row3 'SUPER+-'      '視窗縮小 50px'     ''              ''                   ''              ''

    header '背景圖片'
    row3 'SUPER+/'      '隨機背景'          'SUPER_REV+/'   'Fuzzy 選背景'       'SUPER+,'       '上一張'
    row3 'SUPER+.'      '下一張'            'SUPER+b'       'BG Focus 淡化'      ''              ''

    header 'Scratchpad'
    row3 'SUPER_REV+`'  'Toggle Scratchpad' ''              ''                   ''              ''

    header 'Session'
    row3 'SUPER_REV+s'  '儲存 Session'      ''              ''                   ''              ''

    header 'Key Tables（LEADER 進入，q / Esc 離開）'
    row3 'LEADER+f'     'resize_font 模式'  'LEADER+p'      'resize_pane 模式'   'LEADER+w'      'workspace 模式'

    Write-Host ''
    Write-Host '  ' -NoNewline
    Write-Host '[ resize_font ]  ' -ForegroundColor $magenta -NoNewline
    Write-Host 'k 增大  j 縮小  r 重置  q/Esc 離開' -ForegroundColor $white
    Write-Host '  ' -NoNewline
    Write-Host '[ resize_pane ]  ' -ForegroundColor $magenta -NoNewline
    Write-Host 'h/j/k/l 擴大方向  q/Esc 離開' -ForegroundColor $white
    Write-Host '  ' -NoNewline
    Write-Host '[ workspace   ]  ' -ForegroundColor $magenta -NoNewline
    Write-Host 'n 新建  r 重命名  q/Esc 離開' -ForegroundColor $white
    Write-Host '  ' -NoNewline
    Write-Host '[ 滑鼠        ]  ' -ForegroundColor $magenta -NoNewline
    Write-Host 'Ctrl+左鍵 開啟游標下連結' -ForegroundColor $white

    Write-Host ''
    Write-Host ("  " + [string]('═' * 82)) -ForegroundColor $gray
    Write-Host '  * SUPER+BS 清除整行不支援 PowerShell/cmd' -ForegroundColor $gray
    Write-Host '  輸入 Show-WeztermHelp 可隨時重新顯示此說明' -ForegroundColor $green
    Write-Host ''
}

# 每次開啟 PowerShell 自動顯示
Show-WeztermHelp
