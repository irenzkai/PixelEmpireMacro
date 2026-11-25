; ==============================================================================
; CHARACTER MOVEMENT, ORIGIN TRACKING, WORLD MAP (M) RECOVERY & OBSTACLE DETOUR
; ==============================================================================

MarkWaystoneOrigin() {
    global wayPosX, wayPosY, wayOriginMarked
    wayPosX := 0.0
    wayPosY := 0.0
    wayOriginMarked := true
}

ClearWaystoneOrigin() {
    global wayPosX, wayPosY, wayOriginMarked
    wayPosX := 0.0
    wayPosY := 0.0
    wayOriginMarked := false
}

RecordMoveDisplacement(keys, durationMs) {
    global wayPosX, wayPosY, wayOriginMarked
    if (!wayOriginMarked || durationMs <= 0 || keys.Length = 0)
        return

    factor := (keys.Length > 1) ? 0.7071 : 1.0
    delta  := durationMs * factor

    for k in keys {
        if (k = "w")
            wayPosY -= delta
        else if (k = "s")
            wayPosY += delta
        else if (k = "a")
            wayPosX -= delta
        else if (k = "d")
            wayPosX += delta
    }
}

GetActiveHeldKeysList(held) {
    list := []
    for k in ["w", "a", "s", "d"] {
        if (held[k])
            list.Push(k)
    }
    return list
}

HoldKeys(keys, duration) {
    for k in keys
        SendEvent("{" k " down}")
    Sleep(duration)
    ReleaseMoveKeys()
    RecordMoveDisplacement(keys, duration)
}

SyncMoveKeys(held, want) {
    for k in ["w", "a", "s", "d"] {
        if (held[k] && !want[k]) {
            SendEvent("{" k " up}")
            held[k] := false
        }
    }
    for k in ["w", "a", "s", "d"] {
        if (!held[k] && want[k]) {
            SendEvent("{" k " down}")
            held[k] := true
        }
    }
}

ReleaseMoveKeys() {
    for key in ["w", "a", "s", "d"] {
        SendEvent("{" key " up}")
    }
}

GetOppositeKeys(keys) {
    opp := []
    for k in keys {
        if (k = "w")
            opp.Push("s")
        else if (k = "s")
            opp.Push("w")
        else if (k = "a")
            opp.Push("d")
        else if (k = "d")
            opp.Push("a")
    }
    return opp
}

GetCompassDir(dx, dy, dz := 24) {
    ns := (dy < -dz) ? "North" : ((dy > dz) ? "South" : "")
    ew := (dx < -dz) ? "West"  : ((dx > dz) ? "East"  : "")
    if (ns != "" && ew != "")
        return ns "-" ew
    if (ns != "")
        return ns
    if (ew != "")
        return ew
    return "Center"
}

GetVectorInwardKeys(dxMs, dyMs) {
    keys := []
    if (Abs(dyMs) >= 140)
        keys.Push(dyMs < 0 ? "w" : "s")
    if (Abs(dxMs) >= 140)
        keys.Push(dxMs < 0 ? "a" : "d")
    if (keys.Length = 0) {
        if (Abs(dyMs) >= Abs(dxMs))
            keys.Push(dyMs < 0 ? "w" : "s")
        else
            keys.Push(dxMs < 0 ? "a" : "d")
    }
    return keys
}

GetPerpendicularPair(keys) {
    if (keys.Length = 1) {
        k := keys[1]
        if (k = "w" || k = "s")
            return {a: ["a"], b: ["d"]}
        return {a: ["w"], b: ["s"]}
    }
    hasW := (keys[1] = "w" || keys[2] = "w")
    hasD := (keys[1] = "d" || keys[2] = "d")
    hasS := (keys[1] = "s" || keys[2] = "s")
    hasA := (keys[1] = "a" || keys[2] = "a")
    if ((hasW && hasD) || (hasS && hasA))
        return {a: ["w", "a"], b: ["s", "d"]}
    return {a: ["w", "d"], b: ["s", "a"]}
}

IsNearBadSpot(x, y, badSpots) {
    for pt in badSpots {
        if (Abs(x - pt.x) <= 35 && Abs(y - pt.y) <= 35)
            return true
    }
    return false
}

ReturnUntilPrompt(keys, limitMs) {
    global running, microStepMs
    elapsed := 0

    for k in keys
        SendEvent("{" k " down}")

    while (running && elapsed < limitMs) {
        Sleep(microStepMs)
        elapsed += microStepMs

        if (elapsed >= 350 && IsOnWaystone()) {
            ReleaseMoveKeys()
            MarkWaystoneOrigin()
            return true
        }
    }

    ReleaseMoveKeys()
    if (IsOnWaystone()) {
        MarkWaystoneOrigin()
        return true
    }
    RecordMoveDisplacement(keys, elapsed)
    return false
}

PathToWaystoneSprite(badSpots := "", maxDurationMs := 3800) {
    global running, hudStatus, robloxWinBox, statueSearchBox, recoveryImg
    if (!running || !FileExist(recoveryImg))
        return false

    if !IsObject(badSpots)
        badSpots := []

    if (IsOnWaystone()) {
        ReleaseMoveKeys()
        MarkWaystoneOrigin()
        hudStatus := "Recovered Point 0!"
        return true
    }

    if !FindWaystoneStatue(&sx, &sy)
        return false

    if (IsNearBadSpot(sx, sy, badSpots))
        return false

    cx := (robloxWinBox.x1 + robloxWinBox.x2) // 2
    cy := (robloxWinBox.y1 + robloxWinBox.y2) // 2
    bounds := IsSet(statueSearchBox) ? statueSearchBox : robloxWinBox

    GetImageDimensions(recoveryImg, &rw, &rh)
    spriteW := (rw > 0) ? rw : 20
    spriteH := (rh > 0) ? rh : 20
    halfW   := spriteW // 2
    halfH   := spriteH // 2

    held := Map("w", false, "a", false, "s", false, "d", false)
    tickMs := 35
    elapsed := 0
    missedFrames := 0
    centeredTicks := 0

    anchorSx := sx
    anchorSy := sy
    anchorElapsed := 0

    while (running && elapsed < maxDurationMs) {
        if (IsOnWaystone()) {
            ReleaseMoveKeys()
            MarkWaystoneOrigin()
            hudStatus := "Recovered Point 0!"
            return true
        }

        localBox := {
            x1: Max(bounds.x1, sx - 120),
            y1: Max(bounds.y1, sy - 120),
            x2: Min(bounds.x2, sx + spriteW + 120),
            y2: Min(bounds.y2, sy + spriteH + 120)
        }

        found := FindWaystoneStatue(&nx, &ny, localBox)
        if (!found && Mod(missedFrames, 2) = 1)
            found := FindWaystoneStatue(&nx, &ny)

        if (found) {
            if (IsNearBadSpot(nx, ny, badSpots)) {
                ReleaseMoveKeys()
                return false
            }

            if (Abs(nx - sx) > 180 || Abs(ny - sy) > 180) {
                badSpots.Push({x: sx, y: sy})
                badSpots.Push({x: nx, y: ny})
                ReleaseMoveKeys()
                return false
            }

            sx := nx
            sy := ny
            missedFrames := 0

            if (elapsed - anchorElapsed >= 360) {
                isMoving := (held["w"] || held["a"] || held["s"] || held["d"])
                if (isMoving && Abs(sx - anchorSx) <= 5 && Abs(sy - anchorSy) <= 5) {
                    badSpots.Push({x: sx, y: sy})
                    ReleaseMoveKeys()
                    return false
                }
                anchorSx := sx
                anchorSy := sy
                anchorElapsed := elapsed
            }

            tx := sx + halfW
            ty := sy + halfH + 16

            dzA := held["a"] ? 14 : 24
            dzD := held["d"] ? 14 : 24
            dzW := held["w"] ? 14 : 24
            dzS := held["s"] ? 14 : 24

            want := Map(
                "w", (ty < cy - dzW),
                "s", (ty > cy + dzS),
                "a", (tx < cx - dzA),
                "d", (tx > cx + dzD)
            )

            SyncMoveKeys(held, want)

            if !(want["w"] || want["a"] || want["s"] || want["d"]) {
                centeredTicks += 1
                if (centeredTicks >= 3) {
                    ReleaseMoveKeys()
                    if (IsOnWaystone()) {
                        MarkWaystoneOrigin()
                        return true
                    }
                    return false
                }
            } else {
                centeredTicks := 0
                dirLabel := GetCompassDir(tx - cx, ty - cy, 24)
                hudStatus := "Waystone Detected " dirLabel " -> Smooth Pathing (" sx "," sy ")"
            }
        } else {
            missedFrames += 1
            if (missedFrames >= 8) {
                ReleaseMoveKeys()
                return false
            }
        }

        Sleep(tickMs)
        elapsed += tickMs
        RecordMoveDisplacement(GetActiveHeldKeysList(held), tickMs)

        if (IsOnWaystone()) {
            ReleaseMoveKeys()
            MarkWaystoneOrigin()
            hudStatus := "Recovered Point 0!"
            return true
        }
    }

    ReleaseMoveKeys()
    if (IsOnWaystone()) {
        MarkWaystoneOrigin()
        hudStatus := "Recovered Point 0!"
        return true
    }
    return false
}

WalkVectorToWaystone(dxMs, dyMs, labelPrefix, badSpots := "", maxBudgetMs := 3200) {
    global running, hudStatus
    if (!running)
        return true

    if !IsObject(badSpots)
        badSpots := []

    if (Abs(dxMs) < 130 && Abs(dyMs) < 130)
        return false

    dirLabel := GetCompassDir(dxMs, dyMs, 110)
    hudStatus := labelPrefix " (" dirLabel ")..."

    segments := []
    minAxis := Min(Abs(dxMs), Abs(dyMs))
    if (minAxis >= 130) {
        diagKeys := []
        diagKeys.Push(dyMs < 0 ? "w" : "s")
        diagKeys.Push(dxMs < 0 ? "a" : "d")
        diagDur := Min(maxBudgetMs, Round(minAxis / 0.7071))
        segments.Push({keys: diagKeys, dur: diagDur})
        maxBudgetMs -= diagDur

        movedAxis := diagDur * 0.7071
        remX := dxMs + (dxMs < 0 ? movedAxis : -movedAxis)
        remY := dyMs + (dyMs < 0 ? movedAxis : -movedAxis)
    } else {
        remX := dxMs
        remY := dyMs
    }

    if (maxBudgetMs > 120 && Abs(remX) >= 130) {
        segDur := Min(maxBudgetMs, Round(Abs(remX)))
        segments.Push({keys: [remX < 0 ? "a" : "d"], dur: segDur})
        maxBudgetMs -= segDur
    }
    if (maxBudgetMs > 120 && Abs(remY) >= 130) {
        segDur := Min(maxBudgetMs, Round(Abs(remY)))
        segments.Push({keys: [remY < 0 ? "w" : "s"], dur: segDur})
    }

    spritePollToggle := 0
    for seg in segments {
        if (!running) {
            ReleaseMoveKeys()
            return true
        }
        if (IsOnWaystone()) {
            ReleaseMoveKeys()
            MarkWaystoneOrigin()
            hudStatus := "Recovered Point 0!"
            return true
        }
        if (FindWaystoneStatue(&sx, &sy) && !IsNearBadSpot(sx, sy, badSpots)) {
            ReleaseMoveKeys()
            Sleep(25)
            if (PathToWaystoneSprite(badSpots))
                return true
        }

        moved := 0
        for k in seg.keys
            SendEvent("{" k " down}")

        while (running && moved < seg.dur) {
            chunk := Min(35, seg.dur - moved)
            Sleep(chunk)
            moved += chunk
            RecordMoveDisplacement(seg.keys, chunk)

            if (IsOnWaystone()) {
                ReleaseMoveKeys()
                MarkWaystoneOrigin()
                hudStatus := "Recovered Point 0!"
                return true
            }

            spritePollToggle := !spritePollToggle
            if (spritePollToggle && FindWaystoneStatue(&sx, &sy) && !IsNearBadSpot(sx, sy, badSpots)) {
                ReleaseMoveKeys()
                Sleep(25)
                if (PathToWaystoneSprite(badSpots))
                    return true
                if (!running || IsOnWaystone()) {
                    ReleaseMoveKeys()
                    if (IsOnWaystone())
                        MarkWaystoneOrigin()
                    return true
                }
                for k in seg.keys
                    SendEvent("{" k " down}")
            }
        }
        ReleaseMoveKeys()
    }

    if (IsOnWaystone()) {
        MarkWaystoneOrigin()
        hudStatus := "Recovered Point 0!"
        return true
    }
    return false
}

ExecuteObstacleDetour(inwardKeys, blockCount, badSpots) {
    global hudStatus
    perp := GetPerpendicularPair(inwardKeys)
    sideKeys := (Mod(blockCount, 2) = 1) ? perp.a : perp.b
    sideDur  := Min(1300, 550 + (blockCount * 200))

    hudStatus := "Obstacle Blocked! Detouring (" (Mod(blockCount, 2) = 1 ? "Left" : "Right") ")..."
    detourMoves := [
        {keys: sideKeys,   dur: sideDur},
        {keys: inwardKeys, dur: 600}
    ]
    return RunSearchSequence(detourMoves, true, badSpots)
}

ReturnTowardMarkedOrigin(badSpots := "") {
    global running, wayPosX, wayPosY, wayOriginMarked
    if (!running || !wayOriginMarked)
        return false

    dx := -wayPosX
    dy := -wayPosY
    recovered := WalkVectorToWaystone(dx, dy, "Backtracking to Marked Waystone", badSpots, 2200)
    if (!recovered)
        ClearWaystoneOrigin()
    return recovered
}

AntiTrapRecovery(inwardKeys := "", targetMapIdx := -1) {
    global running, recoveryCount, hudStatus, useWorldMapRecovery, mapArrowImg, mapWaystoneImg, mapMsPerPx
    global mapCycleMode, currentWaystoneIdx
    recoveryCount += 1
    badSpots := []

    if (targetMapIdx < 0 && mapCycleMode)
        targetMapIdx := currentWaystoneIdx

    if (IsOnWaystone()) {
        ReleaseMoveKeys()
        MarkWaystoneOrigin()
        hudStatus := "Recovered Point 0!"
        return
    }

    ; 1. Visual sprite lock if Waystone is already on screen
    if (FindWaystoneStatue(&sx, &sy) && !IsNearBadSpot(sx, sy, badSpots)) {
        hudStatus := "Recovery #" recoveryCount ": Waystone Detected -> Smooth Pathing..."
        if (PathToWaystoneSprite(badSpots))
            return
    }

    ; 2. World Map (M) Guided Loop using map_area + Progress-Based Obstacle Avoidance
    if (useWorldMapRecovery && FileExist(mapArrowImg) && FileExist(mapWaystoneImg)) {
        prevDistPx := -1.0
        blockCount := 0
        mapWorkedOnce := false

        Loop 5 {
            if (!running)
                return

            ReleaseMoveKeys()
            hudStatus := "Recovery #" recoveryCount ": Checking World Map (" A_Index "/5)..."
            scan := ScanWorldMapVector(targetMapIdx)
            if (!running)
                return

            if (!scan.ok)
                break

            mapWorkedOnce := true
            ClearWaystoneOrigin()

            dxMs := scan.dx * mapMsPerPx
            dyMs := scan.dy * mapMsPerPx
            distPx := Sqrt((scan.dx * scan.dx) + (scan.dy * scan.dy))
            inward := GetVectorInwardKeys(dxMs, dyMs)

            if (distPx <= 5) {
                hudStatus := "Near Waystone on Map -> Micro-Nudge..."
                microCheck := [
                    {keys: ["w"], dur: 220},
                    {keys: ["s"], dur: 440},
                    {keys: ["a"], dur: 220},
                    {keys: ["d"], dur: 440}
                ]
                if (RunSearchSequence(microCheck, true, badSpots))
                    return
                prevDistPx := distPx
                continue
            }

            if (prevDistPx > 0 && (prevDistPx - distPx) <= 3.5) {
                blockCount += 1
                if (ExecuteObstacleDetour(inward, blockCount, badSpots))
                    return
            } else {
                blockCount := 0
                if (WalkVectorToWaystone(dxMs, dyMs, "World Map Return", badSpots, 3200))
                    return
            }

            prevDistPx := distPx
        }

        if (mapWorkedOnce)
            return
    }

    ; 3. Fallback only if World Map PNGs are missing or scan didn't match
    if (ReturnTowardMarkedOrigin(badSpots))
        return

    hudStatus := "Recovery #" recoveryCount ": Local Check..."
    localSpiral := [
        {keys: ["w"], dur: 200},
        {keys: ["d"], dur: 200},
        {keys: ["s"], dur: 400},
        {keys: ["a"], dur: 400}
    ]
    RunSearchSequence(localSpiral, true, badSpots)
}

RunSearchSequence(moveList, allowSpriteLock := false, badSpots := "") {
    global running, hudStatus
    if !IsObject(badSpots)
        badSpots := []
    spriteCooldownUntil := 0
    spritePollToggle := 0

    for move in moveList {
        if (!running) {
            ReleaseMoveKeys()
            return true
        }
        if (IsOnWaystone()) {
            ReleaseMoveKeys()
            MarkWaystoneOrigin()
            hudStatus := "Recovered Point 0!"
            return true
        }
        if (allowSpriteLock && A_TickCount >= spriteCooldownUntil && FindWaystoneStatue(&sx, &sy) && !IsNearBadSpot(sx, sy, badSpots)) {
            ReleaseMoveKeys()
            Sleep(25)
            if (PathToWaystoneSprite(badSpots))
                return true
            spriteCooldownUntil := A_TickCount + 1000
            if (!running || IsOnWaystone()) {
                ReleaseMoveKeys()
                if (IsOnWaystone())
                    MarkWaystoneOrigin()
                return true
            }
        }

        moved := 0
        for k in move.keys
            SendEvent("{" k " down}")

        while (running && moved < move.dur) {
            chunk := Min(35, move.dur - moved)
            Sleep(chunk)
            moved += chunk
            RecordMoveDisplacement(move.keys, chunk)

            if (IsOnWaystone()) {
                ReleaseMoveKeys()
                MarkWaystoneOrigin()
                hudStatus := "Recovered Point 0!"
                return true
            }

            spritePollToggle := !spritePollToggle
            if (allowSpriteLock && spritePollToggle && A_TickCount >= spriteCooldownUntil && FindWaystoneStatue(&sx, &sy) && !IsNearBadSpot(sx, sy, badSpots)) {
                ReleaseMoveKeys()
                Sleep(25)
                if (PathToWaystoneSprite(badSpots))
                    return true
                spriteCooldownUntil := A_TickCount + 1000
                if (!running || IsOnWaystone()) {
                    ReleaseMoveKeys()
                    if (IsOnWaystone())
                        MarkWaystoneOrigin()
                    return true
                }
                for k in move.keys
                    SendEvent("{" k " down}")
            }
        }
        ReleaseMoveKeys()
    }
    return false
}

AltAntiAFK() {
    global running
    if (!running)
        return

    windows := GetSortedRobloxWindows()
    if (windows.Length <= 1)
        return

    mainHwnd := windows[1]
    Loop windows.Length - 1 {
        altHwnd := windows[A_Index + 1]
        if WinExist("ahk_id " altHwnd) {
            WinActivate("ahk_id " altHwnd)
            Sleep(60)
            SendEvent("{Space down}")
            Sleep(60)
            SendEvent("{Space up}")
            Sleep(40)
        }
    }
    if WinExist("ahk_id " mainHwnd) {
        WinActivate("ahk_id " mainHwnd)
    }
}

PathToPortalSprite(fromIdx, toIdx, recorded := "", maxDurationMs := 3400) {
    global running, hudStatus, robloxWinBox, statueSearchBox
    if (!running)
        return "STOP"

    if (IsMapTopLabel(toIdx) && !IsMapTopLabel(fromIdx))
        return "TARGET_MAP"

    if !FindPortalSprite(fromIdx, toIdx, &px, &py)
        return "NOT_FOUND"

    cx := (robloxWinBox.x1 + robloxWinBox.x2) // 2
    cy := (robloxWinBox.y1 + robloxWinBox.y2) // 2
    bounds := IsSet(statueSearchBox) ? statueSearchBox : robloxWinBox

    held := Map("w", false, "a", false, "s", false, "d", false)
    tickMs := 35
    elapsed := 0
    missedFrames := 0
    anchorPx := px
    anchorPy := py
    anchorElapsed := 0

    while (running && elapsed < maxDurationMs) {
        if (!IsMapTopLabel(fromIdx) && IsMapTopLabel(toIdx)) {
            ReleaseMoveKeys()
            return "TARGET_MAP"
        }

        localBox := {
            x1: Max(bounds.x1, px - 140),
            y1: Max(bounds.y1, py - 140),
            x2: Min(bounds.x2, px + 140),
            y2: Min(bounds.y2, py + 140)
        }

        found := FindPortalSprite(fromIdx, toIdx, &nx, &ny, localBox)
        if (!found && Mod(missedFrames, 2) = 1)
            found := FindPortalSprite(fromIdx, toIdx, &nx, &ny)

        if (found) {
            px := nx
            py := ny
            missedFrames := 0

            if (elapsed - anchorElapsed >= 420) {
                isMoving := (held["w"] || held["a"] || held["s"] || held["d"])
                if (isMoving && Abs(px - anchorPx) <= 5 && Abs(py - anchorPy) <= 5) {
                    ReleaseMoveKeys()
                    return "BLOCKED"
                }
                anchorPx := px
                anchorPy := py
                anchorElapsed := elapsed
            }

            dzA := held["a"] ? 12 : 20
            dzD := held["d"] ? 12 : 20
            dzW := held["w"] ? 12 : 20
            dzS := held["s"] ? 12 : 20

            want := Map(
                "w", (py < cy - dzW),
                "s", (py > cy + dzS),
                "a", (px < cx - dzA),
                "d", (px > cx + dzD)
            )
            SyncMoveKeys(held, want)

            if !(want["w"] || want["a"] || want["s"] || want["d"]) {
                ; Right on portal center: push gently toward target grid dir
                ReleaseMoveKeys()
                return "CENTERED"
            }
            hudStatus := "Portal Detected -> Pathing to WS #" toIdx " (" px "," py ")"
        } else {
            missedFrames += 1
            if (missedFrames >= 7) {
                ReleaseMoveKeys()
                if (!IsMapTopLabel(fromIdx) && IsMapTopLabel(toIdx))
                    return "TARGET_MAP"
                return "LOST"
            }
        }

        Sleep(tickMs)
        elapsed += tickMs
        activeList := GetActiveHeldKeysList(held)
        RecordMoveDisplacement(activeList, tickMs)
        if IsObject(recorded) && activeList.Length > 0
            recorded.Push({keys: activeList, ms: tickMs})
    }

    ReleaseMoveKeys()
    if (!IsMapTopLabel(fromIdx) && IsMapTopLabel(toIdx))
        return "TARGET_MAP"
    return "DONE"
}