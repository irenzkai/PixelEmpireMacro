; ==============================================================================
; ENHANCED TOWER AUTOMATION
;   Spawn (Bottom) -> Center -> Box Combat Walk -> Floor Cleared
;   -> Return to Center -> Enter Top Portal -> Detect Next Floor -> Loop
; ==============================================================================

ToggleTowerMode(*) {
    global running, freeCircleMode, chaosTestRunning, mapCycleMode, completedLoops, recoveryCount, hudStatus
    global floorsCleared, towerPhase, towerPosX, towerPosY

    if (running && !freeCircleMode) {
        StopAll("Switched / Stopped")
        return
    }

    running := !running
    if (running) {
        if !InitVisionAndWindow(false) {
            running := false
            return
        }

        running := true
        freeCircleMode := true
        chaosTestRunning := false
        mapCycleMode := false
        completedLoops := 0
        recoveryCount := 0
        floorsCleared := 0
        towerPhase := "Starting"
        towerPosX := 0.0
        towerPosY := 0.0

        hudStatus := "Tower Mode Active — Assuming bottom of floor..."
        UpdateGuiStatus(hudStatus)

        ActivateRunOverlay()
        SetTimer(UpdateHUD, 80)
        SetTimer(AltAntiAFK, 600000)
        SetTimer(RunTowerLoop, -10)
    } else {
        StopAll("Stopped Tower Mode")
    }
}

RecordTowerDisplacement(keys, durationMs) {
    global towerPosX, towerPosY
    if (durationMs <= 0 || keys.Length = 0)
        return
    factor := (keys.Length > 1) ? 0.7071 : 1.0
    delta  := durationMs * factor
    for k in keys {
        if (k = "w")
            towerPosY -= delta
        else if (k = "s")
            towerPosY += delta
        else if (k = "a")
            towerPosX -= delta
        else if (k = "d")
            towerPosX += delta
    }
}

TowerMoveStep(keys, durationMs, checkClear := true) {
    global running, freeCircleMode
    if (!running || !freeCircleMode) {
        ReleaseMoveKeys()
        return "STOP"
    }

    if (checkClear && IsFloorCleared()) {
        ReleaseMoveKeys()
        return "CLEARED"
    }

    for k in keys
        SendEvent("{" k " down}")

    elapsed := 0
    while (running && freeCircleMode && elapsed < durationMs) {
        chunk := Min(40, durationMs - elapsed)
        Sleep(chunk)
        elapsed += chunk
        RecordTowerDisplacement(keys, chunk)

        if (checkClear && IsFloorCleared()) {
            ReleaseMoveKeys()
            return "CLEARED"
        }
    }

    ReleaseMoveKeys()
    return "DONE"
}

ReturnToTowerCenter() {
    global running, freeCircleMode, towerPosX, towerPosY, hudStatus
    if (!running || !freeCircleMode)
        return false

    hudStatus := "Floor Cleared! Returning to Center..."
    dx := -towerPosX
    dy := -towerPosY

    if (Abs(dx) < 40 && Abs(dy) < 40) {
        towerPosX := 0.0
        towerPosY := 0.0
        return true
    }

    minAxis := Min(Abs(dx), Abs(dy))
    if (minAxis >= 60) {
        diagKeys := []
        diagKeys.Push(dy < 0 ? "w" : "s")
        diagKeys.Push(dx < 0 ? "a" : "d")
        diagDur := Round(minAxis / 0.7071)
        TowerMoveStep(diagKeys, diagDur, false)

        movedAxis := diagDur * 0.7071
        dx += (dx < 0 ? movedAxis : -movedAxis)
        dy += (dy < 0 ? movedAxis : -movedAxis)
    }

    if (!running || !freeCircleMode)
        return false

    if (Abs(dx) >= 40)
        TowerMoveStep([dx < 0 ? "a" : "d"], Round(Abs(dx)), false)
    if (Abs(dy) >= 40)
        TowerMoveStep([dy < 0 ? "w" : "s"], Round(Abs(dy)), false)

    towerPosX := 0.0
    towerPosY := 0.0
    return true
}

RunTowerLoop() {
    global running, freeCircleMode, towerCenterMs, towerRadiusMs, towerPortalMs
    global towerPhase, floorsCleared, completedLoops, hudStatus
    if (!running || !freeCircleMode)
        return

    windows := GetSortedRobloxWindows()
    if (windows.Length = 0) {
        StopAll("Roblox window lost!")
        return
    }
    FocusWindow(windows[1])

    ; ==========================================================================
    ; PHASE 1: SPAWN (BOTTOM) -> CENTER OF BOX (Immediate W, no clear-check)
    ; ==========================================================================
    towerPhase := "To Center"
    hudStatus := "Floor #" (floorsCleared + 1) ": Moving to Center (" towerCenterMs "ms)..."
    towerPosX := 0.0
    towerPosY := 0.0

    TowerMoveStep(["w"], towerCenterMs, false)
    if (!running || !freeCircleMode)
        return

    towerPosX := 0.0
    towerPosY := 0.0

    ; ==========================================================================
    ; PHASE 2: COMBAT BOX WALK RADIUS AROUND CENTER
    ; ==========================================================================
    towerPhase := "Patrol"
    halfR := Round(towerRadiusMs * 0.5)
    fullR := towerRadiusMs

    boxLegs := [
        {keys: ["d"], dur: halfR, label: "East Flank"},
        {keys: ["w"], dur: halfR, label: "NE Corner"},
        {keys: ["a"], dur: fullR, label: "North Wall Sweep"},
        {keys: ["s"], dur: fullR, label: "West Wall Sweep"},
        {keys: ["d"], dur: fullR, label: "South Wall Sweep"},
        {keys: ["w"], dur: halfR, label: "SE Return"},
        {keys: ["a"], dur: halfR, label: "Center Re-Align"}
    ]

    while (running && freeCircleMode) {
        clearedTriggered := false
        for leg in boxLegs {
            hudStatus := "Floor #" (floorsCleared + 1) " Combat: " leg.label
            stepRes := TowerMoveStep(leg.keys, leg.dur, true)
            if (!running || !freeCircleMode)
                return
            if (stepRes = "CLEARED") {
                clearedTriggered := true
                break
            }
        }

        if (clearedTriggered || IsFloorCleared())
            break
    }

    if (!running || !freeCircleMode)
        return

    ; ==========================================================================
    ; PHASE 3: RETURN TO CENTER & RUN TO TOP PORTAL
    ; ==========================================================================
    towerPhase := "To Center"
    ReturnToTowerCenter()
    if (!running || !freeCircleMode)
        return

    towerPhase := "Entering Portal"
    hudStatus := "Floor Cleared! Running to Top Portal (" towerPortalMs "ms)..."
    TowerMoveStep(["w"], towerPortalMs, false)
    if (!running || !freeCircleMode)
        return

    ; ==========================================================================
    ; PHASE 4: WAIT FOR NEXT FLOOR INDICATOR
    ; ==========================================================================
    towerPhase := "Next Floor"
    hudStatus := "Waiting for next floor indicator..."

    waitStart := A_TickCount
    arrivedNextFloor := false

    while (running && freeCircleMode && (A_TickCount - waitStart < 10000)) {
        if IsNextFloorIndicator() {
            arrivedNextFloor := true
            break
        }
        SendEvent("{w down}")
        Sleep(60)
        SendEvent("{w up}")
        Sleep(220)
    }

    floorsCleared += 1
    completedLoops := floorsCleared
    SoundBeep(1250, 100)
    hudStatus := "Floor #" floorsCleared " Complete! Spawning on Floor #" (floorsCleared + 1) "..."
    Sleep(500)

    if (running && freeCircleMode)
        SetTimer(RunTowerLoop, -20)
}