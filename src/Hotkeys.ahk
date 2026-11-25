; ==============================================================================
; DYNAMIC HOTKEY REGISTRATION & CLICK-TO-BIND SWITCHER
; ==============================================================================

ApplyHotkeys() {
    global hotkeys, hotkeysEnabled, registeredHotkeys

    for hk in registeredHotkeys {
        try Hotkey(hk, "Off")
    }
    registeredHotkeys := []

    if (!hotkeysEnabled) {
        RefreshHotkeyLabels()
        return
    }

    bindings := [
        {key: hotkeys.waystone, fn: ToggleWaystoneMode},
        {key: hotkeys.tower,    fn: ToggleTowerMode},
        {key: hotkeys.mapCycle, fn: ToggleMapCycleMode},
        {key: hotkeys.preset,   fn: ToggleShortWidePreset},
        {key: hotkeys.circle,   fn: QueuePerimeterCircle},
        {key: hotkeys.chaos,    fn: StartChaosStressTest},
        {key: hotkeys.exit,     fn: ExitMacro}
    ]

    for b in bindings {
        if (b.key != "") {
            try {
                Hotkey(b.key, b.fn, "On")
                registeredHotkeys.Push(b.key)
            }
        }
    }

    RefreshHotkeyLabels()
}

ToggleHotkeysEnabled(*) {
    global hotkeysEnabled
    hotkeysEnabled := !hotkeysEnabled
    ApplyHotkeys()
    SaveConfig()
    RefreshSettingsTabUI()
    UpdateGuiStatus(hotkeysEnabled ? "Hotkeys Enabled" : "Hotkeys Suspended (OFF)")
}

ResetDefaultHotkeys(*) {
    global hotkeys
    hotkeys := {
        waystone: "F8",
        tower:    "F5",
        mapCycle: "F4",
        preset:   "F6",
        circle:   "F9",
        chaos:    "F7",
        exit:     "Esc"
    }
    ApplyHotkeys()
    SaveConfig()
    RefreshSettingsTabUI()
    UpdateGuiStatus("Hotkeys reset to defaults.")
}

RebindHotkey(actionName) {
    global isBindingHotkey, hotkeys, registeredHotkeys, hkBadges, mainGui

    if (isBindingHotkey)
        return

    isBindingHotkey := true

    for hk in registeredHotkeys {
        try Hotkey(hk, "Off")
    }

    if hkBadges.Has(actionName)
        hkBadges[actionName].Text := "PRESS KEY..."
    UpdateGuiStatus("Listening for new key (5s timeout)...")

    ih := InputHook("I")
    ih.VisibleNonText := false
    ih.KeyOpt("{All}", "E")
    ih.KeyOpt("{LCtrl}{RCtrl}{LShift}{RShift}{LAlt}{RAlt}{LWin}{RWin}", "-E")
    ih.Start()
    reason := ih.Wait(5)

    if (reason = "EndKey" && ih.EndKey != "") {
        mods := ""
        if GetKeyState("Ctrl", "P")
            mods .= "^"
        if GetKeyState("Shift", "P")
            mods .= "+"
        if GetKeyState("Alt", "P")
            mods .= "!"

        newKey := mods . NormalizeKeyName(ih.EndKey)
        conflict := FindHotkeyConflict(actionName, newKey)
        if (conflict != "") {
            mainGui.Opt("+OwnDialogs")
            MsgBox("'" FormatHotkeyShort(newKey) "' is already bound to '" conflict "'!`nPlease choose another key.", "Hotkey Conflict", "Icon!")
        } else {
            hotkeys.%actionName% := newKey
            SaveConfig()
            UpdateGuiStatus("Rebound " actionName " -> " FormatHotkeyShort(newKey))
        }
    } else {
        UpdateGuiStatus("Hotkey rebind cancelled / timed out.")
    }

    isBindingHotkey := false
    ApplyHotkeys()
    RefreshSettingsTabUI()
}

FindHotkeyConflict(targetAction, candidateKey) {
    global hotkeys
    labels := Map(
        "waystone", "Waystone 8-Star",
        "tower",    "Tower Mode",
        "mapCycle", "Map Cycle",
        "preset",   "Short / Wide",
        "circle",   "Queue Circle",
        "chaos",    "Chaos Test",
        "exit",     "Stop & Exit"
    )
    for act, label in labels {
        if (act != targetAction && StrLower(hotkeys.%act%) = StrLower(candidateKey))
            return label
    }
    return ""
}

NormalizeKeyName(k) {
    if (k = "Escape")
        return "Esc"
    if (StrLen(k) = 1)
        return StrLower(k)
    return k
}

FormatHotkeyShort(hk) {
    global hotkeysEnabled
    if (!hotkeysEnabled)
        return "OFF"
    if (hk = "")
        return "NONE"
    out := hk
    out := StrReplace(out, "^", "Ctrl+")
    out := StrReplace(out, "+", "Shift+")
    out := StrReplace(out, "!", "Alt+")
    if (StrLen(out) = 1)
        out := StrUpper(out)
    return out
}

FormatHotkeyRaw(hk) {
    if (hk = "")
        return "NONE"
    out := hk
    out := StrReplace(out, "^", "Ctrl+")
    out := StrReplace(out, "+", "Shift+")
    out := StrReplace(out, "!", "Alt+")
    if (StrLen(out) = 1)
        out := StrUpper(out)
    return out
}