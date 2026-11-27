; Overlay-free indicator rectangle selector (Shift+F11).
InitAssetPicker() {
    global assetPickerActive, assetPickerPhase, assetPickerPurpose, assetPickerWindows, assetPickerBorders, assetPickerSelecting, mainGui
    assetPickerActive := false, assetPickerPhase := "off", assetPickerPurpose := "indicator"
    assetPickerWindows := Map(), assetPickerBorders := [], assetPickerSelecting := false
    AssetPickerWriteCommand(false)
    IniWrite(mainGui.Hwnd, A_ScriptDir "\.task-output\macro_window.ini", "Window", "hwnd")
    IniWrite(DllCall("GetCurrentProcessId"), A_ScriptDir "\.task-output\macro_window.ini", "Window", "pid")
    OnMessage(0x8003, PauseForManualRecording)
    HotIf(AssetPickerCanSelect)
    Hotkey("*LButton", AssetPickerPress, "On")
    HotIf((*) => assetPickerActive)
    Hotkey("Esc", ExitAssetPicker, "On")
    HotIf(AssetPickerCanRelease)
    Hotkey("*LButton Up", AssetPickerRelease, "On")
    HotIf()
}

AssetPickerWriteCommand(enabled, fresh := true, target := "") {
    global assetPickerEpoch, assetPickerPhase, assetPickerPurpose
    if fresh
        assetPickerEpoch := A_NowUTC "-" A_TickCount
    DirCreate(A_ScriptDir "\.task-output")
    temp := A_ScriptDir "\.task-output\asset_picker_command.tmp"
    file := FileOpen(temp,"w","UTF-16")
    file.Write("[Picker]`nenabled=" (enabled ? 1 : 0) "`nepoch=" assetPickerEpoch "`nphase=" assetPickerPhase
        "`npurpose=" assetPickerPurpose "`ntarget=" RegExReplace(target,"[^A-Za-z0-9_-]", "") "`n")
    file.Close()
    FileMove(temp,A_ScriptDir "\.task-output\asset_picker_command.ini",true)
}

AssetPickerRememberWindows() {
    global assetPickerWindows
    assetPickerWindows := Map()
    pids := [DllCall("GetCurrentProcessId")]
    for kind in ["agent_overlay","image_review","asset_picker","reference_setup"] {
        path := A_ScriptDir "\.task-output\" kind "_window.ini"
        hwnd := IniRead(path,"Window","hwnd","0")+0
        pid := IniRead(path,"Window","pid","0")+0
        if hwnd && WinExist("ahk_id " hwnd) && WinGetPID("ahk_id " hwnd)=pid
            pids.Push(pid)
    }
    for pid in pids {
        DetectHiddenWindows(true)
        for hwnd in WinGetList("ahk_pid " pid) {
            assetPickerWindows[hwnd] := {visible:DllCall("IsWindowVisible","ptr",hwnd),iconic:DllCall("IsIconic","ptr",hwnd)}
        }
        DetectHiddenWindows(false)
    }
}

AssetPickerHideWindows() {
    global assetPickerWindows
    for hwnd, state in assetPickerWindows
        if DllCall("IsWindow","ptr",hwnd)
            DllCall("ShowWindow","ptr",hwnd,"int",0)
}

AssetPickerRestoreWindows() {
    global assetPickerWindows
    for hwnd,state in assetPickerWindows {
        if DllCall("IsWindow","ptr",hwnd)
            DllCall("ShowWindow","ptr",hwnd,"int",state.visible ? (state.iconic ? 6 : 4) : 0)
    }
    assetPickerWindows := Map()
}

DefineIndicatorRegion(*) {
    BeginAssetSelection("indicator")
}

BeginAssetSelection(purpose,target := "") {
    global assetPickerActive,assetPickerPhase,assetPickerPurpose,assetPickerStarted,assetPickerDpiContext,hudStatus,assetPickerTarget
    global assetPickerSelecting,assetPickerFocusReady
    assetPickerSelecting := false,assetPickerFocusReady := false
    if !WinExist("ahk_exe RobloxPlayerBeta.exe") {
        UpdateGuiStatus("Rectangle selection requires a Roblox client")
        return
    }
    AssetPickerDestroyBorder()
    AssetPickerRestoreWindows()
    AssetPickerRememberWindows()
    StopAll("Rectangle selection: automation paused")
    ReleaseMoveKeys()
    assetPickerActive := true,assetPickerPhase := "selecting",assetPickerPurpose := purpose,assetPickerTarget := target
    assetPickerStarted := A_TickCount
    AssetPickerHideWindows()
    ; Also hide windows StopAll may have just shown (without changing saved visibility).
    global mainGui
    mainGui.Hide()
    assetPickerDpiContext := DllCall("SetThreadDpiAwarenessContext","ptr",-4,"ptr")
    AssetPickerWriteCommand(true,true,target)
    try Run('"' A_ScriptDir '\.venv\Scripts\pythonw.exe" "' A_ScriptDir '\scripts\indicator_capture.py"',A_ScriptDir)
    catch as err {
        ExitAssetPicker()
        UpdateGuiStatus("Selection helper failed: " err.Message)
        return
    }
    FocusWindow(WinExist("ahk_exe RobloxPlayerBeta.exe"))
    hudStatus := "Drag a rectangle in Roblox — Esc cancels"
    SetTimer(PollAssetPicker,80)
}

AssetPickerDestroyBorder() {
    global assetPickerBorders
    SetTimer(DrawAssetPickerBorder,0)
    if IsSet(assetPickerBorders) {
        for gui in assetPickerBorders
            try gui.Destroy()
    }
    assetPickerBorders := []
    ToolTip()
}

AssetPickerFinishCapture() {
    global assetPickerPhase,assetPickerDpiContext,assetPickerTarget
    AssetPickerDestroyBorder()
    if IsSet(assetPickerDpiContext) && assetPickerDpiContext {
        DllCall("SetThreadDpiAwarenessContext","ptr",assetPickerDpiContext,"ptr")
        assetPickerDpiContext := 0
    }
    AssetPickerRestoreWindows()
    assetPickerPhase := "review"
    AssetPickerWriteCommand(true,false,assetPickerTarget)
}

ExitAssetPicker(*) {
    global assetPickerActive,assetPickerSelecting,assetPickerPhase,assetPickerDpiContext
    assetPickerActive := false,assetPickerSelecting := false,assetPickerPhase := "off"
    AssetPickerDestroyBorder()
    if IsSet(assetPickerDpiContext) && assetPickerDpiContext {
        DllCall("SetThreadDpiAwarenessContext","ptr",assetPickerDpiContext,"ptr")
        assetPickerDpiContext := 0
    }
    AssetPickerWriteCommand(false)
    SetTimer(PollAssetPicker,0)
    ReleaseMoveKeys()
    AssetPickerRestoreWindows()
    UpdateGuiStatus("Selection cancelled — normal mouse behavior restored; movement stays paused")
}

PollAssetPicker() {
    global assetPickerActive,assetPickerPhase,assetPickerEpoch,assetPickerStarted,assetPickerPending,assetPickerPurpose,assetPickerFocusReady
    path := A_ScriptDir "\.task-output\asset_picker_command.ini"
    if !assetPickerActive || IniRead(path,"Picker","enabled","0")!="1" {
        ExitAssetPicker()
        return
    }
    if assetPickerPhase="review" && IniRead(path,"Picker","phase","")="selecting" {
        BeginAssetSelection(IniRead(path,"Picker","purpose","indicator"),IniRead(path,"Picker","target",""))
        return
    }
    if assetPickerPhase="waiting" {
        ack := A_ScriptDir "\.task-output\asset_picker_capture_ack.ini"
        if IniRead(ack,"Capture","id","")=assetPickerPending {
            AssetPickerFinishCapture()
            return
        }
        if A_TickCount-assetPickerStarted>12000 {
            ExitAssetPicker()
            UpdateGuiStatus("Capture timed out; windows restored. Try again.")
        }
    } else if assetPickerPhase="selecting" {
        AssetPickerHideWindows()
        ; A newly created Tk root can take focus during startup. Focus once after its ready handshake.
        if !assetPickerFocusReady && IniRead(A_ScriptDir "\.task-output\asset_picker_state.ini","Picker","epoch","")=assetPickerEpoch {
            FocusWindow(WinExist("ahk_exe RobloxPlayerBeta.exe"))
            assetPickerFocusReady := true
        }
        if A_TickCount-assetPickerStarted>20000 && IniRead(A_ScriptDir "\.task-output\asset_picker_state.ini","Picker","epoch","")!=assetPickerEpoch {
            ExitAssetPicker()
            UpdateGuiStatus("Selection helper startup timed out; windows restored")
        }
    }
}

AssetPickerCursor(&x,&y) {
    point := Buffer(8)
    DllCall("GetPhysicalCursorPos","ptr",point)
    x := NumGet(point,0,"int"),y := NumGet(point,4,"int")
}

AssetPickerClient(hwnd) {
    rect := Buffer(16),point := Buffer(8,0)
    if !DllCall("GetClientRect","ptr",hwnd,"ptr",rect) || !DllCall("ClientToScreen","ptr",hwnd,"ptr",point)
        throw Error("Roblox client unavailable")
    return {x:NumGet(point,0,"int"),y:NumGet(point,4,"int"),w:NumGet(rect,8,"int"),h:NumGet(rect,12,"int"),hwnd:hwnd}
}

AssetPickerCanSelect(*) {
    global assetPickerActive,assetPickerPhase
    if !assetPickerActive || assetPickerPhase!="selecting" || !WinActive("ahk_exe RobloxPlayerBeta.exe")
        return false
    try {
        AssetPickerCursor(&x,&y)
        point := Buffer(8),NumPut("int",x,"int",y,point)
        under := DllCall("WindowFromPhysicalPoint","int64",NumGet(point,0,"int64"),"ptr")
        if WinGetProcessName("ahk_id " under)!="RobloxPlayerBeta.exe"
            return false
        box := AssetPickerClient(WinActive("ahk_exe RobloxPlayerBeta.exe"))
        return x>=box.x && y>=box.y && x<box.x+box.w && y<box.y+box.h
    } catch {
        return false
    }
}

AssetPickerCanRelease(*) {
    global assetPickerSelecting
    return assetPickerSelecting || AssetPickerCanSelect()
}

AssetPickerPress(*) {
    global assetPickerSelecting,assetPickerX,assetPickerY,assetPickerBox,assetPickerEpoch,assetPickerBorders,assetPickerDimensionText
    if IniRead(A_ScriptDir "\.task-output\asset_picker_state.ini","Picker","epoch","")!=assetPickerEpoch
        return
    AssetPickerCursor(&assetPickerX,&assetPickerY)
    assetPickerBox := AssetPickerClient(WinActive("ahk_exe RobloxPlayerBeta.exe"))
    assetPickerSelecting := true
    loop 5 {
        edge := Gui("-Caption +AlwaysOnTop +ToolWindow -DPIScale +E0x08000020")
        edge.BackColor := A_Index=5 ? "152230" : "00FF99"
        if A_Index=5 {
            edge.SetFont("s10 cFFFFFF","Segoe UI")
            assetPickerDimensionText := edge.AddText("x4 y2 w300 h22","")
        }
        assetPickerBorders.Push(edge)
    }
    SetTimer(DrawAssetPickerBorder,16)
}

DrawAssetPickerBorder() {
    global assetPickerSelecting,assetPickerBorders,assetPickerX,assetPickerY,assetPickerBox,assetPickerDimensionText
    if !assetPickerSelecting
        return
    AssetPickerCursor(&x,&y)
    box := assetPickerBox
    x:=Max(box.x,Min(box.x+box.w-1,x)),y:=Max(box.y,Min(box.y+box.h-1,y))
    left:=Min(x,assetPickerX),top:=Min(y,assetPickerY),w:=Max(2,Abs(x-assetPickerX)),h:=Max(2,Abs(y-assetPickerY))
    positions := [[left,top,w,2],[left,top+h,w,2],[left,top,2,h],[left+w,top,2,h]]
    for i,pos in positions
        assetPickerBorders[i].Show("NA x" pos[1] " y" pos[2] " w" pos[3] " h" pos[4])
    label := assetPickerBorders[5]
    assetPickerDimensionText.Text := w " x " h " px — Esc cancels"
    label.Show("NA x" box.x+8 " y" box.y+8 " w310 h26")
}

AssetPickerRelease(*) {
    global assetPickerSelecting,assetPickerX,assetPickerY,assetPickerBox,assetPickerEpoch,assetPickerPhase,assetPickerPurpose,assetPickerTarget,assetPickerStarted,assetPickerPending,assetPickerWindows
    if !assetPickerSelecting
        return
    assetPickerSelecting := false
    AssetPickerDestroyBorder()
    if !WinActive("ahk_exe RobloxPlayerBeta.exe") {
        ExitAssetPicker()
        return
    }
    AssetPickerCursor(&x,&y)
    box:=assetPickerBox
    x:=Max(box.x,Min(box.x+box.w-1,x)),y:=Max(box.y,Min(box.y+box.h-1,y))
    AssetPickerHideWindows()
    DllCall("dwmapi\DwmFlush")
    Sleep(60)
    assetPickerPending:=assetPickerEpoch "-" A_TickCount
    hidden:=""
    for hwnd,_ in assetPickerWindows
        hidden.=(hidden="" ? "" : ",") hwnd
    temp:=A_ScriptDir "\.task-output\asset_picker_request.tmp"
    file:=FileOpen(temp,"w","UTF-16")
    file.Write("[Selection]`nid=" assetPickerPending "`nepoch=" assetPickerEpoch "`npurpose=" assetPickerPurpose "`ntarget=" assetPickerTarget
        "`nhwnd=" box.hwnd "`nclient_x=" box.x "`nclient_y=" box.y "`nclient_w=" box.w "`nclient_h=" box.h
        "`nx1=" assetPickerX "`ny1=" assetPickerY "`nx2=" x "`ny2=" y "`nhidden_hwnds=" hidden "`n")
    file.Close()
    assetPickerPhase:="waiting",assetPickerStarted:=A_TickCount
    FileMove(temp,A_ScriptDir "\.task-output\asset_picker_request.ini",true)
    ReleaseMoveKeys()
}

PauseForManualRecording(*) {
    StopAll("Manual route demonstration")
    ReleaseMoveKeys()
    return 1
}
