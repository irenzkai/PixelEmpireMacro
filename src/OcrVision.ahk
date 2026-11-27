; ==============================================================================
; OCR VISION CLIENT (AUTO-CAPTURE + FAST OPENCV PRE-GATE + BINARIZED OCR)
; ==============================================================================

global ocrServerUrl := "http://127.0.0.1:8765"
global ocrLastState := Map()
global ocrLastStateTick := 0
global ocrLastStateKey := ""
global ocrLastBoss := Map()
global ocrLastBossTick := 0
global ocrAvailCached := false
global ocrAvailTick := 0

OcrLogMsg(msg) {
    try OutputDebug(msg)
    try FileAppend(msg "`n", "**")
}

OcrHttpGetKV(endpoint, recvTimeoutMs := 6000, fastPoll := false) {
    global ocrServerUrl
    out := Map()
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.SetProxy(1)
        if fastPoll
            req.SetTimeouts(25, 25, 25, recvTimeoutMs)
        else
            req.SetTimeouts(250, 250, 1000, recvTimeoutMs)
        sep := InStr(endpoint, "?") ? "&" : "?"
        req.Open("GET", ocrServerUrl . endpoint . sep . "format=ahk", false)
        req.Send()
        if (req.Status != 200) {
            OcrLogMsg("OcrHttpGetKV HTTP " req.Status " on " endpoint)
            return out
        }
        for line in StrSplit(req.ResponseText, "`n", "`r") {
            pos := InStr(line, "=")
            if (pos > 0) {
                k := SubStr(line, 1, pos - 1)
                v := SubStr(line, pos + 1)
                out[k] := v
            }
        }
    } catch as err {
        OcrLogMsg("OcrHttpGetKV error on " endpoint ": " err.Message)
    }
    return out
}

OcrFocusRoblox() {
    hwnds := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    if (hwnds.Length = 0)
        return false
    bestHwnd := hwnds[1]
    bestX := 999999
    for hwnd in hwnds {
        try {
            WinGetPos(&wx, , , , "ahk_id " hwnd)
            if (wx < bestX) {
                bestX := wx
                bestHwnd := hwnd
            }
        }
    }
    if WinExist("ahk_id " bestHwnd) && !WinActive("ahk_id " bestHwnd) {
        WinActivate("ahk_id " bestHwnd)
        Sleep(30)
    }
    return true
}

OcrPing() {
    res := OcrHttpGetKV("/ping", 1000)
    return res.Has("ok") && (res["ok"] = "1")
}

OcrServerReady(cacheMs := 3000) {
    global ocrAvailCached, ocrAvailTick
    if (ocrAvailTick > 0 && (A_TickCount - ocrAvailTick) <= cacheMs)
        return ocrAvailCached
    ocrAvailCached := OcrPing()
    ocrAvailTick := A_TickCount
    return ocrAvailCached
}

EnsureOcrServerRunning() {
    global ocrAvailCached, ocrAvailTick
    if (OcrPing()) {
        ocrAvailCached := true
        ocrAvailTick := A_TickCount
        return true
    }
    pyVenv := A_ScriptDir "\.venv\Scripts\python.exe"
    pyParentVenv := A_ScriptDir "\..\.venv\Scripts\python.exe"
    pyExe := FileExist(pyVenv) ? pyVenv : (FileExist(pyParentVenv) ? pyParentVenv : "python")
    srv := FileExist(A_ScriptDir "\ocr_vision_server.py") ? (A_ScriptDir "\ocr_vision_server.py") : (A_ScriptDir "\..\ocr_vision_server.py")
    if !FileExist(srv)
        return false
    try Run('"' pyExe '" "' srv '"', A_ScriptDir, "Hide")
    Loop 28 {
        Sleep(250)
        if (OcrPing()) {
            ocrAvailCached := true
            ocrAvailTick := A_TickCount
            return true
        }
    }
    return false
}

OcrGetState(includeBoss := true, includePrompt := true, saveDebug := false, maxAgeMs := 1500) {
    global ocrLastState, ocrLastStateTick, ocrLastStateKey
    reqKey := (includeBoss ? "1" : "0") ":" (includePrompt ? "1" : "0")

    if (!saveDebug && maxAgeMs > 0 && ocrLastState.Count > 0 && (A_TickCount - ocrLastStateTick) <= maxAgeMs) {
        if (ocrLastStateKey = reqKey || ocrLastStateKey = "1:1")
            return ocrLastState
    }

    ep := "/state?boss=" (includeBoss ? "1" : "0")
        . "&prompt=" (includePrompt ? "1" : "0")
        . "&debug=" (saveDebug ? "1" : "0")
    res := OcrHttpGetKV(ep)
    if (res.Count > 0 && res.Has("ok") && res["ok"] = "1") {
        ocrLastState := res
        ocrLastStateTick := A_TickCount
        ocrLastStateKey := reqKey
    }
    return res
}

OcrReadRoiText(roi := "top_bar", preset := "auto", saveDebug := false) {
    res := OcrHttpGetKV("/ocr?roi=" roi "&preset=" preset "&debug=" (saveDebug ? "1" : "0"))
    return res.Has("text") ? res["text"] : ""
}

; --- Drop-in OCR detection functions ---

OcrDetectCurrentMap(&mapName := "") {
    st := OcrGetState(false, false, false, 350)
    if (st.Has("ok") && st["ok"] = "1") {
        mapName := st.Has("ws_name") ? st["ws_name"] : ""
        if st.Has("ws_idx") && IsInteger(st["ws_idx"])
            return Integer(st["ws_idx"])
    }
    mapName := ""
    return -1
}

; On-demand saved indicator detection; no new timer/detection loop.
OcrTestIndicator(name) {
    global recoveryTolerance
    if name = "waystone"
        return OcrHttpGetKV("/waystone_sprite?async=1&threshold=" (recoveryTolerance / 100), 60, true)
    if name = "waystone_prompt" {
        kv := OcrHttpGetKV("/waystone_fast", 3000)
        return Map("ok", kv.Has("ok") ? kv["ok"] : "0", "found", kv.Has("on_waystone") ? kv["on_waystone"] : "0")
    }
    static stamp := "", config := ""
    path := A_ScriptDir "\config\indicator_regions.json"
    if !FileExist(path)
        return Map()
    current := FileGetTime(path, "M") FileGetSize(path)
    if current != stamp {
        config := FileRead(path, "UTF-8"), stamp := current
    }
    if !InStr(config, Chr(34) name Chr(34))
        return Map()

    if !RegExMatch(name, "^[A-Za-z][A-Za-z0-9_-]{0,63}$")
        return Map("ok", "0", "error", "Invalid indicator name")
    return OcrHttpGetKV("/indicator?name=" name, 4000)
}

OcrIsOnWaystone() {
    kv := OcrHttpGetKV("/waystone_fast", 2500)
    if (kv.Has("ok") && kv["ok"] = "1")
        return kv.Has("on_waystone") && (kv["on_waystone"] = "1")
    return false
}

OcrIsInTower() {
    kv := OcrHttpGetKV("/tower_fast", 3000)
    if (kv.Has("ok") && kv["ok"] = "1")
        return kv.Has("in_tower") && (kv["in_tower"] = "1")
    return false
}

OcrIsFloorCleared() {
    kv := OcrHttpGetKV("/tower_fast", 3000)
    if (kv.Has("ok") && kv["ok"] = "1")
        return kv.Has("floor_cleared") && (kv["floor_cleared"] = "1")
    return false
}

OcrGetBossState(&rawText := "") {
    st := OcrGetState(true, true)
    rawText := st.Has("boss_text") ? st["boss_text"] : ""
    return st.Has("boss_state") ? st["boss_state"] : ""
}

OcrCheckBossBanner(&kind := "", &defeated := false, &youDefeated := false, &rawText := "") {
    global ocrLastBoss, ocrLastBossTick
    if (ocrLastBoss.Count > 0 && (A_TickCount - ocrLastBossTick) <= 350) {
        kv := ocrLastBoss
    } else {
        kv := OcrHttpGetKV("/boss_fast", 3000)
        if (kv.Has("ok") && kv["ok"] = "1") {
            ocrLastBoss := kv
            ocrLastBossTick := A_TickCount
        }
    }
    if !(kv.Has("ok") && kv["ok"] = "1")
        return false

    kind := kv.Has("kind") ? kv["kind"] : ""
    defeated := kv.Has("defeated") && (kv["defeated"] = "1")
    youDefeated := kv.Has("you_defeated") && (kv["you_defeated"] = "1")
    rawText := kv.Has("boss_text") ? kv["boss_text"] : ""
    return kv.Has("active") && (kv["active"] = "1")
}

OcrFindPortalSprite(&px := 0, &py := 0) {
    global portalPlayerX, portalPlayerY
    portalPlayerX := 0
    portalPlayerY := 0
    kv := OcrHttpGetKV("/portal_fast", 2500)
    if (kv.Has("ok") && kv["ok"] = "1" && kv.Has("found") && kv["found"] = "1") {
        px := Integer(kv["x"])
        py := Integer(kv["y"])
        if (kv.Has("player_found") && kv["player_found"] = "1") {
            portalPlayerX := Integer(kv["player_x"])
            portalPlayerY := Integer(kv["player_y"])
        }
        return true
    }
    return false
}

OcrScanWorldMapVector(targetMapIdx := -1) {
    res := {ok: false, openDetected: false, arrowFound: false, wayFound: false, dx: 0, dy: 0}
    if !OcrFocusRoblox()
        return res

    SendEvent("m")
    Sleep(220)

    kv := OcrHttpGetKV("/worldmap_vector?target=" targetMapIdx)
    if (kv.Has("open") && kv["open"] = "1") {
        res.openDetected := true
        res.arrowFound := kv.Has("arrow_found") && (kv["arrow_found"] = "1")
        res.wayFound   := kv.Has("way_found")   && (kv["way_found"] = "1")
        res.dx         := kv.Has("dx") ? Integer(kv["dx"]) : 0
        res.dy         := kv.Has("dy") ? Integer(kv["dy"]) : 0
        res.ok         := kv.Has("ok") && (kv["ok"] = "1")
    }

    SendEvent("m")
    Sleep(140)
    return res
}

OcrCaptureDebug(roi := "full") {
    EnsureOcrServerRunning()
    return OcrReadRoiText(roi, "full", true)
}

NavProgress(detail) {
    global hudStatus
    static navDeadUntil := 0
    hudStatus := detail
    if (A_TickCount < navDeadUntil)
        return
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.SetProxy(1)
        req.SetTimeouts(40, 40, 60, 80)
        req.Open("POST", "http://127.0.0.1:8766", false)
        req.SetRequestHeader("Content-Type", "application/json")
        safe := StrReplace(StrReplace(detail, Chr(92), Chr(92) Chr(92)), Chr(34), Chr(92) Chr(34))
        req.Send('{"action":"log","who":"AHK","text":"' safe '"}')
    } catch {
        navDeadUntil := A_TickCount + 10000
    }
}
