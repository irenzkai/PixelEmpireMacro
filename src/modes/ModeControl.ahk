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
    ClearWaystoneOrigin()
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
    ClearWaystoneOrigin()
    ToolTip()
    HideOverlay()
    ExitApp()
}