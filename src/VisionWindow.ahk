; ==============================================================================
; ROBLOX WINDOW MANAGEMENT & WAYSTONE IMAGE DETECTION
; ==============================================================================

InitVisionAndWindow(requirePrompt) {
    global promptImg, searchBox
    if (requirePrompt && !FileExist(promptImg)) {
        MsgBox("Missing Waystone prompt image!`n`nClick 'Import...' in the Macro tab to select your 'Return to Town (E)' (or shortened) image.`nCurrent path:`n" promptImg)
        return false
    }

    windows := GetSortedRobloxWindows()
    if (windows.Length = 0) {
        MsgBox("No Roblox windows found!")
        return false
    }

    WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " windows[1])
    cx := wx + (ww // 2)
    cy := wy + (wh // 2)

    halfW := Max(180, Round(ww * 0.22))
    topH  := Max(220, Round(wh * 0.28))
    botH  := Max(120, Round(wh * 0.16))
    searchBox := {x1: cx - halfW, y1: cy - topH, x2: cx + halfW, y2: cy + botH}

    FocusWindow(windows[1])
    return true
}

IsOnWaystone(&fx := 0, &fy := 0) {
    global searchBox, promptImg, imgTolerance
    try {
        return ImageSearch(&fx, &fy, searchBox.x1, searchBox.y1, searchBox.x2, searchBox.y2, "*" imgTolerance " " promptImg)
    } catch {
        return false
    }
}

GetSortedRobloxWindows() {
    hwnds := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    i := 1
    while (i < hwnds.Length) {
        j := i + 1
        while (j <= hwnds.Length) {
            try {
                WinGetPos(&x1, , , , "ahk_id " hwnds[i])
                WinGetPos(&x2, , , , "ahk_id " hwnds[j])
                if (x2 < x1) {
                    temp := hwnds[i]
                    hwnds[i] := hwnds[j]
                    hwnds[j] := temp
                }
            }
            j++
        }
        i++
    }
    return hwnds
}

FocusWindow(hwnd) {
    if WinExist("ahk_id " hwnd) && !WinActive("ahk_id " hwnd) {
        WinActivate("ahk_id " hwnd)
        Sleep(30)
    }
}