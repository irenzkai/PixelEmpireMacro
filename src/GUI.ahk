; ==============================================================================
; BLACK & WHITE GUI (DARK / LIGHT MODE, SETTINGS, HOTKEY SWITCH, CREDITS)
; ==============================================================================

BuildGUI() {
    global mainGui, activeTab, pageControls, clickableHwnds
    global themeCards, themeDividers, themePrimaryText, themeMutedText, themeEdits
    global themePrimaryBtns, themeSecondaryBtns, themeTabs
    global btnThemeQuick, tabMacro, tabSettings, tabCredits
    global edtPromptPath, edtTolerance, txtImgStatus
    global radShortBtn, radWideBtn, edtWayUp, edtWayDown, edtWayLeft, edtWayRight, edtWayDiag, edtWayRet
    global edtF5Ring, edtF5Up, edtF5Down, edtF5Left, edtF5Right, edtF5Diag
    global btnActWaystone, btnActTower, btnActPreset, btnActCircle, btnActChaos, btnActExit
    global btnSetDark, btnSetLight, btnSetHud, btnSetKeysToggle, hkBadges
    global txtGuiStatus, promptImg, imgTolerance
    global f5RingEdgeMs, f5UpMs, f5DownMs, f5LeftMs, f5RightMs, f5DiagMs

    pageControls := Map("MACRO", [], "SETTINGS", [], "CREDITS", [])
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

    lblSub := mainGui.AddText("x16 y34 w260 h14 +0x80 +0x04000000", "WAYSTONE & TOWER AUTOMATION")
    lblSub.SetFont("s7 Bold", "Segoe UI")
    themeMutedText.Push({ctrl: lblSub, onCard: false})

    btnThemeQuick := AddFlatButton(346, 16, 98, 26, "", false, (*) => ToggleDarkMode())

    ; --- NAVIGATION TABS ---
    tabMacro    := AddTabButton("MACRO",    16,  56, 138, 28, "MACRO")
    tabSettings := AddTabButton("SETTINGS", 160, 56, 138, 28, "SETTINGS")
    tabCredits  := AddTabButton("CREDITS",  304, 56, 140, 28, "CREDITS")

    AddDivider(16, 92, 428)

    ; ==========================================================================
    ; TAB 1: MACRO
    ; ==========================================================================
    AddCard("MACRO", 16, 102, 428, 90)
    AddCardTitle("MACRO", 28, 110, 230, "WAYSTONE PROMPT IMAGE")
    txtImgStatus := mainGui.AddText("x340 y110 w92 h16 Right +0x80 +0x04000000", "")
    txtImgStatus.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtImgStatus, onCard: true})
    pageControls["MACRO"].Push(txtImgStatus)

    edtPromptPath := AddStyledEdit("MACRO", 28, 131, 318, 22, promptImg, "ReadOnly")
    AddFlatButton(352, 131, 80, 22, "Import...", false, ImportPromptImage, "MACRO")

    AddMutedLabel("MACRO", 28, 162, 62, "Tolerance:")
    edtTolerance := AddStyledEdit("MACRO", 92, 160, 48, 22, imgTolerance, "Number")
    edtTolerance.OnEvent("Change", OnSettingsChanged)

    AddFlatButton(148, 160, 116, 22, "Test Waystone", false, TestWaystoneDetection, "MACRO")
    AddMutedLabel("MACRO", 272, 162, 160, "Return to Town (E)", "Right")

    ; --- F8 WAYSTONE 8-STAR CARD ---
    AddCard("MACRO", 16, 200, 428, 128)
    AddCardTitle("MACRO", 28, 208, 204, "WAYSTONE 8-STAR TIMES (MS)")

    radShortBtn := AddFlatButton(242, 206, 66, 20, "SHORT", false, (*) => SelectWaystonePreset(false), "MACRO")
    radWideBtn  := AddFlatButton(312, 206, 74, 20, "VERY WIDE", false, (*) => SelectWaystonePreset(true), "MACRO")
    AddFlatButton(390, 206, 42, 20, "RST", false, ResetPresetDefaults, "MACRO")

    AddMutedLabel("MACRO", 28, 239, 52, "Up (W):")
    edtWayUp := AddStyledEdit("MACRO", 82, 236, 56, 22, "", "Number")
    AddMutedLabel("MACRO", 154, 239, 56, "Down (S):")
    edtWayDown := AddStyledEdit("MACRO", 212, 236, 56, 22, "", "Number")
    AddMutedLabel("MACRO", 284, 239, 56, "Diagonal:")
    edtWayDiag := AddStyledEdit("MACRO", 342, 236, 90, 22, "", "Number")

    AddMutedLabel("MACRO", 28, 269, 52, "Left (A):")
    edtWayLeft := AddStyledEdit("MACRO", 82, 266, 56, 22, "", "Number")
    AddMutedLabel("MACRO", 154, 269, 56, "Right (D):")
    edtWayRight := AddStyledEdit("MACRO", 212, 266, 56, 22, "", "Number")
    AddMutedLabel("MACRO", 284, 269, 56, "Ret Max:")
    edtWayRet := AddStyledEdit("MACRO", 342, 266, 90, 22, "", "Number")

    for ctrl in [edtWayUp, edtWayDown, edtWayLeft, edtWayRight, edtWayDiag, edtWayRet]
        ctrl.OnEvent("Change", OnSettingsChanged)

    AddMutedLabel("MACRO", 28, 298, 404, "Increase ms to travel farther. Toggle Short / Very Wide anytime.")

    ; --- F5 TOWER MODE CARD ---
    AddCard("MACRO", 16, 336, 428, 98)
    AddCardTitle("MACRO", 28, 344, 390, "TOWER MODE / FREE RANGE TIMES (MS)")

    AddMutedLabel("MACRO", 28, 371, 58, "Ring Edge:")
    edtF5Ring := AddStyledEdit("MACRO", 88, 368, 54, 22, f5RingEdgeMs, "Number")
    AddMutedLabel("MACRO", 156, 371, 50, "Up (W):")
    edtF5Up := AddStyledEdit("MACRO", 208, 368, 56, 22, f5UpMs, "Number")
    AddMutedLabel("MACRO", 280, 371, 58, "Down (S):")
    edtF5Down := AddStyledEdit("MACRO", 340, 368, 92, 22, f5DownMs, "Number")

    AddMutedLabel("MACRO", 28, 401, 58, "Left (A):")
    edtF5Left := AddStyledEdit("MACRO", 88, 398, 54, 22, f5LeftMs, "Number")
    AddMutedLabel("MACRO", 156, 401, 52, "Right (D):")
    edtF5Right := AddStyledEdit("MACRO", 208, 398, 56, 22, f5RightMs, "Number")
    AddMutedLabel("MACRO", 280, 401, 58, "Diagonal:")
    edtF5Diag := AddStyledEdit("MACRO", 340, 398, 92, 22, f5DiagMs, "Number")

    for ctrl in [edtF5Ring, edtF5Up, edtF5Down, edtF5Left, edtF5Right, edtF5Diag]
        ctrl.OnEvent("Change", OnSettingsChanged)

    ; --- QUICK ACTIONS CARD ---
    AddCard("MACRO", 16, 442, 428, 102)
    AddCardTitle("MACRO", 28, 450, 390, "QUICK ACTIONS")

    btnActWaystone := AddFlatButton(28,  472, 198, 30, "", true,  ToggleWaystoneMode, "MACRO")
    btnActTower    := AddFlatButton(234, 472, 198, 30, "", false, ToggleTowerMode,    "MACRO")

    btnActPreset := AddFlatButton(28,  508, 96, 26, "", false, ToggleShortWidePreset, "MACRO")
    btnActCircle := AddFlatButton(130, 508, 96, 26, "", false, QueuePerimeterCircle,  "MACRO")
    btnActChaos  := AddFlatButton(232, 508, 96, 26, "", false, StartChaosStressTest,  "MACRO")
    btnActExit   := AddFlatButton(334, 508, 98, 26, "", false, ExitMacro,             "MACRO")

    ; ==========================================================================
    ; TAB 2: SETTINGS (LIGHT/DARK MODE & HOTKEY SWITCH)
    ; ==========================================================================
    AddCard("SETTINGS", 16, 102, 428, 110)
    AddCardTitle("SETTINGS", 28, 112, 390, "APPEARANCE & DISPLAY")

    AddPrimaryLabel("SETTINGS", 28, 140, 180, "Interface Theme")
    btnSetDark  := AddFlatButton(236, 136, 96, 26, "DARK MODE",  false, (*) => SetDarkMode(true),  "SETTINGS")
    btnSetLight := AddFlatButton(336, 136, 96, 26, "LIGHT MODE", false, (*) => SetDarkMode(false), "SETTINGS")

    AddPrimaryLabel("SETTINGS", 28, 176, 210, "Floating HUD ToolTip")
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
    ; TAB 3: CREDITS (DEV / CONTRIBUTOR AREA)
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
    AddMutedLabel("CREDITS", 28, 412, 404, "Modules: State · Config · VisionWindow · Movement · Modes · Hotkeys · GUI")

    ; --- PERSISTENT FOOTER ---
    AddDivider(16, 554, 428)
    txtGuiStatus := mainGui.AddText("x16 y562 w428 h20 +0x80 +0x04000000", "● Ready")
    txtGuiStatus.SetFont("s8 Bold", "Segoe UI")
    themeMutedText.Push({ctrl: txtGuiStatus, onCard: false})

    mainGui.OnEvent("Close", (*) => ExitMacro())
    OnMessage(0x0020, HandleSetCursor)

    RefreshPresetUI()
    RefreshImageStatus()
    RefreshHotkeyLabels()
    RefreshSettingsTabUI()
    SwitchTab("MACRO")

    mainGui.Show("w460 h590")
    ; Clear default blue highlight on read-only path Edit & scroll to filename
    SendMessage(0x00B1, 999, 999, edtPromptPath.Hwnd)
    ApplyTheme()
}

; ==============================================================================
; CUSTOM BLACK & WHITE COMPONENT BUILDERS (NON-OVERLAPPING BORDERS)
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

    ; Native Windows 10/11 Dark/Light Title Bar
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", mainGui.Hwnd, "int", 20, "int*", darkMode ? 1 : 0, "int", 4)

    for c in themeCards {
        for e in c.edges
            e.Opt("+Background" SubStr(p.border, 3))
        c.fill.Opt("+Background" SubStr(p.cardBg, 3))
        ; Push card background strictly behind all labels/edits/buttons
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
        ToolTip()
    SaveConfig()
    RefreshSettingsTabUI()
    UpdateGuiStatus(hudEnabled ? "Floating HUD Enabled" : "Floating HUD Disabled")
}

; ==============================================================================
; UI REFRESH & EVENT HANDLERS
; ==============================================================================

RefreshPresetUI() {
    global isUpdatingUI, wideStarMode, shortCfg, wideCfg
    global edtWayUp, edtWayDown, edtWayLeft, edtWayRight, edtWayDiag, edtWayRet

    if !IsSet(edtWayUp)
        return

    isUpdatingUI := true
    cfg := wideStarMode ? wideCfg : shortCfg
    edtWayUp.Value    := cfg.up
    edtWayDown.Value  := cfg.down
    edtWayLeft.Value  := cfg.left
    edtWayRight.Value := cfg.right
    edtWayDiag.Value  := cfg.diag
    edtWayRet.Value   := cfg.ret
    isUpdatingUI := false

    ApplyTheme()
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
    if !IsSet(btnActWaystone)
        return

    btnActWaystone.btn.Text := "Waystone 8-Star [" FormatHotkeyShort(hotkeys.waystone) "]"
    btnActTower.btn.Text    := "Tower Mode [" FormatHotkeyShort(hotkeys.tower) "]"
    btnActPreset.btn.Text   := "Preset [" FormatHotkeyShort(hotkeys.preset) "]"
    btnActCircle.btn.Text   := "Circle [" FormatHotkeyShort(hotkeys.circle) "]"
    btnActChaos.btn.Text    := "Chaos [" FormatHotkeyShort(hotkeys.chaos) "]"
    btnActExit.btn.Text     := "Exit [" FormatHotkeyShort(hotkeys.exit) "]"
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
    global isUpdatingUI, wideStarMode, shortCfg, wideCfg, imgTolerance
    global edtTolerance, edtWayUp, edtWayDown, edtWayLeft, edtWayRight, edtWayDiag, edtWayRet
    global f5RingEdgeMs, f5UpMs, f5DownMs, f5LeftMs, f5RightMs, f5DiagMs
    global edtF5Ring, edtF5Up, edtF5Down, edtF5Left, edtF5Right, edtF5Diag

    if (isUpdatingUI)
        return

    imgTolerance := ParseSetting(edtTolerance.Value, imgTolerance, 0, 255)

    cfg := wideStarMode ? wideCfg : shortCfg
    cfg.up    := ParseSetting(edtWayUp.Value, cfg.up, 50, 30000)
    cfg.down  := ParseSetting(edtWayDown.Value, cfg.down, 50, 30000)
    cfg.left  := ParseSetting(edtWayLeft.Value, cfg.left, 50, 30000)
    cfg.right := ParseSetting(edtWayRight.Value, cfg.right, 50, 30000)
    cfg.diag  := ParseSetting(edtWayDiag.Value, cfg.diag, 50, 30000)
    cfg.ret   := ParseSetting(edtWayRet.Value, cfg.ret, 100, 60000)

    f5RingEdgeMs := ParseSetting(edtF5Ring.Value, f5RingEdgeMs, 50, 30000)
    f5UpMs       := ParseSetting(edtF5Up.Value, f5UpMs, 50, 30000)
    f5DownMs     := ParseSetting(edtF5Down.Value, f5DownMs, 50, 30000)
    f5LeftMs     := ParseSetting(edtF5Left.Value, f5LeftMs, 50, 30000)
    f5RightMs    := ParseSetting(edtF5Right.Value, f5RightMs, 50, 30000)
    f5DiagMs     := ParseSetting(edtF5Diag.Value, f5DiagMs, 50, 30000)

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
    global shortCfg, wideCfg, f5RingEdgeMs, f5UpMs, f5DownMs, f5LeftMs, f5RightMs, f5DiagMs, imgTolerance
    global isUpdatingUI, edtTolerance, edtF5Ring, edtF5Up, edtF5Down, edtF5Left, edtF5Right, edtF5Diag

    shortCfg := {up: 1050, down: 1300, left: 1300, right: 1300, diag: 1050, ret: 1850}
    wideCfg  := {up: 1650, down: 1950, left: 1950, right: 1950, diag: 1650, ret: 2600}

    f5RingEdgeMs := 1150
    f5UpMs       := 1750
    f5DownMs     := 1750
    f5LeftMs     := 1750
    f5RightMs    := 1750
    f5DiagMs     := 1750
    imgTolerance := 45

    RefreshPresetUI()

    isUpdatingUI := true
    edtTolerance.Value := imgTolerance
    edtF5Ring.Value    := f5RingEdgeMs
    edtF5Up.Value      := f5UpMs
    edtF5Down.Value    := f5DownMs
    edtF5Left.Value    := f5LeftMs
    edtF5Right.Value   := f5RightMs
    edtF5Diag.Value    := f5DiagMs
    isUpdatingUI := false

    SaveConfig()
    UpdateGuiStatus("Reset move times to defaults.")
}

UpdateGuiStatus(msg) {
    global txtGuiStatus
    if IsSet(txtGuiStatus)
        try txtGuiStatus.Text := "● " msg
}

UpdateHUD() {
    global running, chaosTestRunning, freeCircleMode, wideStarMode, completedLoops, recoveryCount, hudStatus, hudEnabled, hotkeys
    if (!running)
        return

    if (chaosTestRunning) {
        if (hudEnabled)
            ToolTip("CHAOS STRESS TEST`nStatus: " hudStatus "`n" FormatHotkeyShort(hotkeys.chaos) " or " FormatHotkeyShort(hotkeys.exit) ": Abort", 20, 20)
        UpdateGuiStatus(hudStatus)
        return
    }

    winCount := GetSortedRobloxWindows().Length
    altInfo := (winCount > 1) ? " | Alts: " (winCount - 1) : ""

    if (freeCircleMode) {
        if (hudEnabled)
            ToolTip("TOWER MODE (FREE RANGE) | Cycles: " completedLoops altInfo "`nStatus: " hudStatus "`n" FormatHotkeyShort(hotkeys.tower) ": Stop | " FormatHotkeyShort(hotkeys.exit) ": Exit", 20, 20)
        UpdateGuiStatus("Tower Mode (" completedLoops " cycles) - " hudStatus)
        return
    }

    stripTag := wideStarMode ? "VERY WIDE" : "SHORT"
    if (hudEnabled)
        ToolTip("WAYSTONE 8-STAR [" stripTag "] | Loops: " completedLoops " | Recoveries: " recoveryCount altInfo "`nStatus: " hudStatus "`n" FormatHotkeyShort(hotkeys.preset) ": Short/Wide | " FormatHotkeyShort(hotkeys.circle) ": Circle | " FormatHotkeyShort(hotkeys.exit) ": Exit", 20, 20)
    UpdateGuiStatus("[" stripTag "] Loops: " completedLoops " - " hudStatus)
}