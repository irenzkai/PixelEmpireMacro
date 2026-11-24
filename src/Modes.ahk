; ==============================================================================
; FARMING MODES (WAYSTONE 8-STAR, TOWER MODE, PERIMETER CIRCLE, CHAOS TEST)
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
    global running, circleRequested, chaosTestRunning, freeCircleMode, step, completedLoops, recoveryCount, hudStatus, wideStarMode
    global mainGui, hudEnabled

    if (chaosTestRunning || freeCircleMode) {
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

        step := 0
        completedLoops := 0
        recoveryCount := 0
        circleRequested := false
        freeCircleMode := false
        modeLabel := wideStarMode ? "VERY WIDE" : "SHORT"
        hudStatus := "Waystone 8-Star (" modeLabel ") Active!"
        UpdateGuiStatus(hudStatus)

        if (hudEnabled) {
            if IsSet(mainGui)
                mainGui.Hide()
            ShowOverlay()
        }

        SetTimer(UpdateHUD, 80)
        SetTimer(AltAntiAFK, 600000)
        SetTimer(RunHomingCycle, -10)
    } else {
        StopAll("Paused manually")
    }
}

ToggleTowerMode(*) {
    global running, freeCircleMode, chaosTestRunning, completedLoops, recoveryCount, hudStatus
    global mainGui, hudEnabled

    if (running) {
        StopAll("Stopped Tower Mode")
        return
    }

    if !InitVisionAndWindow(false)
        return

    running := true
    freeCircleMode := true
    chaosTestRunning := false
    completedLoops := 0
    recoveryCount := 0
    hudStatus := "Tower Mode: Starting Free Range Loop..."
    UpdateGuiStatus(hudStatus)

    if (hudEnabled) {
        if IsSet(mainGui)
            mainGui.Hide()
        ShowOverlay()
    }

    SetTimer(UpdateHUD, 80)
    SetTimer(AltAntiAFK, 600000)
    SetTimer(RunFreeCircleCrossLoop, -10)
}

StartChaosStressTest(*) {
    global running, chaosTestRunning, freeCircleMode, recoveryCount, hudStatus
    global mainGui, hudEnabled

    if (running || chaosTestRunning) {
        StopAll("Stress Test Stopped")
        return
    }

    if !InitVisionAndWindow(true)
        return

    Sleep(80)
    if !IsOnWaystone() {
        MsgBox("Stand on the Waystone first ('Return to Town (E)' visible) so we can measure recovery back to Point 0!")
        return
    }

    running := true
    chaosTestRunning := true
    freeCircleMode := false
    recoveryCount := 0
    hudStatus := "Starting Chaos Stress Test..."

    if (hudEnabled) {
        if IsSet(mainGui)
            mainGui.Hide()
        ShowOverlay()
    }

    SetTimer(UpdateHUD, 80)
    SetTimer(RunChaosStressTest, -10)
}

QueuePerimeterCircle(*) {
    global running, chaosTestRunning, freeCircleMode, circleRequested, hudStatus
    if (!running || chaosTestRunning || freeCircleMode) {
        UpdateGuiStatus("Start Waystone 8-Star farming first before queuing Circle!")
        return
    }
    circleRequested := true
    SoundBeep(1100, 100)
    hudStatus := "Queued Wide Circle..."
    UpdateHUD()
}

; --- TOWER MODE LOOP (FREE RANGE) ---
RunFreeCircleCrossLoop() {
    global running, freeCircleMode, f5RingEdgeMs, f5UpMs, f5DownMs, f5LeftMs, f5RightMs, f5DiagMs, completedLoops, hudStatus
    if (!running || !freeCircleMode)
        return

    windows := GetSortedRobloxWindows()
    if (windows.Length = 0) {
        StopAll("Roblox window lost!")
        return
    }
    FocusWindow(windows[1])

    circleSegments := [
        {keys: ["w", "d"], dur: f5RingEdgeMs, label: "Circle 1/8: NE"},
        {keys: ["d"],      dur: f5RingEdgeMs, label: "Circle 2/8: East"},
        {keys: ["s", "d"], dur: f5RingEdgeMs, label: "Circle 3/8: SE"},
        {keys: ["s"],      dur: f5RingEdgeMs, label: "Circle 4/8: South"},
        {keys: ["s", "a"], dur: f5RingEdgeMs, label: "Circle 5/8: SW"},
        {keys: ["a"],      dur: f5RingEdgeMs, label: "Circle 6/8: West"},
        {keys: ["w", "a"], dur: f5RingEdgeMs, label: "Circle 7/8: NW"},
        {keys: ["w"],      dur: f5RingEdgeMs, label: "Circle 8/8: North"}
    ]

    for seg in circleSegments {
        if (!running || !freeCircleMode)
            return
        hudStatus := "Tower " seg.label " (" seg.dur "ms)"
        HoldKeys(seg.keys, seg.dur)
    }

    crossLegs := [
        {out: ["w", "d"], ret: ["s", "a"], dur: f5DiagMs,  label: "Cross 1/8: NE Diagonal"},
        {out: ["s", "a"], ret: ["w", "d"], dur: f5DiagMs,  label: "Cross 2/8: SW Diagonal"},
        {out: ["w", "a"], ret: ["s", "d"], dur: f5DiagMs,  label: "Cross 3/8: NW Diagonal"},
        {out: ["s", "d"], ret: ["w", "a"], dur: f5DiagMs,  label: "Cross 4/8: SE Diagonal"},
        {out: ["d"],      ret: ["a"],      dur: f5RightMs, label: "Cross 5/8: East Flank"},
        {out: ["a"],      ret: ["d"],      dur: f5LeftMs,  label: "Cross 6/8: West Flank"},
        {out: ["w"],      ret: ["s"],      dur: f5UpMs,    label: "Cross 7/8: North Flank"},
        {out: ["s"],      ret: ["w"],      dur: f5DownMs,  label: "Cross 8/8: South Flank"}
    ]

    for leg in crossLegs {
        if (!running || !freeCircleMode)
            return
        hudStatus := "Tower " leg.label " (Out)"
        HoldKeys(leg.out, leg.dur)
        if (!running || !freeCircleMode)
            return
        hudStatus := "Tower " leg.label " (Back)"
        HoldKeys(leg.ret, leg.dur)
    }

    completedLoops += 1
    if (running && freeCircleMode)
        SetTimer(RunFreeCircleCrossLoop, -30)
}

; --- WAYSTONE 8-STAR LOOP ---
RunHomingCycle() {
    global running, circleRequested, step, completedLoops, wideStarMode, shortCfg, wideCfg, hudStatus
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

    cfg := wideStarMode ? wideCfg : shortCfg
    retLimit := cfg.ret

    legs := [
        {outKeys: ["w", "d"], retKeys: ["s", "a"], dur: cfg.diag,  name: "1/8: NE Diagonal"},
        {outKeys: ["s", "a"], retKeys: ["w", "d"], dur: cfg.diag,  name: "2/8: SW Diagonal"},
        {outKeys: ["d"],      retKeys: ["a"],      dur: cfg.right, name: "3/8: East Flank"},
        {outKeys: ["a"],      retKeys: ["d"],      dur: cfg.left,  name: "4/8: West Flank"},
        {outKeys: ["w", "a"], retKeys: ["s", "d"], dur: cfg.diag,  name: "5/8: NW Diagonal"},
        {outKeys: ["s", "d"], retKeys: ["w", "a"], dur: cfg.diag,  name: "6/8: SE Diagonal"},
        {outKeys: ["w"],      retKeys: ["s"],      dur: cfg.up,    name: "7/8: North Flank"},
        {outKeys: ["s"],      retKeys: ["w"],      dur: cfg.down,  name: "8/8: South Flank"}
    ]

    step := Mod(step, legs.Length) + 1
    currentLeg := legs[step]

    hudStatus := currentLeg.name " -> Outward (" currentLeg.dur "ms)"
    HoldKeys(currentLeg.outKeys, currentLeg.dur)
    if (!running)
        return

    hudStatus := currentLeg.name " -> Homing to Waystone..."
    foundWaystone := ReturnUntilPrompt(currentLeg.retKeys, retLimit)
    if (!running)
        return

    if (!foundWaystone) {
        AntiTrapRecovery()
    }

    if (step = legs.Length && running) {
        completedLoops += 1
    }

    if (running)
        SetTimer(RunHomingCycle, -30)
}

; --- CHAOS STRESS TEST ---
RunChaosStressTest() {
    global running, chaosTestRunning, chaosAngleMs, step, completedLoops, circleRequested, hudStatus
    history := []

    chaosAngles := [
        {keys: ["w", "d"], dur: chaosAngleMs, label: "1/8 Long NE"},
        {keys: ["s", "a"], dur: chaosAngleMs, label: "2/8 Long SW"},
        {keys: ["d"],      dur: chaosAngleMs, label: "3/8 Long East"},
        {keys: ["a"],      dur: chaosAngleMs, label: "4/8 Long West"},
        {keys: ["w", "a"], dur: chaosAngleMs, label: "5/8 Long NW"},
        {keys: ["s", "d"], dur: chaosAngleMs, label: "6/8 Long SE"},
        {keys: ["w"],      dur: chaosAngleMs, label: "7/8 Long North"},
        {keys: ["s"],      dur: chaosAngleMs, label: "8/8 Long South"}
    ]

    for m in chaosAngles {
        if (!running)
            return
        hudStatus := "CHAOS OUT: " m.label
        HoldKeys(m.keys, m.dur)
        history.Push({keys: m.keys, dur: m.dur, label: m.label})
    }

    zigZags := [
        {keys: ["w", "d"], dur: 450, label: "Zig 1 (NE)"},
        {keys: ["w", "a"], dur: 450, label: "Zag 2 (NW)"},
        {keys: ["s", "d"], dur: 450, label: "Zig 3 (SE)"},
        {keys: ["s", "a"], dur: 450, label: "Zig 4 (SW)"},
        {keys: ["d"],      dur: 500, label: "Zig 5 (E)"},
        {keys: ["a"],      dur: 500, label: "Zig 6 (W)"}
    ]

    for z in zigZags {
        if (!running)
            return
        hudStatus := "ZIG-ZAG: " z.label
        HoldKeys(z.keys, z.dur)
        history.Push({keys: z.keys, dur: z.dur, label: z.label})
    }

    idx := history.Length
    while (idx >= 1) {
        if (!running)
            return
        recorded := history[idx]
        revKeys := GetOppositeKeys(recorded.keys)
        hudStatus := "REVERSE (" idx "/" history.Length "): Undoing " recorded.label
        HoldKeys(revKeys, recorded.dur)
        idx -= 1
    }

    if (!running)
        return

    if !IsOnWaystone() {
        hudStatus := "Off-Center — Engaging Anti-Trap Homing..."
        AntiTrapRecovery()
    }

    if (!running)
        return

    if IsOnWaystone() {
        SoundBeep(1200, 150)
        chaosTestRunning := false
        step := 0
        completedLoops := 0
        circleRequested := false
        hudStatus := "CHAOS PASSED! Auto-starting Waystone Farming..."
        SetTimer(AltAntiAFK, 600000)
        SetTimer(RunHomingCycle, -300)
    } else {
        SoundBeep(450, 300)
        StopAll("CHAOS FAILED — Could not locate Waystone prompt")
    }
}

; --- ONE-SHOT PERIMETER CIRCLE ---
ExecutePerimeterCircle() {
    global running, circleOutMs, circleEdgeMs, shortCfg, wideCfg, hudStatus
    hudStatus := "CIRCLE: Stepping out to outer ring..."

    HoldKeys(["w"], circleOutMs)
    if (!running)
        return

    ringMoves := [
        {keys: ["d"],      dur: circleEdgeMs,       label: "North-East Ring"},
        {keys: ["s", "d"], dur: circleEdgeMs * 1.2, label: "East Flank Ring"},
        {keys: ["s"],      dur: circleEdgeMs * 1.2, label: "South-East Ring"},
        {keys: ["s", "a"], dur: circleEdgeMs * 1.2, label: "South Flank Ring"},
        {keys: ["a"],      dur: circleEdgeMs * 1.2, label: "South-West Ring"},
        {keys: ["w", "a"], dur: circleEdgeMs * 1.2, label: "West Flank Ring"},
        {keys: ["w"],      dur: circleEdgeMs * 1.2, label: "North-West Ring"},
        {keys: ["d"],      dur: circleEdgeMs,       label: "Closing Circle"}
    ]

    for seg in ringMoves {
        if (!running)
            return
        hudStatus := "CIRCLE: " seg.label
        HoldKeys(seg.keys, Round(seg.dur))
    }

    hudStatus := "CIRCLE: Homing back to Waystone..."
    retLimit := Max(shortCfg.ret, wideCfg.ret)
    foundWaystone := ReturnUntilPrompt(["s"], retLimit)
    if (running && !foundWaystone) {
        AntiTrapRecovery()
    }
}

StopAll(reason) {
    global running, chaosTestRunning, freeCircleMode, completedLoops, mainGui
    running := false
    chaosTestRunning := false
    freeCircleMode := false
    SetTimer(RunHomingCycle, 0)
    SetTimer(RunFreeCircleCrossLoop, 0)
    SetTimer(RunChaosStressTest, 0)
    SetTimer(UpdateHUD, 0)
    SetTimer(AltAntiAFK, 0)
    ReleaseMoveKeys()
    ToolTip()
    HideOverlay()
    if IsSet(mainGui)
        mainGui.Show()
    UpdateGuiStatus("Stopped (" reason ") | Loops: " completedLoops)
}

ExitMacro(*) {
    global running, chaosTestRunning, freeCircleMode
    running := false
    chaosTestRunning := false
    freeCircleMode := false
    SetTimer(RunHomingCycle, 0)
    SetTimer(RunFreeCircleCrossLoop, 0)
    SetTimer(RunChaosStressTest, 0)
    SetTimer(UpdateHUD, 0)
    SetTimer(AltAntiAFK, 0)
    ReleaseMoveKeys()
    ToolTip()
    HideOverlay()
    ExitApp()
}