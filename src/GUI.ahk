; ==============================================================================
; BLACK & WHITE GUI + FLOATING OVERLAY HUD + RATIO RANGE SCALERS
; ==============================================================================

BuildGUI() {
    global mainGui, activeTab, pageControls, clickableHwnds
    global themeCards, themeDividers, themePrimaryText, themeMutedText, themeEdits
    global themePrimaryBtns, themeSecondaryBtns, themeTabs
    global btnThemeQuick, tabWaystone, tabTower, tabF9F7, tabSettings, tabCredits
    global edtPromptPath, edtRecoveryPath, edtTolerance, edtRecTolerance, txtImgStatus
    global radShortBtn, radWideBtn, edtWayUp, edtWayDown, edtWayLeft, edtWayRight, edtWayDiag, edtWayRet, txtWayRangePct
    global edtF5Ring, edtF5Up, edtF5Down, edtF5Left, edtF5Right, edtF5Diag, txtF5RangePct
    global edtCirOut, edtCirEdge, edtCirCard, edtCirDiag, edtCirRet, txtCirRangePct, btnF9TabQueue
    global edtChaosAngle, edtChaosZigDiag, edtChaosZigSide, txtChaosRangePct, btnF7TabRun
    global btnActWaystone, btnActTower, btnActPreset, btnActCircle, btnActChaos, btnActExit
    global btnSetDark, btnSetLight, btnSetHud, btnSetKeysToggle, hkBadges
    global txtGuiStatus, promptImg, recoveryImg, imgTolerance, recoveryTolerance
    global f5RingEdgeMs, f5UpMs, f5DownMs, f5LeftMs, f5RightMs, f5DiagMs

    pageControls := Map("WAYSTONE", [], "TOWER", [], "F9F7", [], "SETTINGS", [], "CREDITS", [])
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
    lblTitle := mainGui.AddText("x20 y14 w300 h24 +0x80 +0x04000000", "PIXEL EMPIRE MACRO")
    lblTitle.SetFont("s13 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: lblTitle, onCard: false})

    lblSub := mainGui.AddText("x20 y38 w300 h16 +0x80 +0x04000000", "FARMING & GRIND AUTOMATION")
    lblSub.SetFont("s8 Bold", "Segoe UI")
    themeMutedText.Push({ctrl: lblSub, onCard: false})

    btnThemeQuick := AddFlatButton(406, 18, 114, 30, "", false, (*) => ToggleDarkMode())

    ; --- NAVIGATION TABS ---
    tabWaystone := AddTabButton("WAYSTONE", 20,  66, 95, 30, "WAYSTONE")
    tabTower    := AddTabButton("TOWER",    121, 66, 95, 30, "TOWER")
    tabF9F7     := AddTabButton("F9F7",     222, 66, 95, 30, "F9 / F7")
    tabSettings := AddTabButton("SETTINGS", 323, 66, 95, 30, "SETTINGS")
    tabCredits  := AddTabButton("CREDITS",  424, 66, 96, 30, "CREDITS")

    AddDivider(20, 106, 500)

    ; ==========================================================================
    ; TAB 1: WAYSTONE (DETECTION & F8 8-STAR)
    ; ==========================================================================
    AddCard("WAYSTONE", 20, 116, 500, 144)
    AddCardTitle("WAYSTONE", 36, 128, 280, "WAYSTONE VISION & SPRITES")
    txtImgStatus := mainGui.AddText("x374 y128 w130 h16 Right +0x80 +0x04000000", "")
    txtImgStatus.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtImgStatus, onCard: true})
    pageControls["WAYSTONE"].Push(txtImgStatus)

    AddMutedLabel("WAYSTONE", 36, 158, 56, "Prompt:")
    edtPromptPath := AddStyledEdit("WAYSTONE", 96, 154, 312, 26, promptImg, "ReadOnly")
    AddFlatButton(416, 154, 88, 26, "Import...", false, ImportPromptImage, "WAYSTONE")

    AddMutedLabel("WAYSTONE", 36, 192, 56, "Sprite:")
    edtRecoveryPath := AddStyledEdit("WAYSTONE", 96, 188, 312, 26, recoveryImg, "ReadOnly")
    AddFlatButton(416, 188, 88, 26, "Sprite...", false, ImportRecoveryImage, "WAYSTONE")

    AddMutedLabel("WAYSTONE", 36, 226, 70, "Prompt Tol:")
    edtTolerance := AddStyledEdit("WAYSTONE", 108, 222, 56, 26, imgTolerance, "Number")
    edtTolerance.OnEvent("Change", OnSettingsChanged)

    AddMutedLabel("WAYSTONE", 180, 226, 64, "Sprite Tol:")
    edtRecTolerance := AddStyledEdit("WAYSTONE", 246, 222, 56, 26, recoveryTolerance, "Number")
    edtRecTolerance.OnEvent("Change", OnSettingsChanged)

    AddFlatButton(364, 222, 140, 26, "Test Waystone", false, TestWaystoneDetection, "WAYSTONE")

    ; --- F8 WAYSTONE 8-STAR CARD ---
    AddCard("WAYSTONE", 20, 270, 500, 206)
    AddCardTitle("WAYSTONE", 36, 284, 220, "F8 WAYSTONE 8-STAR TIMES (MS)")

    radShortBtn := AddFlatButton(284, 280, 72, 24, "SHORT", false, (*) => SelectWaystonePreset(false), "WAYSTONE")
    radWideBtn  := AddFlatButton(362, 280, 88, 24, "VERY WIDE", false, (*) => SelectWaystonePreset(true), "WAYSTONE")
    AddFlatButton(456, 280, 48, 24, "RST", false, ResetWaystoneDefaults, "WAYSTONE")

    AddMutedLabel("WAYSTONE", 36, 322, 56, "Up (W):")
    edtWayUp := AddStyledEdit("WAYSTONE", 94, 318, 76, 26, "", "Number")
    AddMutedLabel("WAYSTONE", 192, 322, 64, "Down (S):")
    edtWayDown := AddStyledEdit("WAYSTONE", 258, 318, 76, 26, "", "Number")
    AddMutedLabel("WAYSTONE", 356, 322, 62, "Diagonal:")
    edtWayDiag := AddStyledEdit("WAYSTONE", 420, 318, 84, 26, "", "Number")

    AddMutedLabel("WAYSTONE", 36, 358, 56, "Left (A):")
    edtWayLeft := AddStyledEdit("WAYSTONE", 94, 354, 76, 26, "", "Number")
    AddMutedLabel("WAYSTONE", 192, 358, 64, "Right (D):")
    edtWayRight := AddStyledEdit("WAYSTONE", 258, 354, 76, 26, "", "Number")
    AddMutedLabel("WAYSTONE", 356, 358, 62, "Ret Max:")
    edtWayRet := AddStyledEdit("WAYSTONE", 420, 354, 84, 26, "", "Number")

    for ctrl in [edtWayUp, edtWayDown, edtWayLeft, edtWayRight, edtWayDiag, edtWayRet]
        ctrl.OnEvent("Change", OnWaystoneManualEdit)

    AddMutedLabel("WAYSTONE", 36, 398, 52, "Range:")
    AddFlatButton(94, 394, 34, 26, "<", false, (*) => AdjustWaystoneRange(-10), "WAYSTONE")
    txtWayRangePct := mainGui.AddText("x132 y398 w50 h18 Center +0x80 +0x04000000", "100%")
    txtWayRangePct.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtWayRangePct, onCard: true})
    pageControls["WAYSTONE"].Push(txtWayRangePct)
    AddFlatButton(186, 394, 34, 26, ">", false, (*) => AdjustWaystoneRange(10), "WAYSTONE")
    AddMutedLabel("WAYSTONE", 232, 398, 272, "Scales all values equally by ratio", "Right")

    AddMutedLabel("WAYSTONE", 36, 438, 468, "Manual edits set your 100% ratio baseline. Press F6 (or preset key) to toggle.")

    ; ==========================================================================
    ; TAB 2: TOWER MODE (F5 FREE RANGE)
    ; ==========================================================================
    AddCard("TOWER", 20, 116, 500, 232)
    AddCardTitle("TOWER", 36, 130, 300, "F5 TOWER MODE / FREE RANGE (MS)")
    AddFlatButton(404, 126, 100, 24, "Reset Tower", false, ResetTowerDefaults, "TOWER")

    AddMutedLabel("TOWER", 36, 170, 64, "Ring Edge:")
    edtF5Ring := AddStyledEdit("TOWER", 102, 166, 68, 26, f5RingEdgeMs, "Number")
    AddMutedLabel("TOWER", 192, 170, 60, "Up (W):")
    edtF5Up := AddStyledEdit("TOWER", 254, 166, 76, 26, f5UpMs, "Number")
    AddMutedLabel("TOWER", 352, 170, 64, "Down (S):")
    edtF5Down := AddStyledEdit("TOWER", 418, 166, 86, 26, f5DownMs, "Number")

    AddMutedLabel("TOWER", 36, 208, 64, "Left (A):")
    edtF5Left := AddStyledEdit("TOWER", 102, 204, 68, 26, f5LeftMs, "Number")
    AddMutedLabel("TOWER", 192, 208, 60, "Right (D):")
    edtF5Right := AddStyledEdit("TOWER", 254, 204, 76, 26, f5RightMs, "Number")
    AddMutedLabel("TOWER", 352, 208, 64, "Diagonal:")
    edtF5Diag := AddStyledEdit("TOWER", 418, 204, 86, 26, f5DiagMs, "Number")

    for ctrl in [edtF5Ring, edtF5Up, edtF5Down, edtF5Left, edtF5Right, edtF5Diag]
        ctrl.OnEvent("Change", OnTowerManualEdit)

    AddMutedLabel("TOWER", 36, 252, 52, "Range:")
    AddFlatButton(94, 248, 34, 26, "<", false, (*) => AdjustTowerRange(-10), "TOWER")
    txtF5RangePct := mainGui.AddText("x132 y252 w50 h18 Center +0x80 +0x04000000", "100%")
    txtF5RangePct.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtF5RangePct, onCard: true})
    pageControls["TOWER"].Push(txtF5RangePct)
    AddFlatButton(186, 248, 34, 26, ">", false, (*) => AdjustTowerRange(10), "TOWER")
    AddMutedLabel("TOWER", 232, 252, 272, "Scales Ring Edge & Cross equally", "Right")

    AddMutedLabel("TOWER", 36, 294, 468, "Waystone-free continuous loop: 8-sided octagonal sweep followed by full X")
    AddMutedLabel("TOWER", 36, 314, 468, "diagonals and cardinal flanks. Ideal when farming without a Waystone prompt.")

    ; ==========================================================================
    ; TAB 3: F9 PERIMETER CIRCLE & F7 CHAOS STRESS TEST
    ; ==========================================================================
    AddCard("F9F7", 20, 116, 500, 194)
    AddCardTitle("F9F7", 36, 128, 300, "F9 PERIMETER CIRCLE TIMES (MS)")
    AddFlatButton(456, 126, 48, 24, "RST", false, ResetF9F7Defaults, "F9F7")

    AddMutedLabel("F9F7", 36, 166, 62, "Out (W):")
    edtCirOut := AddStyledEdit("F9F7", 100, 162, 70, 26, "", "Number")
    AddMutedLabel("F9F7", 190, 166, 66, "Top Edge:")
    edtCirEdge := AddStyledEdit("F9F7", 258, 162, 74, 26, "", "Number")
    AddMutedLabel("F9F7", 354, 166, 60, "Ret Max:")
    edtCirRet := AddStyledEdit("F9F7", 416, 162, 88, 26, "", "Number")

    AddMutedLabel("F9F7", 36, 202, 62, "Cardinals:")
    edtCirCard := AddStyledEdit("F9F7", 100, 198, 70, 26, "", "Number")
    AddMutedLabel("F9F7", 190, 202, 66, "Diagonals:")
    edtCirDiag := AddStyledEdit("F9F7", 258, 198, 74, 26, "", "Number")
    btnF9TabQueue := AddFlatButton(354, 198, 150, 26, "", false, QueuePerimeterCircle, "F9F7")

    for ctrl in [edtCirOut, edtCirEdge, edtCirCard, edtCirDiag, edtCirRet]
        ctrl.OnEvent("Change", OnCircleManualEdit)

    AddMutedLabel("F9F7", 36, 240, 52, "Range:")
    AddFlatButton(94, 236, 34, 26, "<", false, (*) => AdjustCircleRange(-10), "F9F7")
    txtCirRangePct := mainGui.AddText("x132 y240 w50 h18 Center +0x80 +0x04000000", "100%")
    txtCirRangePct.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtCirRangePct, onCard: true})
    pageControls["F9F7"].Push(txtCirRangePct)
    AddFlatButton(186, 236, 34, 26, ">", false, (*) => AdjustCircleRange(10), "F9F7")
    AddMutedLabel("F9F7", 232, 240, 272, "Lower % if circle travels too far out", "Right")

    AddMutedLabel("F9F7", 36, 276, 468, "Out (W) sets radius. Top Edge is D; Cardinals S/A/W; Diagonals SE/SW/NW.")

    ; --- F7 CHAOS STRESS TEST CARD ---
    AddCard("F9F7", 20, 322, 500, 154)
    AddCardTitle("F9F7", 36, 334, 240, "F7 CHAOS STRESS TEST (MS)")

    AddMutedLabel("F9F7", 322, 334, 48, "Range:")
    AddFlatButton(376, 331, 34, 24, "<", false, (*) => AdjustChaosRange(-10), "F9F7")
    txtChaosRangePct := mainGui.AddText("x414 y334 w50 h18 Center +0x80 +0x04000000", "100%")
    txtChaosRangePct.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtChaosRangePct, onCard: true})
    pageControls["F9F7"].Push(txtChaosRangePct)
    AddFlatButton(468, 331, 36, 24, ">", false, (*) => AdjustChaosRange(10), "F9F7")

    AddMutedLabel("F9F7", 36, 372, 72, "Long Angle:")
    edtChaosAngle := AddStyledEdit("F9F7", 110, 368, 68, 26, "", "Number")
    AddMutedLabel("F9F7", 200, 372, 58, "Zig Diag:")
    edtChaosZigDiag := AddStyledEdit("F9F7", 260, 368, 68, 26, "", "Number")
    AddMutedLabel("F9F7", 350, 372, 58, "Zig Side:")
    edtChaosZigSide := AddStyledEdit("F9F7", 410, 368, 94, 26, "", "Number")

    for ctrl in [edtChaosAngle, edtChaosZigDiag, edtChaosZigSide]
        ctrl.OnEvent("Change", OnChaosManualEdit)

    btnF7TabRun := AddFlatButton(36, 408, 210, 28, "", true, StartChaosStressTest, "F9F7")
    AddFlatButton(364, 408, 140, 28, "Reset F9 & F7", false, ResetF9F7Defaults, "F9F7")

    AddMutedLabel("F9F7", 36, 446, 468, "Runs outward chaos + reverse check, then auto-starts F8 Waystone on pass.")

    ; ==========================================================================
    ; TAB 4: SETTINGS (LIGHT/DARK MODE, OVERLAY HUD & HOTKEY SWITCH)
    ; ==========================================================================
    AddCard("SETTINGS", 20, 116, 500, 114)
    AddCardTitle("SETTINGS", 36, 128, 390, "APPEARANCE & DISPLAY")

    AddPrimaryLabel("SETTINGS", 36, 156, 200, "Interface Theme")
    btnSetDark  := AddFlatButton(290, 152, 102, 28, "DARK MODE",  false, (*) => SetDarkMode(true),  "SETTINGS")
    btnSetLight := AddFlatButton(400, 152, 104, 28, "LIGHT MODE", false, (*) => SetDarkMode(false), "SETTINGS")

    AddPrimaryLabel("SETTINGS", 36, 194, 200, "Floating Run Overlay")
    AddFlatButton(290, 190, 102, 28, "Reset Pos", false, ResetOverlayPosition, "SETTINGS")
    btnSetHud := AddFlatButton(400, 190, 104, 28, "", false, ToggleHudSetting, "SETTINGS")

    ; --- HOTKEY SWITCH CARD ---
    AddCard("SETTINGS", 20, 240, 500, 236)
    AddCardTitle("SETTINGS", 36, 250, 200, "HOTKEY SWITCH")

    btnSetKeysToggle := AddFlatButton(290, 246, 102, 24, "", false, ToggleHotkeysEnabled, "SETTINGS")
    AddFlatButton(400, 246, 104, 24, "Reset Keys", false, ResetDefaultHotkeys, "SETTINGS")

    AddHotkeyRow("waystone", "Waystone 8-Star",          280)
    AddHotkeyRow("tower",    "Tower Mode (Free Range)",  310)
    AddHotkeyRow("preset",   "Toggle Short / Very Wide", 340)
    AddHotkeyRow("circle",   "Queue Perimeter Circle",   370)
    AddHotkeyRow("chaos",    "Chaos Stress Test",        400)
    AddHotkeyRow("exit",     "Stop & Exit Macro",        430)

    AddMutedLabel("SETTINGS", 36, 458, 468, "Click 'Change' then press any key (supports Ctrl / Shift / Alt combos).")

    ; ==========================================================================
    ; TAB 5: CREDITS (DEV / CONTRIBUTOR AREA)
    ; ==========================================================================
    AddCard("CREDITS", 20, 116, 500, 112)
    AddCardTitle("CREDITS", 36, 128, 200, "DEVELOPER")
    AddPrimaryLabel("CREDITS", 36, 150, 280, "Chase", 13, true)
    AddMutedLabel("CREDITS", 36, 174, 280, "@alphagamer121204")
    AddMutedLabel("CREDITS", 36, 196, 310, "roblox.com/users/605992135/profile")
    AddFlatButton(364, 154, 140, 34, "Open Profile  ↗", true, (*) => Run("https://www.roblox.com/users/605992135/profile"), "CREDITS")

    AddCard("CREDITS", 20, 240, 500, 112)
    AddCardTitle("CREDITS", 36, 252, 200, "CONTRIBUTOR")
    AddPrimaryLabel("CREDITS", 36, 274, 280, "kaze", 13, true)
    AddMutedLabel("CREDITS", 36, 298, 280, "@kazefast")
    AddMutedLabel("CREDITS", 36, 320, 310, "roblox.com/users/1676005584/profile")
    AddFlatButton(364, 278, 140, 34, "Open Profile  ↗", true, (*) => Run("https://www.roblox.com/users/1676005584/profile"), "CREDITS")

    AddCard("CREDITS", 20, 364, 500, 112)
    AddCardTitle("CREDITS", 36, 376, 390, "PROJECT ARCHITECTURE")
    AddPrimaryLabel("CREDITS", 36, 398, 468, "Pixel Empire Macro · Modular AutoHotkey v2.0")
    AddMutedLabel("CREDITS", 36, 422, 468, "Entry: PixelEmpireMacro.ahk")
    AddMutedLabel("CREDITS", 36, 442, 468, "Modules: State · Config · VisionWindow · Movement · Modes/* · Hotkeys · GUI")

    ; ==========================================================================
    ; PERSISTENT QUICK ACTIONS BAR (ALWAYS VISIBLE)
    ; ==========================================================================
    AddCard("", 20, 488, 500, 98)
    AddCardTitle("", 36, 496, 300, "QUICK ACTIONS")

    btnActWaystone := AddFlatButton(36,  516, 230, 28, "", true,  ToggleWaystoneMode)
    btnActTower    := AddFlatButton(274, 516, 230, 28, "", false, ToggleTowerMode)

    btnActPreset := AddFlatButton(36,  550, 112, 26, "", false, ToggleShortWidePreset)
    btnActCircle := AddFlatButton(154, 550, 112, 26, "", false, QueuePerimeterCircle)
    btnActChaos  := AddFlatButton(272, 550, 112, 26, "", false, StartChaosStressTest)
    btnActExit   := AddFlatButton(390, 550, 114, 26, "", false, ExitMacro)

    ; --- PERSISTENT FOOTER ---
    AddDivider(20, 594, 500)
    txtGuiStatus := mainGui.AddText("x20 y602 w500 h20 +0x80 +0x04000000", "● Ready")
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
    SwitchTab("WAYSTONE")

    mainGui.Show("w540 h630")
    SendMessage(0x00B1, 999, 999, edtPromptPath.Hwnd)
    SendMessage(0x00B1, 999, 999, edtRecoveryPath.Hwnd)
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
    if (tabName != "" && pageControls.Has(tabName)) {
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
    if (tabName != "" && pageControls.Has(tabName))
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
    if (tabName != "" && pageControls.Has(tabName))
        pageControls[tabName].Push(ctrl)
    return ctrl
}

AddPrimaryLabel(tabName, x, y, w, text, fontSize := 9, isBold := false) {
    global mainGui, pageControls, themePrimaryText
    ctrl := mainGui.AddText("x" x " y" y " w" w " h22 +0x80 +0x04000000", text)
    ctrl.SetFont("s" fontSize (isBold ? " Bold" : ""), "Segoe UI")
    themePrimaryText.Push({ctrl: ctrl, onCard: true})
    if (tabName != "" && pageControls.Has(tabName))
        pageControls[tabName].Push(ctrl)
    return ctrl
}

AddMutedLabel(tabName, x, y, w, text, alignOpt := "") {
    global mainGui, pageControls, themeMutedText
    ctrl := mainGui.AddText("x" x " y" y " w" w " h18 " alignOpt " +0x80 +0x04000000", text)
    ctrl.SetFont("s8", "Segoe UI")
    themeMutedText.Push({ctrl: ctrl, onCard: true})
    if (tabName != "" && pageControls.Has(tabName))
        pageControls[tabName].Push(ctrl)
    return ctrl
}

AddStyledEdit(tabName, x, y, w, h, defaultVal, extraOpts := "") {
    global mainGui, pageControls, themeEdits
    ctrl := mainGui.AddEdit("x" x " y" y " w" w " h" h " " extraOpts, defaultVal)
    ctrl.SetFont("s9", "Segoe UI")
    themeEdits.Push(ctrl)
    if (tabName != "" && pageControls.Has(tabName))
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

    if (tabName != "" && pageControls.Has(tabName))
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

    AddPrimaryLabel("SETTINGS", 36, y + 3, 240, label)

    edges := AddRectBorder(290, y, 102, 24, "SETTINGS")
    badge := mainGui.AddText("x291 y" (y + 1) " w100 h22 Center 0x200 +0x80 +0x04000000", "")
    badge.SetFont("s8 Bold", "Segoe UI")
    themeSecondaryBtns.Push({edges: edges, btn: badge})
    pageControls["SETTINGS"].Push(badge)
    hkBadges[actionKey] := badge

    AddFlatButton(400, y, 104, 24, "Change", false, (*) => RebindHotkey(actionKey), "SETTINGS")
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
    global promptImg, recoveryImg, txtImgStatus, edtPromptPath, edtRecoveryPath
    if IsSet(edtPromptPath)
        edtPromptPath.Value := promptImg
    if IsSet(edtRecoveryPath)
        edtRecoveryPath.Value := recoveryImg
    if IsSet(txtImgStatus) {
        if !FileExist(promptImg)
            txtImgStatus.Text := "● PROMPT MISSING"
        else if !FileExist(recoveryImg)
            txtImgStatus.Text := "● SPRITE MISSING"
        else
            txtImgStatus.Text := "● READY"
    }
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
    global isUpdatingUI, imgTolerance, edtTolerance, recoveryTolerance, edtRecTolerance
    if (isUpdatingUI)
        return
    imgTolerance      := ParseSetting(edtTolerance.Value, imgTolerance, 0, 255)
    recoveryTolerance := ParseSetting(edtRecTolerance.Value, recoveryTolerance, 0, 255)
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
    global promptImg, mainGui, edtPromptPath
    mainGui.Opt("+OwnDialogs")
    selected := FileSelect(3, A_ScriptDir, "Select Waystone Prompt Image (Return to Town (E) or shortened)", "Images (*.png; *.jpg; *.jpeg; *.bmp)")
    if (selected != "") {
        promptImg := selected
        RefreshImageStatus()
        SendMessage(0x00B1, 999, 999, edtPromptPath.Hwnd)
        SaveConfig()
        UpdateGuiStatus("Imported prompt image.")
    }
}

ImportRecoveryImage(*) {
    global recoveryImg, mainGui, edtRecoveryPath
    mainGui.Opt("+OwnDialogs")
    selected := FileSelect(3, A_ScriptDir, "Select Recovery Waystone Sprite Image", "Images (*.png; *.jpg; *.jpeg; *.bmp)")
    if (selected != "") {
        recoveryImg := selected
        RefreshImageStatus()
        SendMessage(0x00B1, 999, 999, edtRecoveryPath.Hwnd)
        SaveConfig()
        UpdateGuiStatus("Imported recovery sprite.")
    }
}

TestWaystoneDetection(*) {
    global mainGui, searchBox, imgTolerance, recoveryImg, recoveryTolerance
    if !InitVisionAndWindow(true)
        return

    mainGui.Hide()
    Sleep(120)
    promptFound := IsOnWaystone(&fx, &fy)
    statueFound := FindWaystoneStatue(&sx, &sy)
    mainGui.Show()

    promptMsg := promptFound
        ? "FOUND at (" fx ", " fy ")"
        : "NOT found (Tol: " imgTolerance ")"

    GetImageDimensions(recoveryImg, &rw, &rh)
    statueMsg := !FileExist(recoveryImg)
        ? "FILE MISSING (" recoveryImg ")"
        : (statueFound ? "FOUND at (" sx ", " sy ") [" rw "x" rh "px]" : "NOT found (Tol: " recoveryTolerance ", Size: " rw "x" rh "px)")

    mainGui.Opt("+OwnDialogs")
    MsgBox(
        "Point 0 Prompt ('Return to Town'):`n  " promptMsg
        "`n`nRecovery Sprite:`n  " statueMsg
        "`n`nTip: If Recovery Sprite is NOT found, crop an opaque ~24x34px stone + rune patch from Roblox at your zoom level.",
        "Waystone Detection Test",
        (promptFound || statueFound) ? "Iconi" : "Icon!"
    )
}

ResetWaystoneDefaults(*) {
    global shortCfg, shortBase, shortPct, wideCfg, wideBase, widePct
    global imgTolerance, recoveryTolerance, isUpdatingUI, edtTolerance, edtRecTolerance

    shortCfg  := {up: 1050, down: 1300, left: 1300, right: 1300, diag: 1050, ret: 1850}
    shortBase := {up: 1050, down: 1300, left: 1300, right: 1300, diag: 1050, ret: 1850}
    shortPct  := 100

    wideCfg  := {up: 1650, down: 1950, left: 1950, right: 1950, diag: 1650, ret: 2600}
    wideBase := {up: 1650, down: 1950, left: 1950, right: 1950, diag: 1650, ret: 2600}
    widePct  := 100

    imgTolerance := 45
    recoveryTolerance := 50
    isUpdatingUI := true
    edtTolerance.Value := imgTolerance
    edtRecTolerance.Value := recoveryTolerance
    isUpdatingUI := false

    RefreshPresetUI()
    SaveConfig()
    UpdateGuiStatus("Reset Waystone move times & tolerances to defaults.")
}

ResetTowerDefaults(*) {
    global f5RingEdgeMs, f5UpMs, f5DownMs, f5LeftMs, f5RightMs, f5DiagMs, f5Base, f5Pct

    f5RingEdgeMs := 1150
    f5UpMs       := 1750
    f5DownMs     := 1750
    f5LeftMs     := 1750
    f5RightMs    := 1750
    f5DiagMs     := 1750
    f5Base       := {ring: 1150, up: 1750, down: 1750, left: 1750, right: 1750, diag: 1750}
    f5Pct        := 100

    RefreshTowerUI()
    SaveConfig()
    UpdateGuiStatus("Reset Tower Mode defaults.")
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