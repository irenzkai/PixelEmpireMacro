; ==============================================================================
; WAYSTONE 8-STAR MODE & SHORT / VERY WIDE PRESET TOGGLE
; ==============================================================================

global f8MapIdx := -1
global f8Session := 0
global f8Record := 0
global f8Build := "tracker-20261127-v4-mapgate-shins"

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
    global running, circleRequested, chaosTestRunning, freeCircleMode, mapCycleMode
    global shortestPathRunning, manualRecordRunning, f8Session
    global step, completedLoops, recoveryCount, hudStatus, wideStarMode, overlayTitleTxt, overlayGui
    if (running || chaosTestRunning || freeCircleMode || mapCycleMode || shortestPathRunning || manualRecordRunning) {
        StopAll("Paused manually")
        return
    }
    F8RecordStart()
    F8SetStatus("F8 START: preparing window and vision")
    ShowOverlay(true)
    overlayTitleTxt.Text := "F8 STARTING"
    F8RecordEvent("INIT", "Preparing window and approved vision; no movement yet")
    if !InitVisionAndWindow(true) {
        F8RecordStop("Window/vision initialization failed")
        F8SetStatus("F8 stopped: window/vision initialization failed", "STOPPED")
        ShowOverlay(true)
        return
    }
    running := true
    f8Session := F8CreateSession()
    step := 0
    completedLoops := 0
    recoveryCount := 0
    circleRequested := false
    F8SetStatus("START: checking ward prompt")
    ActivateRunOverlay(true)
    F8RecordEvent("HUD", "hwnd=" overlayGui.Hwnd " visible=" DllCall("IsWindowVisible", "ptr", overlayGui.Hwnd)
        " | Roblox-screen HUD forced on; saved enable/position preference bypassed for F8")
    SetTimer(UpdateHUD, 80)
    ; F8 never schedules the alternate-window input timer: focus loss must stop.
    SetTimer(RunHomingCycle, -1)
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

ExecuteSingleWaystoneLeg(legIdx, prefix := "", session := 0) {
    global running, wideStarMode, shortCfg, wideCfg, hudStatus
    if !IsObject(session)
        return ExecuteLegacyWaystoneLeg(legIdx, prefix)
    cfg := wideStarMode ? wideCfg : shortCfg
    currentLeg := GetWaystoneStarLegs()[legIdx]
    F8SetStatus(currentLeg.name " OUT (" currentLeg.dur "ms)")
    ; Do not check/recover for the naturally absent prompt during outward travel.
    HoldKeys(currentLeg.outKeys, currentLeg.dur, currentLeg.name, session)
    if !F8Alive(session)
        return false
    F8SetStatus(currentLeg.name " RETURN")
    ; Transition directly to the return keys; no blocking vision or all-key release.
    found := ReturnUntilPrompt(currentLeg.retKeys, Min(cfg.ret, currentLeg.dur + 450), session)
    if !F8Alive(session)
        return false
    if !found {
        F8SetStatus(currentLeg.name " RETURN LIMIT: check last frames")
        ; Only a missed checkpoint pauses. Keep the same phase so a brief
        ; already-captured prompt can still finish this return.
        if !F8CheckPrompt(session, 200, false) {
            F8SetStatus("RECOVERY: ward prompt missed")
            if !AntiTrapRecovery([], -1, session)
                return false
        }
    }
    MarkWaystoneOrigin()
    return true
}

F8Stop(reason) {
    global hudStatus, overlayTitleTxt, overlayStatusTxt
    StopAll(reason)
    F8SetStatus("F8 stopped: " reason, "STOPPED")
    ; StopAll hides the run HUD; retain a stopped, nonactivating reason for review.
    ShowOverlay(true)
    overlayTitleTxt.Text := "F8 STOPPED"
    overlayStatusTxt.Text := reason
    UpdateGuiStatus(hudStatus)
}

RunHomingCycle() {
    global running, circleRequested, step, completedLoops, f8Session, mapOpen
    if !running
        return
    ; Preserve the existing Chaos -> F8 handoff without changing Chaos behavior.
    if !IsObject(f8Session) {
        f8Session := F8CreateSession()
        SetTimer(AltAntiAFK, 0)
    }
    session := f8Session
    try {
        if !F8Alive(session) {
            F8Stop("Roblox focus lost")
            return
        }
        if !session.ready {
            if mapOpen {
                F8SetStatus("START: close map before live detection")
                if !F8CloseMap(session, true, GetQpcMs()+6000) {
                    F8Stop("Close World Map before starting live movement")
                    return
                }
            }
            if !F8CheckPrompt(session, 3500) {
                if !F8Alive(session) {
                    if (running && session = f8Session)
                        F8Stop("Roblox focus lost")
                    return
                }
                if !session.wardChecked {
                    F8Stop("Ward check unavailable: " (session.wardError != "" ? session.wardError : "no completed prompt result"))
                    return
                }
                F8SetStatus("START: prompt absent; recover until ward")
                if !AntiTrapRecovery([], -1, session) {
                    if (running && session = f8Session)
                        F8Stop(F8Alive(session) ? session.reason : "Roblox focus lost")
                    return
                }
            }
            if !F8Alive(session)
                return
            MarkWaystoneOrigin()
            session.ready := true
        }
        ; One owning runtime loop, with no timer gap or finally-release between
        ; successful legs. SyncMoveKeys carries shared keys into the next leg.
        while F8Alive(session) {
            if circleRequested {
                circleRequested := false
                F8Release(session)
                ExecutePerimeterCircle()
            } else {
                step := Mod(step, 8) + 1
                if !ExecuteSingleWaystoneLeg(step, "", session) {
                    if (running && session = f8Session)
                        F8Stop(F8Alive(session) ? session.reason : "Roblox focus lost")
                    return
                }
                if (step = 8)
                    completedLoops += 1
            }
        }
        if (running && session = f8Session)
            F8Stop("Roblox focus lost")
    } catch as err {
        if (running && session = f8Session)
            F8Stop("Error: " err.Message)
    } finally {
        ; Do not release a newer run's keys if a stopped request unwinds later.
        if (session = f8Session)
            F8Release(session)
    }
}

; Non-F8 callers (map-cycle boss/loot passes) keep their existing behavior.
ExecuteLegacyWaystoneLeg(legIdx, prefix := "") {
    global running, wideStarMode, shortCfg, wideCfg, hudStatus, f8MapIdx
    cfg := wideStarMode ? wideCfg : shortCfg
    legs := GetWaystoneStarLegs()
    currentLeg := legs[legIdx]
    hudStatus := prefix currentLeg.name " -> Outward (" currentLeg.dur "ms)"
    HoldKeys(currentLeg.outKeys, currentLeg.dur, currentLeg.name)
    if (!running)
        return false
    if (IsOnWaystone()) {
        MarkWaystoneOrigin()
        return true
    }
    retLimit := Min(cfg.ret, currentLeg.dur + 450)
    hudStatus := prefix currentLeg.name " -> Homing..."
    foundWaystone := ReturnUntilPrompt(currentLeg.retKeys, retLimit)
    if (!running)
        return false
    if (!foundWaystone) {
        if (FindWaystoneStatue(&sx, &sy)) {
            hudStatus := prefix currentLeg.name " -> Statue Lock..."
            if (PathToWaystoneSprite([], 3500))
                return true
        }
        if (f8MapIdx < 0 && OcrServerReady())
            f8MapIdx := OcrDetectCurrentMap()
        NavProgress("F8 " currentLeg.name ": return prompt not confirmed; starting recovery")
        AntiTrapRecovery(currentLeg.retKeys, f8MapIdx)
        if (!running || !WinActive("ahk_exe RobloxPlayerBeta.exe") || !IsOnWaystone()) {
            StopAll("F8 recovery failed to confirm live waystone")
            return false
        }
    }
    return true
}
