; ==============================================================================
; CHAOS STRESS TEST (VERIFIES RECOVERY BACK TO WAYSTONE -> AUTO-STARTS F8)
; ==============================================================================

StartChaosStressTest(*) {
    global running, chaosTestRunning, freeCircleMode, recoveryCount, hudStatus

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

    ActivateRunOverlay()
    SetTimer(UpdateHUD, 80)
    SetTimer(RunChaosStressTest, -10)
}

RunChaosStressTest() {
    global running, chaosTestRunning, chaosCfg, step, completedLoops, circleRequested, hudStatus
    history := []

    chaosAngles := [
        {keys: ["w", "d"], dur: chaosCfg.angle, label: "1/8 Long NE"},
        {keys: ["s", "a"], dur: chaosCfg.angle, label: "2/8 Long SW"},
        {keys: ["d"],      dur: chaosCfg.angle, label: "3/8 Long East"},
        {keys: ["a"],      dur: chaosCfg.angle, label: "4/8 Long West"},
        {keys: ["w", "a"], dur: chaosCfg.angle, label: "5/8 Long NW"},
        {keys: ["s", "d"], dur: chaosCfg.angle, label: "6/8 Long SE"},
        {keys: ["w"],      dur: chaosCfg.angle, label: "7/8 Long North"},
        {keys: ["s"],      dur: chaosCfg.angle, label: "8/8 Long South"}
    ]

    for m in chaosAngles {
        if (!running)
            return
        hudStatus := "CHAOS OUT: " m.label
        HoldKeys(m.keys, m.dur)
        history.Push({keys: m.keys, dur: m.dur, label: m.label})
    }

    zigZags := [
        {keys: ["w", "d"], dur: chaosCfg.zigDiag, label: "Zig 1 (NE)"},
        {keys: ["w", "a"], dur: chaosCfg.zigDiag, label: "Zag 2 (NW)"},
        {keys: ["s", "d"], dur: chaosCfg.zigDiag, label: "Zig 3 (SE)"},
        {keys: ["s", "a"], dur: chaosCfg.zigDiag, label: "Zig 4 (SW)"},
        {keys: ["d"],      dur: chaosCfg.zigSide, label: "Zig 5 (E)"},
        {keys: ["a"],      dur: chaosCfg.zigSide, label: "Zig 6 (W)"}
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