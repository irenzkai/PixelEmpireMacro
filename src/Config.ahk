; ==============================================================================
; CONFIGURATION (INI LOAD / SAVE & VALIDATION)
; ==============================================================================

LoadConfig() {
    global iniFile, promptImg, recoveryImg, recoveryOffImg, recoveryTolerance, imgTolerance, wideStarMode
    global mapOpenImg, mapArrowImg, mapWaystoneImg, mapWaystoneOffImg, mapTolerance, mapMsPerPx, useWorldMapRecovery
    global currentWaystoneIdx, maxWaystoneIdx, bossBannerTol, topLabelTol, portalTol
    global bossComingImg, bossSpawnImg, bossDefeatedImg
    global towerCenterMs, towerPortalMs, towerRadiusMs, towerBase, towerRangePct, towerImgTol
    global inTowerImg, towerClearedImg, towerNextImg
    global shortCfg, shortBase, shortPct, wideCfg, wideBase, widePct
    global circleCfg, circleBase, circlePct, chaosCfg, chaosBase, chaosPct
    global darkMode, hudEnabled, overlayCustomPos, overlayX, overlayY, hotkeysEnabled, hotkeys

    if !FileExist(iniFile)
        return

    savedImg := IniRead(iniFile, "General", "PromptImg", promptImg)
    if (savedImg != "")
        promptImg := savedImg

    savedRecImg := IniRead(iniFile, "General", "RecoveryImg", recoveryImg)
    if (savedRecImg != "")
        recoveryImg := savedRecImg

    savedRecOffImg := IniRead(iniFile, "General", "RecoveryOffImg", recoveryOffImg)
    if (savedRecOffImg != "")
        recoveryOffImg := savedRecOffImg

    recoveryTolerance := ParseSetting(IniRead(iniFile, "General", "RecoveryTolerance", recoveryTolerance), recoveryTolerance, 0, 255)
    imgTolerance      := ParseSetting(IniRead(iniFile, "General", "ImgTolerance", imgTolerance), imgTolerance, 0, 255)
    wideStarMode      := (IniRead(iniFile, "General", "WideStarMode", wideStarMode ? "1" : "0") = "1")

    savedMapOpen := IniRead(iniFile, "WorldMap", "OpenImg", mapOpenImg)
    if (savedMapOpen != "")
        mapOpenImg := savedMapOpen
    savedArrow := IniRead(iniFile, "WorldMap", "ArrowImg", mapArrowImg)
    if (savedArrow != "")
        mapArrowImg := savedArrow
    savedMapWay := IniRead(iniFile, "WorldMap", "WaystoneImg", mapWaystoneImg)
    if (savedMapWay != "")
        mapWaystoneImg := savedMapWay
    savedMapWayOff := IniRead(iniFile, "WorldMap", "WaystoneOffImg", mapWaystoneOffImg)
    if (savedMapWayOff != "")
        mapWaystoneOffImg := savedMapWayOff
    mapTolerance        := ParseSetting(IniRead(iniFile, "WorldMap", "Tolerance", mapTolerance), mapTolerance, 0, 255)
    mapMsPerPx          := ParseSetting(IniRead(iniFile, "WorldMap", "MsPerPx", mapMsPerPx), mapMsPerPx, 5, 300)
    useWorldMapRecovery := (IniRead(iniFile, "WorldMap", "Enabled", useWorldMapRecovery ? "1" : "0") = "1")

    currentWaystoneIdx := ParseSetting(IniRead(iniFile, "MapCycle", "StartWs", currentWaystoneIdx), currentWaystoneIdx, 0, maxWaystoneIdx)
    topLabelTol        := ParseSetting(IniRead(iniFile, "MapCycle", "TopLabelTol", topLabelTol), topLabelTol, 0, 255)
    bossBannerTol      := ParseSetting(IniRead(iniFile, "MapCycle", "BossTol", bossBannerTol), bossBannerTol, 0, 255)
    portalTol          := ParseSetting(IniRead(iniFile, "MapCycle", "PortalTol", portalTol), portalTol, 0, 255)

    savedBossComing := IniRead(iniFile, "MapCycle", "BossComingImg", bossComingImg)
    if (savedBossComing != "")
        bossComingImg := savedBossComing
    savedBossSpawn := IniRead(iniFile, "MapCycle", "BossSpawnImg", bossSpawnImg)
    if (savedBossSpawn != "")
        bossSpawnImg := savedBossSpawn
    savedBossDef := IniRead(iniFile, "MapCycle", "BossDefeatedImg", bossDefeatedImg)
    if (savedBossDef != "")
        bossDefeatedImg := savedBossDef

    savedInTower := IniRead(iniFile, "TowerMode", "InTowerImg", inTowerImg)
    if (savedInTower != "")
        inTowerImg := savedInTower
    savedCleared := IniRead(iniFile, "TowerMode", "ClearedImg", towerClearedImg)
    if (savedCleared != "")
        towerClearedImg := savedCleared
    savedNext := IniRead(iniFile, "TowerMode", "NextImg", towerNextImg)
    if (savedNext != "")
        towerNextImg := savedNext

    rawCenter := Integer(IniRead(iniFile, "TowerMode", "CenterMs", 500))
    rawPortal := Integer(IniRead(iniFile, "TowerMode", "PortalMs", 1000))
    towerCenterMs := (rawCenter = 1500) ? 500 : ParseSetting(rawCenter, 500, 10, 30000)
    towerRadiusMs := ParseSetting(IniRead(iniFile, "TowerMode", "RadiusMs", 500), 500, 10, 30000)
    towerPortalMs := (rawPortal = 2000) ? 1000 : ParseSetting(rawPortal, 1000, 10, 30000)
    towerRangePct := ParseSetting(IniRead(iniFile, "TowerMode", "RangePct", 100), 100, 10, 500)

    towerBase.center := ParseSetting(IniRead(iniFile, "TowerBase", "CenterMs", towerCenterMs), towerCenterMs, 10, 30000)
    towerBase.radius := ParseSetting(IniRead(iniFile, "TowerBase", "RadiusMs", towerRadiusMs), towerRadiusMs, 10, 30000)
    towerBase.portal := ParseSetting(IniRead(iniFile, "TowerBase", "PortalMs", towerPortalMs), towerPortalMs, 10, 30000)
    towerImgTol      := ParseSetting(IniRead(iniFile, "TowerMode", "ImgTolerance", towerImgTol), towerImgTol, 0, 255)

    darkMode         := (IniRead(iniFile, "Appearance", "DarkMode", darkMode ? "1" : "0") = "1")
    hudEnabled       := (IniRead(iniFile, "Appearance", "HudEnabled", hudEnabled ? "1" : "0") = "1")
    overlayCustomPos := (IniRead(iniFile, "Appearance", "OverlayCustomPos", "0") = "1")
    overlayX         := ParseSetting(IniRead(iniFile, "Appearance", "OverlayX", -1), -1, -10000, 10000)
    overlayY         := ParseSetting(IniRead(iniFile, "Appearance", "OverlayY", -1), -1, -10000, 10000)

    hotkeysEnabled    := (IniRead(iniFile, "Hotkeys", "Enabled", hotkeysEnabled ? "1" : "0") = "1")
    hotkeys.waystone  := IniRead(iniFile, "Hotkeys", "Waystone", hotkeys.waystone)
    hotkeys.tower     := IniRead(iniFile, "Hotkeys", "Tower", hotkeys.tower)
    hotkeys.mapCycle  := IniRead(iniFile, "Hotkeys", "MapCycle", hotkeys.mapCycle)
    hotkeys.preset    := IniRead(iniFile, "Hotkeys", "Preset", hotkeys.preset)
    hotkeys.circle    := IniRead(iniFile, "Hotkeys", "Circle", hotkeys.circle)
    hotkeys.chaos     := IniRead(iniFile, "Hotkeys", "Chaos", hotkeys.chaos)
    hotkeys.exit      := IniRead(iniFile, "Hotkeys", "Exit", hotkeys.exit)

    shortCfg.up    := ParseSetting(IniRead(iniFile, "ShortPreset", "Up", shortCfg.up), shortCfg.up)
    shortCfg.down  := ParseSetting(IniRead(iniFile, "ShortPreset", "Down", shortCfg.down), shortCfg.down)
    shortCfg.left  := ParseSetting(IniRead(iniFile, "ShortPreset", "Left", shortCfg.left), shortCfg.left)
    shortCfg.right := ParseSetting(IniRead(iniFile, "ShortPreset", "Right", shortCfg.right), shortCfg.right)
    shortCfg.diag  := ParseSetting(IniRead(iniFile, "ShortPreset", "Diag", shortCfg.diag), shortCfg.diag)
    shortCfg.ret   := ParseSetting(IniRead(iniFile, "ShortPreset", "Ret", shortCfg.ret), shortCfg.ret, 100, 60000)
    shortPct       := ParseSetting(IniRead(iniFile, "ShortPreset", "RangePct", 100), 100, 10, 500)
    shortBase.up    := ParseSetting(IniRead(iniFile, "ShortBase", "Up", shortCfg.up), shortCfg.up)
    shortBase.down  := ParseSetting(IniRead(iniFile, "ShortBase", "Down", shortCfg.down), shortCfg.down)
    shortBase.left  := ParseSetting(IniRead(iniFile, "ShortBase", "Left", shortCfg.left), shortCfg.left)
    shortBase.right := ParseSetting(IniRead(iniFile, "ShortBase", "Right", shortCfg.right), shortCfg.right)
    shortBase.diag  := ParseSetting(IniRead(iniFile, "ShortBase", "Diag", shortCfg.diag), shortCfg.diag)
    shortBase.ret   := ParseSetting(IniRead(iniFile, "ShortBase", "Ret", shortCfg.ret), shortCfg.ret, 100, 60000)

    wideCfg.up     := ParseSetting(IniRead(iniFile, "WidePreset", "Up", wideCfg.up), wideCfg.up)
    wideCfg.down   := ParseSetting(IniRead(iniFile, "WidePreset", "Down", wideCfg.down), wideCfg.down)
    wideCfg.left   := ParseSetting(IniRead(iniFile, "WidePreset", "Left", wideCfg.left), wideCfg.left)
    wideCfg.right  := ParseSetting(IniRead(iniFile, "WidePreset", "Right", wideCfg.right), wideCfg.right)
    wideCfg.diag   := ParseSetting(IniRead(iniFile, "WidePreset", "Diag", wideCfg.diag), wideCfg.diag)
    wideCfg.ret    := ParseSetting(IniRead(iniFile, "WidePreset", "Ret", wideCfg.ret), wideCfg.ret, 100, 60000)
    widePct        := ParseSetting(IniRead(iniFile, "WidePreset", "RangePct", 100), 100, 10, 500)
    wideBase.up    := ParseSetting(IniRead(iniFile, "WideBase", "Up", wideCfg.up), wideCfg.up)
    wideBase.down  := ParseSetting(IniRead(iniFile, "WideBase", "Down", wideCfg.down), wideCfg.down)
    wideBase.left  := ParseSetting(IniRead(iniFile, "WideBase", "Left", wideCfg.left), wideCfg.left)
    wideBase.right := ParseSetting(IniRead(iniFile, "WideBase", "Right", wideCfg.right), wideCfg.right)
    wideBase.diag  := ParseSetting(IniRead(iniFile, "WideBase", "Diag", wideCfg.diag), wideCfg.diag)
    wideBase.ret   := ParseSetting(IniRead(iniFile, "WideBase", "Ret", wideCfg.ret), wideCfg.ret, 100, 60000)

    circleCfg.out  := ParseSetting(IniRead(iniFile, "CircleMode", "Out", circleCfg.out), circleCfg.out)
    circleCfg.edge := ParseSetting(IniRead(iniFile, "CircleMode", "Edge", circleCfg.edge), circleCfg.edge)
    circleCfg.card := ParseSetting(IniRead(iniFile, "CircleMode", "Card", circleCfg.card), circleCfg.card)
    circleCfg.diag := ParseSetting(IniRead(iniFile, "CircleMode", "Diag", circleCfg.diag), circleCfg.diag)
    circleCfg.ret  := ParseSetting(IniRead(iniFile, "CircleMode", "Ret", circleCfg.ret), circleCfg.ret, 100, 60000)
    circlePct      := ParseSetting(IniRead(iniFile, "CircleMode", "RangePct", 100), 100, 10, 500)
    circleBase.out  := ParseSetting(IniRead(iniFile, "CircleBase", "Out", circleCfg.out), circleCfg.out)
    circleBase.edge := ParseSetting(IniRead(iniFile, "CircleBase", "Edge", circleCfg.edge), circleCfg.edge)
    circleBase.card := ParseSetting(IniRead(iniFile, "CircleBase", "Card", circleCfg.card), circleCfg.card)
    circleBase.diag := ParseSetting(IniRead(iniFile, "CircleBase", "Diag", circleCfg.diag), circleCfg.diag)
    circleBase.ret  := ParseSetting(IniRead(iniFile, "CircleBase", "Ret", circleCfg.ret), circleCfg.ret, 100, 60000)

    chaosCfg.angle   := ParseSetting(IniRead(iniFile, "ChaosMode", "Angle", chaosCfg.angle), chaosCfg.angle)
    chaosCfg.zigDiag := ParseSetting(IniRead(iniFile, "ChaosMode", "ZigDiag", chaosCfg.zigDiag), chaosCfg.zigDiag)
    chaosCfg.zigSide := ParseSetting(IniRead(iniFile, "ChaosMode", "ZigSide", chaosCfg.zigSide), chaosCfg.zigSide)
    chaosPct         := ParseSetting(IniRead(iniFile, "ChaosMode", "RangePct", 100), 100, 10, 500)
    chaosBase.angle   := ParseSetting(IniRead(iniFile, "ChaosBase", "Angle", chaosCfg.angle), chaosCfg.angle)
    chaosBase.zigDiag := ParseSetting(IniRead(iniFile, "ChaosBase", "ZigDiag", chaosCfg.zigDiag), chaosCfg.zigDiag)
    chaosBase.zigSide := ParseSetting(IniRead(iniFile, "ChaosBase", "ZigSide", chaosCfg.zigSide), chaosCfg.zigSide)
}

SaveConfig() {
    global iniFile, promptImg, recoveryImg, recoveryOffImg, recoveryTolerance, imgTolerance, wideStarMode
    global mapOpenImg, mapArrowImg, mapWaystoneImg, mapWaystoneOffImg, mapTolerance, mapMsPerPx, useWorldMapRecovery
    global currentWaystoneIdx, topLabelTol, bossBannerTol, portalTol, bossComingImg, bossSpawnImg, bossDefeatedImg
    global towerCenterMs, towerRadiusMs, towerPortalMs, towerBase, towerRangePct, towerImgTol
    global inTowerImg, towerClearedImg, towerNextImg
    global shortCfg, shortBase, shortPct, wideCfg, wideBase, widePct
    global circleCfg, circleBase, circlePct, chaosCfg, chaosBase, chaosPct
    global darkMode, hudEnabled, overlayCustomPos, overlayX, overlayY, hotkeysEnabled, hotkeys

    IniWrite(promptImg, iniFile, "General", "PromptImg")
    IniWrite(recoveryImg, iniFile, "General", "RecoveryImg")
    IniWrite(recoveryOffImg, iniFile, "General", "RecoveryOffImg")
    IniWrite(recoveryTolerance, iniFile, "General", "RecoveryTolerance")
    IniWrite(imgTolerance, iniFile, "General", "ImgTolerance")
    IniWrite(wideStarMode ? "1" : "0", iniFile, "General", "WideStarMode")

    IniWrite(mapOpenImg, iniFile, "WorldMap", "OpenImg")
    IniWrite(mapArrowImg, iniFile, "WorldMap", "ArrowImg")
    IniWrite(mapWaystoneImg, iniFile, "WorldMap", "WaystoneImg")
    IniWrite(mapWaystoneOffImg, iniFile, "WorldMap", "WaystoneOffImg")
    IniWrite(mapTolerance, iniFile, "WorldMap", "Tolerance")
    IniWrite(mapMsPerPx, iniFile, "WorldMap", "MsPerPx")
    IniWrite(useWorldMapRecovery ? "1" : "0", iniFile, "WorldMap", "Enabled")

    IniWrite(currentWaystoneIdx, iniFile, "MapCycle", "StartWs")
    IniWrite(topLabelTol, iniFile, "MapCycle", "TopLabelTol")
    IniWrite(bossBannerTol, iniFile, "MapCycle", "BossTol")
    IniWrite(portalTol, iniFile, "MapCycle", "PortalTol")
    IniWrite(bossComingImg, iniFile, "MapCycle", "BossComingImg")
    IniWrite(bossSpawnImg, iniFile, "MapCycle", "BossSpawnImg")
    IniWrite(bossDefeatedImg, iniFile, "MapCycle", "BossDefeatedImg")

    IniWrite(inTowerImg, iniFile, "TowerMode", "InTowerImg")
    IniWrite(towerClearedImg, iniFile, "TowerMode", "ClearedImg")
    IniWrite(towerNextImg, iniFile, "TowerMode", "NextImg")
    IniWrite(towerCenterMs, iniFile, "TowerMode", "CenterMs")
    IniWrite(towerRadiusMs, iniFile, "TowerMode", "RadiusMs")
    IniWrite(towerPortalMs, iniFile, "TowerMode", "PortalMs")
    IniWrite(towerRangePct, iniFile, "TowerMode", "RangePct")
    IniWrite(towerBase.center, iniFile, "TowerBase", "CenterMs")
    IniWrite(towerBase.radius, iniFile, "TowerBase", "RadiusMs")
    IniWrite(towerBase.portal, iniFile, "TowerBase", "PortalMs")
    IniWrite(towerImgTol, iniFile, "TowerMode", "ImgTolerance")

    IniWrite(darkMode ? "1" : "0", iniFile, "Appearance", "DarkMode")
    IniWrite(hudEnabled ? "1" : "0", iniFile, "Appearance", "HudEnabled")
    IniWrite(overlayCustomPos ? "1" : "0", iniFile, "Appearance", "OverlayCustomPos")
    IniWrite(overlayX, iniFile, "Appearance", "OverlayX")
    IniWrite(overlayY, iniFile, "Appearance", "OverlayY")

    IniWrite(hotkeysEnabled ? "1" : "0", iniFile, "Hotkeys", "Enabled")
    IniWrite(hotkeys.waystone, iniFile, "Hotkeys", "Waystone")
    IniWrite(hotkeys.tower, iniFile, "Hotkeys", "Tower")
    IniWrite(hotkeys.mapCycle, iniFile, "Hotkeys", "MapCycle")
    IniWrite(hotkeys.preset, iniFile, "Hotkeys", "Preset")
    IniWrite(hotkeys.circle, iniFile, "Hotkeys", "Circle")
    IniWrite(hotkeys.chaos, iniFile, "Hotkeys", "Chaos")
    IniWrite(hotkeys.exit, iniFile, "Hotkeys", "Exit")

    IniWrite(shortCfg.up, iniFile, "ShortPreset", "Up")
    IniWrite(shortCfg.down, iniFile, "ShortPreset", "Down")
    IniWrite(shortCfg.left, iniFile, "ShortPreset", "Left")
    IniWrite(shortCfg.right, iniFile, "ShortPreset", "Right")
    IniWrite(shortCfg.diag, iniFile, "ShortPreset", "Diag")
    IniWrite(shortCfg.ret, iniFile, "ShortPreset", "Ret")
    IniWrite(shortPct, iniFile, "ShortPreset", "RangePct")
    IniWrite(shortBase.up, iniFile, "ShortBase", "Up")
    IniWrite(shortBase.down, iniFile, "ShortBase", "Down")
    IniWrite(shortBase.left, iniFile, "ShortBase", "Left")
    IniWrite(shortBase.right, iniFile, "ShortBase", "Right")
    IniWrite(shortBase.diag, iniFile, "ShortBase", "Diag")
    IniWrite(shortBase.ret, iniFile, "ShortBase", "Ret")

    IniWrite(wideCfg.up, iniFile, "WidePreset", "Up")
    IniWrite(wideCfg.down, iniFile, "WidePreset", "Down")
    IniWrite(wideCfg.left, iniFile, "WidePreset", "Left")
    IniWrite(wideCfg.right, iniFile, "WidePreset", "Right")
    IniWrite(wideCfg.diag, iniFile, "WidePreset", "Diag")
    IniWrite(wideCfg.ret, iniFile, "WidePreset", "Ret")
    IniWrite(widePct, iniFile, "WidePreset", "RangePct")
    IniWrite(wideBase.up, iniFile, "WideBase", "Up")
    IniWrite(wideBase.down, iniFile, "WideBase", "Down")
    IniWrite(wideBase.left, iniFile, "WideBase", "Left")
    IniWrite(wideBase.right, iniFile, "WideBase", "Right")
    IniWrite(wideBase.diag, iniFile, "WideBase", "Diag")
    IniWrite(wideBase.ret, iniFile, "WideBase", "Ret")

    IniWrite(circleCfg.out, iniFile, "CircleMode", "Out")
    IniWrite(circleCfg.edge, iniFile, "CircleMode", "Edge")
    IniWrite(circleCfg.card, iniFile, "CircleMode", "Card")
    IniWrite(circleCfg.diag, iniFile, "CircleMode", "Diag")
    IniWrite(circleCfg.ret, iniFile, "CircleMode", "Ret")
    IniWrite(circlePct, iniFile, "CircleMode", "RangePct")
    IniWrite(circleBase.out, iniFile, "CircleBase", "Out")
    IniWrite(circleBase.edge, iniFile, "CircleBase", "Edge")
    IniWrite(circleBase.card, iniFile, "CircleBase", "Card")
    IniWrite(circleBase.diag, iniFile, "CircleBase", "Diag")
    IniWrite(circleBase.ret, iniFile, "CircleBase", "Ret")

    IniWrite(chaosCfg.angle, iniFile, "ChaosMode", "Angle")
    IniWrite(chaosCfg.zigDiag, iniFile, "ChaosMode", "ZigDiag")
    IniWrite(chaosCfg.zigSide, iniFile, "ChaosMode", "ZigSide")
    IniWrite(chaosPct, iniFile, "ChaosMode", "RangePct")
    IniWrite(chaosBase.angle, iniFile, "ChaosBase", "Angle")
    IniWrite(chaosBase.zigDiag, iniFile, "ChaosBase", "ZigDiag")
    IniWrite(chaosBase.zigSide, iniFile, "ChaosBase", "ZigSide")
}

ParseSetting(rawVal, fallback, minVal := 50, maxVal := 30000) {
    cleaned := Trim(rawVal)
    if (cleaned != "" && IsInteger(cleaned)) {
        num := Integer(cleaned)
        if (num >= minVal && num <= maxVal)
            return num
    }
    return fallback
}