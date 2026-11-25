; ==============================================================================
; ONE-SHOT PERIMETER CIRCLE (QUEUED DURING WAYSTONE 8-STAR FARMING)
; ==============================================================================

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

ExecutePerimeterCircle() {
    global running, circleCfg, hudStatus
    hudStatus := "CIRCLE: Stepping out (" circleCfg.out "ms)..."

    HoldKeys(["w"], circleCfg.out)
    if (!running)
        return

    ringMoves := [
        {keys: ["d"],      dur: circleCfg.edge, label: "North-East Ring"},
        {keys: ["s", "d"], dur: circleCfg.diag, label: "East Flank Ring"},
        {keys: ["s"],      dur: circleCfg.card, label: "South-East Ring"},
        {keys: ["s", "a"], dur: circleCfg.diag, label: "South Flank Ring"},
        {keys: ["a"],      dur: circleCfg.card, label: "South-West Ring"},
        {keys: ["w", "a"], dur: circleCfg.diag, label: "West Flank Ring"},
        {keys: ["w"],      dur: circleCfg.card, label: "North-West Ring"},
        {keys: ["d"],      dur: circleCfg.edge, label: "Closing Circle"}
    ]

    for seg in ringMoves {
        if (!running)
            return
        hudStatus := "CIRCLE: " seg.label " (" seg.dur "ms)"
        HoldKeys(seg.keys, seg.dur)
    }

    hudStatus := "CIRCLE: Homing back to Waystone..."
    foundWaystone := ReturnUntilPrompt(["s"], circleCfg.ret)
    if (running && !foundWaystone) {
        AntiTrapRecovery(["s"])
    }
}