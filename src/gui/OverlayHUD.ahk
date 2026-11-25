; ==============================================================================
; FLOATING RUN OVERLAY BAR & LIVE STATUS HUD
; ==============================================================================

HandleOverlayStopClick(*) {
    global manualRecordRunning
    if (manualRecordRunning) {
        FinishManualPathRecording()
        return
    }
    StopAll("Stopped by user")
}

BuildOverlayGUI() {
    global overlayGui, overlayEdges, overlayTitleTxt, overlayStatusTxt, overlayHintTxt, overlayStopBtn, clickableHwnds

    overlayGui := Gui("+AlwaysOnTop +ToolWindow -Caption", "PixelEmpireHUD")
    overlayGui.MarginX := 0
    overlayGui.MarginY := 0
    overlayGui.SetFont("s9", "Segoe UI")

    w := 440, h := 58
    top := overlayGui.AddText("x0 y0 w" w " h1 Disabled +0x04000000", "")
    bot := overlayGui.AddText("x0 y" (h - 1) " w" w " h1 Disabled +0x04000000", "")
    lft := overlayGui.AddText("x0 y1 w1 h" (h - 2) " Disabled +0x04000000", "")
    rgt := overlayGui.AddText("x" (w - 1) " y1 w1 h" (h - 2) " Disabled +0x04000000", "")
    overlayEdges := [top, bot, lft, rgt]

    overlayTitleTxt := overlayGui.AddText("x14 y7 w306 h17 +0x80 +0x04000000", "● RUNNING")
    overlayTitleTxt.SetFont("s8 Bold", "Segoe UI")

    overlayStatusTxt := overlayGui.AddText("x14 y24 w306 h17 +0x80 +0x04000000", "Ready")
    overlayStatusTxt.SetFont("s8", "Segoe UI")

    overlayHintTxt := overlayGui.AddText("x14 y41 w306 h12 +0x80 +0x04000000", "Drag anywhere on bar to move")
    overlayHintTxt.SetFont("s7", "Segoe UI")

    sTop := overlayGui.AddText("x328 y10 w98 h1 Disabled +0x04000000", "")
    sBot := overlayGui.AddText("x328 y47 w98 h1 Disabled +0x04000000", "")
    sLft := overlayGui.AddText("x328 y11 w1 h36 Disabled +0x04000000", "")
    sRgt := overlayGui.AddText("x425 y11 w1 h36 Disabled +0x04000000", "")
    sBtn := overlayGui.AddText("x329 y11 w96 h36 Center 0x200 +0x80 +0x04000000", "■ STOP")
    sBtn.SetFont("s9 Bold", "Segoe UI")
    sBtn.OnEvent("Click", HandleOverlayStopClick)
    clickableHwnds[sBtn.Hwnd] := true

    overlayStopBtn := {edges: [sTop, sBot, sLft, sRgt], btn: sBtn}
}

ShowOverlay() {
    global overlayGui, overlayVisible, overlayCustomPos, overlayX, overlayY
    if !IsSet(overlayGui)
        return

    ApplyOverlayTheme()
    UpdateHUD()

    if (!overlayCustomPos || overlayX < 0 || overlayY < 0) {
        windows := GetSortedRobloxWindows()
        if (windows.Length > 0) {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " windows[1])
            ox := wx + ((ww - 440) // 2)
            oy := wy + wh - Max(115, Round(wh * 0.155))
        } else {
            ox := (A_ScreenWidth - 440) // 2
            oy := A_ScreenHeight - 165
        }
    } else {
        ox := overlayX
        oy := overlayY
    }

    overlayVisible := true
    overlayGui.Show("x" ox " y" oy " w440 h58 NoActivate")
}

HideOverlay() {
    global overlayGui, overlayVisible
    overlayVisible := false
    if IsSet(overlayGui)
        overlayGui.Hide()
}

ResetOverlayPosition(*) {
    global overlayCustomPos, overlayX, overlayY, overlayVisible
    overlayCustomPos := false
    overlayX := -1
    overlayY := -1
    SaveConfig()
    if (overlayVisible)
        ShowOverlay()
    UpdateGuiStatus("Overlay position reset to bottom-center above hotbar.")
}

HandleOverlayDrag(wParam, lParam, msg, hwnd) {
    global overlayGui, overlayVisible, overlayStopBtn, overlayCustomPos, overlayX, overlayY

    if (!overlayVisible || !IsSet(overlayGui))
        return

    isOverlay := (hwnd = overlayGui.Hwnd) || (DllCall("GetParent", "ptr", hwnd, "ptr") = overlayGui.Hwnd)
    if (!isOverlay)
        return

    if (hwnd = overlayStopBtn.btn.Hwnd)
        return

    SendMessage(0xA1, 2, 0, overlayGui.Hwnd)
    try {
        WinGetPos(&ox, &oy, , , "ahk_id " overlayGui.Hwnd)
        overlayX := ox
        overlayY := oy
        overlayCustomPos := true
        SaveConfig()
    }
    return 0
}

ApplyOverlayTheme() {
    global overlayGui, overlayEdges, overlayTitleTxt, overlayStatusTxt, overlayHintTxt, overlayStopBtn
    if !IsSet(overlayGui)
        return

    p := GetPalette()
    overlayGui.BackColor := p.bg
    for e in overlayEdges
        e.Opt("+Background" SubStr(p.priBorder, 3))

    overlayTitleTxt.Opt("+Background" SubStr(p.bg, 3))
    overlayTitleTxt.SetFont("c" SubStr(p.text, 3))
    overlayStatusTxt.Opt("+Background" SubStr(p.bg, 3))
    overlayStatusTxt.SetFont("c" SubStr(p.muted, 3))
    overlayHintTxt.Opt("+Background" SubStr(p.bg, 3))
    overlayHintTxt.SetFont("c" SubStr(p.muted, 3))

    StyleButton(overlayStopBtn, p.priBg, p.priText, p.priBorder)
    if WinExist("ahk_id " overlayGui.Hwnd)
        WinRedraw("ahk_id " overlayGui.Hwnd)
}

UpdateGuiStatus(msg) {
    global txtGuiStatus
    if IsSet(txtGuiStatus)
        try txtGuiStatus.Text := "● " msg
}

UpdateHUD() {
    global running, chaosTestRunning, freeCircleMode, mapCycleMode, shortestPathRunning, manualRecordRunning, wideStarMode
    global completedLoops, recoveryCount, bossesHunted, currentWaystoneIdx, manualRecFromIdx, manualRecCrossedIdx, hudStatus
    global floorsCleared, towerPhase, overlayVisible, overlayTitleTxt, overlayStatusTxt
    if (!running)
        return

    winCount := GetSortedRobloxWindows().Length
    altInfo := (winCount > 1) ? " · Alts: " (winCount - 1) : ""

    if (chaosTestRunning) {
        titleLine := "● CHAOS STRESS TEST" altInfo
        UpdateGuiStatus(hudStatus)
    } else if (manualRecordRunning) {
        destTag := (manualRecCrossedIdx >= 1) ? (" -> WS #" manualRecCrossedIdx) : ""
        titleLine := "● RECORDING KEYS [WS #" manualRecFromIdx destTag "]" altInfo
        UpdateGuiStatus("[Manual Record WS #" manualRecFromIdx "] " hudStatus)
    } else if (shortestPathRunning) {
        titleLine := "● SHORTEST PATH [WS #" currentWaystoneIdx "]  ·  Saved: " completedLoops altInfo
        UpdateGuiStatus("[PathFinder WS #" currentWaystoneIdx "] " hudStatus)
    } else if (mapCycleMode) {
        titleLine := "● MAP CYCLE [WS #" currentWaystoneIdx "]  ·  Bosses: " bossesHunted altInfo
        UpdateGuiStatus("[WS #" currentWaystoneIdx "] " hudStatus)
    } else if (freeCircleMode) {
        titleLine := "● TOWER [Floor #" (floorsCleared + 1) "]  ·  Phase: " towerPhase "  ·  Cleared: " floorsCleared altInfo
        UpdateGuiStatus("[Floor #" (floorsCleared + 1) " - " towerPhase "] " hudStatus)
    } else {
        stripTag := wideStarMode ? "VERY WIDE" : "SHORT"
        titleLine := "● WAYSTONE [" stripTag "]  ·  Loops: " completedLoops "  ·  Rec: " recoveryCount altInfo
        UpdateGuiStatus("[" stripTag "] Loops: " completedLoops " - " hudStatus)
    }

    if (overlayVisible && IsSet(overlayTitleTxt)) {
        try {
            if (overlayTitleTxt.Text != titleLine)
                overlayTitleTxt.Text := titleLine
            if (overlayStatusTxt.Text != hudStatus)
                overlayStatusTxt.Text := hudStatus
        }
    }
}