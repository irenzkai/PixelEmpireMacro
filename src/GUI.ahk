; ==============================================================================
; BLACK & WHITE GUI + FLOATING OVERLAY HUD + RATIO RANGE SCALERS
; ==============================================================================

BuildGUI() {
    global mainGui, activeTab, pageControls, clickableHwnds
    global themeCards, themeDividers, themePrimaryText, themeMutedText, themeEdits
    global themePrimaryBtns, themeSecondaryBtns, themeTabs
    global btnThemeQuick, tabMacro, tabF9F7, tabSettings, tabCredits
    global edtPromptPath, edtTolerance, txtImgStatus
    global radShortBtn, radWideBtn, edtWayUp, edtWayDown, edtWayLeft, edtWayRight, edtWayDiag, edtWayRet, txtWayRangePct
    global edtF5Ring, edtF5Up, edtF5Down, edtF5Left, edtF5Right, edtF5Diag, txtF5RangePct
    global edtCirOut, edtCirEdge, edtCirCard, edtCirDiag, edtCirRet, txtCirRangePct, btnF9TabQueue
    global edtChaosAngle, edtChaosZigDiag, edtChaosZigSide, txtChaosRangePct, btnF7TabRun
    global btnActWaystone, btnActTower, btnActPreset, btnActCircle, btnActChaos, btnActExit
    global btnSetDark, btnSetLight, btnSetHud, btnSetKeysToggle, hkBadges
    global txtGuiStatus, promptImg, imgTolerance
    global f5RingEdgeMs, f5UpMs, f5DownMs, f5LeftMs, f5RightMs, f5DiagMs

    pageControls := Map("MACRO", [], "F9F7", [], "SETTINGS", [], "CREDITS", [])
    clickableHwnds := Map()
    themeCards := []
    themeDividers := []
    themePrimaryText := []
    themeMutedText := []
    themeEdits := []
    themePrimaryBtns := []
    themeSecondaryBtns := []
    themeTabs := Map()
    hkBadges := Map()

    mainGui := Gui("-MaximizeBox", "Pixel Empire Macro")
    mainGui.MarginX := 0
    mainGui.MarginY := 0
    mainGui.SetFont("s9", "Segoe UI")

    ; --- HEADER ---
    lblTitle := mainGui.AddText("x16 y12 w260 h22 +0x80 +0x04000000", "PIXEL EMPIRE MACRO")
    lblTitle.SetFont("s12 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: lblTitle, onCard: false})

    lblSub := mainGui.AddText("x16 y34 w260 h14 +0x80 +0x04000000", "FARMING / GRIND AUTOMATION")
    lblSub.SetFont("s7 Bold", "Segoe UI")
    themeMutedText.Push({ctrl: lblSub, onCard: false})

    btnThemeQuick := AddFlatButton(346, 16, 98, 26, "", false, (*) => ToggleDarkMode())

    ; --- NAVIGATION TABS ---
    tabMacro    := AddTabButton("MACRO",    16,  56, 102, 28, "MACRO")
    tabF9F7     := AddTabButton("F9F7",     124, 56, 102, 28, "F9 / F7")
    tabSettings := AddTabButton("SETTINGS", 232, 56, 102, 28, "SETTINGS")
    tabCredits  := AddTabButton("CREDITS",  340, 56, 104, 28, "CREDITS")

    AddDivider(16, 92, 428)

    ; ==========================================================================
    ; TAB 1: MACRO (WAYSTONE PROMPT + F8 8-STAR + F5 TOWER MODE + QUICK ACTIONS)
    ; ==========================================================================
    AddCard("MACRO", 16, 102, 428, 88)
    AddCardTitle("MACRO", 28, 110, 230, "WAYSTONE PROMPT IMAGE")
    txtImgStatus := mainGui.AddText("x340 y110 w92 h16 Right +0x80 +0x04000000", "")
    txtImgStatus.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtImgStatus, onCard: true})
    pageControls["MACRO"].Push(txtImgStatus)

    edtPromptPath := AddStyledEdit("MACRO", 28, 130, 318, 22, promptImg, "ReadOnly")
    AddFlatButton(352, 130, 80, 22, "Import...", false, ImportPromptImage, "MACRO")

    AddMutedLabel("MACRO", 28, 160, 62, "Tolerance:")
    edtTolerance := AddStyledEdit("MACRO", 92, 158, 48, 22, imgTolerance, "Number")
    edtTolerance.OnEvent("Change", OnSettingsChanged)

    AddFlatButton(148, 158, 116, 22, "Test Waystone", false, TestWaystoneDetection, "MACRO")
    AddMutedLabel("MACRO", 272, 160, 160, "Return to Town (E)", "Right")

    ; --- F8 WAYSTONE 8-STAR CARD ---
    AddCard("MACRO", 16, 198, 428, 148)
    AddCardTitle("MACRO", 28, 206, 204, "WAYSTONE 8-STAR TIMES (MS)")

    radShortBtn := AddFlatButton(242, 204, 66, 20, "SHORT", false, (*) => SelectWaystonePreset(false), "MACRO")
    radWideBtn  := AddFlatButton(312, 204, 74, 20, "VERY WIDE", false, (*) => SelectWaystonePreset(true), "MACRO")
    AddFlatButton(390, 204, 42, 20, "RST", false, ResetPresetDefaults, "MACRO")

    AddMutedLabel("MACRO", 28, 237, 52, "Up (W):")
    edtWayUp := AddStyledEdit("MACRO", 82, 234, 56, 22, "", "Number")
    AddMutedLabel("MACRO", 154, 237, 56, "Down (S):")
    edtWayDown := AddStyledEdit("MACRO", 212, 234, 56, 22, "", "Number")
    AddMutedLabel("MACRO", 284, 237, 56, "Diagonal:")
    edtWayDiag := AddStyledEdit("MACRO", 342, 234, 90, 22, "", "Number")

    AddMutedLabel("MACRO", 28, 267, 52, "Left (A):")
    edtWayLeft := AddStyledEdit("MACRO", 82, 264, 56, 22, "", "Number")
    AddMutedLabel("MACRO", 154, 267, 56, "Right (D):")
    edtWayRight := AddStyledEdit("MACRO", 212, 264, 56, 22, "", "Number")
    AddMutedLabel("MACRO", 284, 267, 56, "Ret Max:")
    edtWayRet := AddStyledEdit("MACRO", 342, 264, 90, 22, "", "Number")

    for ctrl in [edtWayUp, edtWayDown, edtWayLeft, edtWayRight, edtWayDiag, edtWayRet]
        ctrl.OnEvent("Change", OnWaystoneManualEdit)

    AddMutedLabel("MACRO", 28, 297, 46, "Range:")
    AddFlatButton(76, 294, 26, 20, "<", false, (*) => AdjustWaystoneRange(-10), "MACRO")
    txtWayRangePct := mainGui.AddText("x104 y296 w44 h18 Center +0x80 +0x04000000", "100%")
    txtWayRangePct.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtWayRangePct, onCard: true})
    pageControls["MACRO"].Push(txtWayRangePct)
    AddFlatButton(150, 294, 26, 20, ">", false, (*) => AdjustWaystoneRange(10), "MACRO")
    AddMutedLabel("MACRO", 184, 297, 248, "Range scales equally by ratio", "Right")

    AddMutedLabel("MACRO", 28, 322, 404, "Increase ms to travel farther. Press F6 (or preset key) to toggle.")

    ; --- F5 TOWER MODE CARD ---
    AddCard("MACRO", 16, 354, 428, 102)
    AddCardTitle("MACRO", 28, 362, 240, "TOWER MODE / FREE RANGE (MS)")

    AddMutedLabel("MACRO", 272, 362, 44, "Range:")
    AddFlatButton(318, 360, 26, 20, "<", false, (*) => AdjustTowerRange(-10), "MACRO")
    txtF5RangePct := mainGui.AddText("x346 y362 w44 h18 Center +0x80 +0x04000000", "100%")
    txtF5RangePct.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtF5RangePct, onCard: true})
    pageControls["MACRO"].Push(txtF5RangePct)
    AddFlatButton(392, 360, 26, 20, ">", false, (*) => AdjustTowerRange(10), "MACRO")

    AddMutedLabel("MACRO", 28, 393, 58, "Ring Edge:")
    edtF5Ring := AddStyledEdit("MACRO", 88, 390, 54, 22, f5RingEdgeMs, "Number")
    AddMutedLabel("MACRO", 156, 393, 50, "Up (W):")
    edtF5Up := AddStyledEdit("MACRO", 208, 390, 56, 22, f5UpMs, "Number")
    AddMutedLabel("MACRO", 280, 393, 58, "Down (S):")
    edtF5Down := AddStyledEdit("MACRO", 340, 390, 92, 22, f5DownMs, "Number")

    AddMutedLabel("MACRO", 28, 423, 58, "Left (A):")
    edtF5Left := AddStyledEdit("MACRO", 88, 420, 54, 22, f5LeftMs, "Number")
    AddMutedLabel("MACRO", 156, 423, 52, "Right (D):")
    edtF5Right := AddStyledEdit("MACRO", 208, 420, 56, 22, f5RightMs, "Number")
    AddMutedLabel("MACRO", 280, 423, 58, "Diagonal:")
    edtF5Diag := AddStyledEdit("MACRO", 340, 420, 92, 22, f5DiagMs, "Number")

    for ctrl in [edtF5Ring, edtF5Up, edtF5Down, edtF5Left, edtF5Right, edtF5Diag]
        ctrl.OnEvent("Change", OnTowerManualEdit)

    ; --- QUICK ACTIONS CARD ---
    AddCard("MACRO", 16, 464, 428, 98)
    AddCardTitle("MACRO", 28, 472, 390, "QUICK ACTIONS")

    btnActWaystone := AddFlatButton(28,  492, 198, 28, "", true,  ToggleWaystoneMode, "MACRO")
    btnActTower    := AddFlatButton(234, 492, 198, 28, "", false, ToggleTowerMode,    "MACRO")

    btnActPreset := AddFlatButton(28,  526, 96, 26, "", false, ToggleShortWidePreset, "MACRO")
    btnActCircle := AddFlatButton(130, 526, 96, 26, "", false, QueuePerimeterCircle,  "MACRO")
    btnActChaos  := AddFlatButton(232, 526, 96, 26, "", false, StartChaosStressTest,  "MACRO")
    btnActExit   := AddFlatButton(334, 526, 98, 26, "", false, ExitMacro,             "MACRO")

    ; ==========================================================================
    ; TAB 2: F9 PERIMETER CIRCLE & F7 CHAOS STRESS TEST
    ; ==========================================================================
    AddCard("F9F7", 16, 102, 428, 174)
    AddCardTitle("F9F7", 28, 110, 260, "F9 PERIMETER CIRCLE TIMES (MS)")
    AddFlatButton(390, 108, 42, 20, "RST", false, ResetF9F7Defaults, "F9F7")

    AddMutedLabel("F9F7", 28, 141, 56, "Out (W):")
    edtCirOut := AddStyledEdit("F9F7", 86, 138, 56, 22, "", "Number")
    AddMutedLabel("F9F7", 156, 141, 60, "Top Edge:")
    edtCirEdge := AddStyledEdit("F9F7", 218, 138, 56, 22, "", "Number")
    AddMutedLabel("F9F7", 286, 141, 54, "Ret Max:")
    edtCirRet := AddStyledEdit("F9F7", 342, 138, 90, 22, "", "Number")

    AddMutedLabel("F9F7", 28, 171, 56, "Cardinals:")
    edtCirCard := AddStyledEdit("F9F7", 86, 168, 56, 22, "", "Number")
    AddMutedLabel("F9F7", 156, 171, 60, "Diagonals:")
    edtCirDiag := AddStyledEdit("F9F7", 218, 168, 56, 22, "", "Number")
    btnF9TabQueue := AddFlatButton(312, 168, 120, 22, "", false, QueuePerimeterCircle, "F9F7")

    for ctrl in [edtCirOut, edtCirEdge, edtCirCard, edtCirDiag, edtCirRet]
        ctrl.OnEvent("Change", OnCircleManualEdit)

    AddMutedLabel("F9F7", 28, 203, 46, "Range:")
    AddFlatButton(76, 200, 26, 20, "<", false, (*) => AdjustCircleRange(-10), "F9F7")
    txtCirRangePct := mainGui.AddText("x104 y202 w44 h18 Center +0x80 +0x04000000", "100%")
    txtCirRangePct.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtCirRangePct, onCard: true})
    pageControls["F9F7"].Push(txtCirRangePct)
    AddFlatButton(150, 200, 26, 20, ">", false, (*) => AdjustCircleRange(10), "F9F7")
    AddMutedLabel("F9F7", 184, 203, 248, "Lower % if circle travels too far out", "Right")

    AddMutedLabel("F9F7", 28, 232, 404, "Out (W) sets radius from Waystone. Top Edge is D; Cardinals are S/A/W;")
    AddMutedLabel("F9F7", 28, 250, 404, "Diagonals are SE/SW/NW. Queues a one-shot sweep during F8 Waystone mode.")

    ; --- F7 CHAOS STRESS TEST CARD ---
    AddCard("F9F7", 16, 286, 428, 138)
    AddCardTitle("F9F7", 28, 294, 220, "F7 CHAOS STRESS TEST (MS)")

    AddMutedLabel("F9F7", 272, 294, 44, "Range:")
    AddFlatButton(318, 292, 26, 20, "<", false, (*) => AdjustChaosRange(-10), "F9F7")
    txtChaosRangePct := mainGui.AddText("x346 y294 w44 h18 Center +0x80 +0x04000000", "100%")
    txtChaosRangePct.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtChaosRangePct, onCard: true})
    pageControls["F9F7"].Push(txtChaosRangePct)
    AddFlatButton(392, 292, 26, 20, ">", false, (*) => AdjustChaosRange(10), "F9F7")

    AddMutedLabel("F9F7", 28, 327, 68, "Long Angle:")
    edtChaosAngle := AddStyledEdit("F9F7", 98, 324, 58, 22, "", "Number")
    AddMutedLabel("F9F7", 170, 327, 56, "Zig Diag:")
    edtChaosZigDiag := AddStyledEdit("F9F7", 228, 324, 56, 22, "", "Number")
    AddMutedLabel("F9F7", 298, 327, 56, "Zig Side:")
    edtChaosZigSide := AddStyledEdit("F9F7", 356, 324, 76, 22, "", "Number")

    for ctrl in [edtChaosAngle, edtChaosZigDiag, edtChaosZigSide]
        ctrl.OnEvent("Change", OnChaosManualEdit)

    btnF7TabRun := AddFlatButton(28, 358, 176, 26, "", true, StartChaosStressTest, "F9F7")
    AddFlatButton(314, 358, 118, 26, "Reset F9 & F7", false, ResetF9F7Defaults, "F9F7")

    AddMutedLabel("F9F7", 28, 396, 404, "Runs outward chaos + reverse check, then auto-starts F8 Waystone on pass.")

    ; ==========================================================================
    ; TAB 3: SETTINGS (LIGHT/DARK MODE, OVERLAY HUD & HOTKEY SWITCH)
    ; ==========================================================================
    AddCard("SETTINGS", 16, 102, 428, 110)
    AddCardTitle("SETTINGS", 28, 112, 390, "APPEARANCE & DISPLAY")

    AddPrimaryLabel("SETTINGS", 28, 140, 180, "Interface Theme")
    btnSetDark  := AddFlatButton(236, 136, 96, 26, "DARK MODE",  false, (*) => SetDarkMode(true),  "SETTINGS")
    btnSetLight := AddFlatButton(336, 136, 96, 26, "LIGHT MODE", false, (*) => SetDarkMode(false), "SETTINGS")

    AddPrimaryLabel("SETTINGS", 28, 176, 190, "Floating Run Overlay")
    AddFlatButton(236, 172, 96, 26, "Reset Pos", false, ResetOverlayPosition, "SETTINGS")
    btnSetHud := AddFlatButton(336, 172, 96, 26, "", false, ToggleHudSetting, "SETTINGS")

    ; --- HOTKEY SWITCH CARD ---
    AddCard("SETTINGS", 16, 220, 428, 286)
    AddCardTitle("SETTINGS", 28, 230, 200, "HOTKEY SWITCH")

    btnSetKeysToggle := AddFlatButton(244, 226, 94, 22, "", false, ToggleHotkeysEnabled, "SETTINGS")
    AddFlatButton(344, 226, 88, 22, "Reset Keys", false, ResetDefaultHotkeys, "SETTINGS")

    AddHotkeyRow("waystone", "Waystone 8-Star",          260)
    AddHotkeyRow("tower",    "Tower Mode (Free Range)",  296)
    AddHotkeyRow("preset",   "Toggle Short / Very Wide", 332)
    AddHotkeyRow("circle",   "Queue Perimeter Circle",   368)
    AddHotkeyRow("chaos",    "Chaos Stress Test",        404)
    AddHotkeyRow("exit",     "Stop & Exit Macro",        440)

    AddMutedLabel("SETTINGS", 28, 478, 404, "Click 'Change' then press any key (supports Ctrl / Shift / Alt combos).")

    ; ==========================================================================
    ; TAB 4: CREDITS (DEV / CONTRIBUTOR AREA)
    ; ==========================================================================
    AddCard("CREDITS", 16, 102, 428, 108)
    AddCardTitle("CREDITS", 28, 112, 200, "DEVELOPER")
    AddPrimaryLabel("CREDITS", 28, 134, 260, "Chase", 13, true)
    AddMutedLabel("CREDITS", 28, 158, 260, "@alphagamer121204")
    AddMutedLabel("CREDITS", 28, 180, 290, "roblox.com/users/605992135/profile")
    AddFlatButton(304, 138, 128, 32, "Open Profile  ↗", true, (*) => Run("https://www.roblox.com/users/605992135/profile"), "CREDITS")

    AddCard("CREDITS", 16, 220, 428, 108)
    AddCardTitle("CREDITS", 28, 230, 200, "CONTRIBUTOR")
    AddPrimaryLabel("CREDITS", 28, 252, 260, "kaze", 13, true)
    AddMutedLabel("CREDITS", 28, 276, 260, "@kazefast")
    AddMutedLabel("CREDITS", 28, 298, 290, "roblox.com/users/1676005584/profile")
    AddFlatButton(304, 256, 128, 32, "Open Profile  ↗", true, (*) => Run("https://www.roblox.com/users/1676005584/profile"), "CREDITS")

    AddCard("CREDITS", 16, 338, 428, 110)
    AddCardTitle("CREDITS", 28, 348, 390, "PROJECT ARCHITECTURE")
    AddPrimaryLabel("CREDITS", 28, 370, 404, "Pixel Empire Macro · Modular AutoHotkey v2.0")
    AddMutedLabel("CREDITS", 28, 392, 404, "Entry: PixelEmpireMacro.ahk")
    AddMutedLabel("CREDITS", 28, 412, 404, "Modules: State · Config · VisionWindow · Movement · Modes/* · Hotkeys · GUI")

    ; --- PERSISTENT FOOTER ---
    AddDivider(16, 570, 428)
    txtGuiStatus := mainGui.AddText("x16 y578 w428 h20 +0x80 +0x04000000", "● Ready")
    txtGuiStatus.SetFont("s8 Bold", "Segoe UI")
    themeMutedText.Push({ctrl: txtGuiStatus, onCard: false})

    mainGui.OnEvent("Close", (*) => ExitMacro())
    OnMessage(0x0020, HandleSetCursor)
    OnMessage(0x0201, HandleOverlayDrag)

    BuildOverlayGUI()
    RefreshPresetUI()
    RefreshTowerUI()
    RefreshCircleUI()
    RefreshChaosUI()
    RefreshImageStatus()
    RefreshHotkeyLabels()
    RefreshSettingsTabUI()
    SwitchTab("MACRO")

    mainGui.Show("w460 h606")
    SendMessage(0x00B1, 999, 999, edtPromptPath.Hwnd)
    ApplyTheme()
}

; ==============================================================================
; FLOATING RUN OVERLAY BAR (MOVABLE + CLEAR STOP BUTTON)
; ==============================================================================

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
    sBtn.OnEvent("Click", (*) => StopAll("Stopped by user"))
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

; ==============================================================================
; RATIO-LOCKED RANGE < > SCALING (WAYSTONE, TOWER, CIRCLE, CHAOS)
; ==============================================================================

AdjustWaystoneRange(deltaPct) {
    global wideStarMode, shortCfg, shortBase, shortPct, wideCfg, wideBase, widePct
    if (wideStarMode) {
        widePct := Max(10, Min(500, widePct + deltaPct))
        ApplyRatioToObj(wideCfg, wideBase, widePct, true)
    } else {
        shortPct := Max(10, Min(500, shortPct + deltaPct))
        ApplyRatioToObj(shortCfg, shortBase, shortPct, true)
    }
    RefreshPresetUI()
    SaveConfig()
    pct := wideStarMode ? widePct : shortPct
    UpdateGuiStatus("Waystone Range scaled to " pct "%")
}

AdjustTowerRange(deltaPct) {
    global f5RingEdgeMs, f5UpMs, f5DownMs, f5LeftMs, f5RightMs, f5DiagMs, f5Base, f5Pct
    f5Pct := Max(10, Min(500, f5Pct + deltaPct))
    scale := f5Pct / 100.0
    f5RingEdgeMs := Max(50, Round(f5Base.ring * scale))
    f5UpMs       := Max(50, Round(f5Base.up * scale))
    f5DownMs     := Max(50, Round(f5Base.down * scale))
    f5LeftMs     := Max(50, Round(f5Base.left * scale))
    f5RightMs    := Max(50, Round(f5Base.right * scale))
    f5DiagMs     := Max(50, Round(f5Base.diag * scale))

    RefreshTowerUI()
    SaveConfig()
    UpdateGuiStatus("Tower Range scaled to " f5Pct "%")
}

AdjustCircleRange(deltaPct) {
    global circleCfg, circleBase, circlePct
    circlePct := Max(10, Min(500, circlePct + deltaPct))
    scale := circlePct / 100.0
    circleCfg.out  := Max(50,  Round(circleBase.out * scale))
    circleCfg.edge := Max(50,  Round(circleBase.edge * scale))
    circleCfg.card := Max(50,  Round(circleBase.card * scale))
    circleCfg.diag := Max(50,  Round(circleBase.diag * scale))
    circleCfg.ret  := Max(100, Round(circleBase.ret * scale))

    RefreshCircleUI()
    SaveConfig()
    UpdateGuiStatus("F9 Circle Range scaled to " circlePct "%")
}

AdjustChaosRange(deltaPct) {
    global chaosCfg, chaosBase, chaosPct
    chaosPct := Max(10, Min(500, chaosPct + deltaPct))
    scale := chaosPct / 100.0
    chaosCfg.angle   := Max(50, Round(chaosBase.angle * scale))
    chaosCfg.zigDiag := Max(50, Round(chaosBase.zigDiag * scale))
    chaosCfg.zigSide := Max(50, Round(chaosBase.zigSide * scale))

    RefreshChaosUI()
    SaveConfig()
    UpdateGuiStatus("F7 Chaos Range scaled to " chaosPct "%")
}

ApplyRatioToObj(targetObj, baseObj, pct, hasRet := false) {
    scale := pct / 100.0
    targetObj.up    := Max(50, Round(baseObj.up * scale))
    targetObj.down  := Max(50, Round(baseObj.down * scale))
    targetObj.left  := Max(50, Round(baseObj.left * scale))
    targetObj.right := Max(50, Round(baseObj.right * scale))
    targetObj.diag  := Max(50, Round(baseObj.diag * scale))
    if (hasRet)
        targetObj.ret := Max(100, Round(baseObj.ret * scale))
}

; ==============================================================================
; CUSTOM BLACK & WHITE COMPONENT BUILDERS
; ==============================================================================

AddRectBorder(x, y, w, h, tabName := "") {
    global mainGui, pageControls
    top := mainGui.AddText("x" x " y" y " w" w " h1 Disabled +0x04000000", "")
    bot := mainGui.AddText("x" x " y" (y + h - 1) " w" w " h1 Disabled +0x04000000", "")
    lft := mainGui.AddText("x" x " y" (y + 1) " w1 h" (h - 2) " Disabled +0x04000000", "")
    rgt := mainGui.AddText("x" (x + w - 1) " y" (y + 1) " w1 h" (h - 2) " Disabled +0x04000000", "")
    edges := [top, bot, lft, rgt]
    if (tabName != "") {
        for e in edges
            pageControls[tabName].Push(e)
    }
    return edges
}

AddCard(tabName, x, y, w, h) {
    global mainGui, pageControls, themeCards
    edges := AddRectBorder(x, y, w, h, tabName)
    fill  := mainGui.AddText("x" (x + 1) " y" (y + 1) " w" (w - 2) " h" (h - 2) " Disabled +0x04000000", "")
    themeCards.Push({edges: edges, fill: fill})
    pageControls[tabName].Push(fill)
}

AddDivider(x, y, w) {
    global mainGui, themeDividers
    line := mainGui.AddText("x" x " y" y " w" w " h1 Disabled +0x04000000", "")
    themeDividers.Push(line)
    return line
}

AddCardTitle(tabName, x, y, w, text) {
    global mainGui, pageControls, themeMutedText
    ctrl := mainGui.AddText("x" x " y" y " w" w " h16 +0x80 +0x04000000", text)
    ctrl.SetFont("s8 Bold", "Segoe UI")
    themeMutedText.Push({ctrl: ctrl, onCard: true})
    pageControls[tabName].Push(ctrl)
    return ctrl
}

AddPrimaryLabel(tabName, x, y, w, text, fontSize := 9, isBold := false) {
    global mainGui, pageControls, themePrimaryText
    ctrl := mainGui.AddText("x" x " y" y " w" w " h22 +0x80 +0x04000000", text)
    ctrl.SetFont("s" fontSize (isBold ? " Bold" : ""), "Segoe UI")
    themePrimaryText.Push({ctrl: ctrl, onCard: true})
    pageControls[tabName].Push(ctrl)
    return ctrl
}

AddMutedLabel(tabName, x, y, w, text, alignOpt := "") {
    global mainGui, pageControls, themeMutedText
    ctrl := mainGui.AddText("x" x " y" y " w" w " h18 " alignOpt " +0x80 +0x04000000", text)
    ctrl.SetFont("s8", "Segoe UI")
    themeMutedText.Push({ctrl: ctrl, onCard: true})
    pageControls[tabName].Push(ctrl)
    return ctrl
}

AddStyledEdit(tabName, x, y, w, h, defaultVal, extraOpts := "") {
    global mainGui, pageControls, themeEdits
    ctrl := mainGui.AddEdit("x" x " y" y " w" w " h" h " " extraOpts, defaultVal)
    ctrl.SetFont("s9", "Segoe UI")
    themeEdits.Push(ctrl)
    pageControls[tabName].Push(ctrl)
    return ctrl
}

AddFlatButton(x, y, w, h, text, isPrimary, callback, tabName := "") {
    global mainGui, pageControls, clickableHwnds, themePrimaryBtns, themeSecondaryBtns

    edges := AddRectBorder(x, y, w, h, tabName)
    btn   := mainGui.AddText("x" (x + 1) " y" (y + 1) " w" (w - 2) " h" (h - 2) " Center 0x200 +0x80 +0x04000000", text)
    btn.SetFont("s8 Bold", "Segoe UI")
    btn.OnEvent("Click", callback)
    clickableHwnds[btn.Hwnd] := true

    entry := {edges: edges, btn: btn}
    if (isPrimary)
        themePrimaryBtns.Push(entry)
    else
        themeSecondaryBtns.Push(entry)

    if (tabName != "")
        pageControls[tabName].Push(btn)
    return entry
}

AddTabButton(tabKey, x, y, w, h, label) {
    global mainGui, clickableHwnds, themeTabs
    edges := AddRectBorder(x, y, w, h)
    btn   := mainGui.AddText("x" (x + 1) " y" (y + 1) " w" (w - 2) " h" (h - 2) " Center 0x200 +0x80 +0x04000000", label)
    btn.SetFont("s8 Bold", "Segoe UI")
    btn.OnEvent("Click", (*) => SwitchTab(tabKey))
    clickableHwnds[btn.Hwnd] := true
    entry := {edges: edges, btn: btn}
    themeTabs[tabKey] := entry
    return entry
}

AddHotkeyRow(actionKey, label, y) {
    global mainGui, pageControls, themeSecondaryBtns, hkBadges

    AddPrimaryLabel("SETTINGS", 28, y + 3, 190, label)

    edges := AddRectBorder(228, y, 98, 26, "SETTINGS")
    badge := mainGui.AddText("x229 y" (y + 1) " w96 h24 Center 0x200 +0x80 +0x04000000", "")
    badge.SetFont("s8 Bold", "Segoe UI")
    themeSecondaryBtns.Push({edges: edges, btn: badge})
    pageControls["SETTINGS"].Push(badge)
    hkBadges[actionKey] := badge

    AddFlatButton(334, y, 98, 26, "Change", false, (*) => RebindHotkey(actionKey), "SETTINGS")
}

HandleSetCursor(wParam, lParam, msg, hwnd) {
    global clickableHwnds
    static hHand := DllCall("LoadCursor", "ptr", 0, "ptr", 32649, "ptr")
    if IsSet(clickableHwnds) && clickableHwnds.Has(wParam) {
        DllCall("SetCursor", "ptr", hHand)
        return true
    }
}

; ==============================================================================
; THEME ENGINE (MONOCHROME BLACK & WHITE)
; ==============================================================================

GetPalette() {
    global darkMode
    if (darkMode) {
        return {
            bg:         "0x0A0A0A",
            cardBg:     "0x141414",
            border:     "0x2E2E2E",
            divider:    "0x262626",
            inputBg:    "0x1C1C1C",
            text:       "0xFFFFFF",
            muted:      "0xA0A0A0",
            priBg:      "0xFFFFFF",
            priText:    "0x0A0A0A",
            priBorder:  "0xFFFFFF",
            secBg:      "0x1F1F1F",
            secText:    "0xFFFFFF",
            secBorder:  "0x3D3D3D",
            tabOffBg:   "0x141414",
            tabOffText: "0x8C8C8C"
        }
    }
    return {
        bg:         "0xF3F3F3",
        cardBg:     "0xFFFFFF",
        border:     "0xD4D4D4",
        divider:    "0xD0D0D0",
        inputBg:    "0xFAFAFA",
        text:       "0x0A0A0A",
        muted:      "0x5E5E5E",
        priBg:      "0x0A0A0A",
        priText:    "0xFFFFFF",
        priBorder:  "0x0A0A0A",
        secBg:      "0xEAEAEA",
        secText:    "0x0A0A0A",
        secBorder:  "0xC6C6C6",
        tabOffBg:   "0xFFFFFF",
        tabOffText: "0x666666"
    }
}

ApplyTheme() {
    global mainGui, darkMode, activeTab
    global themeCards, themeDividers, themePrimaryText, themeMutedText, themeEdits
    global themePrimaryBtns, themeSecondaryBtns, themeTabs
    global btnThemeQuick, radShortBtn, radWideBtn, btnSetDark, btnSetLight, wideStarMode

    p := GetPalette()
    mainGui.BackColor := p.bg

    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", mainGui.Hwnd, "int", 20, "int*", darkMode ? 1 : 0, "int", 4)

    for c in themeCards {
        for e in c.edges
            e.Opt("+Background" SubStr(p.border, 3))
        c.fill.Opt("+Background" SubStr(p.cardBg, 3))
        DllCall("SetWindowPos", "ptr", c.fill.Hwnd, "ptr", 1, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x0013)
    }
    for d in themeDividers {
        d.Opt("+Background" SubStr(p.divider, 3))
    }
    for item in themePrimaryText {
        item.ctrl.Opt("+Background" SubStr(item.onCard ? p.cardBg : p.bg, 3))
        item.ctrl.SetFont("c" SubStr(p.text, 3))
    }
    for item in themeMutedText {
        item.ctrl.Opt("+Background" SubStr(item.onCard ? p.cardBg : p.bg, 3))
        item.ctrl.SetFont("c" SubStr(p.muted, 3))
    }
    for e in themeEdits {
        e.Opt("+Background" SubStr(p.inputBg, 3))
        e.SetFont("c" SubStr(p.text, 3))
        try DllCall("uxtheme\SetWindowTheme", "ptr", e.Hwnd, "str", darkMode ? "DarkMode_Explorer" : "Explorer", "ptr", 0)
    }
    for b in themePrimaryBtns {
        StyleButton(b, p.priBg, p.priText, p.priBorder)
    }
    for b in themeSecondaryBtns {
        StyleButton(b, p.secBg, p.secText, p.secBorder)
    }

    for key, t in themeTabs {
        if (key = activeTab)
            StyleButton(t, p.priBg, p.priText, p.priBorder)
        else
            StyleButton(t, p.tabOffBg, p.tabOffText, p.border)
    }

    if IsSet(radShortBtn) && IsSet(radWideBtn) {
        StyleButton(radShortBtn, !wideStarMode ? p.priBg : p.secBg, !wideStarMode ? p.priText : p.secText, !wideStarMode ? p.priBorder : p.secBorder)
        StyleButton(radWideBtn,   wideStarMode ? p.priBg : p.secBg,  wideStarMode ? p.priText : p.secText,  wideStarMode ? p.priBorder : p.secBorder)
    }
    if IsSet(btnSetDark) && IsSet(btnSetLight) {
        StyleButton(btnSetDark,   darkMode ? p.priBg : p.secBg,  darkMode ? p.priText : p.secText,  darkMode ? p.priBorder : p.secBorder)
        StyleButton(btnSetLight, !darkMode ? p.priBg : p.secBg, !darkMode ? p.priText : p.secText, !darkMode ? p.priBorder : p.secBorder)
    }
    if IsSet(btnThemeQuick) {
        btnThemeQuick.btn.Text := darkMode ? "THEME: DARK" : "THEME: LIGHT"
    }

    if WinExist("ahk_id " mainGui.Hwnd)
        WinRedraw("ahk_id " mainGui.Hwnd)

    ApplyOverlayTheme()
}

StyleButton(entry, bgHex, txtHex, borderHex) {
    for e in entry.edges
        e.Opt("+Background" SubStr(borderHex, 3))
    entry.btn.Opt("+Background" SubStr(bgHex, 3))
    entry.btn.SetFont("c" SubStr(txtHex, 3))
}

SwitchTab(tabKey) {
    global activeTab, pageControls
    activeTab := tabKey
    for name, ctrls in pageControls {
        vis := (name = tabKey)
        for c in ctrls
            c.Visible := vis
    }
    ApplyTheme()
}

ToggleDarkMode(*) {
    global darkMode
    darkMode := !darkMode
    SaveConfig()
    ApplyTheme()
    UpdateGuiStatus(darkMode ? "Switched to Dark Mode" : "Switched to Light Mode")
}

SetDarkMode(enableDark) {
    global darkMode
    darkMode := enableDark
    SaveConfig()
    ApplyTheme()
    UpdateGuiStatus(darkMode ? "Switched to Dark Mode" : "Switched to Light Mode")
}

ToggleHudSetting(*) {
    global hudEnabled
    hudEnabled := !hudEnabled
    if (!hudEnabled)
        HideOverlay()
    SaveConfig()
    RefreshSettingsTabUI()
    UpdateGuiStatus(hudEnabled ? "Floating Run Overlay Enabled" : "Floating Run Overlay Disabled")
}

; ==============================================================================
; UI REFRESH & EVENT HANDLERS
; ==============================================================================

RefreshPresetUI() {
    global isUpdatingUI, wideStarMode, shortCfg, wideCfg, shortPct, widePct
    global edtWayUp, edtWayDown, edtWayLeft, edtWayRight, edtWayDiag, edtWayRet, txtWayRangePct

    if !IsSet(edtWayUp)
        return

    isUpdatingUI := true
    cfg := wideStarMode ? wideCfg : shortCfg
    pct := wideStarMode ? widePct : shortPct
    edtWayUp.Value    := cfg.up
    edtWayDown.Value  := cfg.down
    edtWayLeft.Value  := cfg.left
    edtWayRight.Value := cfg.right
    edtWayDiag.Value  := cfg.diag
    edtWayRet.Value   := cfg.ret
    txtWayRangePct.Text := pct "%"
    isUpdatingUI := false

    ApplyTheme()
}

RefreshTowerUI() {
    global isUpdatingUI, f5RingEdgeMs, f5UpMs, f5DownMs, f5LeftMs, f5RightMs, f5DiagMs, f5Pct
    global edtF5Ring, edtF5Up, edtF5Down, edtF5Left, edtF5Right, edtF5Diag, txtF5RangePct

    if !IsSet(edtF5Ring)
        return

    isUpdatingUI := true
    edtF5Ring.Value  := f5RingEdgeMs
    edtF5Up.Value    := f5UpMs
    edtF5Down.Value  := f5DownMs
    edtF5Left.Value  := f5LeftMs
    edtF5Right.Value := f5RightMs
    edtF5Diag.Value  := f5DiagMs
    txtF5RangePct.Text := f5Pct "%"
    isUpdatingUI := false
}

RefreshCircleUI() {
    global isUpdatingUI, circleCfg, circlePct
    global edtCirOut, edtCirEdge, edtCirCard, edtCirDiag, edtCirRet, txtCirRangePct

    if !IsSet(edtCirOut)
        return

    isUpdatingUI := true
    edtCirOut.Value  := circleCfg.out
    edtCirEdge.Value := circleCfg.edge
    edtCirCard.Value := circleCfg.card
    edtCirDiag.Value := circleCfg.diag
    edtCirRet.Value  := circleCfg.ret
    txtCirRangePct.Text := circlePct "%"
    isUpdatingUI := false
}

RefreshChaosUI() {
    global isUpdatingUI, chaosCfg, chaosPct
    global edtChaosAngle, edtChaosZigDiag, edtChaosZigSide, txtChaosRangePct

    if !IsSet(edtChaosAngle)
        return

    isUpdatingUI := true
    edtChaosAngle.Value   := chaosCfg.angle
    edtChaosZigDiag.Value := chaosCfg.zigDiag
    edtChaosZigSide.Value := chaosCfg.zigSide
    txtChaosRangePct.Text := chaosPct "%"
    isUpdatingUI := false
}

RefreshImageStatus() {
    global promptImg, txtImgStatus, edtPromptPath
    if !IsSet(edtPromptPath)
        return
    edtPromptPath.Value := promptImg
    txtImgStatus.Text := FileExist(promptImg) ? "● READY" : "● MISSING"
}

RefreshHotkeyLabels() {
    global hotkeys, btnActWaystone, btnActTower, btnActPreset, btnActCircle, btnActChaos, btnActExit
    global btnF9TabQueue, btnF7TabRun
    if !IsSet(btnActWaystone)
        return

    btnActWaystone.btn.Text := "Waystone 8-Star [" FormatHotkeyShort(hotkeys.waystone) "]"
    btnActTower.btn.Text    := "Tower Mode [" FormatHotkeyShort(hotkeys.tower) "]"
    btnActPreset.btn.Text   := "Preset [" FormatHotkeyShort(hotkeys.preset) "]"
    btnActCircle.btn.Text   := "Circle [" FormatHotkeyShort(hotkeys.circle) "]"
    btnActChaos.btn.Text    := "Chaos [" FormatHotkeyShort(hotkeys.chaos) "]"
    btnActExit.btn.Text     := "Exit [" FormatHotkeyShort(hotkeys.exit) "]"

    if IsSet(btnF9TabQueue)
        btnF9TabQueue.btn.Text := "Queue Circle [" FormatHotkeyShort(hotkeys.circle) "]"
    if IsSet(btnF7TabRun)
        btnF7TabRun.btn.Text := "Run Chaos Test [" FormatHotkeyShort(hotkeys.chaos) "]"
}

RefreshSettingsTabUI() {
    global hudEnabled, hotkeysEnabled, hotkeys, btnSetHud, btnSetKeysToggle, hkBadges

    if IsSet(btnSetHud)
        btnSetHud.btn.Text := hudEnabled ? "HUD: ON" : "HUD: OFF"

    if IsSet(btnSetKeysToggle)
        btnSetKeysToggle.btn.Text := hotkeysEnabled ? "KEYS: ON" : "KEYS: OFF"

    for actionKey, badge in hkBadges {
        badge.Text := FormatHotkeyRaw(hotkeys.%actionKey%)
    }
}

SelectWaystonePreset(useWide) {
    global wideStarMode, hudStatus
    wideStarMode := useWide
    RefreshPresetUI()
    SaveConfig()
    modeName := wideStarMode ? "VERY WIDE" : "SHORT"
    hudStatus := "Waystone Preset -> " modeName
    UpdateGuiStatus(hudStatus)
}

OnSettingsChanged(*) {
    global isUpdatingUI, imgTolerance, edtTolerance
    if (isUpdatingUI)
        return
    imgTolerance := ParseSetting(edtTolerance.Value, imgTolerance, 0, 255)
    SaveConfig()
}

OnWaystoneManualEdit(*) {
    global isUpdatingUI, wideStarMode, shortCfg, shortBase, shortPct, wideCfg, wideBase, widePct
    global edtWayUp, edtWayDown, edtWayLeft, edtWayRight, edtWayDiag, edtWayRet, txtWayRangePct

    if (isUpdatingUI)
        return

    cfg  := wideStarMode ? wideCfg  : shortCfg
    base := wideStarMode ? wideBase : shortBase

    cfg.up    := ParseSetting(edtWayUp.Value, cfg.up, 50, 30000)
    cfg.down  := ParseSetting(edtWayDown.Value, cfg.down, 50, 30000)
    cfg.left  := ParseSetting(edtWayLeft.Value, cfg.left, 50, 30000)
    cfg.right := ParseSetting(edtWayRight.Value, cfg.right, 50, 30000)
    cfg.diag  := ParseSetting(edtWayDiag.Value, cfg.diag, 50, 30000)
    cfg.ret   := ParseSetting(edtWayRet.Value, cfg.ret, 100, 60000)

    base.up    := cfg.up
    base.down  := cfg.down
    base.left  := cfg.left
    base.right := cfg.right
    base.diag  := cfg.diag
    base.ret   := cfg.ret

    if (wideStarMode)
        widePct := 100
    else
        shortPct := 100
    txtWayRangePct.Text := "100%"

    SaveConfig()
}

OnTowerManualEdit(*) {
    global isUpdatingUI, f5RingEdgeMs, f5UpMs, f5DownMs, f5LeftMs, f5RightMs, f5DiagMs, f5Base, f5Pct
    global edtF5Ring, edtF5Up, edtF5Down, edtF5Left, edtF5Right, edtF5Diag, txtF5RangePct

    if (isUpdatingUI)
        return

    f5RingEdgeMs := ParseSetting(edtF5Ring.Value, f5RingEdgeMs, 50, 30000)
    f5UpMs       := ParseSetting(edtF5Up.Value, f5UpMs, 50, 30000)
    f5DownMs     := ParseSetting(edtF5Down.Value, f5DownMs, 50, 30000)
    f5LeftMs     := ParseSetting(edtF5Left.Value, f5LeftMs, 50, 30000)
    f5RightMs    := ParseSetting(edtF5Right.Value, f5RightMs, 50, 30000)
    f5DiagMs     := ParseSetting(edtF5Diag.Value, f5DiagMs, 50, 30000)

    f5Base.ring  := f5RingEdgeMs
    f5Base.up    := f5UpMs
    f5Base.down  := f5DownMs
    f5Base.left  := f5LeftMs
    f5Base.right := f5RightMs
    f5Base.diag  := f5DiagMs
    f5Pct := 100
    txtF5RangePct.Text := "100%"

    SaveConfig()
}

OnCircleManualEdit(*) {
    global isUpdatingUI, circleCfg, circleBase, circlePct
    global edtCirOut, edtCirEdge, edtCirCard, edtCirDiag, edtCirRet, txtCirRangePct

    if (isUpdatingUI)
        return

    circleCfg.out  := ParseSetting(edtCirOut.Value, circleCfg.out, 50, 30000)
    circleCfg.edge := ParseSetting(edtCirEdge.Value, circleCfg.edge, 50, 30000)
    circleCfg.card := ParseSetting(edtCirCard.Value, circleCfg.card, 50, 30000)
    circleCfg.diag := ParseSetting(edtCirDiag.Value, circleCfg.diag, 50, 30000)
    circleCfg.ret  := ParseSetting(edtCirRet.Value, circleCfg.ret, 100, 60000)

    circleBase.out  := circleCfg.out
    circleBase.edge := circleCfg.edge
    circleBase.card := circleCfg.card
    circleBase.diag := circleCfg.diag
    circleBase.ret  := circleCfg.ret
    circlePct := 100
    txtCirRangePct.Text := "100%"

    SaveConfig()
}

OnChaosManualEdit(*) {
    global isUpdatingUI, chaosCfg, chaosBase, chaosPct
    global edtChaosAngle, edtChaosZigDiag, edtChaosZigSide, txtChaosRangePct

    if (isUpdatingUI)
        return

    chaosCfg.angle   := ParseSetting(edtChaosAngle.Value, chaosCfg.angle, 50, 30000)
    chaosCfg.zigDiag := ParseSetting(edtChaosZigDiag.Value, chaosCfg.zigDiag, 50, 30000)
    chaosCfg.zigSide := ParseSetting(edtChaosZigSide.Value, chaosCfg.zigSide, 50, 30000)

    chaosBase.angle   := chaosCfg.angle
    chaosBase.zigDiag := chaosCfg.zigDiag
    chaosBase.zigSide := chaosCfg.zigSide
    chaosPct := 100
    txtChaosRangePct.Text := "100%"

    SaveConfig()
}

ImportPromptImage(*) {
    global promptImg, mainGui
    mainGui.Opt("+OwnDialogs")
    selected := FileSelect(3, A_ScriptDir, "Select Waystone Prompt Image (Return to Town (E) or shortened)", "Images (*.png; *.jpg; *.jpeg; *.bmp)")
    if (selected != "") {
        promptImg := selected
        RefreshImageStatus()
        SaveConfig()
        UpdateGuiStatus("Imported prompt image.")
    }
}

TestWaystoneDetection(*) {
    global mainGui, searchBox, imgTolerance
    if !InitVisionAndWindow(true)
        return

    Sleep(80)
    if (IsOnWaystone(&fx, &fy)) {
        mainGui.Opt("+OwnDialogs")
        MsgBox("Waystone Prompt DETECTED!`n`nCoordinates: X=" fx ", Y=" fy "`nSearch Box: (" searchBox.x1 "," searchBox.y1 ") to (" searchBox.x2 "," searchBox.y2 ")`nTolerance: " imgTolerance, "Waystone Test Passed", "Iconi")
    } else {
        mainGui.Opt("+OwnDialogs")
        MsgBox("Waystone Prompt NOT detected.`n`nTips:`n1. Make sure 'Return to Town (E)' is clearly visible on screen.`n2. Import a tighter/shortened crop of the prompt text if your screen resolution changed.`n3. Try increasing Tolerance (currently " imgTolerance ").", "Waystone Test Failed", "Icon!")
    }
}

ResetPresetDefaults(*) {
    global shortCfg, shortBase, shortPct, wideCfg, wideBase, widePct
    global f5RingEdgeMs, f5UpMs, f5DownMs, f5LeftMs, f5RightMs, f5DiagMs, f5Base, f5Pct, imgTolerance
    global isUpdatingUI, edtTolerance

    shortCfg  := {up: 1050, down: 1300, left: 1300, right: 1300, diag: 1050, ret: 1850}
    shortBase := {up: 1050, down: 1300, left: 1300, right: 1300, diag: 1050, ret: 1850}
    shortPct  := 100

    wideCfg  := {up: 1650, down: 1950, left: 1950, right: 1950, diag: 1650, ret: 2600}
    wideBase := {up: 1650, down: 1950, left: 1950, right: 1950, diag: 1650, ret: 2600}
    widePct  := 100

    f5RingEdgeMs := 1150
    f5UpMs       := 1750
    f5DownMs     := 1750
    f5LeftMs     := 1750
    f5RightMs    := 1750
    f5DiagMs     := 1750
    f5Base       := {ring: 1150, up: 1750, down: 1750, left: 1750, right: 1750, diag: 1750}
    f5Pct        := 100

    imgTolerance := 45
    isUpdatingUI := true
    edtTolerance.Value := imgTolerance
    isUpdatingUI := false

    RefreshPresetUI()
    RefreshTowerUI()
    SaveConfig()
    UpdateGuiStatus("Reset Waystone & Tower move times to defaults.")
}

ResetF9F7Defaults(*) {
    global circleCfg, circleBase, circlePct, chaosCfg, chaosBase, chaosPct

    circleCfg  := {out: 1350, edge: 800, card: 960, diag: 960, ret: 2600}
    circleBase := {out: 1350, edge: 800, card: 960, diag: 960, ret: 2600}
    circlePct  := 100

    chaosCfg  := {angle: 1750, zigDiag: 450, zigSide: 500}
    chaosBase := {angle: 1750, zigDiag: 450, zigSide: 500}
    chaosPct  := 100

    RefreshCircleUI()
    RefreshChaosUI()
    SaveConfig()
    UpdateGuiStatus("Reset F9 Circle & F7 Chaos defaults.")
}

UpdateGuiStatus(msg) {
    global txtGuiStatus
    if IsSet(txtGuiStatus)
        try txtGuiStatus.Text := "● " msg
}

UpdateHUD() {
    global running, chaosTestRunning, freeCircleMode, wideStarMode, completedLoops, recoveryCount, hudStatus
    global overlayVisible, overlayTitleTxt, overlayStatusTxt
    if (!running)
        return

    winCount := GetSortedRobloxWindows().Length
    altInfo := (winCount > 1) ? " · Alts: " (winCount - 1) : ""

    if (chaosTestRunning) {
        titleLine := "● CHAOS STRESS TEST" altInfo
        UpdateGuiStatus(hudStatus)
    } else if (freeCircleMode) {
        titleLine := "● TOWER MODE  ·  Cycles: " completedLoops altInfo
        UpdateGuiStatus("Tower Mode (" completedLoops " cycles) - " hudStatus)
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