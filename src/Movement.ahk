; ==============================================================================
; CHARACTER MOVEMENT, HOMING, RECOVERY & ALT ANTI-AFK
; ==============================================================================

HoldKeys(keys, duration) {
    for k in keys
        SendEvent("{" k " down}")
    Sleep(duration)
    ReleaseMoveKeys()
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
            return true
        }
    }

    ReleaseMoveKeys()
    return IsOnWaystone()
}

PathToWaystoneSprite(badSpots := "", maxDurationMs := 3200) {
    global running, hudStatus, robloxWinBox, statueSearchBox, recoveryImg
    if (!running || !FileExist(recoveryImg))
        return false

    if !IsObject(badSpots)
        badSpots := []

    if (IsOnWaystone()) {
        ReleaseMoveKeys()
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
    tickMs := 40
    elapsed := 0
    missedFrames := 0
    centeredTicks := 0

    anchorSx := sx
    anchorSy := sy
    anchorElapsed := 0

    while (running && elapsed < maxDurationMs) {
        if (IsOnWaystone()) {
            ReleaseMoveKeys()
            hudStatus := "Recovered Point 0!"
            return true
        }

        localBox := {
            x1: Max(bounds.x1, sx - 140),
            y1: Max(bounds.y1, sy - 140),
            x2: Min(bounds.x2, sx + spriteW + 140),
            y2: Min(bounds.y2, sy + spriteH + 140)
        }

        found := FindWaystoneStatue(&nx, &ny, localBox)
        if (!found)
            found := FindWaystoneStatue(&nx, &ny)

        if (found) {
            if (IsNearBadSpot(nx, ny, badSpots)) {
                ReleaseMoveKeys()
                return false
            }

            ; Reject erratic cross-screen false-positive jumps
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
            ty := sy + halfH

            dzA := held["a"] ? 16 : 26
            dzD := held["d"] ? 16 : 26
            dzW := held["w"] ? 16 : 26
            dzS := held["s"] ? 16 : 26

            want := Map(
                "w", (ty < cy - dzW),
                "s", (ty > cy + dzS),
                "a", (tx < cx - dzA),
                "d", (tx > cx + dzD)
            )

            SyncMoveKeys(held, want)

            if !(want["w"] || want["a"] || want["s"] || want["d"]) {
                centeredTicks += 1
                if (centeredTicks >= 4) {
                    badSpots.Push({x: sx, y: sy})
                    ReleaseMoveKeys()
                    return IsOnWaystone()
                }
            } else {
                centeredTicks := 0
                dirLabel := GetCompassDir(tx - cx, ty - cy, 24)
                hudStatus := "Waystone Detected " dirLabel " -> Smooth Pathing (" sx "," sy ")"
            }
        } else {
            missedFrames += 1
            if (missedFrames >= 7) {
                ReleaseMoveKeys()
                return false
            }
        }

        Sleep(tickMs)
        elapsed += tickMs
    }

    ReleaseMoveKeys()
    if (IsOnWaystone()) {
        hudStatus := "Recovered Point 0!"
        return true
    }
    badSpots.Push({x: sx, y: sy})
    return false
}

AntiTrapRecovery() {
    global running, recoveryCount, hudStatus
    recoveryCount += 1
    badSpots := []

    if (IsOnWaystone()) {
        ReleaseMoveKeys()
        hudStatus := "Recovered Point 0!"
        return
    }

    ; Only try Waystone smooth pathing at start if sprite is detected
    if (FindWaystoneStatue(&sx, &sy) && !IsNearBadSpot(sx, sy, badSpots)) {
        hudStatus := "Recovery #" recoveryCount ": Waystone Detected -> Smooth Pathing..."
        if (PathToWaystoneSprite(badSpots))
            return
    }

    ; Default recovery runs uninterrupted to get clear of trees/fences
    hudStatus := "Recovery #" recoveryCount ": Default Local Spiral..."
    localSpiral := [
        {keys: ["w"], dur: 240},
        {keys: ["d"], dur: 240},
        {keys: ["s"], dur: 480},
        {keys: ["a"], dur: 480},
        {keys: ["w"], dur: 720},
        {keys: ["d"], dur: 720}
    ]
    if (RunSearchSequence(localSpiral, false, badSpots))
        return

    hudStatus := "Recovery #" recoveryCount ": Default Fence/Tree Escape!"
    escapeMoves := [
        {keys: ["s", "a"], dur: 1100},
        {keys: ["s"],      dur: 1100},
        {keys: ["s", "d"], dur: 900},
        {keys: ["w", "d"], dur: 700},
        {keys: ["w", "a"], dur: 700}
    ]
    if (RunSearchSequence(escapeMoves, false, badSpots))
        return

    hudStatus := "Recovery #" recoveryCount ": Default Wide Sweep..."
    wideSweep := [
        {keys: ["s"], dur: 1400},
        {keys: ["a"], dur: 1400},
        {keys: ["w"], dur: 1800},
        {keys: ["d"], dur: 1800}
    ]
    RunSearchSequence(wideSweep, true, badSpots)
}

RunSearchSequence(moveList, allowSpriteLock := false, badSpots := "") {
    global running, hudStatus
    if !IsObject(badSpots)
        badSpots := []
    spriteCooldownUntil := 0

    for move in moveList {
        if (!running) {
            ReleaseMoveKeys()
            return true
        }
        if (IsOnWaystone()) {
            ReleaseMoveKeys()
            hudStatus := "Recovered Point 0!"
            return true
        }
        if (allowSpriteLock && A_TickCount >= spriteCooldownUntil && FindWaystoneStatue(&sx, &sy) && !IsNearBadSpot(sx, sy, badSpots)) {
            ReleaseMoveKeys()
            Sleep(25)
            if (PathToWaystoneSprite(badSpots))
                return true
            spriteCooldownUntil := A_TickCount + 1200
            if (!running || IsOnWaystone()) {
                ReleaseMoveKeys()
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

            if (IsOnWaystone()) {
                ReleaseMoveKeys()
                hudStatus := "Recovered Point 0!"
                return true
            }
            if (allowSpriteLock && A_TickCount >= spriteCooldownUntil && FindWaystoneStatue(&sx, &sy) && !IsNearBadSpot(sx, sy, badSpots)) {
                ReleaseMoveKeys()
                Sleep(25)
                if (PathToWaystoneSprite(badSpots))
                    return true
                spriteCooldownUntil := A_TickCount + 1200
                if (!running || IsOnWaystone()) {
                    ReleaseMoveKeys()
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