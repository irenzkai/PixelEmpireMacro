; ==============================================================================
; SHORTEST PATH FINDER, MANUAL KEY RECORDER & LOGGER (WAYSTONE <-> NEXT / PREV)
;   - Standalone "Record Mine": walk manually with W/A/S/D from current Waystone
;     to Next or Prev Waystone; auto-saves on Waystone arrival or Overlay Stop
;   - Hybrid manual steering: press W/A/S/D anytime during Find Shortest Path
;     and the bot yields, records your own keys, and resumes when you let go
; ==============================================================================

GetPhysicalHeldKeys() {
    keys := []
    for k in ["w", "a", "s", "d"] {
        if GetKeyState(k, "P")
            keys.Push(k)
    }
    return keys
}

ReleaseBotKeysExceptPhysical() {
    for k in ["w", "a", "s", "d"] {
        if !GetKeyState(k, "P")
            SendEvent("{" k " up}")
    }
}

; ==============================================================================
; STANDALONE MANUAL PATH RECORDING ("RECORD MINE")
; ==============================================================================

StartManualPathRecording(*) {
    global running, manualRecordRunning, shortestPathRunning, mapCycleMode, freeCircleMode, chaosTestRunning
    global currentWaystoneIdx, manualRecFromIdx, manualRecCrossedIdx, manualRecLegs
    global completedLoops, recoveryCount, hudStatus, waystoneRoutes

    if (manualRecordRunning) {
        FinishManualPathRecording()
        return
    }
    if (running) {
        StopAll("Switched / Stopped")
        return
    }

    if !InitVisionAndWindow(true)
        return

    MarkWaystoneOrigin()
    running             := true
    manualRecordRunning := true
    shortestPathRunning := false
    mapCycleMode        := false
    freeCircleMode      := false
    chaosTestRunning    := false
    completedLoops      := 0
    recoveryCount       := 0

    manualRecFromIdx    := currentWaystoneIdx
    manualRecCrossedIdx := -1
    manualRecLegs       := []

    hudStatus := "Recording YOUR W/A/S/D from " waystoneRoutes[manualRecFromIdx].label "..."
    UpdateGuiStatus(hudStatus)

    ActivateRunOverlay()
    SetTimer(UpdateHUD, 80)
    SetTimer(RunManualPathRecorder, -20)
}

RunManualPathRecorder() {
    global running, manualRecordRunning, manualRecFromIdx, manualRecCrossedIdx, manualRecLegs
    global currentWaystoneIdx, maxWaystoneIdx, hudStatus, waystoneRoutes

    if (!running || !manualRecordRunning)
        return

    activeKeys := []
    segStartTick := A_TickCount
    totalWalkedMs := 0
    onPadTicks := 0
    tickCount := 0

    while (running && manualRecordRunning) {
        Sleep(20)
        tickCount += 1

        curKeys := GetPhysicalHeldKeys()
        if !KeysEqual(curKeys, activeKeys) {
            if (activeKeys.Length > 0) {
                dur := A_TickCount - segStartTick
                if (dur >= 25) {
                    manualRecLegs.Push({keys: activeKeys.Clone(), ms: dur})
                    totalWalkedMs += dur
                }
            }
            activeKeys := curKeys.Clone()
            segStartTick := A_TickCount

            if (activeKeys.Length > 0) {
                kLabel := ""
                for idx, k in activeKeys
                    kLabel .= (idx > 1 ? "+" : "") . StrUpper(k)
                hudStatus := "Holding [" kLabel "] (" manualRecLegs.Length " segs" . (manualRecCrossedIdx >= 0 ? (" · In " waystoneRoutes[manualRecCrossedIdx].label) : "") ")"
            } else {
                hudStatus := (manualRecCrossedIdx >= 0)
                    ? ("In " waystoneRoutes[manualRecCrossedIdx].label " — Step onto Waystone or STOP to save")
                    : ("Paused — Walk W/A/S/D to Next/Prev Waystone (or STOP)")
            }
        }

        ; Detect portal transition via top_label every ~160ms after moving >= 900ms
        if (totalWalkedMs >= 900 && Mod(tickCount, 8) = 0) {
            nextIdx := manualRecFromIdx + 1
            prevIdx := manualRecFromIdx - 1
            pref := []
            if (nextIdx <= maxWaystoneIdx)
                pref.Push(nextIdx)
            if (prevIdx >= 1)
                pref.Push(prevIdx)

            if (!IsMapTopLabel(manualRecFromIdx)) {
                det := DetectCurrentMapByTopLabel(pref)
                if (det >= 1 && det != manualRecFromIdx) {
                    if (det != manualRecCrossedIdx) {
                        manualRecCrossedIdx := det
                        SoundBeep(1050, 80)
                        hudStatus := "Entered " waystoneRoutes[det].label "! Walk to its Waystone..."
                    }
                }
            }
        }

        ; Auto-save & finish once inside target map and standing on its Waystone
        if (manualRecCrossedIdx >= 1 && manualRecCrossedIdx != manualRecFromIdx && Mod(tickCount, 6) = 0) {
            if (IsOnWaystone()) {
                onPadTicks += 1
                if (onPadTicks >= 2) {
                    if (activeKeys.Length > 0) {
                        dur := A_TickCount - segStartTick
                        if (dur >= 25)
                            manualRecLegs.Push({keys: activeKeys.Clone(), ms: dur})
                    }
                    FinishManualPathRecording(true)
                    return
                }
            } else {
                onPadTicks := 0
            }
        }
    }
}

FinishManualPathRecording(autoArrived := false) {
    global running, manualRecordRunning, manualRecFromIdx, manualRecCrossedIdx, manualRecLegs
    global currentWaystoneIdx, maxWaystoneIdx, waystoneRoutes, completedLoops

    if (!manualRecordRunning) {
        StopAll("Stopped")
        return
    }

    manualRecordRunning := false
    fromIdx := manualRecFromIdx
    toIdx   := manualRecCrossedIdx

    ; If top_label transition wasn't caught live, check current map now
    if (toIdx < 0 || toIdx = fromIdx) {
        pref := []
        if (fromIdx + 1 <= maxWaystoneIdx)
            pref.Push(fromIdx + 1)
        if (fromIdx - 1 >= 1)
            pref.Push(fromIdx - 1)
        det := DetectCurrentMapByTopLabel(pref)
        if (det >= 1 && det != fromIdx)
            toIdx := det
    }

    if (fromIdx = 0 && toIdx != 1) {
        StopAll("Eldoria (#0) only logs Whisperwood (#1) — discarded")
        return
    }

    simplified := SimplifyRecordedRoute(manualRecLegs)
    if (simplified.Length = 0 || toIdx < 1 || toIdx = fromIdx) {
        StopAll("Manual recording cancelled (no valid map transition)")
        return
    }

    friendLegs := GetFriendRouteLegs(fromIdx, toIdx)
    SaveAndLogShortestRoute(fromIdx, toIdx, simplified, friendLegs)
    completedLoops := 1
    currentWaystoneIdx := toIdx
    SoundBeep(1300, 150)

    StopAll((autoArrived ? "Auto-Saved " : "Saved ") fromIdx "->" toIdx " (" GetRouteTotalMs(simplified) "ms)")
    RefreshCycleUI()
    SaveConfig()
}

; ==============================================================================
; AUTOMATED FIND SHORTEST PATH (WITH LIVE USER WASD STEERING SUPPORT)
; ==============================================================================

StartShortestPathSingle(dir) {
    global running, shortestPathRunning, manualRecordRunning
    global currentWaystoneIdx, maxWaystoneIdx, shortestTaskQueue, waystoneRoutes

    if (running) {
        if (manualRecordRunning)
            FinishManualPathRecording()
        else
            StopAll("Stopped Shortest Path Finder")
        return
    }

    targetIdx := currentWaystoneIdx + dir
    if (currentWaystoneIdx = 0 && dir != 1) {
        MsgBox("At Eldoria Hub (WS #0), only WS #0 -> WS #1 (Whisperwood) can be recorded!")
        return
    }
    if (currentWaystoneIdx = 1 && dir < 0) {
        MsgBox("Map Cycle skips returning to Eldoria Hub (#0). Select WS #2+ to record Prev Path, or WS #0 -> Next Path for Whisperwood.")
        return
    }
    if (targetIdx < 1 || targetIdx > maxWaystoneIdx) {
        MsgBox("Target map out of bounds (1.." maxWaystoneIdx ")!")
        return
    }

    if !InitVisionAndWindow(true)
        return

    shortestTaskQueue := [{from: currentWaystoneIdx, to: targetIdx}]
    BeginShortestPathRunner("Finding Shortest Path: " waystoneRoutes[currentWaystoneIdx].label " -> " waystoneRoutes[targetIdx].label)
}

StartShortestPathAll(*) {
    global running, manualRecordRunning, currentWaystoneIdx, maxWaystoneIdx, shortestTaskQueue, mainGui
    if (running) {
        if (manualRecordRunning)
            FinishManualPathRecording()
        else
            StopAll("Stopped Shortest Path Finder")
        return
    }

    if !InitVisionAndWindow(true)
        return

    mainGui.Opt("+OwnDialogs")
    resp := MsgBox(
        "Auto-Find Shortest Paths starting from WS #" currentWaystoneIdx " up to WS #" maxWaystoneIdx " (and optionally back)?`n`n"
        "Yes = Forward (#" currentWaystoneIdx " -> #" maxWaystoneIdx ") + Backward (#" maxWaystoneIdx " -> #1)`n"
        "No  = Forward only (#" currentWaystoneIdx " -> #" maxWaystoneIdx ")`n"
        "Cancel = Abort",
        "Auto-Find Shortest Paths",
        "YesNoCancel Icon?"
    )
    if (resp = "Cancel")
        return

    shortestTaskQueue := []
    i := currentWaystoneIdx
    while (i < maxWaystoneIdx) {
        shortestTaskQueue.Push({from: i, to: i + 1})
        i += 1
    }
    if (resp = "Yes") {
        i := maxWaystoneIdx
        while (i > 1) {
            shortestTaskQueue.Push({from: i, to: i - 1})
            i -= 1
        }
    }

    if (shortestTaskQueue.Length = 0)
        return

    BeginShortestPathRunner("Auto-Mapping " shortestTaskQueue.Length " transitions...")
}

BeginShortestPathRunner(initialMsg) {
    global running, shortestPathRunning, manualRecordRunning, mapCycleMode, freeCircleMode, chaosTestRunning
    global completedLoops, recoveryCount, hudStatus

    MarkWaystoneOrigin()
    running             := true
    shortestPathRunning := true
    manualRecordRunning := false
    mapCycleMode        := false
    freeCircleMode      := false
    chaosTestRunning    := false
    completedLoops      := 0
    recoveryCount       := 0

    hudStatus := initialMsg
    UpdateGuiStatus(hudStatus)

    ActivateRunOverlay()
    SetTimer(UpdateHUD, 80)
    SetTimer(AltAntiAFK, 600000)
    SetTimer(RunShortestPathQueue, -20)
}

RunShortestPathQueue() {
    global running, shortestPathRunning, shortestTaskQueue, currentWaystoneIdx, completedLoops, hudStatus, waystoneRoutes

    if (!running || !shortestPathRunning)
        return

    if (shortestTaskQueue.Length = 0) {
        SoundBeep(1300, 180)
        StopAll("Shortest Path Logging Complete (" completedLoops " saved)")
        RefreshCycleUI()
        return
    }

    task := shortestTaskQueue.RemoveAt(1)
    fromIdx := task.from
    toIdx   := task.to

    if (fromIdx = 0 && toIdx != 1) {
        if (running && shortestPathRunning)
            SetTimer(RunShortestPathQueue, -20)
        return
    }

    currentWaystoneIdx := fromIdx
    RefreshCycleUI()

    ok := FindAndLogShortestPath(fromIdx, toIdx)
    if (!running || !shortestPathRunning)
        return

    if (ok) {
        completedLoops += 1
        currentWaystoneIdx := toIdx
        RefreshCycleUI()
        SoundBeep(1150, 90)
        Sleep(250)
    } else {
        hudStatus := "Failed " waystoneRoutes[fromIdx].label " -> " waystoneRoutes[toIdx].label " (Stopping)"
        StopAll("Could not complete " fromIdx "->" toIdx)
        return
    }

    if (running && shortestPathRunning)
        SetTimer(RunShortestPathQueue, -30)
}

FindAndLogShortestPath(fromIdx, toIdx) {
    global running, shortestPathRunning, waystoneRoutes, mapMsPerPx, hudStatus

    fromLabel := waystoneRoutes[fromIdx].label
    toLabel   := waystoneRoutes[toIdx].label
    hudStatus := "Shortest Path: " fromLabel " -> " toLabel

    if (fromIdx > 0 && !IsOnWaystone()) {
        AntiTrapRecovery([], fromIdx)
        if (!running || !shortestPathRunning)
            return false
    }
    MarkWaystoneOrigin()

    friendLegs := GetFriendRouteLegs(fromIdx, toIdx)
    friendVec  := ComputeLegsNetVector(friendLegs)

    mapVec := ScanWorldMapBetweenMaps(fromIdx, toIdx)
    if (mapVec.ok) {
        targetDxMs := mapVec.dx * mapMsPerPx
        targetDyMs := mapVec.dy * mapMsPerPx
    } else if (Abs(friendVec.dx) > 100 || Abs(friendVec.dy) > 100) {
        targetDxMs := friendVec.dx
        targetDyMs := friendVec.dy
    } else {
        targetDxMs := (waystoneRoutes[toIdx].gx - waystoneRoutes[fromIdx].gx) * 8500.0
        targetDyMs := (waystoneRoutes[toIdx].gy - waystoneRoutes[fromIdx].gy) * 8500.0
    }

    recorded := []
    crossedToTarget := false
    wrongPortalRetries := 0
    blockCount := 0
    prevDistPx := -1.0
    totalWalkedMs := 0

    ; --- PHASE 1: DIRECT VECTOR WALK WITH VERIFIED TOP_LABEL + USER STEERING ---
    Loop 10 {
        if (!running || !shortestPathRunning)
            return false

        walkRes := WalkShortestBurst(targetDxMs, targetDyMs, fromIdx, toIdx, recorded, &totalWalkedMs, 2800)
        if (!running || !shortestPathRunning)
            return false

        if (walkRes.status = "TARGET_MAP") {
            crossedToTarget := true
            break
        }

        if (walkRes.status = "WRONG_MAP") {
            wrongPortalRetries += 1
            hudStatus := "Wrong portal -> " waystoneRoutes[walkRes.mapIdx].label "! Reverting..."
            RecoverFromWrongPortal(walkRes.mapIdx, fromIdx)
            if (!running || !shortestPathRunning)
                return false

            if (!IsOnWaystone())
                AntiTrapRecovery([], fromIdx)
            recorded := []
            totalWalkedMs := 0

            if (wrongPortalRetries >= 2)
                break

            mapVec := ScanWorldMapBetweenMaps(fromIdx, toIdx)
            if (mapVec.ok) {
                targetDxMs := mapVec.dx * mapMsPerPx
                targetDyMs := mapVec.dy * mapMsPerPx
            } else {
                targetDxMs := friendVec.dx
                targetDyMs := friendVec.dy
            }
            continue
        }

        mapVec := ScanWorldMapBetweenMaps(fromIdx, toIdx)
        if (!running || !shortestPathRunning)
            return false

        if (mapVec.ok) {
            distPx := Sqrt((mapVec.dx * mapVec.dx) + (mapVec.dy * mapVec.dy))
            targetDxMs := mapVec.dx * mapMsPerPx
            targetDyMs := mapVec.dy * mapMsPerPx

            if (prevDistPx > 0 && (prevDistPx - distPx) <= 3.5 && !walkRes.userSteered) {
                blockCount += 1
                inward := GetVectorInwardKeys(targetDxMs, targetDyMs)
                perp := GetPerpendicularPair(inward)
                sideKeys := (Mod(blockCount, 2) = 1) ? perp.a : perp.b
                sideDur  := Min(1200, 500 + (blockCount * 200))

                hudStatus := "Blocked! Shortest Detour (" (Mod(blockCount, 2) = 1 ? "A" : "B") ")..."
                d1 := WalkShortestSegment(sideKeys, sideDur, fromIdx, toIdx, recorded, &totalWalkedMs)
                if (d1.status = "TARGET_MAP") {
                    crossedToTarget := true
                    break
                } else if (d1.status = "WRONG_MAP") {
                    RecoverFromWrongPortal(d1.mapIdx, fromIdx)
                    if (!IsOnWaystone())
                        AntiTrapRecovery([], fromIdx)
                    recorded := []
                    totalWalkedMs := 0
                    continue
                }
            } else {
                blockCount := 0
            }
            prevDistPx := distPx
        } else {
            targetDxMs -= walkRes.walkedDx
            targetDyMs -= walkRes.walkedDy
            if (Abs(targetDxMs) < 350 && Abs(targetDyMs) < 350)
                break
        }
    }

    ; --- PHASE 1B: FALLBACK TO FRIEND'S COORDS IF DIRECT PATH DIDN'T CROSS ---
    if (!crossedToTarget) {
        if (friendLegs.Length = 0)
            return false

        hudStatus := "Direct blocked -> Guiding via Friend Route..."
        if (!IsOnWaystone())
            AntiTrapRecovery([], fromIdx)
        recorded := []
        totalWalkedMs := 0

        for l in friendLegs {
            if (!running || !shortestPathRunning)
                return false
            segRes := WalkShortestSegment(l.keys, l.ms, fromIdx, toIdx, recorded, &totalWalkedMs)
            if (segRes.status = "TARGET_MAP") {
                crossedToTarget := true
                break
            } else if (segRes.status = "WRONG_MAP") {
                RecoverFromWrongPortal(segRes.mapIdx, fromIdx)
                return false
            }
        }
    }

    if (!crossedToTarget) {
        Sleep(120)
        if (!IsMapTopLabel(fromIdx) && IsMapTopLabel(toIdx))
            crossedToTarget := true
    }
    if (!crossedToTarget)
        return false

    ; --- PHASE 2: INSIDE TARGET MAP -> WALK STRAIGHT TO TARGET WAYSTONE ---
    hudStatus := "Entered " toLabel "! Homing to Waystone (recording)..."
    dummyMs := 9999
    if (!IsOnWaystone()) {
        Loop 6 {
            if (!running || !shortestPathRunning)
                return false
            if (IsOnWaystone())
                break

            if (FindWaystoneStatue(&sx, &sy)) {
                beforeX := wayPosX, beforeY := wayPosY
                if (PathToWaystoneSprite()) {
                    AppendDisplacementAsSegments(wayPosX - beforeX, wayPosY - beforeY, recorded)
                    break
                }
            }

            scan := ScanWorldMapVector(toIdx)
            if (!running || !shortestPathRunning)
                return false
            if (!scan.ok)
                break

            dxMs := scan.dx * mapMsPerPx
            dyMs := scan.dy * mapMsPerPx
            distPx := Sqrt((scan.dx * scan.dx) + (scan.dy * scan.dy))
            if (distPx <= 4) {
                for dirK in [["w"], ["s"], ["a"], ["d"]] {
                    WalkShortestSegment(dirK, 220, toIdx, toIdx, recorded, &dummyMs, true)
                    if (IsOnWaystone())
                        break
                }
                break
            }

            homeRes := WalkShortestBurst(dxMs, dyMs, toIdx, toIdx, recorded, &dummyMs, 2600, true)
            if (homeRes.status = "ON_WAYSTONE")
                break
            if (homeRes.status = "WRONG_MAP")
                RecoverFromWrongPortal(homeRes.mapIdx, toIdx)
        }
    }

    if (!IsOnWaystone())
        AntiTrapRecovery([], toIdx)

    if (fromIdx = 0 && toIdx != 1)
        return false

    simplified := SimplifyRecordedRoute(recorded)
    if (simplified.Length = 0)
        return false

    SaveAndLogShortestRoute(fromIdx, toIdx, simplified, friendLegs)
    return true
}

RecordUserManualOverride(expectStayIdx, targetIdx, recorded, &totalWalkedMs, stopOnWaystone := false) {
    global running, shortestPathRunning, hudStatus
    out := {status: "MANUAL_DONE", mapIdx: expectStayIdx, walkedDx: 0.0, walkedDy: 0.0}

    hudStatus := "Manual Override Active (recording your W/A/S/D)..."
    activeKeys := GetPhysicalHeldKeys()
    segStartTick := A_TickCount
    idleStartTick := 0
    tickCount := 0

    while (running && shortestPathRunning) {
        Sleep(20)
        tickCount += 1

        curKeys := GetPhysicalHeldKeys()
        if !KeysEqual(curKeys, activeKeys) {
            if (activeKeys.Length > 0) {
                dur := A_TickCount - segStartTick
                if (dur >= 25) {
                    recorded.Push({keys: activeKeys.Clone(), ms: dur})
                    totalWalkedMs += dur
                    RecordMoveDisplacement(activeKeys, dur)
                    factor := (activeKeys.Length > 1) ? 0.7071 : 1.0
                    for k in activeKeys {
                        if (k = "w")
                            out.walkedDy -= dur * factor
                        else if (k = "s")
                            out.walkedDy += dur * factor
                        else if (k = "a")
                            out.walkedDx -= dur * factor
                        else if (k = "d")
                            out.walkedDx += dur * factor
                    }
                }
            }
            activeKeys := curKeys.Clone()
            segStartTick := A_TickCount
            idleStartTick := (activeKeys.Length = 0) ? A_TickCount : 0
        }

        if (stopOnWaystone && IsOnWaystone()) {
            MarkWaystoneOrigin()
            out.status := "ON_WAYSTONE"
            return out
        }

        if (totalWalkedMs >= 1000 && Mod(tickCount, 5) = 0) {
            if (!IsMapTopLabel(expectStayIdx)) {
                if (targetIdx != expectStayIdx && IsMapTopLabel(targetIdx)) {
                    out.status := "TARGET_MAP"
                    out.mapIdx := targetIdx
                    return out
                }
                pref := [targetIdx, expectStayIdx, expectStayIdx - 1, expectStayIdx + 1, 1, 3, 5, 7, 0]
                det := DetectCurrentMapByTopLabel(pref)
                if (det >= 0 && det != expectStayIdx) {
                    out.status := (det = targetIdx) ? "TARGET_MAP" : "WRONG_MAP"
                    out.mapIdx := det
                    return out
                }
            }
        }

        if (activeKeys.Length = 0 && idleStartTick > 0 && (A_TickCount - idleStartTick >= 350))
            break
    }
    return out
}

WalkShortestBurst(dxMs, dyMs, expectStayIdx, targetIdx, recorded, &totalWalkedMs, maxBudgetMs := 2800, stopOnWaystone := false) {
    global running, shortestPathRunning
    res := {status: "DONE", mapIdx: expectStayIdx, walkedDx: 0.0, walkedDy: 0.0, userSteered: false}

    segments := []
    remX := dxMs
    remY := dyMs
    minAxis := Min(Abs(dxMs), Abs(dyMs))

    if (minAxis >= 130) {
        diagKeys := [dyMs < 0 ? "w" : "s", dxMs < 0 ? "a" : "d"]
        diagDur  := Min(maxBudgetMs, Round(minAxis / 0.7071))
        segments.Push({keys: diagKeys, dur: diagDur})
        maxBudgetMs -= diagDur
        movedAxis := diagDur * 0.7071
        remX += (dxMs < 0 ? movedAxis : -movedAxis)
        remY += (dyMs < 0 ? movedAxis : -movedAxis)
    }

    if (maxBudgetMs > 90 && Abs(remX) >= 110) {
        segDur := Min(maxBudgetMs, Round(Abs(remX)))
        segments.Push({keys: [remX < 0 ? "a" : "d"], dur: segDur})
        maxBudgetMs -= segDur
    }
    if (maxBudgetMs > 90 && Abs(remY) >= 110) {
        segDur := Min(maxBudgetMs, Round(Abs(remY)))
        segments.Push({keys: [remY < 0 ? "w" : "s"], dur: segDur})
    }

    for seg in segments {
        if (!running || !shortestPathRunning) {
            ReleaseMoveKeys()
            return res
        }
        segOut := WalkShortestSegment(seg.keys, seg.dur, expectStayIdx, targetIdx, recorded, &totalWalkedMs, stopOnWaystone)
        res.walkedDx += segOut.walkedDx
        res.walkedDy += segOut.walkedDy
        if (segOut.userSteered)
            res.userSteered := true
        if (segOut.status != "DONE") {
            res.status := segOut.status
            res.mapIdx := segOut.mapIdx
            return res
        }
    }
    return res
}

WalkShortestSegment(keys, durMs, expectStayIdx, targetIdx, recorded, &totalWalkedMs, stopOnWaystone := false) {
    global running, shortestPathRunning
    out := {status: "DONE", mapIdx: expectStayIdx, walkedDx: 0.0, walkedDy: 0.0, userSteered: false}
    if (durMs <= 0 || keys.Length = 0)
        return out

    for k in keys
        SendEvent("{" k " down}")

    elapsed := 0
    tickCount := 0
    while (running && shortestPathRunning && elapsed < durMs) {
        chunk := Min(35, durMs - elapsed)
        Sleep(chunk)
        elapsed += chunk
        totalWalkedMs += chunk
        tickCount += 1
        RecordMoveDisplacement(keys, chunk)

        if (GetPhysicalHeldKeys().Length > 0) {
            ReleaseBotKeysExceptPhysical()
            if (elapsed > 25)
                recorded.Push({keys: keys.Clone(), ms: elapsed})
            factor := (keys.Length > 1) ? 0.7071 : 1.0
            for k in keys {
                if (k = "w")
                    out.walkedDy -= elapsed * factor
                else if (k = "s")
                    out.walkedDy += elapsed * factor
                else if (k = "a")
                    out.walkedDx -= elapsed * factor
                else if (k = "d")
                    out.walkedDx += elapsed * factor
            }

            ov := RecordUserManualOverride(expectStayIdx, targetIdx, recorded, &totalWalkedMs, stopOnWaystone)
            out.userSteered := true
            out.walkedDx += ov.walkedDx
            out.walkedDy += ov.walkedDy
            out.status := (ov.status != "MANUAL_DONE") ? ov.status : "USER_STEERED"
            out.mapIdx := ov.mapIdx
            return out
        }

        if (stopOnWaystone) {
            if (IsOnWaystone()) {
                ReleaseMoveKeys()
                MarkWaystoneOrigin()
                recorded.Push({keys: keys.Clone(), ms: elapsed})
                out.status := "ON_WAYSTONE"
                return out
            }
            if (Mod(tickCount, 3) = 0 && FindWaystoneStatue()) {
                ReleaseMoveKeys()
                if (elapsed > 25)
                    recorded.Push({keys: keys.Clone(), ms: elapsed})
                beforeX := wayPosX, beforeY := wayPosY
                if (PathToWaystoneSprite()) {
                    AppendDisplacementAsSegments(wayPosX - beforeX, wayPosY - beforeY, recorded)
                    out.status := "ON_WAYSTONE"
                    return out
                }
                for k in keys
                    SendEvent("{" k " down}")
            }
        }

        if (totalWalkedMs >= 1200 && Mod(tickCount, 3) = 0) {
            stillInStart := IsMapTopLabel(expectStayIdx)
            if (!stillInStart) {
                if (targetIdx != expectStayIdx && IsMapTopLabel(targetIdx)) {
                    Sleep(60)
                    if (!IsMapTopLabel(expectStayIdx) && IsMapTopLabel(targetIdx)) {
                        ReleaseMoveKeys()
                        recorded.Push({keys: keys.Clone(), ms: elapsed})
                        out.status := "TARGET_MAP"
                        out.mapIdx := targetIdx
                        return out
                    }
                }
                if (Mod(tickCount, 6) = 0) {
                    pref := [targetIdx, expectStayIdx, expectStayIdx - 1, expectStayIdx + 1, 1, 3, 5, 7, 0]
                    det := DetectCurrentMapByTopLabel(pref)
                    if (det >= 0 && det != expectStayIdx) {
                        ReleaseMoveKeys()
                        if (det = targetIdx) {
                            recorded.Push({keys: keys.Clone(), ms: elapsed})
                            out.status := "TARGET_MAP"
                            out.mapIdx := det
                        } else {
                            out.status := "WRONG_MAP"
                            out.mapIdx := det
                        }
                        return out
                    }
                }
            } else if (!stopOnWaystone && targetIdx != expectStayIdx && Mod(tickCount, 6) = 0) {
                ; Steer straight into portal if portal image (day/night) is spotted on screen
                if (FindPortalSprite(expectStayIdx, targetIdx)) {
                    ReleaseMoveKeys()
                    if (elapsed > 25)
                        recorded.Push({keys: keys.Clone(), ms: elapsed})
                    pRes := PathToPortalSprite(expectStayIdx, targetIdx, recorded)
                    if (pRes = "TARGET_MAP") {
                        out.status := "TARGET_MAP"
                        out.mapIdx := targetIdx
                        return out
                    }
                    for k in keys
                        SendEvent("{" k " down}")
                }
            }
        }
    }

    ReleaseMoveKeys()
    recorded.Push({keys: keys.Clone(), ms: elapsed})
    factor := (keys.Length > 1) ? 0.7071 : 1.0
    for k in keys {
        if (k = "w")
            out.walkedDy -= elapsed * factor
        else if (k = "s")
            out.walkedDy += elapsed * factor
        else if (k = "a")
            out.walkedDx -= elapsed * factor
        else if (k = "d")
            out.walkedDx += elapsed * factor
    }
    return out
}

RecoverFromWrongPortal(wrongIdx, wantIdx) {
    global running
    if (!running)
        return false
    return RecoverBetweenMapsByGrid(wrongIdx, wantIdx)
}

RecoverBetweenMapsByGrid(curIdx, wantIdx) {
    global running, waystoneRoutes
    if (!waystoneRoutes.Has(curIdx) || !waystoneRoutes.Has(wantIdx))
        return false

    dx := waystoneRoutes[wantIdx].gx - waystoneRoutes[curIdx].gx
    dy := waystoneRoutes[wantIdx].gy - waystoneRoutes[curIdx].gy
    backKeys := []
    if (dy < 0)
        backKeys.Push("w")
    else if (dy > 0)
        backKeys.Push("s")
    if (dx < 0)
        backKeys.Push("a")
    else if (dx > 0)
        backKeys.Push("d")

    if (backKeys.Length = 0)
        return false

    for k in backKeys
        SendEvent("{" k " down}")
    elapsed := 0
    while (running && elapsed < 2500) {
        Sleep(50)
        elapsed += 50
        if (IsMapTopLabel(wantIdx)) {
            ReleaseMoveKeys()
            return true
        }
    }
    ReleaseMoveKeys()
    return IsMapTopLabel(wantIdx)
}

AppendDisplacementAsSegments(dxMs, dyMs, recorded) {
    minAxis := Min(Abs(dxMs), Abs(dyMs))
    remX := dxMs
    remY := dyMs
    if (minAxis >= 60) {
        diagDur := Round(minAxis / 0.7071)
        recorded.Push({keys: [dyMs < 0 ? "w" : "s", dxMs < 0 ? "a" : "d"], ms: diagDur})
        movedAxis := diagDur * 0.7071
        remX += (dxMs < 0 ? movedAxis : -movedAxis)
        remY += (dyMs < 0 ? movedAxis : -movedAxis)
    }
    if (Abs(remX) >= 40)
        recorded.Push({keys: [remX < 0 ? "a" : "d"], ms: Round(Abs(remX))})
    if (Abs(remY) >= 40)
        recorded.Push({keys: [remY < 0 ? "w" : "s"], ms: Round(Abs(remY))})
}

SimplifyRecordedRoute(rawLegs) {
    merged := []
    for seg in rawLegs {
        if (seg.ms < 35 || seg.keys.Length = 0)
            continue
        sorted := SortKeyList(seg.keys)
        if (merged.Length > 0 && KeysEqual(merged[merged.Length].keys, sorted)) {
            merged[merged.Length].ms += seg.ms
        } else {
            merged.Push({keys: sorted, ms: seg.ms})
        }
    }
    return merged
}

SortKeyList(keys) {
    out := []
    for k in ["w", "a", "s", "d"] {
        for item in keys {
            if (item = k) {
                out.Push(k)
                break
            }
        }
    }
    return out
}

KeysEqual(a, b) {
    if (a.Length != b.Length)
        return false
    Loop a.Length {
        if (a[A_Index] != b[A_Index])
            return false
    }
    return true
}

; ==============================================================================
; PERSISTENCE: shortest_routes.ini & shortest_routes_log.txt
; ==============================================================================

SerializeLegs(legs) {
    parts := []
    for l in legs {
        kStr := ""
        for idx, k in l.keys
            kStr .= (idx > 1 ? "+" : "") . k
        parts.Push(kStr ":" l.ms)
    }
    out := ""
    for idx, p in parts
        out .= (idx > 1 ? "|" : "") . p
    return out
}

DeserializeLegs(rawStr) {
    legs := []
    cleaned := Trim(rawStr)
    if (cleaned = "")
        return legs
    for part in StrSplit(cleaned, "|") {
        pair := StrSplit(part, ":")
        if (pair.Length = 2 && IsInteger(pair[2])) {
            keys := StrSplit(pair[1], "+")
            legs.Push({keys: keys, ms: Integer(pair[2])})
        }
    }
    return legs
}

FormatLegsAsAhk(legs) {
    items := []
    for l in legs {
        kParts := ""
        for idx, k in l.keys
            kParts .= (idx > 1 ? ", " : "") . '"' k '"'
        items.Push("{keys: [" kParts "], ms: " l.ms "}")
    }
    out := "["
    for idx, it in items
        out .= (idx > 1 ? ", " : "") . it
    return out . "]"
}

LoadShortestRoutes() {
    global shortestRoutes, shortestRoutesIni
    shortestRoutes := Map()
    if !FileExist(shortestRoutesIni)
        return
    try {
        sectionText := IniRead(shortestRoutesIni, "Routes")
        for line in StrSplit(sectionText, "`n", "`r") {
            eqPos := InStr(line, "=")
            if (eqPos > 0) {
                k := Trim(SubStr(line, 1, eqPos - 1))
                v := Trim(SubStr(line, eqPos + 1))
                legs := DeserializeLegs(v)
                if (legs.Length > 0)
                    shortestRoutes[k] := legs
            }
        }
    }
}

SaveAndLogShortestRoute(fromIdx, toIdx, legs, friendLegs := "") {
    global shortestRoutes, shortestRoutesIni, shortestRoutesLog, waystoneRoutes

    key := fromIdx "->" toIdx
    shortestRoutes[key] := legs
    IniWrite(SerializeLegs(legs), shortestRoutesIni, "Routes", key)

    newMs := GetRouteTotalMs(legs)
    oldMs := IsObject(friendLegs) ? GetRouteTotalMs(friendLegs) : 0
    savedDiff := (oldMs > 0) ? (" (Friend: " oldMs "ms, Saved: " (oldMs - newMs) "ms)") : ""
    stamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")

    logBlock := "; [" stamp "] " waystoneRoutes[fromIdx].label " -> " waystoneRoutes[toIdx].label
        . " | Total: " newMs "ms" savedDiff "`n"
        . '    "' key '": ' FormatLegsAsAhk(legs) ",`n"
    try FileAppend(logBlock, shortestRoutesLog, "UTF-8")
}