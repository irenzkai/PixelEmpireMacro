; ==============================================================================
; SHARED MODE LIFECYCLE (OVERLAY ACTIVATION, STOP ALL, EXIT)
; ==============================================================================

ActivateRunOverlay(forceHUD := false) {
    global hudEnabled, mainGui
    if (forceHUD || hudEnabled) {
        if IsSet(mainGui)
            mainGui.Hide()
        ShowOverlay(forceHUD)
    }
}

StopAll(reason) {
    global running, chaosTestRunning, freeCircleMode, mapCycleMode, shortestPathRunning, manualRecordRunning
    global completedLoops, mainGui, isScanningMap, f8Session
    running := false
    ReleaseMoveKeys()
    F8RecordStop(reason)
    if IsObject(f8Session) {
        if f8Session.wardReq
            f8Session.wardReq.Cancel()
    }
    f8Session := 0
    F8SetStatus(reason, "STOPPED")
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
    global assetPickerActive
    if assetPickerActive
        ExitAssetPicker()
    global running, chaosTestRunning, freeCircleMode, mapCycleMode, shortestPathRunning, manualRecordRunning, isScanningMap, f8Session
    running := false
    ReleaseMoveKeys()
    F8RecordStop("Macro exited")
    if IsObject(f8Session) {
        if f8Session.wardReq
            f8Session.wardReq.Cancel()
    }
    f8Session := 0
    F8SetStatus("Macro exited", "STOPPED")
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
