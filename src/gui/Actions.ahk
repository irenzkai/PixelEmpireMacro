; ==============================================================================
; GUI ACTIONS (RANGE SCALERS, MAP CYCLE + SEARCH, TOWER ENGINE, IMPORTS, TESTS)
; ==============================================================================

ToggleHudSetting(*) {
    global hudEnabled
    hudEnabled := !hudEnabled
    if (!hudEnabled)
        HideOverlay()
    SaveConfig()
    RefreshSettingsTabUI()
    UpdateGuiStatus(hudEnabled ? "Floating Run Overlay Enabled" : "Floating Run Overlay Disabled")
}

ToggleWorldMapSetting(*) {
    global useWorldMapRecovery
    useWorldMapRecovery := !useWorldMapRecovery
    SaveConfig()
    RefreshWorldMapUI()
    UpdateGuiStatus(useWorldMapRecovery ? "World Map (M) Recovery Enabled" : "World Map (M) Recovery Disabled")
}

; ==============================================================================
; MAP CYCLE WAYSTONE SELECTOR, LIVE SEARCH & DETECT
; ==============================================================================

SelectCycleWs(delta) {
    global currentWaystoneIdx, maxWaystoneIdx, waystoneRoutes
    currentWaystoneIdx := Max(0, Min(maxWaystoneIdx, currentWaystoneIdx + delta))
    RefreshCycleUI()
    SaveConfig()
    UpdateGuiStatus("Cycle Starting Map -> " waystoneRoutes[currentWaystoneIdx].label)
}

OnCycleSearchChange(*) {
    global edtCycleSearch, waystoneRoutes, maxWaystoneIdx, currentWaystoneIdx
    global cycleSearchMatches, cycleSearchCursor, txtCycleMatchInfo

    query := StrLower(Trim(edtCycleSearch.Value))
    cycleSearchMatches := []
    cycleSearchCursor := 0

    if (query = "") {
        if IsSet(txtCycleMatchInfo)
            txtCycleMatchInfo.Text := ""
        return
    }

    cleanNum := StrReplace(query, "#", "")
    idx := 0
    while (idx <= maxWaystoneIdx) {
        lbl := waystoneRoutes[idx].label
        if (IsInteger(cleanNum) && Integer(cleanNum) = idx) {
            cycleSearchMatches.InsertAt(1, idx)
        } else if (InStr(StrLower(lbl), query)) {
            cycleSearchMatches.Push(idx)
        }
        idx += 1
    }

    if (cycleSearchMatches.Length > 0) {
        cycleSearchCursor := 1
        currentWaystoneIdx := cycleSearchMatches[1]
        RefreshCycleUI()
        SaveConfig()
        if IsSet(txtCycleMatchInfo)
            txtCycleMatchInfo.Text := "1/" cycleSearchMatches.Length " match" (cycleSearchMatches.Length > 1 ? "es" : "")
        UpdateGuiStatus("Selected -> " waystoneRoutes[currentWaystoneIdx].label)
    } else {
        if IsSet(txtCycleMatchInfo)
            txtCycleMatchInfo.Text := "No match"
    }
}

CycleSearchNextMatch(*) {
    global cycleSearchMatches, cycleSearchCursor, currentWaystoneIdx, waystoneRoutes, txtCycleMatchInfo
    if (cycleSearchMatches.Length = 0) {
        OnCycleSearchChange()
        return
    }
    cycleSearchCursor := Mod(cycleSearchCursor, cycleSearchMatches.Length) + 1
    currentWaystoneIdx := cycleSearchMatches[cycleSearchCursor]
    RefreshCycleUI()
    SaveConfig()
    if IsSet(txtCycleMatchInfo)
        txtCycleMatchInfo.Text := cycleSearchCursor "/" cycleSearchMatches.Length " matches"
    UpdateGuiStatus("Selected -> " waystoneRoutes[currentWaystoneIdx].label)
}

DetectCycleCurrentMap(*) {
    global currentWaystoneIdx, waystoneRoutes, mainGui, topLabelTol, topLabelBox
    if !InitVisionAndWindow(false)
        return
    mainGui.Hide()
    Sleep(140)
    detected := DetectCurrentMapByTopLabel()
    fullMatch := -1
    if (detected < 0) {
        upperHalf := {x1: 0, y1: 0, x2: A_ScreenWidth, y2: Round(A_ScreenHeight * 0.30)}
        fullMatch := DetectCurrentMapByTopLabel("", upperHalf)
        if (fullMatch >= 0)
            detected := fullMatch
    }
    mainGui.Show()

    if (detected >= 0) {
        currentWaystoneIdx := detected
        RefreshCycleUI()
        SaveConfig()
        UpdateGuiStatus("Detected Current Map -> " waystoneRoutes[detected].label)
    } else {
        samplePath := GetMapTopLabelPath(currentWaystoneIdx)
        GetImageDimensions(samplePath, &sw, &sh)
        mainGui.Opt("+OwnDialogs")
        MsgBox(
            "Could not match any top_label PNG in the top-center PVE bar.`n`n"
            "Top Box: (" topLabelBox.x1 "," topLabelBox.y1 ") -> (" topLabelBox.x2 "," topLabelBox.y2 ")`n"
            "Selected PNG (" waystoneRoutes[currentWaystoneIdx].file "): " (FileExist(samplePath) ? (sw "x" sh "px") : "MISSING") "`n"
            "Top Tol: " topLabelTol "`n`n"
            "Tip: If your top_label PNGs include the dark pill/border, try Top Tol = 85.",
            "Detect Current Map",
            "Icon!"
        )
    }
}

; ==============================================================================
; RATIO-LOCKED RANGE < > SCALING
; ==============================================================================

AdjustWaystoneRange(deltaPct) {
    global wideStarMode, shortCfg, shortBase, shortPct, wideCfg, wideBase, widePct
    if (wideStarMode) {
        widePct := Max(10, Min(500, widePct + deltaPct))
        ApplyRatioToObj(wideCfg, wideBase, widePct, true)
    } else {
        shortPct := Max(10, Min(500, shortPct + deltaPct))
        ApplyRatioToObj(shortCfg, shortBase, shortPct, true)
    }
    RefreshPresetUI()
    SaveConfig()
    pct := wideStarMode ? widePct : shortPct
    UpdateGuiStatus("Waystone Range scaled to " pct "%")
}

AdjustTowerRange(deltaPct) {
    global towerCenterMs, towerRadiusMs, towerPortalMs, towerBase, towerRangePct
    global edtTowerCenter, edtTowerRadius, edtTowerPortal, txtTowerRangePct

    towerRangePct := Max(10, Min(500, towerRangePct + deltaPct))
    scale := towerRangePct / 100.0

    towerCenterMs := Max(10, Round(towerBase.center * scale))
    towerRadiusMs := Max(10, Round(towerBase.radius * scale))
    towerPortalMs := Max(10, Round(towerBase.portal * scale))

    if IsSet(edtTowerCenter)
        edtTowerCenter.Value := towerCenterMs
    if IsSet(edtTowerRadius)
        edtTowerRadius.Value := towerRadiusMs
    if IsSet(edtTowerPortal)
        edtTowerPortal.Value := towerPortalMs
    if IsSet(txtTowerRangePct)
        txtTowerRangePct.Text := towerRangePct "%"

    SaveConfig()
    UpdateGuiStatus("Tower Range scaled to " towerRangePct "% (" towerCenterMs "/" towerRadiusMs "/" towerPortalMs "ms)")
}

AdjustCircleRange(deltaPct) {
    global circleCfg, circleBase, circlePct
    circlePct := Max(10, Min(500, circlePct + deltaPct))
    scale := circlePct / 100.0
    circleCfg.out  := Max(50,  Round(circleBase.out * scale))
    circleCfg.edge := Max(50,  Round(circleBase.edge * scale))
    circleCfg.card := Max(50,  Round(circleBase.card * scale))
    circleCfg.diag := Max(50,  Round(circleBase.diag * scale))
    circleCfg.ret  := Max(100, Round(circleBase.ret * scale))

    RefreshCircleUI()
    SaveConfig()
    UpdateGuiStatus("F9 Circle Range scaled to " circlePct "%")
}

AdjustChaosRange(deltaPct) {
    global chaosCfg, chaosBase, chaosPct
    chaosPct := Max(10, Min(500, chaosPct + deltaPct))
    scale := chaosPct / 100.0
    chaosCfg.angle   := Max(50, Round(chaosBase.angle * scale))
    chaosCfg.zigDiag := Max(50, Round(chaosBase.zigDiag * scale))
    chaosCfg.zigSide := Max(50, Round(chaosBase.zigSide * scale))

    RefreshChaosUI()
    SaveConfig()
    UpdateGuiStatus("F7 Chaos Range scaled to " chaosPct "%")
}

ApplyRatioToObj(targetObj, baseObj, pct, hasRet := false) {
    scale := pct / 100.0
    targetObj.up    := Max(50, Round(baseObj.up * scale))
    targetObj.down  := Max(50, Round(baseObj.down * scale))
    targetObj.left  := Max(50, Round(baseObj.left * scale))
    targetObj.right := Max(50, Round(baseObj.right * scale))
    targetObj.diag  := Max(50, Round(baseObj.diag * scale))
    if (hasRet)
        targetObj.ret := Max(100, Round(baseObj.ret * scale))
}

; ==============================================================================
; UI REFRESH HELPERS
; ==============================================================================

RefreshPresetUI() {
    global isUpdatingUI, wideStarMode, shortCfg, wideCfg, shortPct, widePct
    global edtWayUp, edtWayDown, edtWayLeft, edtWayRight, edtWayDiag, edtWayRet, txtWayRangePct

    if !IsSet(edtWayUp)
        return

    isUpdatingUI := true
    cfg := wideStarMode ? wideCfg : shortCfg
    pct := wideStarMode ? widePct : shortPct
    edtWayUp.Value      := cfg.up
    edtWayDown.Value    := cfg.down
    edtWayLeft.Value    := cfg.left
    edtWayRight.Value   := cfg.right
    edtWayDiag.Value    := cfg.diag
    edtWayRet.Value     := cfg.ret
    txtWayRangePct.Text := pct "%"
    isUpdatingUI := false

    ApplyTheme()
}

RefreshTowerUI() {
    global isUpdatingUI, towerCenterMs, towerRadiusMs, towerPortalMs, towerRangePct, towerImgTol
    global edtTowerCenter, edtTowerRadius, edtTowerPortal, txtTowerRangePct, edtTowerTol
    global inTowerImg, towerClearedImg, towerNextImg
    global edtInTowerPath, edtTowerClearedPath, edtTowerNextPath

    if !IsSet(edtTowerCenter)
        return

    isUpdatingUI := true
    edtTowerCenter.Value := towerCenterMs
    edtTowerRadius.Value := towerRadiusMs
    edtTowerPortal.Value := towerPortalMs
    if IsSet(txtTowerRangePct)
        txtTowerRangePct.Text := towerRangePct "%"
    if IsSet(edtTowerTol)
        edtTowerTol.Value := towerImgTol
    if IsSet(edtInTowerPath)
        edtInTowerPath.Value := inTowerImg
    if IsSet(edtTowerClearedPath)
        edtTowerClearedPath.Value := towerClearedImg
    if IsSet(edtTowerNextPath)
        edtTowerNextPath.Value := towerNextImg
    isUpdatingUI := false
}

RefreshCycleUI() {
    global isUpdatingUI, currentWaystoneIdx, maxWaystoneIdx, waystoneRoutes, shortestRoutes
    global bossBannerTol, topLabelTol, portalTol, txtCycleWs, txtShortestStatus, edtBossTol, edtTopLabelTol, edtPortalTol
    global bossComingImg, bossSpawnImg, bossDefeatedImg
    global edtBossComingPath, edtBossSpawnPath, edtBossDefPath

    if !IsSet(txtCycleWs)
        return

    isUpdatingUI := true
    lbl := waystoneRoutes.Has(currentWaystoneIdx) ? waystoneRoutes[currentWaystoneIdx].label : ("WS #" currentWaystoneIdx)
    txtCycleWs.Text := lbl

    if IsSet(txtShortestStatus) {
        nextInfo := "Next: N/A"
        if (currentWaystoneIdx < maxWaystoneIdx) {
            nLegs := GetActiveRouteLegs(currentWaystoneIdx, currentWaystoneIdx + 1, &nSrc)
            nextInfo := "Next: " nSrc " (" GetRouteTotalMs(nLegs) "ms)"
        }
        prevInfo := "Prev: N/A"
        if (currentWaystoneIdx > 1) {
            pLegs := GetActiveRouteLegs(currentWaystoneIdx, currentWaystoneIdx - 1, &pSrc)
            prevInfo := "Prev: " pSrc " (" GetRouteTotalMs(pLegs) "ms)"
        }
        txtShortestStatus.Text := "Logged: " shortestRoutes.Count "  |  " nextInfo "  |  " prevInfo
    }

    if IsSet(edtBossTol)
        edtBossTol.Value := bossBannerTol
    if IsSet(edtTopLabelTol)
        edtTopLabelTol.Value := topLabelTol
    if IsSet(edtPortalTol)
        edtPortalTol.Value := portalTol
    if IsSet(edtBossComingPath)
        edtBossComingPath.Value := bossComingImg
    if IsSet(edtBossSpawnPath)
        edtBossSpawnPath.Value := bossSpawnImg
    if IsSet(edtBossDefPath)
        edtBossDefPath.Value := bossDefeatedImg
    isUpdatingUI := false
}

RefreshCircleUI() {
    global isUpdatingUI, circleCfg, circlePct
    global edtCirOut, edtCirEdge, edtCirCard, edtCirDiag, edtCirRet, txtCirRangePct

    if !IsSet(edtCirOut)
        return

    isUpdatingUI := true
    edtCirOut.Value     := circleCfg.out
    edtCirEdge.Value    := circleCfg.edge
    edtCirCard.Value    := circleCfg.card
    edtCirDiag.Value    := circleCfg.diag
    edtCirRet.Value     := circleCfg.ret
    txtCirRangePct.Text := circlePct "%"
    isUpdatingUI := false
}

RefreshChaosUI() {
    global isUpdatingUI, chaosCfg, chaosPct
    global edtChaosAngle, edtChaosZigDiag, edtChaosZigSide, txtChaosRangePct

    if !IsSet(edtChaosAngle)
        return

    isUpdatingUI := true
    edtChaosAngle.Value   := chaosCfg.angle
    edtChaosZigDiag.Value := chaosCfg.zigDiag
    edtChaosZigSide.Value := chaosCfg.zigSide
    txtChaosRangePct.Text := chaosPct "%"
    isUpdatingUI := false
}

RefreshWorldMapUI() {
    global isUpdatingUI, mapOpenImg, mapArrowImg, mapWaystoneImg, mapWaystoneOffImg, mapTolerance, mapMsPerPx, useWorldMapRecovery
    global edtMapOpenPath, edtMapArrowPath, edtMapWayPath, edtMapTol, edtMapMsPx, btnMapToggle

    if !IsSet(edtMapArrowPath)
        return

    isUpdatingUI := true
    if IsSet(edtMapOpenPath)
        edtMapOpenPath.Value := mapOpenImg
    edtMapArrowPath.Value := mapArrowImg
    edtMapWayPath.Value   := mapWaystoneImg
    edtMapTol.Value       := mapTolerance
    edtMapMsPx.Value      := mapMsPerPx
    isUpdatingUI := false

    if IsSet(btnMapToggle)
        btnMapToggle.btn.Text := useWorldMapRecovery ? "MAP: ON" : "MAP: OFF"
}

RefreshImageStatus() {
    global wayCardView, promptImg, recoveryImg, recoveryOffImg, mapOpenImg, mapArrowImg, mapWaystoneImg
    global txtImgStatus, edtPromptPath, edtRecoveryPath, edtMapOpenPath, edtMapArrowPath, edtMapWayPath

    if IsSet(edtPromptPath)
        edtPromptPath.Value := promptImg
    if IsSet(edtRecoveryPath)
        edtRecoveryPath.Value := recoveryImg
    if IsSet(edtMapOpenPath)
        edtMapOpenPath.Value := mapOpenImg
    if IsSet(edtMapArrowPath)
        edtMapArrowPath.Value := mapArrowImg
    if IsSet(edtMapWayPath)
        edtMapWayPath.Value := mapWaystoneImg

    if IsSet(txtImgStatus) {
        if (wayCardView = "WORLDMAP") {
            if !FileExist(mapArrowImg)
                txtImgStatus.Text := "● ARROW MISSING"
            else if (!FileExist(mapWaystoneImg) && !FileExist(mapWaystoneOffImg))
                txtImgStatus.Text := "● ICON MISSING"
            else if !FileExist(mapOpenImg)
                txtImgStatus.Text := "● OPEN IMG MISSING"
            else
                txtImgStatus.Text := "● MAP READY"
        } else {
            if !FileExist(promptImg)
                txtImgStatus.Text := "● PROMPT MISSING"
            else if (!FileExist(recoveryImg) && !FileExist(recoveryOffImg))
                txtImgStatus.Text := "● SPRITE MISSING"
            else
                txtImgStatus.Text := "● READY"
        }
    }
}

RefreshHotkeyLabels() {
    global hotkeys, btnActWaystone, btnActTower, btnActMapCycle, btnActPreset, btnActCircle, btnActChaos, btnActExit
    global btnF9TabQueue, btnF7TabRun, btnCycleStart
    if !IsSet(btnActWaystone)
        return

    btnActWaystone.btn.Text := "Waystone 8-Star [" FormatHotkeyShort(hotkeys.waystone) "]"
    btnActTower.btn.Text    := "Tower Mode [" FormatHotkeyShort(hotkeys.tower) "]"
    btnActMapCycle.btn.Text := "Map Cycle [" FormatHotkeyShort(hotkeys.mapCycle) "]"
    btnActPreset.btn.Text   := "Preset [" FormatHotkeyShort(hotkeys.preset) "]"
    btnActCircle.btn.Text   := "Circle [" FormatHotkeyShort(hotkeys.circle) "]"
    btnActChaos.btn.Text    := "Chaos [" FormatHotkeyShort(hotkeys.chaos) "]"
    btnActExit.btn.Text     := "Exit [" FormatHotkeyShort(hotkeys.exit) "]"

    if IsSet(btnCycleStart)
        btnCycleStart.btn.Text := "Cycle [" FormatHotkeyShort(hotkeys.mapCycle) "]"
    if IsSet(btnF9TabQueue)
        btnF9TabQueue.btn.Text := "Queue Circle [" FormatHotkeyShort(hotkeys.circle) "]"
    if IsSet(btnF7TabRun)
        btnF7TabRun.btn.Text := "Run Chaos Test [" FormatHotkeyShort(hotkeys.chaos) "]"
}

RefreshSettingsTabUI() {
    global hudEnabled, hotkeysEnabled, hotkeys, btnSetHud, btnSetKeysToggle, hkBadges

    if IsSet(btnSetHud)
        btnSetHud.btn.Text := hudEnabled ? "HUD: ON" : "HUD: OFF"

    if IsSet(btnSetKeysToggle)
        btnSetKeysToggle.btn.Text := hotkeysEnabled ? "KEYS: ON" : "KEYS: OFF"

    for actionKey, badge in hkBadges {
        badge.Text := FormatHotkeyRaw(hotkeys.%actionKey%)
    }
}

; ==============================================================================
; EDIT & PRESET HANDLERS
; ==============================================================================

SelectWaystonePreset(useWide) {
    global wideStarMode, hudStatus
    wideStarMode := useWide
    RefreshPresetUI()
    SaveConfig()
    modeName := wideStarMode ? "VERY WIDE" : "SHORT"
    hudStatus := "Waystone Preset -> " modeName
    UpdateGuiStatus(hudStatus)
}

OnSettingsChanged(*) {
    global isUpdatingUI, imgTolerance, edtTolerance, recoveryTolerance, edtRecTolerance
    global mapTolerance, edtMapTol, mapMsPerPx, edtMapMsPx, bossBannerTol, edtBossTol, topLabelTol, edtTopLabelTol, portalTol, edtPortalTol
    if (isUpdatingUI)
        return
    imgTolerance      := ParseSetting(edtTolerance.Value, imgTolerance, 0, 255)
    recoveryTolerance := ParseSetting(edtRecTolerance.Value, recoveryTolerance, 0, 255)
    mapTolerance      := ParseSetting(edtMapTol.Value, mapTolerance, 0, 255)
    mapMsPerPx        := ParseSetting(edtMapMsPx.Value, mapMsPerPx, 5, 300)
    if IsSet(edtBossTol)
        bossBannerTol := ParseSetting(edtBossTol.Value, bossBannerTol, 0, 255)
    if IsSet(edtTopLabelTol)
        topLabelTol := ParseSetting(edtTopLabelTol.Value, topLabelTol, 0, 255)
    if IsSet(edtPortalTol)
        portalTol := ParseSetting(edtPortalTol.Value, portalTol, 0, 255)
    SaveConfig()
}

OnWaystoneManualEdit(*) {
    global isUpdatingUI, wideStarMode, shortCfg, shortBase, shortPct, wideCfg, wideBase, widePct
    global edtWayUp, edtWayDown, edtWayLeft, edtWayRight, edtWayDiag, edtWayRet, txtWayRangePct

    if (isUpdatingUI)
        return

    cfg  := wideStarMode ? wideCfg  : shortCfg
    base := wideStarMode ? wideBase : shortBase

    cfg.up    := ParseSetting(edtWayUp.Value, cfg.up, 10, 30000)
    cfg.down  := ParseSetting(edtWayDown.Value, cfg.down, 10, 30000)
    cfg.left  := ParseSetting(edtWayLeft.Value, cfg.left, 10, 30000)
    cfg.right := ParseSetting(edtWayRight.Value, cfg.right, 10, 30000)
    cfg.diag  := ParseSetting(edtWayDiag.Value, cfg.diag, 10, 30000)
    cfg.ret   := ParseSetting(edtWayRet.Value, cfg.ret, 10, 60000)

    base.up    := cfg.up
    base.down  := cfg.down
    base.left  := cfg.left
    base.right := cfg.right
    base.diag  := cfg.diag
    base.ret   := cfg.ret

    if (wideStarMode)
        widePct := 100
    else
        shortPct := 100
    txtWayRangePct.Text := "100%"

    SaveConfig()
}

OnTowerParamEdit(*) {
    global isUpdatingUI, towerCenterMs, towerRadiusMs, towerPortalMs, towerBase, towerRangePct, towerImgTol
    global edtTowerCenter, edtTowerRadius, edtTowerPortal, txtTowerRangePct, edtTowerTol

    if (isUpdatingUI)
        return

    valCenter := ParseSetting(edtTowerCenter.Value, 0, 10, 30000)
    valRadius := ParseSetting(edtTowerRadius.Value, 0, 10, 30000)
    valPortal := ParseSetting(edtTowerPortal.Value, 0, 10, 30000)

    if (valCenter > 0)
        towerCenterMs := valCenter
    if (valRadius > 0)
        towerRadiusMs := valRadius
    if (valPortal > 0)
        towerPortalMs := valPortal

    if IsSet(edtTowerTol)
        towerImgTol := ParseSetting(edtTowerTol.Value, towerImgTol, 0, 255)

    towerBase.center := towerCenterMs
    towerBase.radius := towerRadiusMs
    towerBase.portal := towerPortalMs
    towerRangePct    := 100

    if IsSet(txtTowerRangePct)
        txtTowerRangePct.Text := "100%"

    SaveConfig()
}

OnCircleManualEdit(*) {
    global isUpdatingUI, circleCfg, circleBase, circlePct
    global edtCirOut, edtCirEdge, edtCirCard, edtCirDiag, edtCirRet, txtCirRangePct

    if (isUpdatingUI)
        return

    circleCfg.out  := ParseSetting(edtCirOut.Value, circleCfg.out, 10, 30000)
    circleCfg.edge := ParseSetting(edtCirEdge.Value, circleCfg.edge, 10, 30000)
    circleCfg.card := ParseSetting(edtCirCard.Value, circleCfg.card, 10, 30000)
    circleCfg.diag := ParseSetting(edtCirDiag.Value, circleCfg.diag, 10, 30000)
    circleCfg.ret  := ParseSetting(edtCirRet.Value, circleCfg.ret, 10, 60000)

    circleBase.out  := circleCfg.out
    circleBase.edge := circleCfg.edge
    circleBase.card := circleCfg.card
    circleBase.diag := circleCfg.diag
    circleBase.ret  := circleCfg.ret
    circlePct := 100
    txtCirRangePct.Text := "100%"

    SaveConfig()
}

OnChaosManualEdit(*) {
    global isUpdatingUI, chaosCfg, chaosBase, chaosPct
    global edtChaosAngle, edtChaosZigDiag, edtChaosZigSide, txtChaosRangePct

    if (isUpdatingUI)
        return

    chaosCfg.angle   := ParseSetting(edtChaosAngle.Value, chaosCfg.angle, 10, 30000)
    chaosCfg.zigDiag := ParseSetting(edtChaosZigDiag.Value, chaosCfg.zigDiag, 10, 30000)
    chaosCfg.zigSide := ParseSetting(edtChaosZigSide.Value, chaosCfg.zigSide, 10, 30000)

    chaosBase.angle   := chaosCfg.angle
    chaosBase.zigDiag := chaosCfg.zigDiag
    chaosBase.zigSide := chaosCfg.zigSide
    chaosPct := 100
    txtChaosRangePct.Text := "100%"

    SaveConfig()
}

; ==============================================================================
; IMAGE IMPORTS & DETECTION TESTS
; ==============================================================================

ImportPromptImage(*) {
    global promptImg, mainGui, edtPromptPath
    mainGui.Opt("+OwnDialogs")
    selected := FileSelect(3, A_ScriptDir, "Select Waystone Prompt Image (Return to Town (E) or shortened)", "Images (*.png; *.jpg; *.jpeg; *.bmp)")
    if (selected != "") {
        promptImg := selected
        RefreshImageStatus()
        SendMessage(0x00B1, 999, 999, edtPromptPath.Hwnd)
        SaveConfig()
        UpdateGuiStatus("Imported prompt image.")
    }
}

ImportRecoveryImage(*) {
    global recoveryImg, recoverySearchPrefix, mainGui, edtRecoveryPath
    mainGui.Opt("+OwnDialogs")
    selected := FileSelect(3, A_ScriptDir, "Select Recovery Waystone Sprite Image", "Images (*.png; *.jpg; *.jpeg; *.bmp)")
    if (selected != "") {
        recoveryImg := selected
        recoverySearchPrefix := ""
        RefreshImageStatus()
        SendMessage(0x00B1, 999, 999, edtRecoveryPath.Hwnd)
        SaveConfig()
        UpdateGuiStatus("Imported recovery sprite.")
    }
}

ImportMapOpenImage(*) {
    global mapOpenImg, mapOpenPrefix, mainGui, edtMapOpenPath
    mainGui.Opt("+OwnDialogs")
    selected := FileSelect(3, A_ScriptDir, "Select World Map Open Header Image (map_open.png)", "Images (*.png; *.jpg; *.jpeg; *.bmp)")
    if (selected != "") {
        mapOpenImg := selected
        mapOpenPrefix := ""
        RefreshImageStatus()
        SendMessage(0x00B1, 999, 999, edtMapOpenPath.Hwnd)
        SaveConfig()
        UpdateGuiStatus("Imported World Map open indicator.")
    }
}

ImportMapArrowImage(*) {
    global mapArrowImg, mapArrowPrefix, mainGui, edtMapArrowPath
    mainGui.Opt("+OwnDialogs")
    selected := FileSelect(3, A_ScriptDir, "Select World Map Red Arrow Image", "Images (*.png; *.jpg; *.jpeg; *.bmp)")
    if (selected != "") {
        mapArrowImg := selected
        mapArrowPrefix := ""
        RefreshImageStatus()
        SendMessage(0x00B1, 999, 999, edtMapArrowPath.Hwnd)
        SaveConfig()
        UpdateGuiStatus("Imported World Map arrow image.")
    }
}

ImportMapWaystoneImage(*) {
    global mapWaystoneImg, mapWayPrefix, mainGui, edtMapWayPath
    mainGui.Opt("+OwnDialogs")
    selected := FileSelect(3, A_ScriptDir, "Select World Map Waystone Icon Image", "Images (*.png; *.jpg; *.jpeg; *.bmp)")
    if (selected != "") {
        mapWaystoneImg := selected
        mapWayPrefix := ""
        RefreshImageStatus()
        SendMessage(0x00B1, 999, 999, edtMapWayPath.Hwnd)
        SaveConfig()
        UpdateGuiStatus("Imported World Map Waystone icon.")
    }
}

ImportBossComingImage(*) {
    global bossComingImg, mainGui, edtBossComingPath
    mainGui.Opt("+OwnDialogs")
    selected := FileSelect(3, A_ScriptDir, "Select Boss Coming Banner Image", "Images (*.png; *.jpg; *.jpeg; *.bmp)")
    if (selected != "") {
        bossComingImg := selected
        if IsSet(edtBossComingPath) {
            edtBossComingPath.Value := bossComingImg
            SendMessage(0x00B1, 999, 999, edtBossComingPath.Hwnd)
        }
        SaveConfig()
        UpdateGuiStatus("Imported Boss Coming banner.")
    }
}

ImportBossSpawnImage(*) {
    global bossSpawnImg, mainGui, edtBossSpawnPath
    mainGui.Opt("+OwnDialogs")
    selected := FileSelect(3, A_ScriptDir, "Select Boss Spawn Banner Image", "Images (*.png; *.jpg; *.jpeg; *.bmp)")
    if (selected != "") {
        bossSpawnImg := selected
        if IsSet(edtBossSpawnPath) {
            edtBossSpawnPath.Value := bossSpawnImg
            SendMessage(0x00B1, 999, 999, edtBossSpawnPath.Hwnd)
        }
        SaveConfig()
        UpdateGuiStatus("Imported Boss Spawn banner.")
    }
}

ImportBossDefeatedImage(*) {
    global bossDefeatedImg, mainGui, edtBossDefPath
    mainGui.Opt("+OwnDialogs")
    selected := FileSelect(3, A_ScriptDir, "Select Boss Defeated Banner Image", "Images (*.png; *.jpg; *.jpeg; *.bmp)")
    if (selected != "") {
        bossDefeatedImg := selected
        if IsSet(edtBossDefPath) {
            edtBossDefPath.Value := bossDefeatedImg
            SendMessage(0x00B1, 999, 999, edtBossDefPath.Hwnd)
        }
        SaveConfig()
        UpdateGuiStatus("Imported Boss Defeated banner.")
    }
}

ImportInTowerImg(*) {
    global inTowerImg, inTowerPrefix, mainGui, edtInTowerPath
    mainGui.Opt("+OwnDialogs")
    selected := FileSelect(3, A_ScriptDir, "Select In-Tower Indicator Image (in_tower.png)", "Images (*.png; *.jpg; *.jpeg; *.bmp)")
    if (selected != "") {
        inTowerImg := selected
        inTowerPrefix := ""
        if IsSet(edtInTowerPath) {
            edtInTowerPath.Value := inTowerImg
            SendMessage(0x00B1, 999, 999, edtInTowerPath.Hwnd)
        }
        SaveConfig()
        UpdateGuiStatus("Imported In-Tower indicator.")
    }
}

ImportTowerClearedImg(*) {
    global towerClearedImg, towerClearedPrefix, mainGui, edtTowerClearedPath
    mainGui.Opt("+OwnDialogs")
    selected := FileSelect(3, A_ScriptDir, "Select Floor Cleared Image (floor_cleared.png)", "Images (*.png; *.jpg; *.jpeg; *.bmp)")
    if (selected != "") {
        towerClearedImg := selected
        towerClearedPrefix := ""
        if IsSet(edtTowerClearedPath) {
            edtTowerClearedPath.Value := towerClearedImg
            SendMessage(0x00B1, 999, 999, edtTowerClearedPath.Hwnd)
        }
        SaveConfig()
        UpdateGuiStatus("Imported Floor Cleared indicator.")
    }
}

ImportTowerNextImg(*) {
    global towerNextImg, towerNextPrefix, mainGui, edtTowerNextPath
    mainGui.Opt("+OwnDialogs")
    selected := FileSelect(3, A_ScriptDir, "Select Next Floor Indicator Image (next_floor_indicator.png)", "Images (*.png; *.jpg; *.jpeg; *.bmp)")
    if (selected != "") {
        towerNextImg := selected
        towerNextPrefix := ""
        if IsSet(edtTowerNextPath) {
            edtTowerNextPath.Value := towerNextImg
            SendMessage(0x00B1, 999, 999, edtTowerNextPath.Hwnd)
        }
        SaveConfig()
        UpdateGuiStatus("Imported Next Floor indicator.")
    }
}

TestWaystoneDetection(*) {
    global mainGui, imgTolerance, recoveryImg, recoveryOffImg, recoveryTolerance, lastMatchedStatueImg
    if !InitVisionAndWindow(true)
        return

    mainGui.Hide()
    Sleep(120)
    promptFound := IsOnWaystone(&fx, &fy)
    statueFound := FindWaystoneStatue(&sx, &sy)
    mainGui.Show()

    promptMsg := promptFound
        ? "FOUND at (" fx ", " fy ")"
        : "NOT found (Tol: " imgTolerance ")"

    testedSprite := (statueFound && lastMatchedStatueImg != "") ? lastMatchedStatueImg : recoveryImg
    GetImageDimensions(testedSprite, &rw, &rh)
    statueTag := (testedSprite = recoveryOffImg) ? " [UNLIT]" : " [LIT]"

    statueMsg := (!FileExist(recoveryImg) && !FileExist(recoveryOffImg))
        ? "FILE MISSING (" recoveryImg ")"
        : (statueFound ? "FOUND" statueTag " at (" sx ", " sy ") [" rw "x" rh "px]" : "NOT found (Tol: " recoveryTolerance ", Size: " rw "x" rh "px)")

    mainGui.Opt("+OwnDialogs")
    MsgBox(
        "Point 0 Prompt ('Return to Town'):`n  " promptMsg
        "`n`nRecovery Sprite:`n  " statueMsg
        "`n`nTip: If Recovery Sprite is NOT found, crop an opaque ~24x34px stone + rune patch from Roblox at your zoom level.",
        "Waystone Detection Test",
        (promptFound || statueFound) ? "Iconi" : "Icon!"
    )
}

TestWorldMapDetection(*) {
    global mainGui, mapOpenImg, mapArrowImg, mapWaystoneImg, mapWaystoneOffImg, mapTolerance, mapMsPerPx, currentWaystoneIdx, waystoneRoutes
    if !InitVisionAndWindow(false)
        return

    hasWay := FileExist(mapWaystoneImg) || FileExist(mapWaystoneOffImg)
    if (!FileExist(mapArrowImg) || !hasWay) {
        mainGui.Opt("+OwnDialogs")
        MsgBox("Missing World Map crop(s)!`n`nEnsure these exist:`n- " mapOpenImg " (recommended)`n- " mapArrowImg "`n- " mapWaystoneImg, "World Map Test", "Icon!")
        return
    }

    mainGui.Hide()
    Sleep(120)
    res := ScanWorldMapVector(currentWaystoneIdx)
    mainGui.Show()

    GetImageDimensions(mapOpenImg, &ow, &oh)
    GetImageDimensions(mapArrowImg, &aw, &ah)
    GetImageDimensions(mapWaystoneImg, &ww, &wh)

    openMsg := !FileExist(mapOpenImg)
        ? "FILE MISSING (using Arrow fallback)"
        : (res.openDetected ? "DETECTED [" ow "x" oh "px]" : "NOT detected (Tol: " mapTolerance ", Size: " ow "x" oh "px)")

    arrowMsg := res.arrowFound
        ? "FOUND at (" res.ax ", " res.ay ") [" aw "x" ah "px]"
        : "NOT found (Tol: " mapTolerance ", Size: " aw "x" ah "px)"

    areaMsg := res.areaFound
        ? "MATCHED " waystoneRoutes[currentWaystoneIdx].file
        : "NOT matched (used arrow radius fallback)"

    wayMsg := res.wayFound
        ? "FOUND at (" res.wx ", " res.wy ") [" ww "x" wh "px]"
        : "NOT found (Tol: " mapTolerance ")"

    vecMsg := res.ok
        ? "dx = " res.dx "px, dy = " res.dy "px`n  Est. Walk: " Round(res.dx * mapMsPerPx) "ms X, " Round(res.dy * mapMsPerPx) "ms Y (" mapMsPerPx " ms/px)"
        : "N/A"

    mainGui.Opt("+OwnDialogs")
    MsgBox(
        "Map Open Indicator (map_open.png):`n  " openMsg
        "`n`nRed Player Arrow:`n  " arrowMsg
        "`n`nMap Area (" waystoneRoutes[currentWaystoneIdx].label "):`n  " areaMsg
        "`n`nWaystone Icon:`n  " wayMsg
        "`n`nReturn Vector:`n  " vecMsg,
        "World Map (M) Detection Test",
        res.ok ? "Iconi" : "Icon!"
    )
}

TestTowerDetection(*) {
    global mainGui, inTowerImg, towerClearedImg, towerNextImg, towerImgTol
    if !InitVisionAndWindow(false)
        return

    mainGui.Hide()
    Sleep(120)
    inFound      := IsInTower(&ix, &iy)
    clearedFound := IsFloorCleared(&cx, &cy)
    nextFound    := IsNextFloorIndicator(&nx, &ny)
    mainGui.Show()

    GetImageDimensions(inTowerImg, &inW, &inH)
    GetImageDimensions(towerClearedImg, &cw, &ch)
    GetImageDimensions(towerNextImg, &nw, &nh)

    inMsg := !FileExist(inTowerImg)
        ? "FILE MISSING (assumes in-tower)"
        : (inFound ? "DETECTED at (" ix ", " iy ") [" inW "x" inH "px]" : "NOT found (Tol: " towerImgTol ")")

    clrMsg := !FileExist(towerClearedImg)
        ? "FILE MISSING (" towerClearedImg ")"
        : (clearedFound ? "FOUND at (" cx ", " cy ") [" cw "x" ch "px]" : "NOT found (Tol: " towerImgTol ")")

    nxtMsg := !FileExist(towerNextImg)
        ? "FILE MISSING (" towerNextImg ")"
        : (nextFound ? "FOUND at (" nx ", " ny ") [" nw "x" nh "px]" : "NOT found (Tol: " towerImgTol ")")

    mainGui.Opt("+OwnDialogs")
    MsgBox(
        "In Tower Indicator (in_tower.png):`n  " inMsg
        "`n`nFloor Cleared Banner (floor_cleared.png):`n  " clrMsg
        "`n`nNext Floor Indicator (next_floor_indicator.png):`n  " nxtMsg,
        "Tower Detection Test",
        (inFound || clearedFound || nextFound) ? "Iconi" : "Icon!"
    )
}

TestBossDetection(*) {
    global mainGui, bossComingImg, bossSpawnImg, bossAlreadyInImg, bossDefeatedImg
    global minibossComingImg, minibossSpawnImg, minibossAlreadyInImg, minibossDefeatedImg
    global youDefeatedBossImg, bossBannerTol, robloxWinBox
    if !InitVisionAndWindow(false)
        return

    mainGui.Hide()
    Sleep(160)
    bossBox := GetUpperCenterBossBox()
    fullBox := {x1: 0, y1: 0, x2: A_ScreenWidth, y2: A_ScreenHeight}

    items := [
        {name: "Boss Coming",      path: bossComingImg},
        {name: "Boss Spawn",       path: bossSpawnImg},
        {name: "Boss Already In",  path: bossAlreadyInImg},
        {name: "Boss Defeated",    path: bossDefeatedImg},
        {name: "Mini Coming",      path: minibossComingImg},
        {name: "Mini Spawn",       path: minibossSpawnImg},
        {name: "Mini Already In",  path: minibossAlreadyInImg},
        {name: "Mini Defeated",    path: minibossDefeatedImg},
        {name: "Your Kill Conf",   path: youDefeatedBossImg}
    ]

    anyFound := false
    report := "Upper-Center Box: (" bossBox.x1 "," bossBox.y1 ") -> (" bossBox.x2 "," bossBox.y2 ") | Tol: " bossBannerTol "`n`n"

    for it in items {
        if !FileExist(it.path) {
            report .= it.name ": MISSING FILE`n"
            continue
        }
        p := ""
        ok := SearchBossImage(it.path, bossBox, bossBannerTol, &fx, &fy, &p, &usedMask)
        if (ok) {
            anyFound := true
            report .= it.name ": FOUND at (" fx "," fy ")" (usedMask ? " [Verified BMP]" : "") "`n"
        } else {
            okFull := SearchBossImage(it.path, fullBox, bossBannerTol, &fx2, &fy2, &p, &usedMask2)
            report .= it.name ": " (okFull ? ("OUTSIDE BOX at (" fx2 "," fy2 ")") : "Not visible") "`n"
        }
    }

    mainGui.Show()
    mainGui.Opt("+OwnDialogs")
    MsgBox(report, "Boss / Miniboss Detection Test", anyFound ? "Iconi" : "Icon!")
}

; ==============================================================================
; DEFAULTS RESETS
; ==============================================================================

ResetWaystoneDefaults(*) {
    global shortCfg, shortBase, shortPct, wideCfg, wideBase, widePct
    global imgTolerance, recoveryTolerance, mapTolerance, mapMsPerPx
    global isUpdatingUI, edtTolerance, edtRecTolerance, edtMapTol, edtMapMsPx

    shortCfg  := {up: 1050, down: 1300, left: 1300, right: 1300, diag: 1050, ret: 1850}
    shortBase := {up: 1050, down: 1300, left: 1300, right: 1300, diag: 1050, ret: 1850}
    shortPct  := 100

    wideCfg  := {up: 1650, down: 1950, left: 1950, right: 1950, diag: 1650, ret: 2600}
    wideBase := {up: 1650, down: 1950, left: 1950, right: 1950, diag: 1650, ret: 2600}
    widePct  := 100

    imgTolerance      := 45
    recoveryTolerance := 50
    mapTolerance      := 55
    mapMsPerPx        := 42

    isUpdatingUI := true
    edtTolerance.Value    := imgTolerance
    edtRecTolerance.Value := recoveryTolerance
    edtMapTol.Value       := mapTolerance
    edtMapMsPx.Value      := mapMsPerPx
    isUpdatingUI := false

    RefreshPresetUI()
    SaveConfig()
    UpdateGuiStatus("Reset Waystone move times, tolerances & map defaults.")
}

ResetTowerDefaults(*) {
    global towerCenterMs, towerRadiusMs, towerPortalMs, towerBase, towerRangePct, towerImgTol
    global isUpdatingUI, edtTowerCenter, edtTowerRadius, edtTowerPortal, txtTowerRangePct, edtTowerTol

    towerCenterMs := 500
    towerRadiusMs := 500
    towerPortalMs := 1000
    towerBase := {center: 500, radius: 500, portal: 1000}
    towerRangePct := 100
    towerImgTol := 50

    isUpdatingUI := true
    if IsSet(edtTowerCenter)
        edtTowerCenter.Value := towerCenterMs
    if IsSet(edtTowerRadius)
        edtTowerRadius.Value := towerRadiusMs
    if IsSet(edtTowerPortal)
        edtTowerPortal.Value := towerPortalMs
    if IsSet(txtTowerRangePct)
        txtTowerRangePct.Text := "100%"
    if IsSet(edtTowerTol)
        edtTowerTol.Value := towerImgTol
    isUpdatingUI := false

    SaveConfig()
    UpdateGuiStatus("Reset Tower Mode timings to defaults (500/500/1000ms).")
}

ResetCycleDefaults(*) {
    global currentWaystoneIdx, bossBannerTol, topLabelTol, portalTol, isUpdatingUI, edtBossTol, edtTopLabelTol, edtPortalTol, edtCycleSearch
    currentWaystoneIdx := 0
    bossBannerTol := 65
    topLabelTol := 65
    portalTol := 60
    isUpdatingUI := true
    if IsSet(edtBossTol)
        edtBossTol.Value := bossBannerTol
    if IsSet(edtTopLabelTol)
        edtTopLabelTol.Value := topLabelTol
    if IsSet(edtPortalTol)
        edtPortalTol.Value := portalTol
    if IsSet(edtCycleSearch)
        edtCycleSearch.Value := ""
    isUpdatingUI := false
    RefreshCycleUI()
    SaveConfig()
    UpdateGuiStatus("Reset Cycle start to WS #0: Eldoria Hub.")
}

ResetF9F7Defaults(*) {
    global circleCfg, circleBase, circlePct, chaosCfg, chaosBase, chaosPct

    circleCfg  := {out: 1350, edge: 800, card: 960, diag: 960, ret: 2600}
    circleBase := {out: 1350, edge: 800, card: 960, diag: 960, ret: 2600}
    circlePct  := 100

    chaosCfg  := {angle: 1750, zigDiag: 450, zigSide: 500}
    chaosBase := {angle: 1750, zigDiag: 450, zigSide: 500}
    chaosPct  := 100

    RefreshCircleUI()
    RefreshChaosUI()
    SaveConfig()
    UpdateGuiStatus("Reset F9 Circle & F7 Chaos defaults.")
}