; ==============================================================================
; TOWER MODE (FREE RANGE - WAYSTONE-FREE OCTAGONAL CIRCLE + FULL CROSS)
; ==============================================================================

ToggleTowerMode(*) {
    global running, freeCircleMode, chaosTestRunning, completedLoops, recoveryCount, hudStatus

    if (running) {
        StopAll("Stopped Tower Mode")
        return
    }

    if !InitVisionAndWindow(false)
        return

    ClearWaystoneOrigin()
    running := true
    freeCircleMode := true
    chaosTestRunning := false
    completedLoops := 0
    recoveryCount := 0
    hudStatus := "Tower Mode: Starting Free Range Loop..."
    UpdateGuiStatus(hudStatus)

    ActivateRunOverlay()
    SetTimer(UpdateHUD, 80)
    SetTimer(AltAntiAFK, 600000)
    SetTimer(RunFreeCircleCrossLoop, -10)
}

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