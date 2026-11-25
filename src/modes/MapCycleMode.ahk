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

ExecuteMapTransit(fromIdx, dir) {
    global running, waystoneRoutes, hudStatus
    targetIdx := fromIdx + dir
    legs := GetActiveRouteLegs(fromIdx, targetIdx, &routeSrc)
    if (legs.Length = 0)
        return false

    totalMs := GetRouteTotalMs(legs)
    brakeAfterTick := A_TickCount + Max(1800, Round(totalMs * 0.60))
    portalScanTick := A_TickCount + Max(1200, Round(totalMs * 0.35))

    targetLabel := waystoneRoutes.Has(targetIdx) ? waystoneRoutes[targetIdx].label : ("WS #" targetIdx)
    hudStatus := "[" routeSrc "] -> " targetLabel "..."

    inTargetMap := false
    heldKeys := []
    for l in legs {
        if (!running) {
            ReleaseMoveKeys()
            return false
        }

        for oldK in heldKeys {
            stillHeld := false
            for newK in l.keys {
                if (newK = oldK)
                    stillHeld := true
            }
            if (!stillHeld)
                SendEvent("{" oldK " up}")
        }
        for newK in l.keys {
            alreadyHeld := false
            for oldK in heldKeys {
                if (oldK = newK)
                    alreadyHeld := true
            }
            if (!alreadyHeld)
                SendEvent("{" newK " down}")
        }
        heldKeys := l.keys.Clone()

        stepEnd := A_TickCount + l.ms
        while (A_TickCount < stepEnd && running) {
            Sleep(25)

            if (A_TickCount >= brakeAfterTick && IsOnWaystone()) {
                ReleaseMoveKeys()
                MarkWaystoneOrigin()
                return true
            }

            if (!inTargetMap && A_TickCount >= portalScanTick) {
                if (!IsMapTopLabel(fromIdx) && IsMapTopLabel(targetIdx)) {
                    inTargetMap := true
                } else if (FindPortalSprite(fromIdx, targetIdx)) {
                    ReleaseMoveKeys()
                    pRes := PathToPortalSprite(fromIdx, targetIdx)
                    if (pRes = "TARGET_MAP")
                        inTargetMap := true
                    break
                }
            }

            ; Once inside target map, if Waystone sprite is spotted on screen, go straight to it!
            if ((inTargetMap || A_TickCount >= brakeAfterTick) && FindWaystoneStatue()) {
                ReleaseMoveKeys()
                if (PathToWaystoneSprite())
                    return true
                break
            }
        }
        RecordMoveDisplacement(l.keys, l.ms)
        if (inTargetMap && IsOnWaystone()) {
            ReleaseMoveKeys()
            MarkWaystoneOrigin()
            return true
        }
    }

    ReleaseMoveKeys()
    Sleep(160)

    if (IsOnWaystone()) {
        MarkWaystoneOrigin()
        return true
    }

    curMap := DetectCurrentMapByTopLabel([targetIdx, fromIdx, 3, 5, 7])
    if (curMap >= 0 && curMap != targetIdx) {
        if (curMap = fromIdx && FindPortalSprite(fromIdx, targetIdx)) {
            hudStatus := "Portal spotted in " waystoneRoutes[fromIdx].label " -> Entering..."
            if (PathToPortalSprite(fromIdx, targetIdx) = "TARGET_MAP") {
                if (FindWaystoneStatue() && PathToWaystoneSprite())
                    return true
                AntiTrapRecovery([], targetIdx)
                return IsOnWaystone()
            }
        }
        hudStatus := "Wrong Map (" waystoneRoutes[curMap].label ")! Recovering..."
        if (curMap != fromIdx)
            RecoverBetweenMapsByGrid(curMap, fromIdx)
        AntiTrapRecovery([], fromIdx)
        return false
    }

    if (running) {
        hudStatus := "Aligning onto " targetLabel "..."
        if (FindWaystoneStatue() && PathToWaystoneSprite())
            return true
        AntiTrapRecovery([], targetIdx)
    }
    return IsOnWaystone()
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
    if (detected = nextIdx || ok) {
        currentWaystoneIdx := Max(1, Min(maxWaystoneIdx, nextIdx))
    } else if (detected >= 1) {
        currentWaystoneIdx := detected
    } else {
        currentWaystoneIdx := Max(1, Min(maxWaystoneIdx, nextIdx))
    }

    RefreshCycleUI()

    if (running && mapCycleMode)
        SetTimer(RunMapCycle, -30)
}