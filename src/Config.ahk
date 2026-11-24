; ==============================================================================
; CONFIGURATION (INI LOAD / SAVE & VALIDATION)
; ==============================================================================

LoadConfig() {
    global iniFile, promptImg, imgTolerance, wideStarMode, shortCfg, wideCfg
    global f5RingEdgeMs, f5UpMs, f5DownMs, f5LeftMs, f5RightMs, f5DiagMs
    global darkMode, hudEnabled, hotkeysEnabled, hotkeys

    if !FileExist(iniFile)
        return

    savedImg := IniRead(iniFile, "General", "PromptImg", promptImg)
    if (savedImg != "")
        promptImg := savedImg

    imgTolerance := ParseSetting(IniRead(iniFile, "General", "ImgTolerance", imgTolerance), imgTolerance, 0, 255)
    wideStarMode := (IniRead(iniFile, "General", "WideStarMode", wideStarMode ? "1" : "0") = "1")

    darkMode       := (IniRead(iniFile, "Appearance", "DarkMode", darkMode ? "1" : "0") = "1")
    hudEnabled     := (IniRead(iniFile, "Appearance", "HudEnabled", hudEnabled ? "1" : "0") = "1")
    hotkeysEnabled := (IniRead(iniFile, "Hotkeys", "Enabled", hotkeysEnabled ? "1" : "0") = "1")

    hotkeys.waystone := IniRead(iniFile, "Hotkeys", "Waystone", hotkeys.waystone)
    hotkeys.tower    := IniRead(iniFile, "Hotkeys", "Tower", hotkeys.tower)
    hotkeys.preset   := IniRead(iniFile, "Hotkeys", "Preset", hotkeys.preset)
    hotkeys.circle   := IniRead(iniFile, "Hotkeys", "Circle", hotkeys.circle)
    hotkeys.chaos    := IniRead(iniFile, "Hotkeys", "Chaos", hotkeys.chaos)
    hotkeys.exit     := IniRead(iniFile, "Hotkeys", "Exit", hotkeys.exit)

    shortCfg.up    := ParseSetting(IniRead(iniFile, "ShortPreset", "Up", shortCfg.up), shortCfg.up)
    shortCfg.down  := ParseSetting(IniRead(iniFile, "ShortPreset", "Down", shortCfg.down), shortCfg.down)
    shortCfg.left  := ParseSetting(IniRead(iniFile, "ShortPreset", "Left", shortCfg.left), shortCfg.left)
    shortCfg.right := ParseSetting(IniRead(iniFile, "ShortPreset", "Right", shortCfg.right), shortCfg.right)
    shortCfg.diag  := ParseSetting(IniRead(iniFile, "ShortPreset", "Diag", shortCfg.diag), shortCfg.diag)
    shortCfg.ret   := ParseSetting(IniRead(iniFile, "ShortPreset", "Ret", shortCfg.ret), shortCfg.ret, 100, 60000)

    wideCfg.up     := ParseSetting(IniRead(iniFile, "WidePreset", "Up", wideCfg.up), wideCfg.up)
    wideCfg.down   := ParseSetting(IniRead(iniFile, "WidePreset", "Down", wideCfg.down), wideCfg.down)
    wideCfg.left   := ParseSetting(IniRead(iniFile, "WidePreset", "Left", wideCfg.left), wideCfg.left)
    wideCfg.right  := ParseSetting(IniRead(iniFile, "WidePreset", "Right", wideCfg.right), wideCfg.right)
    wideCfg.diag   := ParseSetting(IniRead(iniFile, "WidePreset", "Diag", wideCfg.diag), wideCfg.diag)
    wideCfg.ret    := ParseSetting(IniRead(iniFile, "WidePreset", "Ret", wideCfg.ret), wideCfg.ret, 100, 60000)

    f5RingEdgeMs := ParseSetting(IniRead(iniFile, "TowerMode", "RingEdge", f5RingEdgeMs), f5RingEdgeMs)
    f5UpMs       := ParseSetting(IniRead(iniFile, "TowerMode", "Up", f5UpMs), f5UpMs)
    f5DownMs     := ParseSetting(IniRead(iniFile, "TowerMode", "Down", f5DownMs), f5DownMs)
    f5LeftMs     := ParseSetting(IniRead(iniFile, "TowerMode", "Left", f5LeftMs), f5LeftMs)
    f5RightMs    := ParseSetting(IniRead(iniFile, "TowerMode", "Right", f5RightMs), f5RightMs)
    f5DiagMs     := ParseSetting(IniRead(iniFile, "TowerMode", "Diag", f5DiagMs), f5DiagMs)
}

SaveConfig() {
    global iniFile, promptImg, imgTolerance, wideStarMode, shortCfg, wideCfg
    global f5RingEdgeMs, f5UpMs, f5DownMs, f5LeftMs, f5RightMs, f5DiagMs
    global darkMode, hudEnabled, hotkeysEnabled, hotkeys

    IniWrite(promptImg, iniFile, "General", "PromptImg")
    IniWrite(imgTolerance, iniFile, "General", "ImgTolerance")
    IniWrite(wideStarMode ? "1" : "0", iniFile, "General", "WideStarMode")

    IniWrite(darkMode ? "1" : "0", iniFile, "Appearance", "DarkMode")
    IniWrite(hudEnabled ? "1" : "0", iniFile, "Appearance", "HudEnabled")

    IniWrite(hotkeysEnabled ? "1" : "0", iniFile, "Hotkeys", "Enabled")
    IniWrite(hotkeys.waystone, iniFile, "Hotkeys", "Waystone")
    IniWrite(hotkeys.tower, iniFile, "Hotkeys", "Tower")
    IniWrite(hotkeys.preset, iniFile, "Hotkeys", "Preset")
    IniWrite(hotkeys.circle, iniFile, "Hotkeys", "Circle")
    IniWrite(hotkeys.chaos, iniFile, "Hotkeys", "Chaos")
    IniWrite(hotkeys.exit, iniFile, "Hotkeys", "Exit")

    IniWrite(shortCfg.up, iniFile, "ShortPreset", "Up")
    IniWrite(shortCfg.down, iniFile, "ShortPreset", "Down")
    IniWrite(shortCfg.left, iniFile, "ShortPreset", "Left")
    IniWrite(shortCfg.right, iniFile, "ShortPreset", "Right")
    IniWrite(shortCfg.diag, iniFile, "ShortPreset", "Diag")
    IniWrite(shortCfg.ret, iniFile, "ShortPreset", "Ret")

    IniWrite(wideCfg.up, iniFile, "WidePreset", "Up")
    IniWrite(wideCfg.down, iniFile, "WidePreset", "Down")
    IniWrite(wideCfg.left, iniFile, "WidePreset", "Left")
    IniWrite(wideCfg.right, iniFile, "WidePreset", "Right")
    IniWrite(wideCfg.diag, iniFile, "WidePreset", "Diag")
    IniWrite(wideCfg.ret, iniFile, "WidePreset", "Ret")

    IniWrite(f5RingEdgeMs, iniFile, "TowerMode", "RingEdge")
    IniWrite(f5UpMs, iniFile, "TowerMode", "Up")
    IniWrite(f5DownMs, iniFile, "TowerMode", "Down")
    IniWrite(f5LeftMs, iniFile, "TowerMode", "Left")
    IniWrite(f5RightMs, iniFile, "TowerMode", "Right")
    IniWrite(f5DiagMs, iniFile, "TowerMode", "Diag")
}

ParseSetting(rawVal, fallback, minVal := 50, maxVal := 30000) {
    cleaned := Trim(rawVal)
    if (cleaned != "" && IsInteger(cleaned)) {
        num := Integer(cleaned)
        if (num >= minVal && num <= maxVal)
            return num
    }
    return fallback
}