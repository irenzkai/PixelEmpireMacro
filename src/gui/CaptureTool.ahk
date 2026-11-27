; ==============================================================================
; BUILT-IN SCREEN SNIPPER, ONE-GO FLOATING CAPTURE BAR & LIVE RECHECK TOOL
; ==============================================================================

GetCaptureCatalogCategories() {
    return [
        "Waystone & Map (M)",
        "Boss & Miniboss",
        "Tower Indicators",
        "Map Top Labels (0..30)",
        "Map Areas (0..30)",
        "Portals Day (0<->30)",
        "Portals Night (0<->30)"
    ]
}

GetCaptureItemsForCategory(catIdx) {
    global promptImg, recoveryImg, mapOpenImg, mapArrowImg, mapWaystoneImg
    global bossComingImg, bossSpawnImg, bossAlreadyInImg, bossDefeatedImg
    global minibossComingImg, minibossSpawnImg, minibossAlreadyInImg, minibossDefeatedImg, youDefeatedBossImg
    global inTowerImg, towerClearedImg, towerNextImg
    global waystoneRoutes, maxWaystoneIdx

    items := []
    if (catIdx = 1) {
        items.Push({name: "Waystone Prompt (Return to Town)", path: promptImg, kind: "PROMPT"})
        items.Push({name: "Waystone (animation frames)",            path: recoveryImg, kind: "STATUE"})
        items.Push({name: "World Map Open Header",            path: mapOpenImg, kind: "MAP_OPEN"})
        items.Push({name: "World Map Red Arrow",              path: mapArrowImg, kind: "MAP_ARROW"})
        items.Push({name: "World Map Waystone",               path: mapWaystoneImg, kind: "MAP_WAY"})
    } else if (catIdx = 2) {
        items.Push({name: "Boss Coming",       path: bossComingImg, kind: "BOSS"})
        items.Push({name: "Boss Spawn",        path: bossSpawnImg, kind: "BOSS"})
        items.Push({name: "Boss Already In",   path: bossAlreadyInImg, kind: "BOSS"})
        items.Push({name: "Boss Defeated",     path: bossDefeatedImg, kind: "BOSS"})
        items.Push({name: "Miniboss Coming",   path: minibossComingImg, kind: "BOSS"})
        items.Push({name: "Miniboss Spawn",    path: minibossSpawnImg, kind: "BOSS"})
        items.Push({name: "Miniboss Already In", path: minibossAlreadyInImg, kind: "BOSS"})
        items.Push({name: "Miniboss Defeated", path: minibossDefeatedImg, kind: "BOSS"})
        items.Push({name: "You Defeated Confirmation", path: youDefeatedBossImg, kind: "BOSS"})
    } else if (catIdx = 3) {
        items.Push({name: "In Tower (Tower of Trials)", path: inTowerImg, kind: "TOWER"})
        items.Push({name: "Floor Cleared Banner",       path: towerClearedImg, kind: "TOWER"})
        items.Push({name: "Next Floor Indicator",       path: towerNextImg, kind: "TOWER"})
    } else if (catIdx = 4) {
        i := 0
        while (i <= maxWaystoneIdx) {
            items.Push({name: waystoneRoutes[i].label " (Top Label)", path: GetMapTopLabelPath(i), kind: "TOP_LABEL", idx: i})
            i += 1
        }
    } else if (catIdx = 5) {
        i := 0
        while (i <= maxWaystoneIdx) {
            items.Push({name: waystoneRoutes[i].label " (Map Area)", path: GetMapAreaPath(i), kind: "MAP_AREA", idx: i})
            i += 1
        }
    } else if (catIdx = 6 || catIdx = 7) {
        folder := (catIdx = 6) ? "portals_day" : "portals_night"
        tag    := (catIdx = 6) ? "Day" : "Night"
        ; Eldoria only records WS0 -> WS1 (Whisperwood)
        items.Push({name: "WS0 -> WS1 (" tag " Portal)", path: A_ScriptDir "\public\maps\" folder "\WS0_WS1.png", kind: "PORTAL", fromIdx: 0, toIdx: 1})
        i := 1
        while (i < maxWaystoneIdx) {
            items.Push({name: "WS" i " -> WS" (i + 1) " (" tag ")", path: A_ScriptDir "\public\maps\" folder "\WS" i "_WS" (i + 1) ".png", kind: "PORTAL", fromIdx: i, toIdx: i + 1})
            items.Push({name: "WS" (i + 1) " -> WS" i " (" tag ")", path: A_ScriptDir "\public\maps\" folder "\WS" (i + 1) "_WS" i ".png", kind: "PORTAL", fromIdx: i + 1, toIdx: i})
            i += 1
        }
    }
    return items
}

GetCurrentCaptureItem() {
    global captureCategoryIdx, captureItemIdx
    items := GetCaptureItemsForCategory(captureCategoryIdx)
    if (items.Length = 0)
        return ""
    captureItemIdx := Max(1, Min(items.Length, captureItemIdx))
    return items[captureItemIdx]
}

CycleCaptureCategory(delta) {
    global captureCategoryIdx, captureItemIdx
    cats := GetCaptureCatalogCategories()
    captureCategoryIdx := Mod(captureCategoryIdx - 1 + delta + cats.Length, cats.Length) + 1
    captureItemIdx := 1
    RefreshCaptureUI()
}

CycleCaptureItem(delta) {
    global captureCategoryIdx, captureItemIdx
    items := GetCaptureItemsForCategory(captureCategoryIdx)
    if (items.Length = 0)
        return
    captureItemIdx := Mod(captureItemIdx - 1 + delta + items.Length, items.Length) + 1
    RefreshCaptureUI()
}

ToggleCaptureOneGo(*) {
    global captureOneGo
    captureOneGo := !captureOneGo
    RefreshCaptureUI()
}

RefreshCaptureUI() {
    RefreshMainPreviews()
    global captureCategoryIdx, captureItemIdx, captureOneGo
    global txtCapCat, txtCapItem, txtCapPath, txtCapStatus, btnCapOneGo
    global captureBarVisible, capBarCatTxt, capBarItemTxt, capBarStatusTxt

    cats := GetCaptureCatalogCategories()
    items := GetCaptureItemsForCategory(captureCategoryIdx)
    it := GetCurrentCaptureItem()

    catLabel := cats[captureCategoryIdx]
    itemLabel := IsObject(it) ? ("(" captureItemIdx "/" items.Length ") " it.name) : "None"

    if IsSet(txtCapCat)
        txtCapCat.Text := catLabel
    if IsSet(txtCapItem)
        txtCapItem.Text := itemLabel
    if IsSet(txtCapPath) && IsObject(it) {
        txtCapPath.Value := it.path
        SendMessage(0x00B1, 999, 999, txtCapPath.Hwnd)
    }
    if IsSet(txtCapStatus) && IsObject(it) {
        if FileExist(it.path) {
            GetImageDimensions(it.path, &w, &h)
            txtCapStatus.Text := "● EXISTS [" w "x" h "px]"
        } else {
            txtCapStatus.Text := "● MISSING (Click Snap)"
        }
    }
    if IsSet(btnCapOneGo)
        btnCapOneGo.btn.Text := captureOneGo ? "AUTO-NEXT: ON" : "AUTO-NEXT: OFF"

    if (captureBarVisible && IsSet(capBarItemTxt)) {
        capBarCatTxt.Text := catLabel
        capBarItemTxt.Text := itemLabel
        if IsObject(it) && FileExist(it.path) {
            GetImageDimensions(it.path, &w, &h)
            capBarStatusTxt.Text := "Exists [" w "x" h "px] — Click SNAP & drag region"
        } else {
            capBarStatusTxt.Text := "Missing — Click SNAP & drag region"
        }
    }
}

; ==============================================================================
; FROZEN-SCREEN 1:1 REGION SNIPPER (NO CURSOR/UI ARTIFACTS)
; ==============================================================================

CaptureScreenRegion(savePath, labelText, &outW := 0, &outH := 0) {
    outW := 0, outH := 0
    vx := SysGet(76), vy := SysGet(77), vw := SysGet(78), vh := SysGet(79)
    if (vw <= 0 || vh <= 0)
        vx := 0, vy := 0, vw := A_ScreenWidth, vh := A_ScreenHeight

    hdcScreen := DllCall("GetDC", "ptr", 0, "ptr")
    memDC     := DllCall("CreateCompatibleDC", "ptr", hdcScreen, "ptr")
    hBmp      := DllCall("CreateCompatibleBitmap", "ptr", hdcScreen, "int", vw, "int", vh, "ptr")
    oldObj    := DllCall("SelectObject", "ptr", memDC, "ptr", hBmp, "ptr")
    DllCall("BitBlt", "ptr", memDC, "int", 0, "int", 0, "int", vw, "int", vh, "ptr", hdcScreen, "int", vx, "int", vy, "uint", 0x00CC0020)
    DllCall("SelectObject", "ptr", memDC, "ptr", oldObj, "ptr")
    DllCall("DeleteDC", "ptr", memDC)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)

    snipGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale", "PixelEmpireSnip")
    snipGui.MarginX := 0
    snipGui.MarginY := 0
    snipGui.AddPicture("x0 y0 w" vw " h" vh, "HBITMAP:*" hBmp)

    banner := snipGui.AddText("x" ((vw - 560) // 2) " y10 w560 h26 Center 0x200 Background141414 cFFFFFF", "DRAG TO SNAP: " labelText "   |   ESC / Right-Click = Cancel")
    banner.SetFont("s9 Bold", "Segoe UI")

    selTop := snipGui.AddText("x0 y0 w1 h2 Background00FF88 Hidden", "")
    selBot := snipGui.AddText("x0 y0 w1 h2 Background00FF88 Hidden", "")
    selLft := snipGui.AddText("x0 y0 w2 h1 Background00FF88 Hidden", "")
    selRgt := snipGui.AddText("x0 y0 w2 h1 Background00FF88 Hidden", "")

    snipGui.Show("x" vx " y" vy " w" vw " h" vh)
    WinActivate("ahk_id " snipGui.Hwnd)

    cancelled := false
    dragging := false
    sx := 0, sy := 0, ex := 0, ey := 0

    ; Wait for LButton press
    while true {
        if (GetKeyState("Esc", "P") || GetKeyState("RButton", "P")) {
            cancelled := true
            break
        }
        if GetKeyState("LButton", "P") {
            MouseGetPos(&sx, &sy)
            dragging := true
            break
        }
        Sleep(12)
    }

    if (dragging && !cancelled) {
        while GetKeyState("LButton", "P") {
            if GetKeyState("Esc", "P") {
                cancelled := true
                break
            }
            MouseGetPos(&ex, &ey)
            rx := Min(sx, ex) - vx
            ry := Min(sy, ey) - vy
            rw := Max(2, Abs(ex - sx))
            rh := Max(2, Abs(ey - sy))

            selTop.Move(rx, ry, rw, 2)
            selBot.Move(rx, ry + rh - 2, rw, 2)
            selLft.Move(rx, ry, 2, rh)
            selRgt.Move(rx + rw - 2, ry, 2, rh)
            selTop.Visible := true, selBot.Visible := true, selLft.Visible := true, selRgt.Visible := true
            ToolTip(rw " x " rh " px")
            Sleep(12)
        }
        ToolTip()
    }

    snipGui.Destroy()

    saved := false
    if (!cancelled) {
        selX := Min(sx, ex) - vx
        selY := Min(sy, ey) - vy
        selW := Abs(ex - sx)
        selH := Abs(ey - sy)
        if (selW >= 6 && selH >= 6) {
            saved := SaveHBitmapCropToPng(hBmp, selX, selY, selW, selH, savePath)
            if (saved)
                outW := selW, outH := selH
        }
    }

    DllCall("DeleteObject", "ptr", hBmp)
    return saved
}

SaveHBitmapCropToPng(hBmp, cx, cy, cw, ch, dstPath) {
    static hGdip := DllCall("LoadLibrary", "str", "gdiplus", "ptr")
    if !hGdip
        return false

    splitPos := InStr(dstPath, "\", , -1)
    if (splitPos > 0) {
        parentDir := SubStr(dstPath, 1, splitPos - 1)
        try DirCreate(parentDir)
    }

    si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    NumPut("uint", 1, si, 0)
    if (DllCall("gdiplus\GdiplusStartup", "ptr*", &token := 0, "ptr", si, "ptr", 0) != 0)
        return false

    ok := false
    pFull := 0, pCrop := 0
    if (DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hBmp, "ptr", 0, "ptr*", &pFull) = 0 && pFull) {
        if (DllCall("gdiplus\GdipCloneBitmapAreaI", "int", cx, "int", cy, "int", cw, "int", ch, "int", 0x26200A, "ptr", pFull, "ptr*", &pCrop) = 0 && pCrop) {
            clsidBuf := Buffer(16, 0)
            DllCall("ole32\CLSIDFromString", "str", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", clsidBuf)
            ok := (DllCall("gdiplus\GdipSaveImageToFile", "ptr", pCrop, "wstr", dstPath, "ptr", clsidBuf, "ptr", 0) = 0)
            DllCall("gdiplus\GdipDisposeImage", "ptr", pCrop)
        }
        DllCall("gdiplus\GdipDisposeImage", "ptr", pFull)
    }
    DllCall("gdiplus\GdiplusShutdown", "ptr", token)
    return ok
}

; ==============================================================================
; SNAP + IMMEDIATE RECHECK ACTIONS
; ==============================================================================

SnapCurrentCaptureItem(*) {
    global mainGui, captureBarGui, captureBarVisible, captureOneGo
    it := GetCurrentCaptureItem()
    if !IsObject(it)
        return
    ; A scene crop must not overwrite the supplied animation sheet.
    if it.kind = "STATUE" {
        TestWaystoneDetection()
        return
    }

    if (captureBarVisible && IsSet(captureBarGui))
        captureBarGui.Hide()
    if IsSet(mainGui)
        mainGui.Hide()
    Sleep(140)

    ok := CaptureScreenRegion(it.path, it.name, &w, &h)
    if (ok) {
        InvalidateImageCaches(it.path)
        Sleep(100)
        detMsg := VerifyCapturedItemOnScreen(it, &detected)
        UpdateGuiStatus("Captured " it.name " [" w "x" h "px] — " detMsg)
        if (captureBarVisible && IsSet(captureBarGui)) {
            captureBarGui.Show("NoActivate")
            capBarStatusTxt_Update(detMsg)
            if (detected && captureOneGo)
                CycleCaptureItem(1)
            else
                RefreshCaptureUI()
            return
        }
        if IsSet(mainGui)
            mainGui.Show()
        RefreshCaptureUI()
        RefreshImageStatus()
        mainGui.Opt("+OwnDialogs")
        MsgBox("Saved to:`n" it.path "`nSize: " w "x" h " px`n`nImmediate Recheck: " detMsg, "Capture & Recheck", detected ? "Iconi" : "Icon!")
        if (detected && captureOneGo)
            CycleCaptureItem(1)
    } else {
        if (captureBarVisible && IsSet(captureBarGui))
            captureBarGui.Show("NoActivate")
        else if IsSet(mainGui)
            mainGui.Show()
        UpdateGuiStatus("Capture cancelled.")
    }
}

capBarStatusTxt_Update(msg) {
    global capBarStatusTxt
    if IsSet(capBarStatusTxt)
        capBarStatusTxt.Text := msg
}

VerifyCapturedItemOnScreen(it, &detected := false) {
    global imgTolerance, recoveryTolerance, mapTolerance, bossBannerTol, towerImgTol, topLabelTol, portalTol
    global robloxWinBox, mapBox, topLabelBox, statueSearchBox
    detected := false

    if !FileExist(it.path)
        return "FILE MISSING"

    if !InitVisionAndWindow(false)
        return "No Roblox window found"

    p := ""
    if (it.kind = "PROMPT") {
        detected := IsOnWaystone(&fx, &fy)
        return detected ? ("DETECTED at (" fx "," fy ")") : ("Not detected (Prompt Tol: " imgTolerance ")")
    } else if (it.kind = "STATUE") {
        detected := FindWaystoneStatue(&fx, &fy, statueSearchBox)
        return detected ? ("DETECTED at (" fx "," fy ")") : ("Not detected (minimum score: " recoveryTolerance "%)")
    } else if (it.kind = "MAP_OPEN" || it.kind = "MAP_ARROW" || it.kind = "MAP_WAY") {
        detected := SearchImageWithCache(it.path, mapBox, mapTolerance, &fx, &fy, &p, true)
        return detected ? ("DETECTED on Map at (" fx "," fy ")") : ("Not detected (open World Map M first, Tol: " mapTolerance ")")
    } else if (it.kind = "BOSS") {
        bossBox := GetUpperCenterBossBox()
        detected := SearchBossImage(it.path, bossBox, bossBannerTol, &fx, &fy, &p)
        return detected ? ("DETECTED in Boss Box (" fx "," fy ")") : ("Not visible (Banner Tol: " bossBannerTol ")")
    } else if (it.kind = "TOWER") {
        detected := SearchTextIndicatorImage(it.path, robloxWinBox, towerImgTol, Map(), "twrtest", &fx, &fy, &p)
        return detected ? ("DETECTED at (" fx "," fy ")") : ("Not visible (Tower Tol: " towerImgTol ")")
    } else if (it.kind = "TOP_LABEL") {
        detected := IsMapTopLabel(it.idx, &fx, &fy)
        return detected ? ("DETECTED Top Label at (" fx "," fy ")") : ("Not detected (Top Tol: " topLabelTol ")")
    } else if (it.kind = "MAP_AREA") {
        detected := FindMapAreaOnWorldMap(it.idx, &areaBox)
        return detected ? ("DETECTED Map Area (" areaBox.x1 "," areaBox.y1 ")") : ("Not detected (open World Map M first)")
    } else if (it.kind = "PORTAL") {
        detected := SearchImageWithCache(it.path, statueSearchBox, portalTol, &fx, &fy, &p, false)
        return detected ? ("DETECTED Portal at (" fx "," fy ")") : ("Not detected (Portal Tol: " portalTol ")")
    }
    return "Checked"
}

RecheckCurrentCaptureItem(*) {
    global mainGui, captureBarGui, captureBarVisible
    it := GetCurrentCaptureItem()
    if !IsObject(it)
        return

    if (captureBarVisible && IsSet(captureBarGui))
        captureBarGui.Hide()
    else if IsSet(mainGui)
        mainGui.Hide()
    Sleep(140)

    msg := VerifyCapturedItemOnScreen(it, &detected)

    if (captureBarVisible && IsSet(captureBarGui)) {
        captureBarGui.Show("NoActivate")
        capBarStatusTxt_Update(msg)
        return
    }
    if IsSet(mainGui)
        mainGui.Show()
    UpdateGuiStatus(it.name ": " msg)
    mainGui.Opt("+OwnDialogs")
    MsgBox(it.name "`n`nResult: " msg, "Recheck Detection", detected ? "Iconi" : "Icon!")
}

RecheckAllVisibleOnScreen(*) {
    global mainGui, currentWaystoneIdx, waystoneRoutes, portalTol, statueSearchBox
    if !InitVisionAndWindow(false)
        return
    mainGui.Hide()
    Sleep(140)

    mapDet := DetectCurrentMapByTopLabel()
    wsOn   := IsOnWaystone()
    stOn   := FindWaystoneStatue(&sx, &sy)
    bossOn := DetectActiveBossOrMiniboss(&bKind)
    clrOn  := IsFloorCleared()

    chkIdx := (mapDet >= 0) ? mapDet : currentWaystoneIdx
    pNext := (chkIdx < 30) && FindPortalSprite(chkIdx, chkIdx + 1, &px1, &py1)
    pPrev := (chkIdx > 1)  && FindPortalSprite(chkIdx, chkIdx - 1, &px2, &py2)

    mainGui.Show()
    mainGui.Opt("+OwnDialogs")
    MsgBox(
        "Top Label: " (mapDet >= 0 ? waystoneRoutes[mapDet].label : "Not matched") "`n"
        "Waystone Prompt: " (wsOn ? "FOUND" : "Not on pad") "`n"
        "Waystone Statue: " (stOn ? ("FOUND at (" sx "," sy ")") : "Not visible") "`n"
        "Portal -> Next (" chkIdx "->" (chkIdx + 1) "): " (pNext ? ("FOUND at (" px1 "," py1 ")") : "Not visible") "`n"
        "Portal -> Prev (" chkIdx "->" (chkIdx - 1) "): " (pPrev ? ("FOUND at (" px2 "," py2 ")") : "Not visible") "`n"
        "Boss/Miniboss: " (bossOn ? bKind : "None") "`n"
        "Tower Floor Cleared: " (clrOn ? "FOUND" : "Not visible"),
        "Live Screen Recheck",
        "Iconi"
    )
}

; ==============================================================================
; FLOATING ONE-GO CAPTURE BAR
; ==============================================================================

OpenFloatingCaptureBar(*) {
    global captureBarGui, captureBarVisible, capBarCatTxt, capBarItemTxt, capBarStatusTxt, mainGui

    if !IsSet(captureBarGui) {
        captureBarGui := Gui("+AlwaysOnTop +ToolWindow", "One-Go Capture Bar")
        captureBarGui.SetFont("s9", "Segoe UI")
        captureBarGui.BackColor := "0x141414"

        capBarCatTxt := captureBarGui.AddText("x10 y8 w320 h16 cA0A0A0", "")
        capBarCatTxt.SetFont("s8 Bold", "Segoe UI")
        capBarItemTxt := captureBarGui.AddText("x10 y26 w320 h18 cFFFFFF", "")
        capBarItemTxt.SetFont("s9 Bold", "Segoe UI")
        capBarStatusTxt := captureBarGui.AddText("x10 y46 w320 h16 c00FF88", "")
        capBarStatusTxt.SetFont("s8", "Segoe UI")

        btnPrev := captureBarGui.AddButton("x10 y70 w56 h26", "< Prev")
        btnSnap := captureBarGui.AddButton("x72 y70 w88 h26", "SNAP")
        btnChk  := captureBarGui.AddButton("x166 y70 w76 h26", "Recheck")
        btnNext := captureBarGui.AddButton("x248 y70 w56 h26", "Next >")
        btnDone := captureBarGui.AddButton("x310 y70 w56 h26", "Done")

        btnPrev.OnEvent("Click", (*) => CycleCaptureItem(-1))
        btnSnap.OnEvent("Click", SnapCurrentCaptureItem)
        btnChk.OnEvent("Click",  RecheckCurrentCaptureItem)
        btnNext.OnEvent("Click", (*) => CycleCaptureItem(1))
        btnDone.OnEvent("Click", CloseFloatingCaptureBar)
        captureBarGui.OnEvent("Close", CloseFloatingCaptureBar)
    }

    if IsSet(mainGui)
        mainGui.Hide()
    captureBarVisible := true
    RefreshCaptureUI()
    captureBarGui.Show("x20 y20 w376 h106")
}

CloseFloatingCaptureBar(*) {
    global captureBarGui, captureBarVisible, mainGui
    captureBarVisible := false
    if IsSet(captureBarGui)
        captureBarGui.Hide()
    if IsSet(mainGui)
        mainGui.Show()
    RefreshCaptureUI()
    RefreshImageStatus()
}
