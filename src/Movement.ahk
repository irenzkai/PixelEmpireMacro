; ==============================================================================
; QPC MICROSECOND MOVEMENT, ORIGIN TRACKING & SMOOTH RECOVERY
; ==============================================================================

GetQpcMs() {
    static freq := 0
    if (freq = 0)
        DllCall("QueryPerformanceFrequency", "int64*", &freq)
    cnt := 0
    DllCall("QueryPerformanceCounter", "int64*", &cnt)
    return (cnt * 1000.0) / freq
}

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

HoldKeys(keys, duration, legLabel := "", session := 0, prompt := 0) {
    global running
    ; F8 owns a continuous key session across direction changes. Other callers
    ; retain their existing single-leg release behavior.
    if IsObject(session)
        return F8HoldKeys(session, keys, duration, prompt)
    if (!running || duration <= 0 || keys.Length = 0)
        return
    if (!WinActive("ahk_exe RobloxPlayerBeta.exe"))
        return

    tStart := GetQpcMs()
    actualMs := 0.0
    try {
        for k in keys
            SendEvent("{" k " down}")
        while (running) {
            elapsed := GetQpcMs() - tStart
            if (elapsed >= duration)
                break
            if (!WinActive("ahk_exe RobloxPlayerBeta.exe"))
                break
            rem := duration - elapsed
            Sleep(Max(1, Min(20, Floor(rem))))
        }
    } finally {
        ReleaseMoveKeys()
        actualMs := GetQpcMs() - tStart
    }
    RecordMoveDisplacement(keys, actualMs)
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

ReturnUntilPrompt(keys, limitMs, session := 0) {
    if IsObject(session)
        return HoldKeys(keys, limitMs, "", session, true)
    if (IsOnWaystone()) {
        MarkWaystoneOrigin()
        return true
    }
    found := ContinuousWaystoneMove(keys, limitMs, true)
    if (found)
        MarkWaystoneOrigin()
    return found
}

; Smooth continuous key hold with QPC timing + crash-proof async prompt check
ContinuousWaystoneMove(keys, limitMs, stopOnPrompt := false) {
    global running, ocrServerUrl, microStepMs

    if (!stopOnPrompt) {
        HoldKeys(keys, limitMs)
        return false
    }

    if (!running || limitMs <= 0 || keys.Length = 0)
        return false
    if (!WinActive("ahk_exe RobloxPlayerBeta.exe"))
        return false

    useOcr := OcrServerReady()
    req := 0
    nextPoll := 60.0
    tStart := 0.0
    try {
        for k in keys
            SendEvent("{" k " down}")
        tStart := GetQpcMs()

        while (running) {
            elapsed := GetQpcMs() - tStart
            if (elapsed >= limitMs)
                break
            if (!WinActive("ahk_exe RobloxPlayerBeta.exe"))
                return false

            if (useOcr) {
                if (!req && elapsed >= nextPoll) {
                    try {
                        req := ComObject("WinHttp.WinHttpRequest.5.1")
                        req.SetProxy(1)
                        req.SetTimeouts(250, 250, 1000, 2500)
                        req.Open("GET", ocrServerUrl "/waystone_fast?format=ahk", true)
                        req.Send()
                    } catch {
                        if (req)
                            try req.Abort()
                        req := 0
                        nextPoll := elapsed + 160
                    }
                }
                if (req) {
                    ready := false
                    try {
                        ready := req.WaitForResponse(0)
                    } catch {
                        try req.Abort()
                        req := 0
                        nextPoll := elapsed + 160
                    }
                    if (ready) {
                        hit := false
                        try {
                            hit := (req.Status = 200 && RegExMatch(req.ResponseText, "m)^on_waystone=1\r?$"))
                        } catch {
                            hit := false
                        }
                        if (hit)
                            return true
                        req := 0
                        nextPoll := elapsed + 80
                    }
                }
                rem := limitMs - (GetQpcMs() - tStart)
                if (rem <= 0)
                    break
                Sleep(Max(1, Min(20, Floor(rem))))
            } else {
                rem := limitMs - elapsed
                Sleep(Max(1, Min(microStepMs, Floor(rem))))
                if ((GetQpcMs() - tStart) >= 60 && IsOnWaystone())
                    return true
            }
        }
        return false
    } finally {
        ReleaseMoveKeys()
        if (tStart > 0)
            RecordMoveDisplacement(keys, GetQpcMs() - tStart)
        if (req)
            try req.Abort()
    }
}

PathToWaystoneSprite(badSpots := "", maxDurationMs := 5000, session := 0) {
    global running, hudStatus, robloxWinBox, recoveryImg, lastWaystoneWidth, lastWaystoneHeight
    if IsObject(session)
        return F8ApproachLive(session, GetQpcMs() + Max(0, maxDurationMs))
    if (!running)
        return false
    if !IsObject(badSpots)
        badSpots := []

    tStart := GetQpcMs()
    lastStep := tStart
    lastPromptTick := 0.0
    missCount := 0
    held := Map("w", false, "a", false, "s", false, "d", false)
    cx := (robloxWinBox.x1 + robloxWinBox.x2) // 2
    cy := (robloxWinBox.y1 + robloxWinBox.y2) // 2 + 22
    width := robloxWinBox.x2 - robloxWinBox.x1
    height := robloxWinBox.y2 - robloxWinBox.y1
    localBox := {
        x1: robloxWinBox.x1 + Round(width * 0.25),
        y1: robloxWinBox.y1 + Round(height * 0.12),
        x2: robloxWinBox.x1 + Round(width * 0.75),
        y2: robloxWinBox.y1 + Round(height * 0.75)
    }

    hudStatus := "Waystone Sprite Lock -> Approaching..."
    try {
        while (running && (GetQpcMs() - tStart) < maxDurationMs) {
            if (!WinActive("ahk_exe RobloxPlayerBeta.exe"))
                return false

            now := GetQpcMs()
            dt := now - lastStep
            lastStep := now
            activeKeys := GetActiveHeldKeysList(held)
            if (activeKeys.Length > 0 && dt > 0)
                RecordMoveDisplacement(activeKeys, dt)

            if (now - lastPromptTick >= 100) {
                lastPromptTick := now
                if IsOnWaystone() {
                    MarkWaystoneOrigin()
                    hudStatus := "Recovered Point 0!"
                    return true
                }
            }

            if !FindWaystoneStatue(&sx, &sy, localBox) {
                ; Pending/uncertain vision is not a fresh steering target.
                ReleaseMoveKeys()
                held := Map("w", false, "a", false, "s", false, "d", false)
                missCount += 1
                if (missCount >= 4)
                    return false
                Sleep(25)
                continue
            }
            if IsNearBadSpot(sx, sy, badSpots)
                return false
            missCount := 0

            ; Use the matched frame body, never the dimensions of the animation strip.
            sw := lastWaystoneWidth, sh := lastWaystoneHeight
            dx := sx + (sw // 2) - cx
            dy := sy + (sh // 2) + 16 - cy

            want := Map("w", false, "a", false, "s", false, "d", false)
            if (Abs(dx) > 18)
                want[dx < 0 ? "a" : "d"] := true
            if (Abs(dy) > 18)
                want[dy < 0 ? "w" : "s"] := true

            if (!want["w"] && !want["a"] && !want["s"] && !want["d"]) {
                ReleaseMoveKeys()
                held := Map("w", false, "a", false, "s", false, "d", false)
                if IsOnWaystone() {
                    MarkWaystoneOrigin()
                    hudStatus := "Recovered Point 0!"
                    return true
                }
                return false
            }

            SyncMoveKeys(held, want)
            Sleep(20)
        }
        return IsOnWaystone()
    } finally {
        ReleaseMoveKeys()
    }
}

WalkVectorToWaystone(dxMs, dyMs, labelPrefix, badSpots := "", maxBudgetMs := 2800) {
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
        diagDur := Min(maxBudgetMs, Round(minAxis * 1.41421356))
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
            if (PathToWaystoneSprite(badSpots))
                return true
        }

        if (ContinuousWaystoneMove(seg.keys, seg.dur, true)) {
            MarkWaystoneOrigin()
            hudStatus := "Recovered Point 0!"
            return true
        }
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

AntiTrapRecovery(inwardKeys := "", targetMapIdx := -1, session := 0) {
    global running, recoveryCount, hudStatus, useWorldMapRecovery, mapArrowImg, mapWaystoneImg, mapMsPerPx
    global mapCycleMode, currentWaystoneIdx
    if IsObject(session)
        return F8Recover(session)
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

    ; 1. Immediate live statue lock if visible
    if (FindWaystoneStatue(&sx, &sy) && !IsNearBadSpot(sx, sy, badSpots)) {
        hudStatus := "Recovery #" recoveryCount ": Waystone Detected -> Smooth Pathing..."
        if (PathToWaystoneSprite(badSpots))
            return
    }

    ; 2. Smooth World Map (M) Vector Loop (uses OCR/HSV when available, PNG fallback otherwise)
    canUseMap := useWorldMapRecovery && (OcrServerReady() || (FileExist(mapArrowImg) && FileExist(mapWaystoneImg)))
    if (canUseMap) {
        if (targetMapIdx < 0 && OcrServerReady())
            targetMapIdx := OcrDetectCurrentMap()

        prevDistPx := -1.0
        blockCount := 0
        Loop 6 {
            if (!running)
                return

            ReleaseMoveKeys()
            hudStatus := "Recovery #" recoveryCount ": World Map Vector (" A_Index "/6)..."
            scan := ScanWorldMapVector(targetMapIdx)
            if (!running)
                return
            if (!scan.ok)
                break

            ClearWaystoneOrigin()
            dxMs := scan.dx * mapMsPerPx
            dyMs := scan.dy * mapMsPerPx
            distPx := Sqrt((scan.dx * scan.dx) + (scan.dy * scan.dy))
            inward := GetVectorInwardKeys(dxMs, dyMs)

            if (distPx <= 5) {
                ; Map overlap alone is not arrival: recheck the live ward prompt first.
                if IsOnWaystone() {
                    MarkWaystoneOrigin()
                    hudStatus := "Waystone ward prompt confirmed after map overlap"
                    return
                }
                if (FindWaystoneStatue(&sx, &sy) && PathToWaystoneSprite(badSpots, 4000))
                    return
                break
            }

            if (prevDistPx > 0 && (prevDistPx - distPx) <= 3.0) {
                blockCount += 1
                if (ExecuteObstacleDetour(inward, blockCount, badSpots))
                    return
            } else {
                blockCount := 0
                if (WalkVectorToWaystone(dxMs, dyMs, "World Map Return", badSpots, 2800))
                    return
            }
            prevDistPx := distPx
        }
    }

    ; 3. Marked-origin inverse vector
    if (ReturnTowardMarkedOrigin(badSpots))
        return

    ; 4. Smooth continuous spiral -> fence/tree escape -> wide sweep (from your basis)
    hudStatus := "Recovery #" recoveryCount ": Local Spiral..."
    localSpiral := [
        {keys: ["w"], dur: 240},
        {keys: ["d"], dur: 240},
        {keys: ["s"], dur: 480},
        {keys: ["a"], dur: 480},
        {keys: ["w"], dur: 720},
        {keys: ["d"], dur: 720}
    ]
    if (RunSearchSequence(localSpiral, true, badSpots))
        return

    hudStatus := "Recovery #" recoveryCount ": Fence/Tree Escape!"
    escapeMoves := [
        {keys: ["s", "a"], dur: 1100},
        {keys: ["s"],      dur: 1100},
        {keys: ["s", "d"], dur: 900},
        {keys: ["w", "d"], dur: 700},
        {keys: ["w", "a"], dur: 700}
    ]
    if (RunSearchSequence(escapeMoves, true, badSpots))
        return

    hudStatus := "Recovery #" recoveryCount ": Wide Homing Sweep..."
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
        if (allowSpriteLock && FindWaystoneStatue(&sx, &sy) && !IsNearBadSpot(sx, sy, badSpots)) {
            if (PathToWaystoneSprite(badSpots, 4000))
                return true
        }

        if (ContinuousWaystoneMove(move.keys, move.dur, true)) {
            MarkWaystoneOrigin()
            hudStatus := "Recovered Point 0!"
            return true
        }
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

PathToPortalSprite(fromIdx, toIdx, recorded := "", maxDurationMs := 12000) {
    global running, hudStatus, portalPlayerX, portalPlayerY
    deadline := A_TickCount + maxDurationMs
    try {
        while (running && A_TickCount < deadline) {
            if !WinActive("ahk_exe RobloxPlayerBeta.exe")
                return "FOCUS_LOST"
            ReleaseMoveKeys()
            if IsMapTopLabel(toIdx)
                return "TARGET_MAP"
            if !FindPortalSprite(fromIdx, toIdx, &px, &py)
                return "LOST"
            if (!IsSet(portalPlayerX) || !portalPlayerX || !portalPlayerY) {
                hudStatus := "Portal candidate; player anchor uncertain -> stop visual steering"
                return "PLAYER_UNKNOWN"
            }
            dx := px - portalPlayerX
            dy := py - portalPlayerY
            keys := []
            if (Abs(dx) > 25)
                keys.Push(dx < 0 ? "a" : "d")
            if (Abs(dy) > 25)
                keys.Push(dy < 0 ? "w" : "s")
            if (keys.Length = 0)
                return "CENTERED"
            hudStatus := "Portal -> WS #" toIdx " target (" px "," py ")"
            duration := Min(200, Max(50, Round(Max(Abs(dx), Abs(dy)) / 0.4)))
            HoldKeys(keys, duration)
            if IsObject(recorded)
                recorded.Push({keys: keys.Clone(), ms: duration})
        }
        return IsMapTopLabel(toIdx) ? "TARGET_MAP" : "TIMEOUT"
    } finally {
        ReleaseMoveKeys()
    }
}
; F8 transport and movement stay in the main AHK runtime. No synchronous vision
; calls are permitted while keys are down. Every wait yields at most 15ms.
class F8VisionRequest {
    __New(endpoint, timeoutMs := 900) {
        global ocrServerUrl
        this.req := 0
        this.started := GetQpcMs()
        this.timeout := timeoutMs
        this.done := false
        this.error := ""
        this.lastPending := this.started
        this.responseDelayBound := 0
        try {
            this.req := ComObject("WinHttp.WinHttpRequest.5.1")
            this.req.SetProxy(1)
            this.req.SetTimeouts(100, 100, 250, timeoutMs)
            sep := InStr(endpoint, "?") ? "&" : "?"
            this.req.Open("GET", ocrServerUrl endpoint sep "format=ahk", true)
            this.req.Send()
        } catch as err {
            this.error := err.Message
            this.Cancel()
            this.done := true
        }
    }
    Poll() {
        kv := Map()
        if this.done
            return this.error != "" ? Map("error", this.error) : kv
        try {
            if (GetQpcMs() - this.started > this.timeout) {
                kv["error"] := "Vision request timed out after " this.timeout "ms"
                this.done := true
            } else if this.req.WaitForResponse(0) {
                ; The response arrived after the previous unfinished poll. Only
                ; this gap, not the full round trip, can add to server capture age.
                this.responseDelayBound := GetQpcMs() - this.lastPending
                this.done := true
                if (this.req.Status = 200) {
                    for line in StrSplit(this.req.ResponseText, "`n", "`r") {
                        pos := InStr(line, "=")
                        if (pos > 0)
                            kv[SubStr(line, 1, pos - 1)] := SubStr(line, pos + 1)
                    }
                } else {
                    kv["error"] := "Vision HTTP " this.req.Status
                }
            } else {
                this.lastPending := GetQpcMs()
            }
        } catch as err {
            kv["error"] := err.Message
            this.done := true
        }
        if this.done
            this.Cancel()
        return kv
    }
    Cancel() {
        if this.req
            try this.req.Abort()
        this.req := 0
    }
}

F8Alive(session) {
    global running, f8Session
    return running && session = f8Session && WinActive("ahk_id " session.hwnd)
}

F8PromptHit(kv) {
    ; Accept the established prompt detector result without requiring new metadata.
    return kv.Has("ok") && kv["ok"] = "1" && kv.Has("on_waystone")
        && kv["on_waystone"] = "1"
}

F8SetStatus(text, state := "RUNNING") {
    global hudStatus, overlayStatusTxt
    hudStatus := text
    if IsSet(overlayStatusTxt)
        overlayStatusTxt.Text := text
    F8PublishStatus(state)
}

F8RecordStart() {
    global f8Record, promptImg, imgTolerance, wideStarMode, shortCfg, wideCfg, f8Build, fastMapTemplateInitMs
    name := "f8-record-" A_NowUTC "-" A_TickCount ".log"
    f8Record := {active: true, path: A_ScriptDir "\.task-output\" name,
        start: GetQpcMs(), events: 0, snapshot: ""}
    try {
        FileAppend("F8 runtime record | UTC " FormatTime(A_NowUTC, "yyyy-MM-dd HH:mm:ss") "`n", f8Record.path, "UTF-8")
        file := FileOpen(A_ScriptDir "\.task-output\f8_record_latest.txt", "w", "UTF-8")
        file.Write(name)
        file.Close()
    }
    cfg := wideStarMode ? wideCfg : shortCfg
    F8RecordEvent("RUNTIME", "build=" f8Build " pid=" DllCall("GetCurrentProcessId") " source=" A_ScriptFullPath)
    F8RecordEvent("START", "preset=" (wideStarMode ? "WIDE" : "SHORT")
        " up=" cfg.up " down=" cfg.down " left=" cfg.left " right=" cfg.right
        " diag=" cfg.diag " return=" cfg.ret)
    F8RecordEvent("MAP_TEMPLATE_CACHE", "startup_decode_prepare_ms=" Round(fastMapTemplateInitMs,2))
    F8RecordEvent("REFERENCE", "ward=" promptImg " exists=" (FileExist(promptImg) ? 1 : 0) " tolerance=" imgTolerance)
}

F8RecordEvent(kind, detail) {
    global f8Record
    if (!IsObject(f8Record) || !f8Record.active)
        return
    ; Bound diagnostics without adding a timer, screen capture, or input source.
    if (f8Record.events > 2048)
        return
    f8Record.events += 1
    if (f8Record.events = 2049)
        detail := "Record event limit reached; automation state is unaffected", kind := "LIMIT"
    elapsed := Round(GetQpcMs() - f8Record.start)
    line := elapsed "ms | " kind " | " SubStr(StrReplace(StrReplace(detail, "`r", " "), "`n", " / "), 1, 1200) "`n"
    try FileAppend(line, f8Record.path, "UTF-8")
}

F8RecordStop(reason) {
    global f8Record, f8Session
    if (!IsObject(f8Record) || !f8Record.active)
        return
    detail := reason " | key releases sent"
    if IsObject(f8Session)
        detail .= (" | ward=" f8Session.wardState " checked=" f8Session.wardChecked
            " error=" f8Session.wardError " phase=" f8Session.phase)
    F8RecordEvent("STOP", detail)
    f8Record.active := false
}

F8PublishStatus(state := "RUNNING") {
    global hudStatus, f8Session, overlayHintTxt, f8Record
    static previous := ""
    ward := IsObject(f8Session) ? f8Session.wardState : "stopped"
    if (IsObject(f8Session) && f8Session.lastWardConfirm > 0 && GetQpcMs() - f8Session.lastWardConfirm < 650)
        ward := "CONFIRMED #" f8Session.wardConfirmations
    keys := IsObject(f8Session) ? GetActiveHeldKeysList(f8Session.held) : []
    keyText := ""
    for k in keys
        keyText .= (keyText = "" ? "" : "+") k
    latency := IsObject(f8Session) && f8Session.wardMs >= 0 ? " (" f8Session.wardMs "ms)" : ""
    detail := "Ward: " ward latency " | Keys: " (keyText = "" ? "released" : keyText)
    if IsSet(overlayHintTxt)
        overlayHintTxt.Text := detail
    content := "state=" state "`naction=" StrReplace(StrReplace(hudStatus, "`r", " "), "`n", " ") "`ndetail=" detail "`n"
    if (IsObject(f8Record) && f8Record.active) {
        snapshot := state " | " hudStatus " | " ward " | keys=" keyText
        if (snapshot != f8Record.snapshot) {
            f8Record.snapshot := snapshot
            F8RecordEvent("STATUS", snapshot " | local_check_ms=" (IsObject(f8Session) ? f8Session.wardMs : -1)
                " | foreground_hwnd=" WinActive("A"))
        }
    }
    if (content = previous)
        return
    try {
        file := FileOpen(A_ScriptDir "\.task-output\runtime_status.tmp", "w", "UTF-8")
        file.Write(content)
        file.Close()
        FileMove(A_ScriptDir "\.task-output\runtime_status.tmp", A_ScriptDir "\.task-output\runtime_status.ini", 1)
        previous := content
    }
}

F8WaitVision(session, endpoint, timeoutMs := 900) {
    F8RecordEvent("VISION_REQUEST", endpoint " timeout_ms=" timeoutMs)
    req := F8VisionRequest(endpoint, timeoutMs)
    try {
        while F8Alive(session) {
            kv := req.Poll()
            if req.done {
                detail := ""
                for key in ["ok", "error", "reason", "state", "open", "map_ws", "arrow_found", "way_found", "dx", "dy", "ms", "capture_ms", "viewport_ms", "registration_ms", "identity_ms", "matching_ms", "registration_cache", "cache_validation_ms", "cache_prepare_ms", "icon_search"] {
                    if kv.Has(key)
                        detail .= key "=" kv[key] " "
                }
                F8RecordEvent("VISION_RESULT", detail)
                return kv
            }
            Sleep(15)
        }
        return Map()
    } finally {
        req.Cancel()
    }
}

F8Release(session) {
    global f8Session
    if (session != f8Session)
        return
    ReleaseMoveKeys()
    session.held := Map("w", false, "a", false, "s", false, "d", false)
}

F8CreateSession() {
    global f8Record, searchBox, robloxWinBox, mapOpen
    if (!IsObject(f8Record) || !f8Record.active)
        F8RecordStart()
    F8RecordEvent("WINDOW", "hwnd=" WinActive("ahk_exe RobloxPlayerBeta.exe")
        " prompt_box=" searchBox.x1 "," searchBox.y1 "," searchBox.x2 "," searchBox.y2
        " client=" robloxWinBox.x1 "," robloxWinBox.y1 "," robloxWinBox.x2 "," robloxWinBox.y2)
    return {held: Map("w", false, "a", false, "s", false, "d", false), ready: false,
        reason: "", hwnd: WinActive("ahk_exe RobloxPlayerBeta.exe"),
        token: A_TickCount "-" Random(100000, 999999), phase: 0,
        wardReq: 0, wardNext: 0, wardSeen: false, wardState: "starting", wardAge: -1, wardMs: -1,
        wardConfirmations: 0, lastWardConfirm: 0, wardLocalNext: 0,
        wardChecked: false, wardError: "", promptWait: false,
        mapOpen: mapOpen, mapCloseAttempts: 0, mapFastOpenConfirmed: false, mapCycleStarted: 0,
        mapTimingPending: false, mapClosedAt: 0}
}

F8ConfirmWard(session) {
    global mapOpen
    if mapOpen
        return
    session.wardConfirmations += 1
    session.lastWardConfirm := GetQpcMs()
    F8RecordEvent("WARD_CONFIRMED", "phase=" session.phase " count=" session.wardConfirmations " source=" session.wardState)
    MarkWaystoneOrigin()
    F8PublishStatus()
}

F8WardBegin(session) {
    if session.wardReq
        session.wardReq.Cancel()
    session.wardReq := 0
    session.phase += 1
    session.wardNext := 0
    session.wardLocalNext := 0
    session.wardSeen := false
    session.wardChecked := false
    session.wardState := "checking"
    session.wardError := ""
    session.wardAge := -1
}

F8WardPoll(session) {
    global promptImg, mapOpen, mapViewEpoch
    if mapOpen
        return false
    observedEpoch := mapViewEpoch
    now := GetQpcMs()
    if !F8Alive(session)
        return false
    ; This is exactly IsOnWaystone's approved native-image fallback, without
    ; making its synchronous HTTP call. No new matcher, ROI, scale or threshold.
    if (now >= session.wardLocalNext) {
        started := GetQpcMs()
        found := IsOnWaystone(&px, &py, true)
        if (mapOpen || observedEpoch != mapViewEpoch)
            return false
        session.wardMs := Round(GetQpcMs() - started)
        session.wardLocalNext := GetQpcMs() + 25
        if (found && F8Alive(session)) {
            session.wardSeen := true
            session.wardChecked := true
            session.wardState := "FOUND (saved ward image)"
            F8PublishStatus()
            return true
        }
        session.wardState := FileExist(promptImg) ? "not visible (ward image)" : "ward reference missing"
    }
    ; During motion use the established local image check only. No OCR backlog
    ; or network response is needed to catch the short-lived prompt.
    if !session.promptWait {
        F8PublishStatus()
        return session.wardSeen
    }
    ; Also preserve the complete approved /waystone_fast result (including its
    ; configured-region/semantic fallback), asynchronously. It need not contain
    ; the evidence field introduced by the rejected F8-only path.
    if (!session.wardReq && now >= session.wardNext)
        session.wardReq := F8VisionRequest("/waystone_fast", session.promptWait ? 3000 : 650)
    if session.wardReq {
        request := session.wardReq
        kv := request.Poll()
        if (mapOpen || observedEpoch != mapViewEpoch)
            return false
        if request.done {
            age := GetQpcMs() - request.started
            detail := "elapsed_ms=" Round(age) " "
            for key in ["ok", "on_waystone", "evidence", "ms", "text", "error"] {
                if kv.Has(key)
                    detail .= key "=" kv[key] " "
            }
            F8RecordEvent("PROMPT_HTTP", detail)
            session.wardReq := 0
            session.wardNext := GetQpcMs() + 100
            if (kv.Has("ok") && kv["ok"] = "1" && kv.Has("on_waystone")) {
                ; An old response cannot steer a moving character. Startup is
                ; stationary, so allow the approved check its normal time budget.
                if (session.promptWait || age <= 350) {
                    session.wardChecked := true
                    if F8PromptHit(kv) {
                        session.wardSeen := true
                        session.wardState := "FOUND (approved prompt check)"
                    } else {
                        session.wardState := "not visible"
                    }
                }
            } else {
                session.wardError := kv.Has("error") ? kv["error"] : "vision request timed out or failed"
                session.wardState := "check unavailable"
            }
            F8PublishStatus()
        }
    }
    return session.wardSeen
}

F8HoldKeys(session, keys, duration, prompt := 0) {
    want := Map("w", false, "a", false, "s", false, "d", false)
    for k in keys
        want[k] := true
    if !F8Alive(session)
        return false
    F8WardBegin(session)
    SyncMoveKeys(session.held, want)
    started := GetQpcMs()
    F8RecordEvent("MOVE", "planned_ms=" duration " phase=" session.phase " stop_on_prompt=" prompt)
    hit := false
    try {
        while (F8Alive(session) && GetQpcMs() - started < duration) {
            ; Sample outward too, but only the current return phase may end a leg.
            seen := F8WardPoll(session)
            if (prompt && seen) {
                hit := true
                break
            }
            Sleep(Max(1, Min(10, Floor(duration - (GetQpcMs() - started)))))
        }
    } finally {
        F8RecordEvent("MOVE_END", "elapsed_ms=" Round(GetQpcMs() - started) " prompt_hit=" hit " active=" (F8Alive(session) ? 1 : 0))
        RecordMoveDisplacement(keys, GetQpcMs() - started)
        if !F8Alive(session)
            F8Release(session)
    }
    ; Keep keys held on success: the next direction synchronizes only changes.
    if hit
        F8ConfirmWard(session)
    return hit
}

F8CheckPrompt(session, budget := 750, newPhase := true) {
    F8Release(session)
    if newPhase
        F8WardBegin(session)
    session.promptWait := true
    deadline := GetQpcMs() + budget
    try {
        while (F8Alive(session) && GetQpcMs() < deadline) {
            if F8WardPoll(session) {
                F8ConfirmWard(session)
                return true
            }
            Sleep(10)
        }
        return false
    } finally {
        session.promptWait := false
    }
}

F8ResetLive(session) {
    if session.HasOwnProp("liveVision") {
        if session.liveVision.req
            session.liveVision.req.Cancel()
    }
    session.liveVision := {req: 0, next: 0, resultId: "", lastLog: 0, anyResponse: false}
    session.liveTracker := {active: false, until: 0, lastSeen: 0, resultId: "",
        want: Map("w", false, "a", false, "s", false, "d", false)}
    F8RecordEvent("TRACKER_RESET", "Internal target cleared; no visible marker")
}

F8PollLive(session) {
    global recoveryTolerance, robloxWinBox, mapOpen, mapViewEpoch
    if mapOpen
        return false
    if !F8Alive(session)
        return false
    if !session.HasOwnProp("liveVision")
        F8ResetLive(session)
    vision := session.liveVision
    tracker := session.liveTracker
    now := GetQpcMs()
    if (!vision.req && now >= vision.next && F8Alive(session))
        vision.req := F8VisionRequest("/waystone_sprite?async=1&recovery=1&tracking=1&view_epoch=" mapViewEpoch "&threshold=" (recoveryTolerance / 100), 1200)
    if vision.req {
        request := vision.req
        observedEpoch := mapViewEpoch
        kv := request.Poll()
        if (mapOpen || observedEpoch != mapViewEpoch)
            return false
        if request.done {
            delayBound := request.responseDelayBound
            vision.req := 0
            vision.next := GetQpcMs() + 20
            now := GetQpcMs()
            vision.anyResponse := vision.anyResponse || (kv.Has("ok") && kv["ok"] = "1")
            id := kv.Has("result_id") ? kv["result_id"] : ""
            newResult := id != "" && id != vision.resultId
            if newResult
                vision.resultId := id
            if (newResult || now-vision.lastLog >= 700) {
                text := "response_gap_ms=" Round(delayBound) " "
                for key in ["ok", "found", "pending", "result_id", "age_ms", "compute_ms", "score", "snapshot_found", "snapshot_reason", "track_found", "track_age_ms", "track_id", "track_score", "reason", "error"] {
                    if kv.Has(key)
                        text .= key "=" kv[key] " "
                }
                F8RecordEvent("LIVE_RESULT", text)
                vision.lastLog := now
            }
            prefix := ""
            targetId := ""
            limit := 350
            age := 99999
            if (kv.Has("track_found") && kv["track_found"] = "1" && kv.Has("track_id") && kv.Has("track_age_ms")) {
                prefix := "track_"
                targetId := kv["track_id"]
                age := Number(kv["track_age_ms"]) + delayBound
                limit := 1500
            } else if (kv.Has("found") && kv["found"] = "1" && kv.Has("age_ms")) {
                targetId := id
                age := Number(kv["age_ms"]) + delayBound
            }
            ; The approved matcher may finish after the 350ms fresh-cache age.
            ; Its last verified sighting can still seed the explicitly retained
            ; 1.5s tracker. Negatives never erase it early; repeats never renew it.
            if (targetId != "" && targetId != tracker.resultId && age >= 0 && age < limit
                && kv.Has(prefix "x") && kv.Has(prefix "y") && kv.Has(prefix "w") && kv.Has(prefix "h")) {
                tx := Number(kv[prefix "x"]), ty := Number(kv[prefix "y"])
                tw := Number(kv[prefix "w"]), th := Number(kv[prefix "h"])
                dx := tx + tw/2 - (robloxWinBox.x1+robloxWinBox.x2)/2
                dy := ty + th/2 + 16 - (robloxWinBox.y1+robloxWinBox.y2)/2 - 22
                want := Map("w", false, "a", false, "s", false, "d", false)
                F8LiveAxis(session.held, want, dx, "a", "d")
                F8LiveAxis(session.held, want, dy, "w", "s")
                ; Do not declare arrival or end the approach at a screen dead
                ; zone. Continue the last approach heading until the ward image.
                if (!want["w"] && !want["a"] && !want["s"] && !want["d"]) {
                    prior := GetActiveHeldKeysList(tracker.want)
                    if prior.Length {
                        for k in prior
                            want[k] := true
                    } else if (Abs(dx) >= Abs(dy)) {
                        want[dx < 0 ? "a" : "d"] := true
                    } else {
                        want[dy < 0 ? "w" : "s"] := true
                    }
                }
                wasActive := tracker.active
                tracker.active := true
                tracker.lastSeen := now-age
                tracker.until := now + Max(0, 1500-age)
                tracker.resultId := targetId
                tracker.box := {x:tx,y:ty,w:tw,h:th}
                tracker.want := want
                F8RecordEvent(wasActive ? "TRACKER_UPDATE" : "TRACKER_LOCK", "dx=" Round(dx) " dy=" Round(dy) " capture_age_ms=" Round(age) " loss_grace_ms=" Round(1500-age) " retained=" (prefix != ""))
            }
        }
    }
    now := GetQpcMs()
    if (tracker.active && now >= tracker.until) {
        tracker.active := false
        F8RecordEvent("TRACKER_LOST", "No new accepted sighting for 1500ms")
    }
    return tracker.active
}

F8SteerTracker(session) {
    global mapOpen
    if (mapOpen || !F8Alive(session))
        return
    SyncMoveKeys(session.held, session.liveTracker.want)
    F8SetStatus(GetQpcMs()-session.liveTracker.lastSeen < 350
        ? "RECOVERY: locked waystone; approaching" : "RECOVERY: holding lock through brief sight loss")
}

F8CancelLiveRequest(session) {
    if session.HasOwnProp("liveVision") {
        if session.liveVision.req
            session.liveVision.req.Cancel()
        session.liveVision.req := 0
    }
}

F8ApproachLive(session, deadline) {
    global mapOpen
    if mapOpen
        return false
    if !session.HasOwnProp("liveVision")
        F8ResetLive(session)
    F8WardBegin(session)
    hadLock := session.liveTracker.active
    session.liveOutcome := "pending"
    try {
        while F8Alive(session) {
            if F8WardPoll(session) {
                F8ConfirmWard(session)
                session.liveOutcome := "arrived"
                return true
            }
            if F8PollLive(session) {
                hadLock := true
                session.liveOutcome := "visible"
                F8SteerTracker(session)
            } else {
                SyncMoveKeys(session.held, Map("w", false, "a", false, "s", false, "d", false))
                F8SetStatus("RECOVERY: searching for live waystone")
                ; The deadline limits only initial acquisition, never an active
                ; approach. A lock moves continuously until ward or sight loss.
                if (hadLock || GetQpcMs() >= deadline) {
                    session.liveOutcome := "not_found"
                    return false
                }
            }
            Sleep(10)
        }
        return false
    } finally {
        F8CancelLiveRequest(session)
        F8Release(session)
        F8RecordEvent("LIVE_END", "outcome=" session.liveOutcome)
    }
}

F8MapWalk(session, keys, keepHeld := false) {
    global mapOpen
    if mapOpen
        return "cancelled"
    F8ResetLive(session)
    F8WardBegin(session)
    want := Map("w", false, "a", false, "s", false, "d", false)
    for k in keys
        want[k] := true
    if !F8Alive(session)
        return "cancelled"
    SyncMoveKeys(session.held, want)
    started := GetQpcMs()
    outcome := "map"
    if session.mapTimingPending {
        F8RecordEvent("MAP_TO_MOVE", "open_to_move_ms=" Round(started-session.mapCycleStarted) " close_to_move_ms=" Round(started-session.mapClosedAt))
        session.mapTimingPending := false
    }
    F8RecordEvent("MAP_WALK", "2000ms maximum; poll live waystone and ward while walking")
    try {
        while (F8Alive(session) && GetQpcMs()-started < 2000) {
            if F8WardPoll(session) {
                F8ConfirmWard(session)
                outcome := "arrived"
                return outcome
            }
            if F8PollLive(session) {
                F8SteerTracker(session)
                outcome := "live"
                F8RecordEvent("MAP_TO_LIVE", "Immediate continuous handoff to internal waystone lock")
                return outcome
            }
            Sleep(10)
        }
        return outcome
    } finally {
        F8RecordEvent("MAP_WALK_END", "elapsed_ms=" Round(GetQpcMs()-started) " outcome=" outcome)
        ; A live handoff keeps keys held; the live approach owns the same request
        ; and tracker. Otherwise release before reopening M or stopping.
        if (outcome != "live" || !F8Alive(session)) {
            F8CancelLiveRequest(session)
            if (!keepHeld || outcome != "map" || !F8Alive(session))
                F8Release(session)
        }
    }
}

F8KeysDirection(keys) {
    dx := 0, dy := 0
    for k in keys {
        if (k = "a")
            dx -= 1
        else if (k = "d")
            dx += 1
        else if (k = "w")
            dy -= 1
        else if (k = "s")
            dy += 1
    }
    return GetCompassDir(dx, dy, 0)
}

F8BlockedDetour(session, forwardKeys) {
    if !F8Alive(session)
        return false
    reverse := GetOppositeKeys(forwardKeys)
    pair := GetPerpendicularPair(forwardKeys)
    draw := Random(0, 1)
    side := draw ? pair.b : pair.a
    F8RecordEvent("BLOCKED_DETOUR", "3 unsuccessful map walks; reverse=" F8KeysDirection(reverse)
        " 2000ms once; perpendicular=" F8KeysDirection(side) " 2000ms; rng=" draw " (50/50)")
    try {
        F8SetStatus("RECOVERY: back off " F8KeysDirection(reverse) " for up to 2s")
        ; Reverse only one timed leg, not all three prior attempts. Keep keys
        ; held into the sidestep; SyncMoveKeys changes only the required axes.
        outcome := F8MapWalk(session, reverse, true)
        if (outcome = "arrived")
            return true
        if (outcome = "live")
            return PathToWaystoneSprite([], 2500, session)
        if !F8Alive(session)
            return false
        F8SetStatus("RECOVERY: random sidestep " F8KeysDirection(side) " for up to 2s")
        outcome := F8MapWalk(session, side)
        if (outcome = "arrived")
            return true
        if (outcome = "live")
            return PathToWaystoneSprite([], 2500, session)
        F8RecordEvent("BLOCKED_RECHECK", "Detour complete; get a fresh map vector")
        return false
    } finally {
        F8Release(session)
    }
}

F8RevealWaystone(session, reason) {
    if !F8Alive(session)
        return false
    F8RecordEvent("OCCLUSION_UP", reason " | move up <=2000ms; live/ward interception active")
    F8SetStatus("RECOVERY: reveal obscured waystone; up for up to 2s")
    outcome := F8MapWalk(session, ["w"])
    if (outcome = "arrived")
        return true
    if (outcome = "live") {
        if PathToWaystoneSprite([], 2500, session)
            return true
    }
    F8RecordEvent("OCCLUSION_RECHECK", "No ward/live lock after reveal; remeasure map, never assume the icon moved")
    return false
}

F8LiveAxis(held, want, delta, negativeKey, positiveKey) {
    key := delta < 0 ? negativeKey : positiveKey
    if (Abs(delta) > 22 || (Abs(delta) > 10 && held[key]))
        want[key] := true
}

F8Recover(session) {
    global recoveryCount, useWorldMapRecovery, mapOpen
    recoveryCount += 1
    session.mapOpen := mapOpen
    session.mapCloseAttempts := 0
    attempt := 0
    blockedHeading := ""
    blockedMisses := 0
    reason := "Recovery cancelled or Roblox focus lost"
    try {
        F8Release(session)
        F8ResetLive(session)
        F8SetStatus("RECOVERY: check ward prompt")
        if F8CheckPrompt(session, 350)
            return true
        F8SetStatus("RECOVERY: find/lock live waystone")
        if PathToWaystoneSprite([], 2500, session)
            return true
        ; No total time or retry limit: retry perception/navigation until arrival,
        ; explicit cancellation, focus loss, or an unexpected runtime error.
        while F8Alive(session) {
            attempt += 1
            F8Release(session)
            F8ResetLive(session)
            if !useWorldMapRecovery {
                F8SetStatus("RECOVERY: map disabled; retry live detection")
                if PathToWaystoneSprite([], 2500, session)
                    return true
                F8Pause(session, 300, GetQpcMs()+500)
                continue
            }
            F8SetStatus("RECOVERY: open map (attempt " attempt ")")
            if !F8OpenMap(session, GetQpcMs()+6000) {
                F8SetStatus("RECOVERY: map not confirmed; retrying")
                if session.mapOpen
                    F8CloseMap(session, true, GetQpcMs()+6000)
                F8Pause(session, 500, GetQpcMs()+700)
                continue
            }
            F8SetStatus("RECOVERY: map vector (attempt " attempt ")")
            mapKV := F8WaitVision(session, "/worldmap_vector?target=-1&kind=waystone&preview=0", 12000)
            scan := WorldMapScanResultFromKV(mapKV)
            if !F8Alive(session)
                return false
            F8SetStatus("RECOVERY: close/verify map before walking")
            if !F8CloseMap(session, true, GetQpcMs()+6000) {
                F8SetStatus("RECOVERY: map closure unknown; retrying without walking")
                F8Pause(session, 500, GetQpcMs()+700)
                continue
            }
            if !F8Alive(session)
                return false
            if !scan.ok {
                F8RecordEvent("MAP_RETRY", scan.reason)
                F8SetStatus("RECOVERY: check live stone before reopening map")
                if PathToWaystoneSprite([], 1200, session)
                    return true
                if !F8Alive(session)
                    return false
                ; Do not invent a vector through an obscured icon. This is the
                ; user's explicit reveal maneuver, with fresh map/arrow identity.
                if (scan.openDetected && scan.arrowFound && scan.areaFound && !scan.wayFound) {
                    blockedHeading := "", blockedMisses := 0
                    if F8RevealWaystone(session, "Current-map icon missing/possibly under arrow")
                        return true
                } else {
                    F8SetStatus("RECOVERY: vector unavailable; retrying")
                    F8Pause(session, 500, GetQpcMs()+700)
                }
                continue
            }
            ; No second prompt HTTP wait between closing M and walking. Native
            ; prompt checks and live acquisition run throughout the timed walk.
            dist := Sqrt(scan.dx**2 + scan.dy**2)
            if (dist <= 5) {
                blockedHeading := "", blockedMisses := 0
                F8SetStatus("RECOVERY: map overlap; find live ward/waystone")
                if PathToWaystoneSprite([], 1200, session)
                    return true
                if F8RevealWaystone(session, "Map overlap but live stone and ward not found")
                    return true
                continue
            }
            keys := []
            if (Abs(scan.dy) > Max(2, Abs(scan.dx)*0.35))
                keys.Push(scan.dy < 0 ? "w" : "s")
            if (Abs(scan.dx) > Max(2, Abs(scan.dy)*0.35))
                keys.Push(scan.dx < 0 ? "a" : "d")
            F8SetStatus("RECOVERY: " GetCompassDir(scan.dx, scan.dy, 2) " for up to 2s; looking for waystone")
            outcome := F8MapWalk(session, keys)
            if (outcome = "arrived")
                return true
            if (outcome = "live") {
                blockedHeading := "", blockedMisses := 0
                if PathToWaystoneSprite([], 2500, session)
                    return true
            }
            if (outcome = "map" && F8Alive(session)) {
                heading := scan.mapIdx "|" F8KeysDirection(keys)
                if (heading != blockedHeading) {
                    blockedHeading := heading
                    blockedMisses := 0
                }
                blockedMisses += 1
                F8RecordEvent("BLOCKED_COUNT", "map=" scan.mapIdx " direction=" F8KeysDirection(keys)
                    " unsuccessful_walks=" blockedMisses "/3")
                if (blockedMisses >= 3) {
                    blockedHeading := "", blockedMisses := 0
                    if F8BlockedDetour(session, keys)
                        return true
                }
            }
            ; Recheck M after an unsuccessful walk or completed detour. A live
            ; sighting resets the no-detection count even if its lock is later lost.
        }
        return false
    } finally {
        F8CancelLiveRequest(session)
        F8Release(session)
        if (F8Alive(session) && session.mapOpen)
            F8CloseMap(session, true, GetQpcMs()+6000)
        if F8Alive(session)
            session.reason := reason
        F8RecordEvent("RECOVERY_END", reason)
    }
}

F8Pause(session, duration, deadline) {
    waitEnd := Min(GetQpcMs() + duration, deadline)
    while (F8Alive(session) && GetQpcMs() < waitEnd)
        Sleep(15)
    return F8Alive(session) && GetQpcMs() < deadline
}

F8SlowMapState(session, deadline) {
    if (!F8Alive(session) || GetQpcMs() >= deadline)
        return "unknown"
    kv := F8WaitVision(session, "/worldmap_state", Min(2500, Max(1, deadline-GetQpcMs())))
    if (kv.Has("ok") && kv["ok"] = "1" && kv.Has("state")) {
        SetMapOpenState(kv["state"] = "open")
        session.mapOpen := kv["state"] = "open"
        return kv["state"]
    }
    return "unknown"
}

F8MapState(session, deadline) {
    global mapOpen
    if (!F8Alive(session) || GetQpcMs() >= deadline)
        return "unknown"
    if FastMapHeaderFound() {
        SetMapOpenState(true)
        session.mapOpen := true
        session.mapFastOpenConfirmed := true
        return "open"
    }
    if (!mapOpen && !session.mapOpen) {
        SetMapOpenState(false)
        session.mapOpen := false
        return "closed"
    }
    return F8SlowMapState(session, deadline)
}

F8OpenMap(session, deadline) {
    state := F8MapState(session, deadline)
    if (state = "open") {
        session.mapOpen := true
        session.mapCloseAttempts := 0
        session.mapCycleStarted := GetQpcMs()
        return true
    }
    if (state != "closed" || !F8Alive(session) || GetQpcMs() >= deadline)
        return false
    ; Gate live detections before M, including the entire render transition.
    SetMapOpenState(true)
    session.mapOpen := true
    session.mapCloseAttempts := 0
    session.mapFastOpenConfirmed := false
    session.mapCycleStarted := GetQpcMs()
    SendEvent("m")
    F8RecordEvent("MAP_TOGGLE", "M open; exact cached indicator polled without fixed 250ms wait")
    renderUntil := Min(deadline, GetQpcMs()+120)
    while (F8Alive(session) && GetQpcMs() < renderUntil) {
        if FastMapHeaderFound() {
            session.mapFastOpenConfirmed := true
            F8RecordEvent("MAP_READY", "open_render_ms=" Round(GetQpcMs()-session.mapCycleStarted) " method=exact_indicator")
            return true
        }
        Sleep(5)
    }
    ; Exact templates can miss changed UI scale/zoom. Preserve approved evidence
    ; rather than treating a missing exact match as permission to walk.
    ready := F8SlowMapState(session, deadline) = "open"
    F8RecordEvent("MAP_READY", "open_render_ms=" Round(GetQpcMs()-session.mapCycleStarted) " method=approved_window_state ready=" ready)
    return ready
}

F8CloseMap(session, confirmedOpen, deadline) {
    if (session.mapCycleStarted = 0)
        session.mapCycleStarted := GetQpcMs()
    if (!F8Alive(session) || GetQpcMs() >= deadline)
        return false
    state := F8MapState(session, deadline)
    if (state = "closed")
        return true
    if (state != "open")
        return false
    Loop 2 {
        if (!F8Alive(session) || GetQpcMs() >= deadline || session.mapCloseAttempts >= 2)
            return false
        session.mapCloseAttempts += 1
        SendEvent("m")
        F8RecordEvent("MAP_TOGGLE", "M close; live lock remains gated until indicator disappears")
        closeStarted := GetQpcMs()
        state := F8SlowMapState(session, deadline)
        ; A slow state reply may describe a frame captured before M finished
        ; closing. Recheck the current frame before allowing another toggle.
        if (state = "open" && !FastMapHeaderFound())
            state := F8SlowMapState(session, deadline)
        if (state = "closed") {
            session.mapClosedAt := GetQpcMs()
            session.mapTimingPending := true
            F8RecordEvent("MAP_CLOSE", "confirmation_ms=" Round(GetQpcMs()-closeStarted) " method=approved_window_state")
            F8RecordEvent("MAP_CYCLE", "open_detect_close_ms=" Round(GetQpcMs()-session.mapCycleStarted))
            return true
        }
        if (state != "open")
            return false
    }
    return false
}
