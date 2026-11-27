; ==============================================================================
; MONOCHROME BLACK & WHITE THEME ENGINE, TAB SWITCHER & CURSOR HANDLER
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
    global mainGui, darkMode, activeTab, wayCardView
    global themeCards, themeDividers, themePrimaryText, themeMutedText, themeEdits
    global themePrimaryBtns, themeSecondaryBtns, themeTabs
    global btnThemeQuick, btnCardSprites, btnCardWorldMap, radShortBtn, radWideBtn, btnSetDark, btnSetLight, wideStarMode

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

    if IsSet(btnCardSprites) && IsSet(btnCardWorldMap) {
        StyleButton(btnCardSprites,  (wayCardView = "SPRITES")  ? p.priBg : p.secBg, (wayCardView = "SPRITES")  ? p.priText : p.secText, (wayCardView = "SPRITES")  ? p.priBorder : p.secBorder)
        StyleButton(btnCardWorldMap, (wayCardView = "WORLDMAP") ? p.priBg : p.secBg, (wayCardView = "WORLDMAP") ? p.priText : p.secText, (wayCardView = "WORLDMAP") ? p.priBorder : p.secBorder)
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
    if (tabKey = "WAYSTONE")
        ApplyWayCardViewVisibility()
    ApplyTheme()
    RefreshMainPreviews()
}

SwitchWayCardView(viewName) {
    global wayCardView, activeTab
    wayCardView := viewName
    if (activeTab = "WAYSTONE")
        ApplyWayCardViewVisibility()
    RefreshImageStatus()
    ApplyTheme()
    RefreshMainPreviews()
}

ApplyWayCardViewVisibility() {
    global wayCardView, wayCardSubControls
    for subKey, ctrls in wayCardSubControls {
        vis := (subKey = wayCardView)
        for c in ctrls
            c.Visible := vis
    }
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

HandleSetCursor(wParam, lParam, msg, hwnd) {
    global clickableHwnds
    static hHand := DllCall("LoadCursor", "ptr", 0, "ptr", 32649, "ptr")
    if IsSet(clickableHwnds) && clickableHwnds.Has(wParam) {
        DllCall("SetCursor", "ptr", hHand)
        return true
    }
}