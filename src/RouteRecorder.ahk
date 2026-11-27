; Small, bounded entry points over the macro's existing functions.
RouteJson(value) {
    return '"' StrReplace(StrReplace(StrReplace(String(value), Chr(92), Chr(92) Chr(92)), Chr(34), Chr(92) Chr(34)), "`n", Chr(92) "n") '"'
}

RouteResult(action, status, detail := "") {
    ReleaseMoveKeys()
    FileAppend('{"action":' RouteJson(action) ',"status":' RouteJson(status) ',"detail":' RouteJson(detail) ',"keys_released":true}`n', "*")
}

RouteActionCleanup(*) {
    global demoCapture
    if IsSet(demoCapture) && demoCapture.active
        StopRouteDemo("exit")
    ReleaseMoveKeys()
}

RouteActionCancel(reason) {
    global running, demoCapture
    if IsSet(demoCapture) && demoCapture.active
        StopRouteDemo(reason)
    running := false
    RouteActionCleanup()
    ExitApp(2)
}

RouteActionMain(args) {
    if args.Length < 2 || (args[1] != "record" && args[1] != "replay")
        throw Error("Use record <request.ini> or replay <route.ini>")
    if !InitVisionAndWindow(false)
        throw Error("Roblox unavailable")
    try {
        if args[1] = "record"
            RunRouteDemo(args[2])
        else
            ReplayRouteDemo(args[2])
    } catch as err {
        RouteDemoStatus(false,"Cancelled: " err.Message)
        NavProgress("PAUSED: " err.Message)
    } finally {
        ReleaseMoveKeys()
    }
}

RunRouteDemo(request) {
    global demoCapture
    if (IniRead(request,"Demo","consent","0") != "1")
        throw Error("Recorder requires explicit Start consent")
    if (IniRead(request,"Demo","chat_closed","0") != "1")
        throw Error("Close chat/text entry before recording")
    try FileDelete(A_ScriptDir "\.task-output\demo_stop")
    countdown := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
    countdown.SetFont("s36 cFFFFFF", "Segoe UI")
    countdown.BackColor := "172033"
    label := countdown.AddText("w260 Center", "3")
    countdown.Show("NA")
    try {
        loop 3 {
            label.Text := "Record in " (4-A_Index)
            loop 20 {
                if !WinActive("ahk_exe RobloxPlayerBeta.exe") || FileExist(A_ScriptDir "\.task-output\demo_stop")
                    throw Error("Countdown cancelled: keep Roblox focused and close chat")
                Sleep(50)
            }
        }
    } finally {
        countdown.Destroy()
    }
    allow := ["w","a","s","d"]
    if (IniRead(request,"Demo","interactions","0") = "1")
        allow.Push("m","e")
    for key in allow {
        if GetKeyState(key,"P")
            throw Error("Release movement/interaction keys before Start")
    }
    demoCapture := {active:true,started:A_TickCount,edges:[],legs:[],held:Map(),
        segmentKeys:[],segmentTick:A_TickCount,allow:allow,request:request,reason:"",hook:""}
    demoCapture.hook := InputHook("V L0")
    demoCapture.hook.MinSendLevel := 1
    demoCapture.hook.KeyOpt("{All}","N")
    demoCapture.hook.OnKeyDown := RouteDemoDown
    demoCapture.hook.OnKeyUp := RouteDemoUp
    demoCapture.hook.Start()
    for button in ["LButton","RButton","MButton"]
        Hotkey("~*" button, (*) => StopRouteDemo("mouse_or_text_ui"), "On")
    try FileDelete(A_ScriptDir "\.task-output\demo_stop")
    RouteDemoStatus(true,"Recording W/A/S/D only unless M/E was opted in; chat/text/mouse activity stops capture")
    NavProgress("RECORDING: your physical demonstration, max 120 seconds. Stop rec, F12 or Escape ends it.")
    while demoCapture.active {
        if !WinActive("ahk_exe RobloxPlayerBeta.exe")
            StopRouteDemo("focus_loss")
        else if (A_TickCount-demoCapture.started >= 120000)
            StopRouteDemo("timeout")
        else if FileExist(A_ScriptDir "\.task-output\demo_stop")
            StopRouteDemo(Trim(FileRead(A_ScriptDir "\.task-output\demo_stop")))
        Sleep(15)
    }
}

RouteDemoAllowed(key) {
    global demoCapture
    for allowed in demoCapture.allow {
        if (key = allowed)
            return true
    }
    return false
}

RouteDemoDown(hook, vk, sc) {
    global demoCapture
    if !demoCapture.active
        return
    if !WinActive("ahk_exe RobloxPlayerBeta.exe") {
        StopRouteDemo("focus_loss")
        return
    }
    key := StrLower(GetKeyName("vk" Format("{:X}",vk)))
    if key = "f12" {
        StopRouteDemo("manual_stop")
        return
    }
    ; No excluded key value or text is ever stored.
    if !RouteDemoAllowed(key) {
        StopRouteDemo("excluded_key_or_text_entry")
        return
    }
    if !GetKeyState(key,"P") || demoCapture.held.Has(key)
        return
    RouteDemoFlushLeg()
    demoCapture.held[key] := true
    demoCapture.edges.Push({t:A_TickCount-demoCapture.started,key:key,state:"down"})
}

RouteDemoUp(hook, vk, sc) {
    global demoCapture
    if !demoCapture.active
        return
    if !WinActive("ahk_exe RobloxPlayerBeta.exe") {
        StopRouteDemo("focus_loss")
        return
    }
    key := StrLower(GetKeyName("vk" Format("{:X}",vk)))
    if !RouteDemoAllowed(key) || !demoCapture.held.Has(key)
        return
    RouteDemoFlushLeg()
    demoCapture.held.Delete(key)
    demoCapture.edges.Push({t:A_TickCount-demoCapture.started,key:key,state:"up"})
}

RouteDemoFlushLeg() {
    global demoCapture
    elapsed := A_TickCount-demoCapture.segmentTick
    keys := []
    for key in ["w","a","s","d"] {
        if demoCapture.held.Has(key)
            keys.Push(key)
    }
    if (elapsed > 0 && keys.Length)
        demoCapture.legs.Push({keys:keys,ms:elapsed})
    demoCapture.segmentTick := A_TickCount
}

RouteDemoStatus(active, reason, path := "") {
    global demoCapture
    file := A_ScriptDir "\.task-output\demo_status.json"
    try FileDelete(file)
    FileAppend('{"active":' (active ? "true" : "false") ',"reason":' RouteJson(reason) ',"path":' RouteJson(path) ',"duration_ms":' (IsSet(demoCapture) ? A_TickCount-demoCapture.started : 0) ',"completion":' RouteJson(reason = "manual_stop" ? "recording_complete_arrival_unverified" : "partial_arrival_unverified") '}',file,"UTF-8-RAW")
}

StopRouteDemo(reason := "manual_stop") {
    global demoCapture
    if !IsSet(demoCapture) || !demoCapture.active
        return
    demoCapture.active := false
    RouteDemoFlushLeg()
    for key,_ in demoCapture.held
        demoCapture.edges.Push({t:A_TickCount-demoCapture.started,key:key,state:"up_forced_cleanup"})
    demoCapture.hook.Stop()
    for button in ["LButton","RButton","MButton"]
        Hotkey("~*" button,"Off")
    ReleaseMoveKeys()
    DirCreate(A_ScriptDir "\routes\demonstrations")
    path := A_ScriptDir "\routes\demonstrations\demo-" A_Now "-" A_TickCount ".ini"
    for field in ["map","subarea","start_landmark","destination","arrival_indicator"]
        IniWrite(IniRead(demoCapture.request,"Demo",field,"unconfirmed"),path,"Meta",field)
    IniWrite(reason,path,"Meta","stop_reason")
    IniWrite("demonstrated_destination_unverified",path,"Meta","evidence")
    IniWrite(SerializeLegs(demoCapture.legs),path,"Route","legs")
    for idx,edge in demoCapture.edges
        IniWrite(edge.t "," edge.key "," edge.state,path,"Edges",idx)
    IniWrite(A_TickCount-demoCapture.started,path,"Meta","duration_ms")
    IniWrite(reason = "manual_stop" ? "recording_complete_arrival_unverified" : "partial_arrival_unverified",path,"Meta","completion")
    RouteDemoStatus(false,reason,path)
    NavProgress("Recorder stopped: " reason ". Segment saved locally; destination remains unverified.")
    RouteResult("record","saved",path)
}

ReplayRouteDemo(path) {
    global running
    if !InStr(path, A_ScriptDir "\routes\demonstrations\")
        throw Error("Replay must use a local route demonstration")
    expectedMap := IniRead(path,"Meta","map","")
    currentMap := ""
    OcrDetectCurrentMap(&currentMap)
    if expectedMap = "" || StrLower(expectedMap) != StrLower(currentMap)
        throw Error("Starting map unconfirmed. Confirm the saved map and landmark before replay")
    if MsgBox("Approximate route from " IniRead(path,"Meta","start_landmark","unknown")
        " to " IniRead(path,"Meta","destination","unknown") ". Confirm you are at this landmark and start replay?", "Manual route replay", "YesNo") != "Yes"
        return
    if !OcrFocusRoblox()
        throw Error("Roblox unavailable")
    edges := IniRead(path,"Edges",,"")
    if InStr(edges,",m,") || InStr(edges,",e,")
        throw Error("Interaction edges require a separately verified UI action; this replay is movement-only")
    legs := DeserializeLegs(IniRead(path,"Route","legs",""))
    ; Recorded idle gaps are part of the timing and must not disappear on replay.
    if (edges != "") {
        parsed := []
        for line in StrSplit(edges,"`n","`r") {
            eq := InStr(line,"=")
            if !eq
                continue
            values := StrSplit(SubStr(line,eq+1),",")
            if (values.Length != 3 || !IsInteger(values[1]) || !InStr("wasd",values[2]) || StrLen(values[2]) != 1)
                throw Error("Invalid recorded edge")
            parsed.Push({t:Integer(values[1]),key:values[2],state:values[3]})
        }
        held := Map(), legs := [], previous := 0
        for edge in parsed {
            if (edge.t < previous || edge.t > 120000)
                throw Error("Invalid recorded timing")
            keys := []
            for key,_ in held
                keys.Push(key)
            if (edge.t > previous)
                legs.Push({keys:keys,ms:edge.t-previous})
            if (edge.state = "down")
                held[edge.key] := true
            else if (edge.state = "up" || edge.state = "up_forced_cleanup") {
                if held.Has(edge.key)
                    held.Delete(edge.key)
            } else
                throw Error("Invalid recorded state")
            previous := edge.t
        }
    }
    total := GetRouteTotalMs(legs)
    if (total > 120000)
        throw Error("Demonstration exceeds replay bound")
    for leg in legs {
        if (leg.ms <= 0 || leg.ms > 120000)
            throw Error("Invalid replay duration")
        for key in leg.keys {
            if !InStr("wasd",key) || StrLen(key) != 1
                throw Error("Replay allowlist violation")
        }
        if !WinActive("ahk_exe RobloxPlayerBeta.exe") || !running
            throw Error("Replay paused after focus loss or cancellation; confirm the starting context again")
        if leg.keys.Length
            HoldKeys(leg.keys,leg.ms)
        else {
            deadlineTick := A_TickCount+leg.ms
            while A_TickCount < deadlineTick {
                if !WinActive("ahk_exe RobloxPlayerBeta.exe") || !running
                    throw Error("Replay paused during recorded idle interval")
                Sleep(Min(20,Max(1,deadlineTick-A_TickCount)))
            }
        }
        if !WinActive("ahk_exe RobloxPlayerBeta.exe") || !running
            throw Error("Replay paused; confirm position before continuing")
    }
    ReleaseMoveKeys()
    indicator := IniRead(path,"Meta","arrival_indicator","")
    if !RegExMatch(indicator,"^[A-Za-z][A-Za-z0-9_-]{0,63}$")
        throw Error("Arrival unconfirmed: attach a named arrival indicator and demonstrate this route again")
    ; A visible waystone is an approach target, not proof that this route arrived.
    confirmation := OcrTestIndicator(indicator = "waystone" ? "waystone_prompt" : indicator)
    if !confirmation.Has("found") || confirmation["found"] != "1" {
        NavProgress("PAUSED: Arrival unconfirmed. Check waystone / World Map center manually, or record a new route.")
        throw Error("Arrival indicator not found; keys released. Confirm context or provide a new recording")
    }
    RouteResult("replay","arrival_confirmed",indicator)
}
