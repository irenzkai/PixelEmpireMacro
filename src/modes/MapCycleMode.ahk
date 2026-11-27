; ==============================================================================
; PING-PONG MAP CYCLE + STACKED BOSS/MINIBOSS LOOT SWEEPS + PORTAL/WAYSTONE LOCK
; ==============================================================================

ToggleMapCycleMode(*) {
    global running, mapCycleMode, freeCircleMode, chaosTestRunning, shortestPathRunning, manualRecordRunning
    global currentWaystoneIdx, cycleDir, completedLoops, recoveryCount, bossesHunted, hudStatus, waystoneRoutes

    if (running && !mapCycleMode) {
        StopAll("Switched / Stopped")
        return
    }

    running := !running
    if (running) {
        if !InitVisionAndWindow(true) {
            running := false
            return
        }
        Sleep(60)

        detectedStart := DetectCurrentMapByTopLabel()
        if (detectedStart < 0 || !IsOnWaystone()) {
            running := false
            NavProgress("Map Cycle start needs a recognized map and confirmed waystone prompt")
            return
        }
        currentWaystoneIdx := detectedStart

        if (currentWaystoneIdx <= 1)
            cycleDir := 1
        else if (currentWaystoneIdx >= 30)
            cycleDir := -1

        MarkWaystoneOrigin()
        mapCycleMode        := true
        freeCircleMode      := false
        chaosTestRunning    := false
        shortestPathRunning := false
        manualRecordRunning := false
        completedLoops      := 0
        recoveryCount       := 0
        bossesHunted        := 0

        hudStatus := "Map Cycle Starting on " waystoneRoutes[currentWaystoneIdx].label "..."
        UpdateGuiStatus(hudStatus)

        ActivateRunOverlay()
        SetTimer(UpdateHUD, 80)
        SetTimer(AltAntiAFK, 600000)
        SetTimer(RunMapCycle, -10)
    } else {
        StopAll("Paused Map Cycle")
    }
}

GetUpperCenterBossBox() {
    global robloxWinBox
    ww := robloxWinBox.x2 - robloxWinBox.x1
    wh := robloxWinBox.y2 - robloxWinBox.y1
    if (ww <= 0 || wh <= 0) {
        return {
            x1: Round(A_ScreenWidth * 0.22),
            y1: Round(A_ScreenHeight * 0.085),
            x2: Round(A_ScreenWidth * 0.78),
            y2: Round(A_ScreenHeight * 0.50)
        }
    }
    ; Start below top PVE bar (0.085) so map name gold text never false-triggers boss_defeated
    return {
        x1: robloxWinBox.x1 + Round(ww * 0.22),
        y1: robloxWinBox.y1 + Round(wh * 0.085),
        x2: robloxWinBox.x1 + Round(ww * 0.78),
        y2: robloxWinBox.y1 + Round(wh * 0.50)
    }
}

DetectActiveBossOrMiniboss(&kind := "") {
    global bossComingImg, bossSpawnImg, bossAlreadyInImg
    global minibossComingImg, minibossSpawnImg, minibossAlreadyInImg, bossBannerTol
    bossBox := GetUpperCenterBossBox()
    kind := ""

    ; OCR first check
    if OcrServerReady() {
        static ocrKind := "", ocrDef := false, ocrYouDef := false
        if OcrCheckBossBanner(&ocrKind, &ocrDef, &ocrYouDef) {
            kind := ocrKind
            return true
        }
    }

    static pBC := "", pBS := "", pBA := "", pMC := "", pMS := "", pMA := ""

    if SearchBossImage(bossComingImg,        bossBox, bossBannerTol, &fx, &fy, &pBC)
        kind := "Boss"
    else if SearchBossImage(bossSpawnImg,    bossBox, bossBannerTol, &fx, &fy, &pBS)
        kind := "Boss"
    else if SearchBossImage(bossAlreadyInImg, bossBox, bossBannerTol, &fx, &fy, &pBA)
        kind := "Boss"
    else if SearchBossImage(minibossComingImg,    bossBox, bossBannerTol, &fx, &fy, &pMC)
        kind := "Miniboss"
    else if SearchBossImage(minibossSpawnImg,     bossBox, bossBannerTol, &fx, &fy, &pMS)
        kind := "Miniboss"
    else if SearchBossImage(minibossAlreadyInImg, bossBox, bossBannerTol, &fx, &fy, &pMA)
        kind := "Miniboss"

    return (kind != "")
}

CheckAnyDefeatedBanner() {
    global bossDefeatedImg, minibossDefeatedImg, bossBannerTol
    bossBox := GetUpperCenterBossBox()

    ; OCR first check
    if OcrServerReady() {
        static ocrKind := "", ocrDef := false, ocrYouDef := false
        if OcrCheckBossBanner(&ocrKind, &ocrDef, &ocrYouDef) {
            if (ocrDef || ocrYouDef)
                return true
        }
    }

    static pBD := "", pMD := ""
    if SearchBossImage(bossDefeatedImg,     bossBox, bossBannerTol, &fx, &fy, &pBD)
        return true
    if SearchBossImage(minibossDefeatedImg, bossBox, bossBannerTol, &fx, &fy, &pMD)
        return true
    return false
}

CheckYouDefeatedConfirmation() {
    global youDefeatedBossImg, bossBannerTol
    bossBox := GetUpperCenterBossBox()
    static pYD := ""

    ; OCR first check
    if OcrServerReady() {
        static ocrKind := "", ocrDef := false, ocrYouDef := false
        if OcrCheckBossBanner(&ocrKind, &ocrDef, &ocrYouDef) {
            if (ocrYouDef)
                return true
        }
    }

    return SearchBossImage(youDefeatedBossImg, bossBox, bossBannerTol, &fx, &fy, &pYD)
}

PollBossStackState(state) {
    youNow := CheckYouDefeatedConfirmation()
    defNow := CheckAnyDefeatedBanner()

    ; Debounced rising-edge detection: stack +1 sweep only when a NEW defeated banner appears
    if (youNow && !state.wasYouDef) {
        state.pendingSweeps += 1
        state.youKilled := true
    } else if (defNow && !state.wasAnyDef && !youNow) {
        state.pendingSweeps += 1
    }

    if (DetectActiveBossOrMiniboss(&k)) {
        state.activeKind := k
        state.lastActiveTick := A_TickCount
    }

    state.wasYouDef := youNow
    state.wasAnyDef := defNow
}

RunFullF8LootPassWithPoll(wsLabel, state) {
    global running, completedLoops
    Loop 8 {
        if (!running)
            return false
        if (!ExecuteSingleWaystoneLeg(A_Index, "[LOOT x" state.pendingSweeps " " wsLabel "] "))
            return false
        PollBossStackState(state)
    }
    completedLoops += 1
    return true
}

FightBossWithF8Cycle(wsIdx, kind := "Boss") {
    global running, bossesHunted, completedLoops, hudStatus, waystoneRoutes
    wsLabel := waystoneRoutes[wsIdx].label
    bossesHunted += 1
    SoundBeep(1100, 110)
    TryBossLandmarkRoute(wsIdx)

    state := {
        pendingSweeps: 0,
        wasYouDef: false,
        wasAnyDef: false,
        youKilled: false,
        activeKind: kind,
        lastActiveTick: A_TickCount
    }

    PollBossStackState(state)
    fightStart := A_TickCount
    legIdx := 0

    while (running) {
        ; 1. Drain all stacked loot sweeps first (more can stack mid-sweep if 2nd boss dies!)
        while (running && state.pendingSweeps > 0) {
            hudStatus := "Defeated (" state.pendingSweeps "x queued) at " wsLabel " -> 8-Star Loot Sweep..."
            if (!RunFullF8LootPassWithPoll(wsLabel, state) || !running)
                return
            state.pendingSweeps -= 1
            fightStart := A_TickCount
        }

        ; 2. After finishing loot sweeps, verify if a 2nd boss/miniboss spawned or is still active
        Sleep(200)
        PollBossStackState(state)
        if (state.pendingSweeps > 0)
            continue

        if (!DetectActiveBossOrMiniboss(&newKind)) {
            ; Double-check 400ms later in case a 2nd boss banner is transitioning
            Sleep(400)
            PollBossStackState(state)
            if (state.pendingSweeps > 0)
                continue
            if (!DetectActiveBossOrMiniboss(&newKind)) {
                ; Only leave if we actually saw a kill/defeat OR active boss disappeared
                if (state.wasYouDef || state.wasAnyDef || (A_TickCount - state.lastActiveTick >= 600)) {
                    hudStatus := "Bosses cleared at " wsLabel " -> Resuming Map Cycle..."
                    return
                }
            }
        } else {
            state.activeKind := newKind
            state.lastActiveTick := A_TickCount
        }

        ; 3. Keep fighting with F8 legs until defeated / confirmation stacks
        legIdx := Mod(legIdx, 8) + 1
        if (!ExecuteSingleWaystoneLeg(legIdx, "[" state.activeKind " " wsLabel "] "))
            return
        if (legIdx = 8)
            completedLoops += 1

        PollBossStackState(state)

        if (A_TickCount - fightStart >= 65000) {
            hudStatus := state.activeKind " Fight Timeout at " wsLabel " -> Final Loot Sweep..."
            state.pendingSweeps := Max(1, state.pendingSweeps)
            RunFullF8LootPassWithPoll(wsLabel, state)
            return
        }
    }
}

TryBossLandmarkRoute(wsIdx) {
    global running
    deadline := A_TickCount + 15000
    try {
        Loop 8 {
            ReleaseMoveKeys()
            if (!running || A_TickCount >= deadline)
                return false
            kv := OcrHttpGetKV("/boss_target", 6000)
            if (!kv.Has("target_reliable") || kv["target_reliable"] != "1") {
                reason := kv.Has("reason") ? kv["reason"] : "Boss location endpoint unavailable"
                NavProgress(reason " -> F8 sweep fallback")
                return false
            }
            if (kv.Has("hp_bar") && kv["hp_bar"] = "1") {
                NavProgress("Boss HP bar visible: arrival signal -> F8 fight/loot")
                return true
            }
            dx := Integer(kv["dx"])
            dy := Integer(kv["dy"])
            keys := []
            if (Abs(dx) > 5)
                keys.Push(dx < 0 ? "a" : "d")
            if (Abs(dy) > 5)
                keys.Push(dy < 0 ? "w" : "s")
            if (keys.Length = 0)
                return true
            NavProgress("Boss landmark " kv["location"] " -> minimap vector " dx "," dy)
            HoldKeys(keys, 200)
        }
        NavProgress("Boss approach bounded limit -> F8 fallback")
        return false
    } finally {
        ReleaseMoveKeys()
    }
}

ExecuteMapTransit(fromIdx, dir) {
    global running, waystoneRoutes, hudStatus
    targetIdx := fromIdx + dir
    if HasConfiguredConnection(fromIdx,targetIdx)
        return ExecuteConfiguredConnection(fromIdx,targetIdx)
    legs := GetActiveRouteLegs(fromIdx, targetIdx, &routeSrc)
    deadline := A_TickCount + 45000
    if (legs.Length = 0)
        return false
    NavProgress("[" routeSrc "] WS" fromIdx " -> WS" targetIdx " (unconfirmed until label changes)")
    try {
        for leg in legs {
            remaining := leg.ms
            while (running && remaining > 0 && A_TickCount < deadline) {
                chunk := Min(250, remaining)
                HoldKeys(leg.keys, chunk)
                remaining -= chunk
                ; Expensive vision must execute with keys UP.
                if IsMapTopLabel(targetIdx) {
                    NavProgress("Confirmed transition WS" fromIdx " -> WS" targetIdx)
                    return true
                }
                if FindPortalSprite(fromIdx, targetIdx) {
                    result := PathToPortalSprite(fromIdx, targetIdx)
                    if (result = "TARGET_MAP")
                        return true
                    if (result = "PLAYER_UNKNOWN" || result = "BLOCKED")
                        return false
                }
            }
            if (!running || A_TickCount >= deadline)
                break
        }
        NavProgress("Bounded transit ended; checking destination label")
        return IsMapTopLabel(targetIdx)
    } finally {
        ReleaseMoveKeys()
    }
}

RunMapCycle() {
    global running, mapCycleMode, currentWaystoneIdx, maxWaystoneIdx, cycleDir, waystoneRoutes, hudStatus
    if (!running || !mapCycleMode)
        return

    windows := GetSortedRobloxWindows()
    if (windows.Length = 0) {
        StopAll("Roblox window lost!")
        return
    }
    FocusWindow(windows[1])

    if (currentWaystoneIdx > 0) {
        Sleep(160)
        if (DetectActiveBossOrMiniboss(&kind) || CheckAnyDefeatedBanner() || CheckYouDefeatedConfirmation()) {
            if (kind = "")
                kind := "Boss"
            FightBossWithF8Cycle(currentWaystoneIdx, kind)
            if (!running || !mapCycleMode)
                return
        }
    }

    if (currentWaystoneIdx >= maxWaystoneIdx)
        cycleDir := -1
    else if (currentWaystoneIdx <= 1 && cycleDir < 0)
        cycleDir := 1
    else if (currentWaystoneIdx = 0)
        cycleDir := 1

    prevIdx := currentWaystoneIdx
    ok := ExecuteMapTransit(currentWaystoneIdx, cycleDir)
    if (!running || !mapCycleMode)
        return

    nextIdx := prevIdx + cycleDir
    detected := DetectCurrentMapByTopLabel([nextIdx, prevIdx])
    if (detected = nextIdx) {
        currentWaystoneIdx := Max(1, Min(maxWaystoneIdx, nextIdx))
    } else if (detected >= 1) {
        currentWaystoneIdx := detected
    } else {
        currentWaystoneIdx := prevIdx
        StopAll("Map transition unconfirmed; retaining WS #" prevIdx)
        return
    }

    RefreshCycleUI()

    if (!ok || !IsOnWaystone()) {
        NavProgress("Transition checked; recovering only to current confirmed WS" currentWaystoneIdx)
        AntiTrapRecovery([], currentWaystoneIdx)
        if !IsOnWaystone() {
            StopAll("Waystone arrival unconfirmed; transit paused")
            return
        }
    }

    if (running && mapCycleMode)
        SetTimer(RunMapCycle, -30)
}
