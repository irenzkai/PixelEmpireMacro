; ==============================================================================
; WAYSTONE 8-STAR MODE & SHORT / VERY WIDE PRESET TOGGLE
; ==============================================================================

ToggleShortWidePreset(*) {
    global wideStarMode, hudStatus, running, shortCfg, wideCfg
    wideStarMode := !wideStarMode
    RefreshPresetUI()
    SaveConfig()
    cfg := wideStarMode ? wideCfg : shortCfg
    modeName := (wideStarMode ? "VERY WIDE" : "SHORT") " (" cfg.up "/" cfg.diag "ms)"
    SoundBeep(wideStarMode ? 1200 : 850, 100)
    if (running) {
        hudStatus := "Switched 8-Star Strip Mode -> " modeName
        UpdateHUD()
    } else {
        UpdateGuiStatus("Preset: " modeName)
    }
}

ToggleWaystoneMode(*) {
    global running, circleRequested, chaosTestRunning, freeCircleMode, mapCycleMode, step, completedLoops, recoveryCount, hudStatus, wideStarMode

    if (chaosTestRunning || freeCircleMode || mapCycleMode) {
        StopAll("Switched / Stopped")
        return
    }

    running := !running
    if (running) {
        if !InitVisionAndWindow(true) {
            running := false
            return
        }
        Sleep(80)
        if !IsOnWaystone() {
            running := false
            MsgBox("Stand on the Waystone first so 'Return to Town (E)' (or your imported prompt) is visible on screen!")
            return
        }

        MarkWaystoneOrigin()
        step := 0
        completedLoops := 0
        recoveryCount := 0
        circleRequested := false
        freeCircleMode := false
        mapCycleMode := false
        modeLabel := wideStarMode ? "VERY WIDE" : "SHORT"
        hudStatus := "Waystone 8-Star (" modeLabel ") Active!"
        UpdateGuiStatus(hudStatus)

        ActivateRunOverlay()
        SetTimer(UpdateHUD, 80)
        SetTimer(AltAntiAFK, 600000)
        SetTimer(RunHomingCycle, -10)
    } else {
        StopAll("Paused manually")
    }
}

GetWaystoneStarLegs() {
    global wideStarMode, shortCfg, wideCfg
    cfg := wideStarMode ? wideCfg : shortCfg
    return [
        {outKeys: ["w", "d"], retKeys: ["s", "a"], dur: cfg.diag,  name: "1/8: NE Diagonal"},
        {outKeys: ["s", "a"], retKeys: ["w", "d"], dur: cfg.diag,  name: "2/8: SW Diagonal"},
        {outKeys: ["d"],      retKeys: ["a"],      dur: cfg.right, name: "3/8: East Flank"},
        {outKeys: ["a"],      retKeys: ["d"],      dur: cfg.left,  name: "4/8: West Flank"},
        {outKeys: ["w", "a"], retKeys: ["s", "d"], dur: cfg.diag,  name: "5/8: NW Diagonal"},
        {outKeys: ["s", "d"], retKeys: ["w", "a"], dur: cfg.diag,  name: "6/8: SE Diagonal"},
        {outKeys: ["w"],      retKeys: ["s"],      dur: cfg.up,    name: "7/8: North Flank"},
        {outKeys: ["s"],      retKeys: ["w"],      dur: cfg.down,  name: "8/8: South Flank"}
    ]
}

ExecuteSingleWaystoneLeg(legIdx, prefix := "") {
    global running, wideStarMode, shortCfg, wideCfg, hudStatus
    cfg := wideStarMode ? wideCfg : shortCfg
    legs := GetWaystoneStarLegs()
    currentLeg := legs[legIdx]

    hudStatus := prefix currentLeg.name " -> Outward (" currentLeg.dur "ms)"
    HoldKeys(currentLeg.outKeys, currentLeg.dur)
    if (!running)
        return false

    hudStatus := prefix currentLeg.name " -> Homing to Waystone..."
    foundWaystone := ReturnUntilPrompt(currentLeg.retKeys, cfg.ret)
    if (!running)
        return false

    if (!foundWaystone)
        AntiTrapRecovery(currentLeg.retKeys)

    return true
}

RunHomingCycle() {
    global running, circleRequested, step, completedLoops
    if (!running)
        return

    windows := GetSortedRobloxWindows()
    if (windows.Length = 0) {
        StopAll("Roblox window lost!")
        return
    }
    FocusWindow(windows[1])

    if (circleRequested) {
        circleRequested := false
        ExecutePerimeterCircle()
        if (running)
            SetTimer(RunHomingCycle, -30)
        return
    }

    step := Mod(step, 8) + 1
    if (!ExecuteSingleWaystoneLeg(step))
        return

    if (step = 8 && running)
        completedLoops += 1

    if (running)
        SetTimer(RunHomingCycle, -30)
}