; ==============================================================================
; SHARED MODE LIFECYCLE (OVERLAY ACTIVATION, STOP ALL, EXIT)
; ==============================================================================

ActivateRunOverlay() {
    global hudEnabled, mainGui
    if (hudEnabled) {
        if IsSet(mainGui)
            mainGui.Hide()
        ShowOverlay()
    }
}

StopAll(reason) {
    global running, chaosTestRunning, freeCircleMode, mapCycleMode, shortestPathRunning, manualRecordRunning
    global completedLoops, mainGui, isScanningMap
    running := false
    chaosTestRunning := false
    freeCircleMode := false
    mapCycleMode := false
    shortestPathRunning := false
    manualRecordRunning := false
    SetTimer(RunHomingCycle, 0)
    SetTimer(RunTowerLoop, 0)
    SetTimer(RunChaosStressTest, 0)
    SetTimer(RunMapCycle, 0)
    SetTimer(RunShortestPathQueue, 0)
    SetTimer(RunManualPathRecorder, 0)
    SetTimer(UpdateHUD, 0)
    SetTimer(AltAntiAFK, 0)
    ReleaseMoveKeys()
    if (isScanningMap) {
        CloseWorldMap()
        isScanningMap := false
    }
    ClearWaystoneOrigin()
    ToolTip()
    HideOverlay()
    if IsSet(mainGui)
        mainGui.Show()
    UpdateGuiStatus("Stopped (" reason ") | Loops: " completedLoops)
}

ExitMacro(*) {
    global running, chaosTestRunning, freeCircleMode, mapCycleMode, shortestPathRunning, manualRecordRunning, isScanningMap
    running := false
    chaosTestRunning := false
    freeCircleMode := false
    mapCycleMode := false
    shortestPathRunning := false
    manualRecordRunning := false
    SetTimer(RunHomingCycle, 0)
    SetTimer(RunTowerLoop, 0)
    SetTimer(RunChaosStressTest, 0)
    SetTimer(RunMapCycle, 0)
    SetTimer(RunShortestPathQueue, 0)
    SetTimer(RunManualPathRecorder, 0)
    SetTimer(UpdateHUD, 0)
    SetTimer(AltAntiAFK, 0)
    ReleaseMoveKeys()
    if (isScanningMap) {
        CloseWorldMap()
        isScanningMap := false
    }
    ClearWaystoneOrigin()
    ToolTip()
    HideOverlay()
    ExitApp()
}