; ==============================================================================
; ROBLOX WINDOW, OCR-FIRST INTEGRATION & FALLBACK PNG VISION
; ==============================================================================
#Include "OcrVision.ahk"

InitVisionAndWindow(requirePrompt) {
    global promptImg, searchBox, robloxWinBox, statueSearchBox, mapBox, topLabelBox
    EnsureOcrServerRunning()

    if (requirePrompt && !OcrServerReady() && !FileExist(promptImg)) {
        MsgBox("OCR Server is offline and Waystone prompt PNG is missing!`n`nStart ocr_vision_server.py or import:`n" promptImg)
        return false
    }

    windows := GetSortedRobloxWindows()
    if (windows.Length = 0) {
        MsgBox("No Roblox windows found!")
        return false
    }

    try {
        WinGetClientPos(&wx, &wy, &ww, &wh, "ahk_id " windows[1])
    } catch {
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " windows[1])
    }
    if (ww <= 0 || wh <= 0)
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " windows[1])

    cx := wx + (ww // 2)
    cy := wy + (wh // 2)

    halfW := Max(180, Round(ww * 0.22))
    topH  := Max(220, Round(wh * 0.28))
    botH  := Max(120, Round(wh * 0.16))
    searchBox    := {x1: cx - halfW, y1: cy - topH, x2: cx + halfW, y2: cy + botH}
    robloxWinBox := {x1: wx, y1: wy, x2: wx + ww, y2: wy + wh}

    topPad := Min(70, Round(wh * 0.08))
    botPad := Min(110, Round(wh * 0.12))
    statueSearchBox := {x1: wx, y1: wy + topPad, x2: wx + ww, y2: wy + wh - botPad}

    mapBox := {
        x1: wx + Round(ww * 0.20),
        y1: wy + Round(wh * 0.14),
        x2: wx + Round(ww * 0.80),
        y2: wy + Round(wh * 0.86)
    }

    topLabelBox := {
        x1: wx + Round(ww * 0.33),
        y1: wy + Round(wh * 0.012),
        x2: wx + Round(ww * 0.69),
        y2: wy + Round(wh * 0.082)
    }

    FocusWindow(windows[1])
    return true
}

IsOnWaystone(&fx := 0, &fy := 0) {
    global searchBox, promptImg, imgTolerance, robloxWinBox
    if (OcrServerReady()) {
        if (OcrIsOnWaystone()) {
            fx := (robloxWinBox.x1 + robloxWinBox.x2) // 2
            fy := (robloxWinBox.y1 + robloxWinBox.y2) // 2
            return true
        }
        return false
    }
    try {
        return ImageSearch(&fx, &fy, searchBox.x1, searchBox.y1, searchBox.x2, searchBox.y2, "*" imgTolerance " " promptImg)
    } catch {
        return false
    }
}

IsInTower(&fx := 0, &fy := 0) {
    global robloxWinBox, inTowerImg, towerImgTol, inTowerPrefix, towerMaskedCache
    if (OcrServerReady())
        return OcrIsInTower()
    if !FileExist(inTowerImg)
        return true
    if !IsSet(inTowerPrefix)
        inTowerPrefix := ""
    return SearchTextIndicatorImage(inTowerImg, robloxWinBox, towerImgTol, towerMaskedCache, "twr3", &fx, &fy, &inTowerPrefix)
}

IsFloorCleared(&fx := 0, &fy := 0) {
    global robloxWinBox, towerClearedImg, towerImgTol, towerClearedPrefix, towerMaskedCache
    if (OcrServerReady())
        return OcrIsFloorCleared()
    if !FileExist(towerClearedImg)
        return false
    if !IsSet(towerClearedPrefix)
        towerClearedPrefix := ""
    return SearchTextIndicatorImage(towerClearedImg, robloxWinBox, towerImgTol, towerClearedPrefix, "twr3", &fx, &fy, &towerClearedPrefix)
}

IsNextFloorIndicator(&fx := 0, &fy := 0) {
    global robloxWinBox, towerNextImg, towerImgTol, towerNextPrefix, towerMaskedCache
    if (OcrServerReady() && OcrIsFloorCleared())
        return true
    if !FileExist(towerNextImg)
        return false
    if !IsSet(towerNextPrefix)
        towerNextPrefix := ""
    return SearchTextIndicatorImage(towerNextImg, robloxWinBox, towerImgTol, towerMaskedCache, "twr3", &fx, &fy, &towerNextPrefix)
}

SearchImageWithCache(imgPath, box, tol, &fx := 0, &fy := 0, &cachedPrefix := "", allowTransFallback := true) {
    if !FileExist(imgPath)
        return false
    try {
        if (cachedPrefix != "") {
            if ImageSearch(&fx, &fy, box.x1, box.y1, box.x2, box.y2, "*" tol " " cachedPrefix " " imgPath)
                return true
        }
        if ImageSearch(&fx, &fy, box.x1, box.y1, box.x2, box.y2, "*" tol " " imgPath) {
            cachedPrefix := ""
            return true
        }
        if (allowTransFallback) {
            if ImageSearch(&fx, &fy, box.x1, box.y1, box.x2, box.y2, "*" tol " *TransBlack " imgPath) {
                cachedPrefix := "*TransBlack"
                return true
            }
            if ImageSearch(&fx, &fy, box.x1, box.y1, box.x2, box.y2, "*" tol " *TransWhite " imgPath) {
                cachedPrefix := "*TransWhite"
                return true
            }
        }
        return false
    } catch {
        return false
    }
}

InvalidateImageCaches(imgPath) {
    global bossMaskedCache, topLabelMaskedCache, towerMaskedCache, textSigCache
    global mapAreaStripCache, portalStripCache, recoverySearchPrefix, recoveryOffPrefix
    global mapOpenPrefix, mapArrowPrefix, mapWayPrefix, mapWayOffPrefix
    global inTowerPrefix, towerClearedPrefix, towerNextPrefix

    for cmap in [bossMaskedCache, topLabelMaskedCache, towerMaskedCache] {
        if cmap.Has(imgPath) {
            p := cmap[imgPath].path
            if textSigCache.Has(p)
                textSigCache.Delete(p)
            try FileDelete(p)
            cmap.Delete(imgPath)
        }
    }
    if portalStripCache.Has(imgPath) {
        for sc in portalStripCache[imgPath].crops
            try FileDelete(sc.path)
        portalStripCache.Delete(imgPath)
    }
    mapAreaStripCache := Map()
    recoverySearchPrefix := "", recoveryOffPrefix := ""
    mapOpenPrefix := "", mapArrowPrefix := "", mapWayPrefix := "", mapWayOffPrefix := ""
    inTowerPrefix := "", towerClearedPrefix := "", towerNextPrefix := ""
}

; ==============================================================================
; 24-BIT BMP TEXT-CORE MASKING + BITBLT CONTRAST-VERIFIED MATCHING
; ==============================================================================

GetTextCoreMaskedImage(imgPath, cacheMap, tag) {
    global textSigCache
    if !FileExist(imgPath)
        return ""

    stamp := FileGetSize(imgPath) "_" FileGetTime(imgPath) "_v4"
    if cacheMap.Has(imgPath) && cacheMap[imgPath].stamp = stamp {
        p := cacheMap[imgPath].path
        if FileExist(p) && textSigCache.Has(p)
            return p
    }

    cacheDir := A_Temp "\PixelEmpireCache"
    try DirCreate(cacheDir)
    baseName := RegExReplace(imgPath, ".*\\|\.[^.]*$", "")
    maskedPath := cacheDir "\" tag "_" baseName "_" stamp ".bmp"

    if !CreateTextCoreMaskedBmp(imgPath, maskedPath, &sig)
        return ""

    textSigCache[maskedPath] := sig
    cacheMap[imgPath] := {stamp: stamp, path: maskedPath}
    return maskedPath
}

CreateTextCoreMaskedBmp(srcPath, dstPath, &sig := "") {
    static hGdip := DllCall("LoadLibrary", "str", "gdiplus", "ptr")
    if !hGdip
        return false

    si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    NumPut("uint", 1, si, 0)
    if (DllCall("gdiplus\GdiplusStartup", "ptr*", &token := 0, "ptr", si, "ptr", 0) != 0)
        return false

    ok := false
    pBmp := 0
    if (DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", srcPath, "ptr*", &pBmp) = 0 && pBmp) {
        DllCall("gdiplus\GdipGetImageWidth",  "ptr", pBmp, "uint*", &w := 0)
        DllCall("gdiplus\GdipGetImageHeight", "ptr", pBmp, "uint*", &h := 0)

        if (w > 0 && h > 0) {
            rect := Buffer(16, 0)
            NumPut("int", 0, "int", 0, "int", w, "int", h, rect)
            bd := Buffer(A_PtrSize = 8 ? 32 : 24, 0)

            if (DllCall("gdiplus\GdipBitmapLockBits", "ptr", pBmp, "ptr", rect, "uint", 3, "int", 0x26200A, "ptr", bd) = 0) {
                stride := NumGet(bd, 8, "int")
                scan0  := NumGet(bd, 16, "ptr")

                hasTransparency := false
                peakBright := 0
                peakSat := 0
                y := 0
                while (y < h) {
                    rowPtr := scan0 + (y * stride)
                    x := 0
                    while (x < w) {
                        px := NumGet(rowPtr + (x * 4), "uint")
                        a := (px >> 24) & 0xFF
                        if (a < 250)
                            hasTransparency := true
                        if (a >= 210) {
                            r := (px >> 16) & 0xFF
                            g := (px >> 8)  & 0xFF
                            b := px & 0xFF
                            mx := Max(r, g, b)
                            mn := Min(r, g, b)
                            if (mx > peakBright)
                                peakBright := mx
                            if ((mx - mn) > peakSat)
                                peakSat := (mx - mn)
                        }
                        x += 1
                    }
                    y += 1
                }

                alphaMin  := hasTransparency ? 225 : 0
                brightMin := Max(80, Round(peakBright * 0.68))
                satMin    := (peakSat >= 60) ? 38 : 0

                kept := CountTextCorePixels(scan0, stride, w, h, alphaMin, brightMin, satMin)
                if (kept < 18) {
                    alphaMin  := hasTransparency ? 180 : 0
                    brightMin := Max(60, Round(peakBright * 0.50))
                    satMin    := (peakSat >= 60) ? 18 : 0
                    kept := CountTextCorePixels(scan0, stride, w, h, alphaMin, brightMin, satMin)
                }

                onAll := []
                offAll := []
                if (kept >= 10) {
                    sumR := 0, sumG := 0, sumB := 0
                    y := 0
                    while (y < h) {
                        rowPtr := scan0 + (y * stride)
                        x := 0
                        while (x < w) {
                            px := NumGet(rowPtr + (x * 4), "uint")
                            a := (px >> 24) & 0xFF
                            r := (px >> 16) & 0xFF
                            g := (px >> 8)  & 0xFF
                            b := px & 0xFF
                            mx := Max(r, g, b)
                            mn := Min(r, g, b)
                            if (a < alphaMin || mx < brightMin || (mx - mn) < satMin) {
                                NumPut("uint", 0xFFFF00FF, rowPtr + (x * 4))
                                if (a < 40 || mx < 50)
                                    offAll.Push({x: x, y: y})
                            } else {
                                NumPut("uint", 0xFF000000 | (r << 16) | (g << 8) | b, rowPtr + (x * 4))
                                if (a >= 235 && mx >= Max(110, brightMin)) {
                                    onAll.Push({x: x, y: y, r: r, g: g, b: b})
                                    sumR += r, sumG += g, sumB += b
                                }
                            }
                            x += 1
                        }
                        y += 1
                    }
                    avgR := (onAll.Length > 0) ? (sumR // onAll.Length) : 220
                    avgG := (onAll.Length > 0) ? (sumG // onAll.Length) : 180
                    avgB := (onAll.Length > 0) ? (sumB // onAll.Length) : 60
                    avgLuma := (avgR * 299 + avgG * 587 + avgB * 114) // 1000
                    sig := {
                        w: w, h: h,
                        avgR: avgR, avgG: avgG, avgB: avgB, avgLuma: avgLuma,
                        onPts:  SamplePointsEvenly(onAll, 28),
                        offPts: SamplePointsEvenly(offAll, 20)
                    }
                }

                DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", pBmp, "ptr", bd)

                if (kept >= 10) {
                    pBmp24 := 0
                    if (DllCall("gdiplus\GdipCloneBitmapAreaI", "int", 0, "int", 0, "int", w, "int", h, "int", 0x21808, "ptr", pBmp, "ptr*", &pBmp24) = 0 && pBmp24) {
                        clsidBuf := Buffer(16, 0)
                        DllCall("ole32\CLSIDFromString", "str", "{557CF400-1A04-11D3-9A73-0000F81EF32E}", "ptr", clsidBuf)
                        ok := (DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBmp24, "wstr", dstPath, "ptr", clsidBuf, "ptr", 0) = 0)
                        DllCall("gdiplus\GdipDisposeImage", "ptr", pBmp24)
                    }
                }
            }
        }
        DllCall("gdiplus\GdipDisposeImage", "ptr", pBmp)
    }
    DllCall("gdiplus\GdiplusShutdown", "ptr", token)
    return ok
}

SamplePointsEvenly(arr, maxCount) {
    out := []
    n := arr.Length
    if (n = 0)
        return out
    if (n <= maxCount)
        return arr
    step := n / maxCount
    i := 0
    while (i < maxCount) {
        idx := Min(n, Max(1, Floor(i * step) + 1))
        out.Push(arr[idx])
        i += 1
    }
    return out
}

CountTextCorePixels(scan0, stride, w, h, alphaMin, brightMin, satMin) {
    kept := 0
    y := 0
    while (y < h) {
        rowPtr := scan0 + (y * stride)
        x := 0
        while (x < w) {
            px := NumGet(rowPtr + (x * 4), "uint")
            a := (px >> 24) & 0xFF
            if (a >= alphaMin) {
                r := (px >> 16) & 0xFF
                g := (px >> 8)  & 0xFF
                b := px & 0xFF
                mx := Max(r, g, b)
                mn := Min(r, g, b)
                if (mx >= brightMin && (mx - mn) >= satMin)
                    kept += 1
            }
            x += 1
        }
        y += 1
    }
    return kept
}

VerifyTextMatchAt(fx, fy, sig, tol) {
    if !IsObject(sig) || sig.onPts.Length = 0
        return true

    hdcScreen := DllCall("GetDC", "ptr", 0, "ptr")
    if !hdcScreen
        return true

    memDC := DllCall("CreateCompatibleDC", "ptr", hdcScreen, "ptr")
    hBmp  := DllCall("CreateCompatibleBitmap", "ptr", hdcScreen, "int", sig.w, "int", sig.h, "ptr")
    oldObj := DllCall("SelectObject", "ptr", memDC, "ptr", hBmp, "ptr")
    DllCall("BitBlt", "ptr", memDC, "int", 0, "int", 0, "int", sig.w, "int", sig.h, "ptr", hdcScreen, "int", fx, "int", fy, "uint", 0x00CC0020)

    vTol := Max(55, tol + 15)
    onHits := 0
    for pt in sig.onPts {
        c := DllCall("GetPixel", "ptr", memDC, "int", pt.x, "int", pt.y, "uint")
        if (c != 0xFFFFFFFF) {
            sr := c & 0xFF
            sg := (c >> 8) & 0xFF
            sb := (c >> 16) & 0xFF
            if (Abs(sr - pt.r) <= vTol && Abs(sg - pt.g) <= vTol && Abs(sb - pt.b) <= vTol)
                onHits += 1
        }
    }

    offHits := 0
    for pt in sig.offPts {
        c := DllCall("GetPixel", "ptr", memDC, "int", pt.x, "int", pt.y, "uint")
        if (c != 0xFFFFFFFF) {
            sr := c & 0xFF
            sg := (c >> 8) & 0xFF
            sb := (c >> 16) & 0xFF
            gapLuma := (sr * 299 + sg * 587 + sb * 114) // 1000
            if (Max(Abs(sr - sig.avgR), Abs(sg - sig.avgG), Abs(sb - sig.avgB)) >= 32 || gapLuma <= sig.avgLuma - 30)
                offHits += 1
        }
    }

    DllCall("SelectObject", "ptr", memDC, "ptr", oldObj, "ptr")
    DllCall("DeleteObject", "ptr", hBmp)
    DllCall("DeleteDC", "ptr", memDC)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)

    onOk  := (onHits / sig.onPts.Length) >= 0.75
    offOk := (sig.offPts.Length < 4) || ((offHits / sig.offPts.Length) >= 0.65)
    return (onOk && offOk)
}

SearchVerifiedBmp(bmpPath, sig, box, tol, &fx := 0, &fy := 0) {
    curX1 := box.x1
    curY1 := box.y1
    Loop 14 {
        if (curY1 >= box.y2)
            break
        if (curX1 >= box.x2) {
            curX1 := box.x1
            curY1 += 3
            continue
        }
        try {
            if !ImageSearch(&cx, &cy, curX1, curY1, box.x2, box.y2, "*" tol " *Trans0xFF00FF " bmpPath)
                return false
        } catch {
            return false
        }
        if VerifyTextMatchAt(cx, cy, sig, tol) {
            fx := cx
            fy := cy
            return true
        }
        if (cx + 10 < box.x2 - sig.w) {
            curX1 := cx + 10
            curY1 := cy
        } else {
            curX1 := box.x1
            curY1 := cy + 3
        }
    }
    return false
}

SearchTextIndicatorImage(imgPath, box, tol, cacheMap, tag, &fx := 0, &fy := 0, &cachedPrefix := "", &usedMask := false) {
    global textSigCache
    usedMask := false
    if !FileExist(imgPath)
        return false

    maskedPath := GetTextCoreMaskedImage(imgPath, cacheMap, tag)
    if (maskedPath != "" && textSigCache.Has(maskedPath)) {
        sig := textSigCache[maskedPath]
        if SearchVerifiedBmp(maskedPath, sig, box, tol, &fx, &fy) {
            usedMask := true
            return true
        }
        if (tol < 90) {
            hiTol := Min(98, tol + 24)
            if SearchVerifiedBmp(maskedPath, sig, box, hiTol, &fx, &fy) {
                usedMask := true
                return true
            }
        }
        return false
    }

    return SearchImageWithCache(imgPath, box, tol, &fx, &fy, &cachedPrefix, true)
}

SearchBossImage(imgPath, box, tol, &fx := 0, &fy := 0, &cachedPrefix := "", &usedMask := false) {
    global bossMaskedCache
    return SearchTextIndicatorImage(imgPath, box, tol, bossMaskedCache, "boss4", &fx, &fy, &cachedPrefix, &usedMask)
}

SearchTopLabelImage(imgPath, box, tol, &fx := 0, &fy := 0, &cachedPrefix := "") {
    global topLabelMaskedCache
    return SearchTextIndicatorImage(imgPath, box, tol, topLabelMaskedCache, "toplbl4", &fx, &fy, &cachedPrefix)
}

; ==============================================================================
; TOP LABEL & MAP AREA PATHS + RECOGNITION
; ==============================================================================

GetMapTopLabelPath(idx) {
    global waystoneRoutes
    if !waystoneRoutes.Has(idx)
        return ""
    return A_ScriptDir "\public\maps\top_label\" waystoneRoutes[idx].file
}

GetMapAreaPath(idx) {
    global waystoneRoutes
    if !waystoneRoutes.Has(idx)
        return ""
    return A_ScriptDir "\public\maps\map_area\" waystoneRoutes[idx].file
}

IsMapTopLabel(idx, &fx := 0, &fy := 0, customBox := "") {
    global topLabelBox, topLabelTol, topLabelPrefixes
    if (!IsObject(customBox) && OcrServerReady()) {
        ocrIdx := OcrDetectCurrentMap()
        if (ocrIdx >= 0)
            return (ocrIdx = idx)
    }
    imgPath := GetMapTopLabelPath(idx)
    if (imgPath = "" || !FileExist(imgPath))
        return false
    box := IsObject(customBox) ? customBox : topLabelBox
    prefix := topLabelPrefixes.Has(idx) ? topLabelPrefixes[idx] : ""
    ok := SearchTopLabelImage(imgPath, box, topLabelTol, &fx, &fy, &prefix)
    topLabelPrefixes[idx] := prefix
    return ok
}

DetectCurrentMapByTopLabel(preferredList := "", customBox := "") {
    global maxWaystoneIdx
    if (!IsObject(customBox) && OcrServerReady()) {
        ocrIdx := OcrDetectCurrentMap()
        if (ocrIdx >= 0)
            return ocrIdx
    }

    checked := Map()
    if IsObject(preferredList) {
        for idx in preferredList {
            if (idx >= 0 && idx <= maxWaystoneIdx && !checked.Has(idx)) {
                checked[idx] := true
                if IsMapTopLabel(idx, , , customBox)
                    return idx
            }
        }
    }

    idx := 0
    while (idx <= maxWaystoneIdx) {
        if (!checked.Has(idx)) {
            if IsMapTopLabel(idx, , , customBox)
                return idx
        }
        idx += 1
    }
    return -1
}

EnsureMapAreaStrips(idx) {
    global mapAreaStripCache
    if mapAreaStripCache.Has(idx)
        return mapAreaStripCache[idx]

    srcPath := GetMapAreaPath(idx)
    if (srcPath = "" || !FileExist(srcPath))
        return ""

    if !GetImageDimensions(srcPath, &w, &h)
        return ""

    cacheDir := A_Temp "\PixelEmpireCache"
    try DirCreate(cacheDir)

    topPath := cacheDir "\ws" idx "_top.png"
    botPath := cacheDir "\ws" idx "_bot.png"

    topX := Round(w * 0.08), topY := Round(h * 0.025)
    topW := Max(24, Round(w * 0.84)), topH := Max(18, Round(h * 0.095))

    botX := Round(w * 0.12), botY := Round(h * 0.85)
    botW := Max(24, Round(w * 0.76)), botH := Max(16, Round(h * 0.11))

    if !FileExist(topPath)
        CropPngSubImage(srcPath, topPath, topX, topY, topW, topH)
    if !FileExist(botPath)
        CropPngSubImage(srcPath, botPath, botX, botY, botW, botH)

    info := {
        full: srcPath, w: w, h: h,
        topPath: topPath, topOx: topX, topOy: topY,
        botPath: botPath, botOx: botX, botOy: botY
    }
    mapAreaStripCache[idx] := info
    return info
}

CropPngSubImage(srcPath, dstPath, cx, cy, cw, ch) {
    static hGdip := DllCall("LoadLibrary", "str", "gdiplus", "ptr")
    if !hGdip
        return false

    si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    NumPut("uint", 1, si, 0)
    if (DllCall("gdiplus\GdiplusStartup", "ptr*", &token := 0, "ptr", si, "ptr", 0) != 0)
        return false

    ok := false
    pBmp := 0
    pCrop := 0
    if (DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", srcPath, "ptr*", &pBmp) = 0 && pBmp) {
        if (DllCall("gdiplus\GdipCloneBitmapAreaI", "int", cx, "int", cy, "int", cw, "int", ch, "int", 0x26200A, "ptr", pBmp, "ptr*", &pCrop) = 0 && pCrop) {
            clsidBuf := Buffer(16, 0)
            DllCall("ole32\CLSIDFromString", "str", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", clsidBuf)
            ok := (DllCall("gdiplus\GdipSaveImageToFile", "ptr", pCrop, "wstr", dstPath, "ptr", clsidBuf, "ptr", 0) = 0)
            DllCall("gdiplus\GdipDisposeImage", "ptr", pCrop)
        }
        DllCall("gdiplus\GdipDisposeImage", "ptr", pBmp)
    }
    DllCall("gdiplus\GdiplusShutdown", "ptr", token)
    return ok
}

FindMapAreaOnWorldMap(idx, &areaBox := "") {
    global mapBox, mapTolerance, mapAreaPrefixes
    info := EnsureMapAreaStrips(idx)
    if !IsObject(info)
        return false

    prefix := mapAreaPrefixes.Has(idx) ? mapAreaPrefixes[idx] : ""

    if FileExist(info.topPath) && SearchImageWithCache(info.topPath, mapBox, mapTolerance, &fx, &fy, &prefix, false) {
        mapAreaPrefixes[idx] := prefix
        mx := fx - info.topOx
        my := fy - info.topOy
        areaBox := {x1: mx, y1: my, x2: mx + info.w, y2: my + info.h, cx: mx + (info.w // 2), cy: my + (info.h // 2)}
        return true
    }

    botPref := ""
    if FileExist(info.botPath) && SearchImageWithCache(info.botPath, mapBox, mapTolerance, &fx, &fy, &botPref, false) {
        mx := fx - info.botOx
        my := fy - info.botOy
        areaBox := {x1: mx, y1: my, x2: mx + info.w, y2: my + info.h, cx: mx + (info.w // 2), cy: my + (info.h // 2)}
        return true
    }

    fullPref := ""
    if SearchImageWithCache(info.full, mapBox, mapTolerance, &fx, &fy, &fullPref, false) {
        areaBox := {x1: fx, y1: fy, x2: fx + info.w, y2: fy + info.h, cx: fx + (info.w // 2), cy: fy + (info.h // 2)}
        return true
    }

    return false
}

; ==============================================================================
; PORTAL IMAGE DETECTION (portals_day & portals_night + OBSTACLE SUB-CROPS)
; ==============================================================================

GetPortalImagePaths(fromIdx, toIdx, timeMode := "ALL") {
    paths := []
    fileName := "WS" fromIdx "_WS" toIdx ".png"
    dayPath   := A_ScriptDir "\public\maps\portals_day\" fileName
    nightPath := A_ScriptDir "\public\maps\portals_night\" fileName
    if (timeMode = "DAY" || timeMode = "ALL") && FileExist(dayPath)
        paths.Push(dayPath)
    if (timeMode = "NIGHT" || timeMode = "ALL") && FileExist(nightPath)
        paths.Push(nightPath)
    return paths
}

EnsurePortalStrips(imgPath) {
    global portalStripCache
    if !FileExist(imgPath)
        return ""

    stamp := FileGetSize(imgPath) "_" FileGetTime(imgPath)
    if portalStripCache.Has(imgPath) && portalStripCache[imgPath].stamp = stamp
        return portalStripCache[imgPath]

    if !GetImageDimensions(imgPath, &w, &h)
        return ""

    cacheDir := A_Temp "\PixelEmpireCache"
    try DirCreate(cacheDir)
    baseName := RegExReplace(imgPath, ".*\\", "")
    parentDir := InStr(imgPath, "portals_night") ? "pn_" : "pd_"

    crops := []
    if (w >= 28 && h >= 28) {
        defs := [
            {tag: "top", ox: Round(w * 0.15), oy: Round(h * 0.06), cw: Max(16, Round(w * 0.70)), ch: Max(16, Round(h * 0.40))},
            {tag: "mid", ox: Round(w * 0.22), oy: Round(h * 0.24), cw: Max(16, Round(w * 0.56)), ch: Max(16, Round(h * 0.46))},
            {tag: "bot", ox: Round(w * 0.20), oy: Round(h * 0.50), cw: Max(16, Round(w * 0.60)), ch: Max(16, Round(h * 0.42))}
        ]
        for d in defs {
            p := cacheDir "\" parentDir baseName "_" d.tag "_" stamp ".png"
            if !FileExist(p)
                CropPngSubImage(imgPath, p, d.ox, d.oy, d.cw, d.ch)
            if FileExist(p)
                crops.Push({path: p, ox: d.ox, oy: d.oy})
        }
    }

    info := {stamp: stamp, full: imgPath, w: w, h: h, crops: crops}
    portalStripCache[imgPath] := info
    return info
}

FindPortalSprite(fromIdx, toIdx, &cx := 0, &cy := 0, customBox := "") {
    global statueSearchBox, robloxWinBox, portalTol, portalPrefixes
    if (OcrServerReady() && OcrFindPortalSprite(&cx, &cy))
        return true
    b := IsObject(customBox) ? customBox : (IsSet(statueSearchBox) ? statueSearchBox : robloxWinBox)
    paths := GetPortalImagePaths(fromIdx, toIdx)
    if (paths.Length = 0)
        return false

    for imgPath in paths {
        info := EnsurePortalStrips(imgPath)
        if !IsObject(info)
            continue
        pref := portalPrefixes.Has(imgPath) ? portalPrefixes[imgPath] : ""
        if SearchImageWithCache(imgPath, b, portalTol, &fx, &fy, &pref, false) {
            portalPrefixes[imgPath] := pref
            cx := fx + (info.w // 2)
            cy := fy + (info.h // 2)
            return true
        }
    }

    for imgPath in paths {
        info := EnsurePortalStrips(imgPath)
        if !IsObject(info)
            continue
        for c in info.crops {
            subPref := ""
            if SearchImageWithCache(c.path, b, portalTol, &fx, &fy, &subPref, false) {
                fullX := fx - c.ox
                fullY := fy - c.oy
                cx := fullX + (info.w // 2)
                cy := fullY + (info.h // 2)
                return true
            }
        }
    }
    return false
}

; ==============================================================================
; WAYSTONE STATUE & WORLD MAP (M) VECTOR SCAN (OCR/HSV + PNG FALLBACK)
; ==============================================================================

FindWaystoneStatue(&fx := 0, &fy := 0, customBox := "") {
    global statueSearchBox, robloxWinBox, recoveryImg, recoveryOffImg, recoveryTolerance
    global recoverySearchPrefix, recoveryOffPrefix, lastMatchedStatueImg

    if !IsSet(recoverySearchPrefix)
        recoverySearchPrefix := ""
    if !IsSet(recoveryOffPrefix)
        recoveryOffPrefix := ""

    defaultBox := IsSet(statueSearchBox) ? statueSearchBox : robloxWinBox
    b := IsObject(customBox) ? customBox : defaultBox
    allowTrans := !IsObject(customBox)

    if SearchImageWithCache(recoveryImg, b, recoveryTolerance, &fx, &fy, &recoverySearchPrefix, allowTrans) {
        lastMatchedStatueImg := recoveryImg
        return true
    }
    if SearchImageWithCache(recoveryOffImg, b, recoveryTolerance, &fx, &fy, &recoveryOffPrefix, allowTrans) {
        lastMatchedStatueImg := recoveryOffImg
        return true
    }

    if (!IsObject(customBox) && recoveryTolerance < 85) {
        blueTol := Min(90, recoveryTolerance + 25)
        if SearchImageWithCache(recoveryImg, b, blueTol, &fx, &fy, &recoverySearchPrefix, true) {
            lastMatchedStatueImg := recoveryImg
            return true
        }
        if SearchImageWithCache(recoveryOffImg, b, blueTol, &fx, &fy, &recoveryOffPrefix, true) {
            lastMatchedStatueImg := recoveryOffImg
            return true
        }
    }
    return false
}

FindMapIcon(imgPath, box, &fx := 0, &fy := 0, &cachedPrefix := "", extraTol := 0) {
    global mapTolerance
    return SearchImageWithCache(imgPath, box, Min(110, mapTolerance + extraTol), &fx, &fy, &cachedPrefix, true)
}

IsWorldMapOpen(&fx := 0, &fy := 0) {
    global mapBox, mapOpenImg, mapOpenPrefix, mapArrowImg, mapArrowPrefix
    if FileExist(mapOpenImg) && FindMapIcon(mapOpenImg, mapBox, &fx, &fy, &mapOpenPrefix)
        return true
    if FileExist(mapArrowImg)
        return FindMapIcon(mapArrowImg, mapBox, &fx, &fy, &mapArrowPrefix, 10)
    return false
}

OpenWorldMap() {
    global running
    if IsWorldMapOpen()
        return true
    SendEvent("m")
    Loop 16 {
        Sleep(50)
        if (!running)
            break
        if IsWorldMapOpen()
            return true
    }
    return IsWorldMapOpen()
}

CloseWorldMap() {
    if !IsWorldMapOpen()
        return true
    SendEvent("m")
    Loop 10 {
        Sleep(40)
        if !IsWorldMapOpen()
            return true
    }
    if IsWorldMapOpen() {
        SendEvent("m")
        Sleep(150)
    }
    return !IsWorldMapOpen()
}

FindWaystoneInMapBox(searchRegion, &wcx := 0, &wcy := 0, &wx := 0, &wy := 0, allowBlueFallback := false) {
    global mapWaystoneImg, mapWaystoneOffImg, mapWayPrefix, mapWayOffPrefix
    matchedImg := ""
    if FindMapIcon(mapWaystoneImg, searchRegion, &wx, &wy, &mapWayPrefix)
        matchedImg := mapWaystoneImg
    else if FindMapIcon(mapWaystoneOffImg, searchRegion, &wx, &wy, &mapWayOffPrefix)
        matchedImg := mapWaystoneOffImg
    else if (allowBlueFallback) {
        if FindMapIcon(mapWaystoneImg, searchRegion, &wx, &wy, &mapWayPrefix, 24)
            matchedImg := mapWaystoneImg
        else if FindMapIcon(mapWaystoneOffImg, searchRegion, &wx, &wy, &mapWayOffPrefix, 24)
            matchedImg := mapWaystoneOffImg
    }

    if (matchedImg != "") {
        GetImageDimensions(matchedImg, &ww, &wh)
        wcx := wx + ((ww > 0) ? (ww // 2) : 6)
        wcy := wy + ((wh > 0) ? (wh // 2) : 10)
        return true
    }
    return false
}

ScanWorldMapVector(targetMapIdx := -1) {
    global mapBox, mapArrowImg, mapWaystoneImg, mapWaystoneOffImg, mapArrowPrefix, isScanningMap
    res := {ok: false, openDetected: false, arrowFound: false, wayFound: false, areaFound: false, ax: 0, ay: 0, acx: 0, acy: 0, wx: 0, wy: 0, dx: 0, dy: 0}

    windows := GetSortedRobloxWindows()
    if (windows.Length = 0)
        return res
    FocusWindow(windows[1])

    isScanningMap := true

    ; OCR/HSV World Map vector path (works without manual World Map PNGs)
    if (OcrServerReady()) {
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
            SendEvent("m")
            Sleep(140)
            isScanningMap := false
            if (res.ok)
                return res
        } else {
            SendEvent("m")
            Sleep(140)
        }
    }

    hasWayIcon := FileExist(mapWaystoneImg) || FileExist(mapWaystoneOffImg)
    if (!FileExist(mapArrowImg) || !hasWayIcon) {
        isScanningMap := false
        return res
    }

    res.openDetected := OpenWorldMap()

    if (res.openDetected) {
        Sleep(80)
        res.arrowFound := FindMapIcon(mapArrowImg, mapBox, &ax, &ay, &mapArrowPrefix)
        if (!res.arrowFound)
            res.arrowFound := FindMapIcon(mapArrowImg, mapBox, &ax, &ay, &mapArrowPrefix, 20)

        if (res.arrowFound) {
            res.ax := ax
            res.ay := ay
            GetImageDimensions(mapArrowImg, &aw, &ah)
            acx := ax + ((aw > 0) ? (aw // 2) : 6)
            acy := ay + ((ah > 0) ? (ah // 2) : 6)
            res.acx := acx
            res.acy := acy

            if (targetMapIdx >= 0 && FindMapAreaOnWorldMap(targetMapIdx, &areaBox)) {
                res.areaFound := true
                clampedBox := {
                    x1: Max(mapBox.x1, areaBox.x1),
                    y1: Max(mapBox.y1, areaBox.y1),
                    x2: Min(mapBox.x2, areaBox.x2),
                    y2: Min(mapBox.y2, areaBox.y2)
                }
                if (clampedBox.x2 > clampedBox.x1 && clampedBox.y2 > clampedBox.y1) {
                    if FindWaystoneInMapBox(clampedBox, &wcx, &wcy, &wx, &wy, true) {
                        res.wayFound := true
                        res.wx := wx
                        res.wy := wy
                        res.dx := wcx - acx
                        res.dy := wcy - acy
                        res.ok := true
                    } else {
                        res.wayFound := true
                        res.wx := areaBox.cx
                        res.wy := areaBox.cy
                        res.dx := areaBox.cx - acx
                        res.dy := areaBox.cy - acy
                        res.ok := true
                    }
                }
            }

            if (!res.ok) {
                for radius in [130, 240, 380] {
                    nearBox := {
                        x1: Max(mapBox.x1, acx - radius),
                        y1: Max(mapBox.y1, acy - radius),
                        x2: Min(mapBox.x2, acx + radius),
                        y2: Min(mapBox.y2, acy + radius)
                    }
                    if FindWaystoneInMapBox(nearBox, &wcx, &wcy, &wx, &wy, true) {
                        res.wayFound := true
                        res.wx := wx
                        res.wy := wy
                        res.dx := wcx - acx
                        res.dy := wcy - acy
                        res.ok := true
                        break
                    }
                }
            }
        }
    }

    CloseWorldMap()
    isScanningMap := false
    return res
}

ScanWorldMapBetweenMaps(fromIdx, toIdx) {
    global mapBox, mapArrowImg, mapArrowPrefix, isScanningMap
    res := {ok: false, openDetected: false, acx: 0, acy: 0, fromOk: false, toOk: false, dx: 0, dy: 0}

    windows := GetSortedRobloxWindows()
    if (windows.Length = 0)
        return res
    FocusWindow(windows[1])

    isScanningMap := true
    res.openDetected := OpenWorldMap()
    if (res.openDetected) {
        Sleep(80)
        if FindMapIcon(mapArrowImg, mapBox, &ax, &ay, &mapArrowPrefix, 15) {
            GetImageDimensions(mapArrowImg, &aw, &ah)
            res.acx := ax + ((aw > 0) ? (aw // 2) : 6)
            res.acy := ay + ((ah > 0) ? (ah // 2) : 6)
        }

        if FindMapAreaOnWorldMap(toIdx, &toArea) {
            res.toOk := true
            toBox := {
                x1: Max(mapBox.x1, toArea.x1),
                y1: Max(mapBox.y1, toArea.y1),
                x2: Min(mapBox.x2, toArea.x2),
                y2: Min(mapBox.y2, toArea.y2)
            }
            if (toBox.x2 > toBox.x1 && toBox.y2 > toBox.y1) && FindWaystoneInMapBox(toBox, &tx, &ty, , , true) {
                targetX := tx, targetY := ty
            } else {
                targetX := toArea.cx, targetY := toArea.cy
            }

            if (res.acx > 0) {
                res.dx := targetX - res.acx
                res.dy := targetY - res.acy
                res.ok := true
            } else if FindMapAreaOnWorldMap(fromIdx, &fromArea) {
                res.fromOk := true
                res.dx := targetX - fromArea.cx
                res.dy := targetY - fromArea.cy
                res.ok := true
            }
        }
    }

    CloseWorldMap()
    isScanningMap := false
    return res
}

GetImageDimensions(imgPath, &w := 0, &h := 0) {
    w := 0
    h := 0
    if !FileExist(imgPath)
        return false
    try {
        hBmp := LoadPicture(imgPath)
        if !hBmp
            return false
        buf := Buffer(32, 0)
        DllCall("GetObject", "ptr", hBmp, "int", 32, "ptr", buf)
        w := NumGet(buf, 4, "int")
        h := NumGet(buf, 8, "int")
        DllCall("DeleteObject", "ptr", hBmp)
        return (w > 0 && h > 0)
    } catch {
        return false
    }
}

GetSortedRobloxWindows() {
    hwnds := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    i := 1
    while (i < hwnds.Length) {
        j := i + 1
        while (j <= hwnds.Length) {
            try {
                WinGetPos(&x1, , , , "ahk_id " hwnds[i])
                WinGetPos(&x2, , , , "ahk_id " hwnds[j])
                if (x2 < x1) {
                    temp := hwnds[i]
                    hwnds[i] := hwnds[j]
                    hwnds[j] := temp
                }
            }
            j++
        }
        i++
    }
    return hwnds
}

FocusWindow(hwnd) {
    if WinExist("ahk_id " hwnd) && !WinActive("ahk_id " hwnd) {
        WinActivate("ahk_id " hwnd)
        Sleep(30)
    }
}