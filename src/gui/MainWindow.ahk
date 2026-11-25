; ==============================================================================
; MAIN WINDOW BUILDER (7 TABS + PERSISTENT QUICK ACTIONS + STATUS FOOTER)
; ==============================================================================

BuildGUI() {
    global mainGui, activeTab, wayCardView, pageControls, wayCardSubControls, clickableHwnds
    global themeCards, themeDividers, themePrimaryText, themeMutedText, themeEdits
    global themePrimaryBtns, themeSecondaryBtns, themeTabs
    global btnThemeQuick, tabWaystone, tabTower, tabCycle, tabF9F7, tabCapture, tabSettings, tabCredits
    global btnCardSprites, btnCardWorldMap, txtImgStatus
    global edtPromptPath, edtRecoveryPath, edtTolerance, edtRecTolerance
    global edtMapOpenPath, edtMapArrowPath, edtMapWayPath, edtMapTol, edtMapMsPx, btnMapToggle
    global radShortBtn, radWideBtn, edtWayUp, edtWayDown, edtWayLeft, edtWayRight, edtWayDiag, edtWayRet, txtWayRangePct
    global txtCycleWs, edtCycleSearch, txtCycleMatchInfo, txtShortestStatus
    global edtBossComingPath, edtBossSpawnPath, edtBossDefPath, edtBossTol, edtTopLabelTol, edtPortalTol, btnCycleStart
    global txtCapCat, txtCapItem, txtCapPath, txtCapStatus, btnCapOneGo
    global edtCirOut, edtCirEdge, edtCirCard, edtCirDiag, edtCirRet, txtCirRangePct, btnF9TabQueue
    global edtChaosAngle, edtChaosZigDiag, edtChaosZigSide, txtChaosRangePct, btnF7TabRun
    global edtTowerCenter, edtTowerRadius, edtTowerPortal, txtTowerRangePct
    global inTowerImg, edtInTowerPath, edtTowerClearedPath, edtTowerNextPath, edtTowerTol
    global btnActWaystone, btnActTower, btnActMapCycle, btnActPreset, btnActCircle, btnActChaos, btnActExit
    global btnSetDark, btnSetLight, btnSetHud, btnSetKeysToggle, hkBadges
    global txtGuiStatus, promptImg, recoveryImg, imgTolerance, recoveryTolerance
    global mapOpenImg, mapArrowImg, mapWaystoneImg, mapTolerance, mapMsPerPx
    global bossComingImg, bossSpawnImg, bossDefeatedImg, bossBannerTol, topLabelTol, portalTol
    global towerCenterMs, towerRadiusMs, towerPortalMs, towerRangePct, towerImgTol, towerClearedImg, towerNextImg

    pageControls       := Map("WAYSTONE", [], "TOWER", [], "CYCLE", [], "F9F7", [], "CAPTURE", [], "SETTINGS", [], "CREDITS", [])
    wayCardSubControls := Map("SPRITES", [], "WORLDMAP", [])
    clickableHwnds     := Map()
    themeCards         := []
    themeDividers      := []
    themePrimaryText   := []
    themeMutedText     := []
    themeEdits         := []
    themePrimaryBtns   := []
    themeSecondaryBtns := []
    themeTabs          := Map()
    hkBadges           := Map()

    mainGui := Gui("-MaximizeBox", "Pixel Empire Macro")
    mainGui.MarginX := 0
    mainGui.MarginY := 0
    mainGui.SetFont("s9", "Segoe UI")

    ; --- HEADER ---
    lblTitle := mainGui.AddText("x20 y14 w300 h24 +0x80 +0x04000000", "PIXEL EMPIRE MACRO")
    lblTitle.SetFont("s13 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: lblTitle, onCard: false})

    lblSub := mainGui.AddText("x20 y38 w300 h16 +0x80 +0x04000000", "FARMING & GRIND AUTOMATION")
    lblSub.SetFont("s8 Bold", "Segoe UI")
    themeMutedText.Push({ctrl: lblSub, onCard: false})

    btnThemeQuick := AddFlatButton(406, 18, 114, 30, "", false, (*) => ToggleDarkMode())

    ; --- NAVIGATION TABS (7 TABS x 68px + 4px GAP = 500px) ---
    tabWaystone := AddTabButton("WAYSTONE", 20,  66, 68, 30, "WAYSTONE")
    tabTower    := AddTabButton("TOWER",    92,  66, 68, 30, "TOWER")
    tabCycle    := AddTabButton("CYCLE",    164, 66, 68, 30, "CYCLE")
    tabF9F7     := AddTabButton("F9F7",     236, 66, 68, 30, "F9 / F7")
    tabCapture  := AddTabButton("CAPTURE",  308, 66, 68, 30, "CAPTURE")
    tabSettings := AddTabButton("SETTINGS", 380, 66, 68, 30, "SETTINGS")
    tabCredits  := AddTabButton("CREDITS",  452, 66, 68, 30, "CREDITS")

    AddDivider(20, 106, 500)

    ; ==========================================================================
    ; TAB 1: WAYSTONE
    ; ==========================================================================
    AddCard("WAYSTONE", 20, 116, 500, 164)
    AddCardTitle("WAYSTONE", 36, 128, 150, "WAYSTONE VISION")

    btnCardSprites  := AddFlatButton(196, 124, 74, 22, "SPRITES",   false, (*) => SwitchWayCardView("SPRITES"),  "WAYSTONE")
    btnCardWorldMap := AddFlatButton(274, 124, 92, 22, "WORLD MAP", false, (*) => SwitchWayCardView("WORLDMAP"), "WAYSTONE")

    txtImgStatus := mainGui.AddText("x374 y128 w130 h16 Right +0x80 +0x04000000", "")
    txtImgStatus.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtImgStatus, onCard: true})
    pageControls["WAYSTONE"].Push(txtImgStatus)

    AddSubMutedLabel("WAYSTONE", "SPRITES", 36, 162, 56, "Prompt:")
    edtPromptPath := AddSubStyledEdit("WAYSTONE", "SPRITES", 96, 158, 312, 26, promptImg, "ReadOnly")
    AddSubFlatButton("WAYSTONE", "SPRITES", 416, 158, 88, 26, "Import...", false, ImportPromptImage)

    AddSubMutedLabel("WAYSTONE", "SPRITES", 36, 198, 56, "Sprite:")
    edtRecoveryPath := AddSubStyledEdit("WAYSTONE", "SPRITES", 96, 194, 312, 26, recoveryImg, "ReadOnly")
    AddSubFlatButton("WAYSTONE", "SPRITES", 416, 194, 88, 26, "Sprite...", false, ImportRecoveryImage)

    AddSubMutedLabel("WAYSTONE", "SPRITES", 36, 240, 70, "Prompt Tol:")
    edtTolerance := AddSubStyledEdit("WAYSTONE", "SPRITES", 108, 236, 56, 26, imgTolerance, "Number")
    edtTolerance.OnEvent("Change", OnSettingsChanged)

    AddSubMutedLabel("WAYSTONE", "SPRITES", 180, 240, 64, "Sprite Tol:")
    edtRecTolerance := AddSubStyledEdit("WAYSTONE", "SPRITES", 246, 236, 56, 26, recoveryTolerance, "Number")
    edtRecTolerance.OnEvent("Change", OnSettingsChanged)

    AddSubFlatButton("WAYSTONE", "SPRITES", 364, 236, 140, 26, "Test Waystone", false, TestWaystoneDetection)

    AddSubMutedLabel("WAYSTONE", "WORLDMAP", 36, 155, 56, "Open:")
    edtMapOpenPath := AddSubStyledEdit("WAYSTONE", "WORLDMAP", 96, 152, 312, 24, mapOpenImg, "ReadOnly")
    AddSubFlatButton("WAYSTONE", "WORLDMAP", 416, 152, 88, 24, "Open...", false, ImportMapOpenImage)

    AddSubMutedLabel("WAYSTONE", "WORLDMAP", 36, 185, 56, "Arrow:")
    edtMapArrowPath := AddSubStyledEdit("WAYSTONE", "WORLDMAP", 96, 182, 312, 24, mapArrowImg, "ReadOnly")
    AddSubFlatButton("WAYSTONE", "WORLDMAP", 416, 182, 88, 24, "Arrow...", false, ImportMapArrowImage)

    AddSubMutedLabel("WAYSTONE", "WORLDMAP", 36, 215, 56, "Icon:")
    edtMapWayPath := AddSubStyledEdit("WAYSTONE", "WORLDMAP", 96, 212, 312, 24, mapWaystoneImg, "ReadOnly")
    AddSubFlatButton("WAYSTONE", "WORLDMAP", 416, 212, 88, 24, "Icon...", false, ImportMapWaystoneImage)

    AddSubMutedLabel("WAYSTONE", "WORLDMAP", 36, 248, 56, "Map Tol:")
    edtMapTol := AddSubStyledEdit("WAYSTONE", "WORLDMAP", 94, 244, 48, 26, mapTolerance, "Number")
    edtMapTol.OnEvent("Change", OnSettingsChanged)

    AddSubMutedLabel("WAYSTONE", "WORLDMAP", 154, 248, 44, "ms/px:")
    edtMapMsPx := AddSubStyledEdit("WAYSTONE", "WORLDMAP", 200, 244, 48, 26, mapMsPerPx, "Number")
    edtMapMsPx.OnEvent("Change", OnSettingsChanged)

    btnMapToggle := AddSubFlatButton("WAYSTONE", "WORLDMAP", 260, 244, 108, 26, "", false, ToggleWorldMapSetting)
    AddSubFlatButton("WAYSTONE", "WORLDMAP", 376, 244, 128, 26, "Test Map (M)", false, TestWorldMapDetection)

    AddCard("WAYSTONE", 20, 288, 500, 188)
    AddCardTitle("WAYSTONE", 36, 300, 220, "F8 WAYSTONE 8-STAR TIMES (MS)")

    radShortBtn := AddFlatButton(284, 296, 72, 24, "SHORT", false, (*) => SelectWaystonePreset(false), "WAYSTONE")
    radWideBtn  := AddFlatButton(362, 296, 88, 24, "VERY WIDE", false, (*) => SelectWaystonePreset(true), "WAYSTONE")
    AddFlatButton(456, 296, 48, 24, "RST", false, ResetWaystoneDefaults, "WAYSTONE")

    AddMutedLabel("WAYSTONE", 36, 336, 56, "Up (W):")
    edtWayUp := AddStyledEdit("WAYSTONE", 94, 332, 76, 26, "", "Number")
    AddMutedLabel("WAYSTONE", 192, 336, 64, "Down (S):")
    edtWayDown := AddStyledEdit("WAYSTONE", 258, 332, 76, 26, "", "Number")
    AddMutedLabel("WAYSTONE", 356, 336, 62, "Diagonal:")
    edtWayDiag := AddStyledEdit("WAYSTONE", 420, 332, 84, 26, "", "Number")

    AddMutedLabel("WAYSTONE", 36, 372, 56, "Left (A):")
    edtWayLeft := AddStyledEdit("WAYSTONE", 94, 368, 76, 26, "", "Number")
    AddMutedLabel("WAYSTONE", 192, 372, 64, "Right (D):")
    edtWayRight := AddStyledEdit("WAYSTONE", 258, 368, 76, 26, "", "Number")
    AddMutedLabel("WAYSTONE", 356, 372, 62, "Ret Max:")
    edtWayRet := AddStyledEdit("WAYSTONE", 420, 368, 84, 26, "", "Number")

    for ctrl in [edtWayUp, edtWayDown, edtWayLeft, edtWayRight, edtWayDiag, edtWayRet]
        ctrl.OnEvent("Change", OnWaystoneManualEdit)

    AddMutedLabel("WAYSTONE", 36, 410, 52, "Range:")
    AddFlatButton(94, 406, 34, 26, "<", false, (*) => AdjustWaystoneRange(-10), "WAYSTONE")
    txtWayRangePct := mainGui.AddText("x132 y410 w50 h18 Center +0x80 +0x04000000", "100%")
    txtWayRangePct.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtWayRangePct, onCard: true})
    pageControls["WAYSTONE"].Push(txtWayRangePct)
    AddFlatButton(186, 406, 34, 26, ">", false, (*) => AdjustWaystoneRange(10), "WAYSTONE")
    AddMutedLabel("WAYSTONE", 232, 410, 272, "Scales all values equally by ratio", "Right")
    AddMutedLabel("WAYSTONE", 36, 444, 468, "Manual edits set your 100% ratio baseline. Press F6 (or preset key) to toggle.")

    ; ==========================================================================
    ; TAB 2: TOWER
    ; ==========================================================================
    AddCard("TOWER", 20, 116, 500, 168)
    AddCardTitle("TOWER", 36, 128, 300, "TOWER FLOOR MOVEMENT (MS)")
    AddFlatButton(404, 126, 100, 24, "Reset Tower", false, ResetTowerDefaults, "TOWER")

    AddMutedLabel("TOWER", 36, 166, 140, "Spawn to Center (W):")
    edtTowerCenter := AddStyledEdit("TOWER", 180, 162, 80, 26, towerCenterMs, "Number")
    AddMutedLabel("TOWER", 280, 166, 134, "Center to Portal (W):")
    edtTowerPortal := AddStyledEdit("TOWER", 420, 162, 84, 26, towerPortalMs, "Number")
    AddMutedLabel("TOWER", 36, 204, 140, "Box Patrol Radius:")
    edtTowerRadius := AddStyledEdit("TOWER", 180, 200, 80, 26, towerRadiusMs, "Number")

    AddMutedLabel("TOWER", 280, 204, 46, "Range:")
    AddFlatButton(330, 200, 32, 26, "<", false, (*) => AdjustTowerRange(-10), "TOWER")
    txtTowerRangePct := mainGui.AddText("x366 y204 w46 h18 Center +0x80 +0x04000000", towerRangePct "%")
    txtTowerRangePct.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtTowerRangePct, onCard: true})
    pageControls["TOWER"].Push(txtTowerRangePct)
    AddFlatButton(416, 200, 32, 26, ">", false, (*) => AdjustTowerRange(10), "TOWER")

    for ctrl in [edtTowerCenter, edtTowerRadius, edtTowerPortal]
        ctrl.OnEvent("Change", OnTowerParamEdit)

    AddMutedLabel("TOWER", 36, 246, 468, "Range scales Spawn to Center, Box Radius, and Portal time equally by ratio.")

    AddCard("TOWER", 20, 294, 500, 184)
    AddCardTitle("TOWER", 36, 304, 320, "TOWER DETECTION & ADVANCEMENT")

    AddMutedLabel("TOWER", 36, 332, 60, "In Tower:")
    edtInTowerPath := AddStyledEdit("TOWER", 102, 328, 306, 24, inTowerImg, "ReadOnly")
    AddFlatButton(416, 328, 88, 24, "Tower...", false, ImportInTowerImg, "TOWER")

    AddMutedLabel("TOWER", 36, 362, 60, "Cleared:")
    edtTowerClearedPath := AddStyledEdit("TOWER", 102, 358, 306, 24, towerClearedImg, "ReadOnly")
    AddFlatButton(416, 358, 88, 24, "Cleared...", false, ImportTowerClearedImg, "TOWER")

    AddMutedLabel("TOWER", 36, 392, 60, "Next Floor:")
    edtTowerNextPath := AddStyledEdit("TOWER", 102, 388, 306, 24, towerNextImg, "ReadOnly")
    AddFlatButton(416, 388, 88, 24, "Next...", false, ImportTowerNextImg, "TOWER")

    AddMutedLabel("TOWER", 36, 428, 68, "Image Tol:")
    edtTowerTol := AddStyledEdit("TOWER", 106, 424, 52, 26, towerImgTol, "Number")
    edtTowerTol.OnEvent("Change", OnTowerParamEdit)

    AddFlatButton(290, 424, 104, 26, "Test Detection", false, TestTowerDetection, "TOWER")
    AddFlatButton(400, 424, 104, 26, "F5: Run Tower", true, ToggleTowerMode, "TOWER")
    AddMutedLabel("TOWER", 36, 460, 468, "Floor Cleared: stops & re-centers to portal. Next Floor: triggers when on new floor.")

    ; ==========================================================================
    ; TAB 3: CYCLE
    ; ==========================================================================
    AddCard("CYCLE", 20, 116, 500, 192)
    AddCardTitle("CYCLE", 36, 124, 270, "MAP CYCLE & SHORTEST PATH")
    AddFlatButton(354, 121, 74, 22, "Detect", false, DetectCycleCurrentMap, "CYCLE")
    AddFlatButton(434, 121, 70, 22, "Reset",  false, ResetCycleDefaults, "CYCLE")

    AddMutedLabel("CYCLE", 36, 152, 36, "Map:")
    AddFlatButton(74, 148, 28, 24, "<", false, (*) => SelectCycleWs(-1), "CYCLE")
    txtCycleWs := mainGui.AddText("x106 y152 w254 h18 Center +0x80 +0x04000000", "")
    txtCycleWs.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtCycleWs, onCard: true})
    pageControls["CYCLE"].Push(txtCycleWs)
    AddFlatButton(364, 148, 28, 24, ">", false, (*) => SelectCycleWs(1), "CYCLE")
    btnCycleStart := AddFlatButton(398, 148, 106, 24, "", true, ToggleMapCycleMode, "CYCLE")

    AddMutedLabel("CYCLE", 36, 182, 48, "Search:")
    edtCycleSearch := AddStyledEdit("CYCLE", 86, 178, 214, 24, "")
    edtCycleSearch.OnEvent("Change", OnCycleSearchChange)
    AddFlatButton(306, 178, 66, 24, "Next", false, CycleSearchNextMatch, "CYCLE")
    txtCycleMatchInfo := AddMutedLabel("CYCLE", 378, 182, 126, "", "Right")

    AddMutedLabel("CYCLE", 36, 213, 38, "Path:")
    AddFlatButton(78,  209, 96,  26, "Find Prev",        false, (*) => StartShortestPathSingle(-1), "CYCLE")
    AddFlatButton(179, 209, 96,  26, "Find Next",        false, (*) => StartShortestPathSingle(1),  "CYCLE")
    AddFlatButton(280, 209, 104, 26, "Record Mine",      false, StartManualPathRecording,         "CYCLE")
    AddFlatButton(389, 209, 115, 26, "Auto-All (0..30)", false, StartShortestPathAll,             "CYCLE")

    txtShortestStatus := AddMutedLabel("CYCLE", 36, 244, 468, "")
    AddMutedLabel("CYCLE", 36, 266, 468, "Hold W/A/S/D anytime during Find Path to steer manually & log your keys.")
    AddMutedLabel("CYCLE", 36, 282, 468, "Uses portals_day/portals_night + map_area + top_label automatically.")

    AddCard("CYCLE", 20, 314, 500, 164)
    AddCardTitle("CYCLE", 36, 322, 320, "BOSS / MINIBOSS DETECTION (UPPER-CENTER)")
    AddFlatButton(404, 318, 100, 22, "Test Boss", false, TestBossDetection, "CYCLE")

    AddMutedLabel("CYCLE", 36, 348, 56, "Coming:")
    edtBossComingPath := AddStyledEdit("CYCLE", 96, 345, 312, 22, bossComingImg, "ReadOnly")
    AddFlatButton(416, 345, 88, 22, "Coming...", false, ImportBossComingImage, "CYCLE")

    AddMutedLabel("CYCLE", 36, 374, 56, "Spawn:")
    edtBossSpawnPath := AddStyledEdit("CYCLE", 96, 371, 312, 22, bossSpawnImg, "ReadOnly")
    AddFlatButton(416, 371, 88, 22, "Spawn...", false, ImportBossSpawnImage, "CYCLE")

    AddMutedLabel("CYCLE", 36, 400, 56, "Defeat:")
    edtBossDefPath := AddStyledEdit("CYCLE", 96, 397, 312, 22, bossDefeatedImg, "ReadOnly")
    AddFlatButton(416, 397, 88, 22, "Defeat...", false, ImportBossDefeatedImage, "CYCLE")

    AddMutedLabel("CYCLE", 36, 428, 60, "Boss Tol:")
    edtBossTol := AddStyledEdit("CYCLE", 98, 424, 44, 24, bossBannerTol, "Number")
    edtBossTol.OnEvent("Change", OnSettingsChanged)

    AddMutedLabel("CYCLE", 150, 428, 50, "Top Tol:")
    edtTopLabelTol := AddStyledEdit("CYCLE", 202, 424, 44, 24, topLabelTol, "Number")
    edtTopLabelTol.OnEvent("Change", OnSettingsChanged)

    AddMutedLabel("CYCLE", 254, 428, 60, "Portal Tol:")
    edtPortalTol := AddStyledEdit("CYCLE", 316, 424, 44, 24, portalTol, "Number")
    edtPortalTol.OnEvent("Change", OnSettingsChanged)

    AddMutedLabel("CYCLE", 366, 428, 138, "Stacked loot sweeps ON", "Right")
    AddMutedLabel("CYCLE", 36, 454, 468, "Stacks loot sweeps for 2nd spawns & new defeated banners automatically.")

    ; ==========================================================================
    ; TAB 4: F9 / F7
    ; ==========================================================================
    AddCard("F9F7", 20, 116, 500, 194)
    AddCardTitle("F9F7", 36, 128, 300, "F9 PERIMETER CIRCLE TIMES (MS)")
    AddFlatButton(456, 126, 48, 24, "RST", false, ResetF9F7Defaults, "F9F7")

    AddMutedLabel("F9F7", 36, 166, 62, "Out (W):")
    edtCirOut := AddStyledEdit("F9F7", 100, 162, 70, 26, "", "Number")
    AddMutedLabel("F9F7", 190, 166, 66, "Top Edge:")
    edtCirEdge := AddStyledEdit("F9F7", 258, 162, 74, 26, "", "Number")
    AddMutedLabel("F9F7", 354, 166, 60, "Ret Max:")
    edtCirRet := AddStyledEdit("F9F7", 416, 162, 88, 26, "", "Number")

    AddMutedLabel("F9F7", 36, 202, 62, "Cardinals:")
    edtCirCard := AddStyledEdit("F9F7", 100, 198, 70, 26, "", "Number")
    AddMutedLabel("F9F7", 190, 202, 66, "Diagonals:")
    edtCirDiag := AddStyledEdit("F9F7", 258, 198, 74, 26, "", "Number")
    btnF9TabQueue := AddFlatButton(354, 198, 150, 26, "", false, QueuePerimeterCircle, "F9F7")

    for ctrl in [edtCirOut, edtCirEdge, edtCirCard, edtCirDiag, edtCirRet]
        ctrl.OnEvent("Change", OnCircleManualEdit)

    AddMutedLabel("F9F7", 36, 240, 52, "Range:")
    AddFlatButton(94, 236, 34, 26, "<", false, (*) => AdjustCircleRange(-10), "F9F7")
    txtCirRangePct := mainGui.AddText("x132 y240 w50 h18 Center +0x80 +0x04000000", "100%")
    txtCirRangePct.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtCirRangePct, onCard: true})
    pageControls["F9F7"].Push(txtCirRangePct)
    AddFlatButton(186, 236, 34, 26, ">", false, (*) => AdjustCircleRange(10), "F9F7")
    AddMutedLabel("F9F7", 232, 240, 272, "Lower % if circle travels too far out", "Right")
    AddMutedLabel("F9F7", 36, 276, 468, "Out (W) sets radius. Top Edge is D; Cardinals S/A/W; Diagonals SE/SW/NW.")

    AddCard("F9F7", 20, 322, 500, 154)
    AddCardTitle("F9F7", 36, 334, 240, "F7 CHAOS STRESS TEST (MS)")
    AddMutedLabel("F9F7", 322, 334, 48, "Range:")
    AddFlatButton(376, 331, 34, 24, "<", false, (*) => AdjustChaosRange(-10), "F9F7")
    txtChaosRangePct := mainGui.AddText("x414 y334 w50 h18 Center +0x80 +0x04000000", "100%")
    txtChaosRangePct.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtChaosRangePct, onCard: true})
    pageControls["F9F7"].Push(txtChaosRangePct)
    AddFlatButton(468, 331, 36, 24, ">", false, (*) => AdjustChaosRange(10), "F9F7")

    AddMutedLabel("F9F7", 36, 372, 72, "Long Angle:")
    edtChaosAngle := AddStyledEdit("F9F7", 110, 368, 68, 26, "", "Number")
    AddMutedLabel("F9F7", 200, 372, 58, "Zig Diag:")
    edtChaosZigDiag := AddStyledEdit("F9F7", 260, 368, 68, 26, "", "Number")
    AddMutedLabel("F9F7", 350, 372, 58, "Zig Side:")
    edtChaosZigSide := AddStyledEdit("F9F7", 410, 368, 94, 26, "", "Number")

    for ctrl in [edtChaosAngle, edtChaosZigDiag, edtChaosZigSide]
        ctrl.OnEvent("Change", OnChaosManualEdit)

    btnF7TabRun := AddFlatButton(36, 408, 210, 28, "", true, StartChaosStressTest, "F9F7")
    AddFlatButton(364, 408, 140, 28, "Reset F9 & F7", false, ResetF9F7Defaults, "F9F7")
    AddMutedLabel("F9F7", 36, 446, 468, "Runs outward chaos + reverse check, then auto-starts F8 Waystone on pass.")

    ; ==========================================================================
    ; TAB 5: CAPTURE STUDIO (IN-ONE-GO SNIPPER & RECHECK)
    ; ==========================================================================
    AddCard("CAPTURE", 20, 116, 500, 248)
    AddCardTitle("CAPTURE", 36, 128, 300, "ONE-GO CAPTURE & RECHECK STUDIO")
    btnCapOneGo := AddFlatButton(374, 124, 130, 24, "", false, ToggleCaptureOneGo, "CAPTURE")

    AddMutedLabel("CAPTURE", 36, 164, 64, "Category:")
    AddFlatButton(104, 160, 30, 26, "<", false, (*) => CycleCaptureCategory(-1), "CAPTURE")
    txtCapCat := mainGui.AddText("x140 y164 w328 h18 Center +0x80 +0x04000000", "")
    txtCapCat.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtCapCat, onCard: true})
    pageControls["CAPTURE"].Push(txtCapCat)
    AddFlatButton(474, 160, 30, 26, ">", false, (*) => CycleCaptureCategory(1), "CAPTURE")

    AddMutedLabel("CAPTURE", 36, 200, 64, "Target:")
    AddFlatButton(104, 196, 30, 26, "<", false, (*) => CycleCaptureItem(-1), "CAPTURE")
    txtCapItem := mainGui.AddText("x140 y200 w328 h18 Center +0x80 +0x04000000", "")
    txtCapItem.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtCapItem, onCard: true})
    pageControls["CAPTURE"].Push(txtCapItem)
    AddFlatButton(474, 196, 30, 26, ">", false, (*) => CycleCaptureItem(1), "CAPTURE")

    AddMutedLabel("CAPTURE", 36, 236, 64, "Save To:")
    txtCapPath := AddStyledEdit("CAPTURE", 104, 232, 400, 26, "", "ReadOnly")

    AddMutedLabel("CAPTURE", 36, 272, 64, "Status:")
    txtCapStatus := mainGui.AddText("x104 y272 w400 h18 +0x80 +0x04000000", "")
    txtCapStatus.SetFont("s8 Bold", "Segoe UI")
    themePrimaryText.Push({ctrl: txtCapStatus, onCard: true})
    pageControls["CAPTURE"].Push(txtCapStatus)

    AddFlatButton(36,  304, 146, 32, "Snap & Recheck", true,  SnapCurrentCaptureItem, "CAPTURE")
    AddFlatButton(190, 304, 130, 32, "Recheck Item",   false, RecheckCurrentCaptureItem, "CAPTURE")
    AddFlatButton(328, 304, 176, 32, "Open One-Go Floating Bar", false, OpenFloatingCaptureBar, "CAPTURE")

    AddCard("CAPTURE", 20, 374, 500, 102)
    AddCardTitle("CAPTURE", 36, 384, 300, "LIVE SCREEN DIAGNOSTIC")
    AddFlatButton(36, 410, 200, 28, "Recheck All Visible Now", false, RecheckAllVisibleOnScreen, "CAPTURE")
    AddMutedLabel("CAPTURE", 250, 416, 254, "Tests map label, waystone, portals & boss", "Right")
    AddMutedLabel("CAPTURE", 36, 448, 468, "Screen freezes during Snap so disappearing banners stay still while you crop.")

    ; ==========================================================================
    ; TAB 6: SETTINGS
    ; ==========================================================================
    AddCard("SETTINGS", 20, 116, 500, 114)
    AddCardTitle("SETTINGS", 36, 128, 390, "APPEARANCE & DISPLAY")

    AddPrimaryLabel("SETTINGS", 36, 156, 200, "Interface Theme")
    btnSetDark  := AddFlatButton(290, 152, 102, 28, "DARK MODE",  false, (*) => SetDarkMode(true),  "SETTINGS")
    btnSetLight := AddFlatButton(400, 152, 104, 28, "LIGHT MODE", false, (*) => SetDarkMode(false), "SETTINGS")

    AddPrimaryLabel("SETTINGS", 36, 194, 200, "Floating Run Overlay")
    AddFlatButton(290, 190, 102, 28, "Reset Pos", false, ResetOverlayPosition, "SETTINGS")
    btnSetHud := AddFlatButton(400, 190, 104, 28, "", false, ToggleHudSetting, "SETTINGS")

    AddCard("SETTINGS", 20, 240, 500, 236)
    AddCardTitle("SETTINGS", 36, 248, 200, "HOTKEY SWITCH")

    btnSetKeysToggle := AddFlatButton(290, 244, 102, 22, "", false, ToggleHotkeysEnabled, "SETTINGS")
    AddFlatButton(400, 244, 104, 22, "Reset Keys", false, ResetDefaultHotkeys, "SETTINGS")

    AddHotkeyRow("waystone", "Waystone 8-Star",          272)
    AddHotkeyRow("tower",    "Tower Mode (Free Range)",  298)
    AddHotkeyRow("mapCycle", "Map Cycle (All Maps)",     324)
    AddHotkeyRow("preset",   "Toggle Short / Very Wide", 350)
    AddHotkeyRow("circle",   "Queue Perimeter Circle",   376)
    AddHotkeyRow("chaos",    "Chaos Stress Test",        402)
    AddHotkeyRow("exit",     "Stop & Exit Macro",        428)
    AddMutedLabel("SETTINGS", 36, 456, 468, "Click 'Change' then press any key (supports Ctrl / Shift / Alt combos).")

    ; ==========================================================================
    ; TAB 7: CREDITS
    ; ==========================================================================
    AddCard("CREDITS", 20, 116, 500, 112)
    AddCardTitle("CREDITS", 36, 128, 200, "DEVELOPER")
    AddPrimaryLabel("CREDITS", 36, 150, 280, "Chase", 13, true)
    AddMutedLabel("CREDITS", 36, 174, 280, "@alphagamer121204")
    AddMutedLabel("CREDITS", 36, 196, 310, "roblox.com/users/605992135/profile")
    AddFlatButton(364, 154, 140, 34, "Open Profile  ↗", true, (*) => Run("https://www.roblox.com/users/605992135/profile"), "CREDITS")

    AddCard("CREDITS", 20, 240, 500, 112)
    AddCardTitle("CREDITS", 36, 252, 200, "CONTRIBUTOR")
    AddPrimaryLabel("CREDITS", 36, 274, 280, "kaze", 13, true)
    AddMutedLabel("CREDITS", 36, 298, 280, "@kazefast")
    AddMutedLabel("CREDITS", 36, 320, 310, "roblox.com/users/1676005584/profile")
    AddFlatButton(364, 278, 140, 34, "Open Profile  ↗", true, (*) => Run("https://www.roblox.com/users/1676005584/profile"), "CREDITS")

    AddCard("CREDITS", 20, 364, 500, 112)
    AddCardTitle("CREDITS", 36, 376, 390, "PROJECT ARCHITECTURE")
    AddPrimaryLabel("CREDITS", 36, 398, 468, "Pixel Empire Macro · Modular AutoHotkey v2.0")
    AddMutedLabel("CREDITS", 36, 422, 468, "Entry: PixelEmpireMacro.ahk")
    AddMutedLabel("CREDITS", 36, 442, 468, "Modules: State · MapRoutes · Config · VisionWindow · Movement · Modes/* · GUI/*")

    ; ==========================================================================
    ; PERSISTENT QUICK ACTIONS BAR & FOOTER
    ; ==========================================================================
    AddCard("", 20, 486, 500, 100)
    AddCardTitle("", 36, 494, 300, "QUICK ACTIONS")

    btnActWaystone := AddFlatButton(36,  514, 152, 28, "", true,  ToggleWaystoneMode)
    btnActTower    := AddFlatButton(194, 514, 152, 28, "", false, ToggleTowerMode)
    btnActMapCycle := AddFlatButton(352, 514, 152, 28, "", false, ToggleMapCycleMode)

    btnActPreset := AddFlatButton(36,  548, 110, 26, "", false, ToggleShortWidePreset)
    btnActCircle := AddFlatButton(154, 548, 110, 26, "", false, QueuePerimeterCircle)
    btnActChaos  := AddFlatButton(272, 548, 110, 26, "", false, StartChaosStressTest)
    btnActExit   := AddFlatButton(390, 548, 114, 26, "", false, ExitMacro)

    AddDivider(20, 594, 500)
    txtGuiStatus := mainGui.AddText("x20 y602 w500 h20 +0x80 +0x04000000", "● Ready")
    txtGuiStatus.SetFont("s8 Bold", "Segoe UI")
    themeMutedText.Push({ctrl: txtGuiStatus, onCard: false})

    mainGui.OnEvent("Close", (*) => ExitMacro())
    OnMessage(0x0020, HandleSetCursor)
    OnMessage(0x0201, HandleOverlayDrag)

    BuildOverlayGUI()
    RefreshPresetUI()
    RefreshTowerUI()
    RefreshCycleUI()
    RefreshCaptureUI()
    RefreshCircleUI()
    RefreshChaosUI()
    RefreshImageStatus()
    RefreshHotkeyLabels()
    RefreshSettingsTabUI()
    RefreshWorldMapUI()
    SwitchTab("WAYSTONE")

    mainGui.Show("w540 h628")
    SendMessage(0x00B1, 999, 999, edtPromptPath.Hwnd)
    SendMessage(0x00B1, 999, 999, edtRecoveryPath.Hwnd)
    SendMessage(0x00B1, 999, 999, edtMapOpenPath.Hwnd)
    SendMessage(0x00B1, 999, 999, edtMapArrowPath.Hwnd)
    SendMessage(0x00B1, 999, 999, edtMapWayPath.Hwnd)
    SendMessage(0x00B1, 999, 999, edtInTowerPath.Hwnd)
    SendMessage(0x00B1, 999, 999, edtTowerClearedPath.Hwnd)
    SendMessage(0x00B1, 999, 999, edtTowerNextPath.Hwnd)
    ApplyTheme()
}