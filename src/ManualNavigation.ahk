; Explicit user-started directed travel. All movement remains inside AHK.
InitManualSetup() {
    OnMessage(0x8004, DefineSetupRegionMessage)
    OnMessage(0x8007, StartConfiguredTravelMessage)
    OnMessage(0x8009, ReloadReferenceSettingsMessage)
    Hotkey("F12", StopUserTravel, "On")
}
DefineSetupRegionMessage(code, *) {
    names := Map(1,"map_name",2,"boss_banner",3,"in_tower",4,"tower_progress",5,"floor_cleared")
    if !names.Has(code)
        return 0
    SetTimer((*) => BeginAssetSelection("indicator",names[code]),-1)
    return 1
}
ReloadReferenceSettingsMessage(*) {
    SetTimer(ApplyManualReferenceSettings,-1)
    return 1
}
ApplyManualReferenceSettings(*) {
    StopAll("Reference settings updated")
    LoadConfig()
    ApplyHotkeys()
    Hotkey("F12", StopUserTravel, "On")
    RefreshImageStatus()
}
StartConfiguredTravelMessage(source, destination, *) {
    global waystoneRoutes
    if !waystoneRoutes.Has(source) || !waystoneRoutes.Has(destination) || source=destination
        return 0
    SetTimer((*) => StartConfiguredTravel(source,destination),-1)
    return 1
}
StopUserTravel(*) {
    StopAll("F12: manual travel/recording stopped")
    DirCreate(A_ScriptDir "\.task-output")
    file := FileOpen(A_ScriptDir "\.task-output\demo_stop","w","UTF-8-RAW")
    file.Write("manual_stop"), file.Close()
}
HasConfiguredConnection(source,destination) {
    return IniRead(A_ScriptDir "\config\manual_navigation.ini","Connection_" source "_" destination,"direction","")!=""
}
StartConfiguredTravel(source,destination) {
    global running
    StopAll("Preparing manually requested travel")
    if !InitVisionAndWindow(false) {
        UpdateGuiStatus("Travel unavailable: Roblox/OCR not ready")
        return
    }
    running := true
    SetTimer(ManualTravelTimeout,-45000)
    try {
        success := ExecuteConfiguredConnection(source,destination)
        NavProgress(success ? "Destination WS" destination " confirmed" : "PAUSED: portal/destination unconfirmed; supply a clearer crop or a new route")
    } catch as err {
        NavProgress("PAUSED: " err.Message)
    } finally {
        SetTimer(ManualTravelTimeout,0)
        ReleaseMoveKeys()
        StopAll("Manual travel finished; check overlay result")
    }
}
ExecuteConfiguredConnection(source,destination) {
    global running, useWorldMapRecovery
    path := A_ScriptDir "\config\manual_navigation.ini", section := "Connection_" source "_" destination
    direction := IniRead(path,section,"direction","")
    keys := Map("Up","w","Down","s","Left","a","Right","d")
    if !keys.Has(direction)
        throw Error("Save a directed connection and assigned portal first")
    if !WinActive("ahk_exe RobloxPlayerBeta.exe") || !IsMapTopLabel(source) || !IsOnWaystone()
        throw Error("Start at a confirmed waystone in WS" source "; current map/prompt not confirmed")
    budget := Max(250,Min(30000,Integer(IniRead(path,section,"travel_ms","10000"))))
    deadline := A_TickCount+budget
    NavProgress("Manual connection WS" source " -> WS" destination " / " direction " / F12 stops")
    try {
        while running && A_TickCount < deadline {
            if !WinActive("ahk_exe RobloxPlayerBeta.exe")
                throw Error("Focus lost; travel paused")
            if IsMapTopLabel(destination)
                return true
            if FindPortalSprite(source,destination) {
                result := PathToPortalSprite(source,destination,"",Min(12000,Max(250,deadline-A_TickCount)))
                if result="TARGET_MAP"
                    return true
                NavProgress("Portal approach unconfirmed: " result)
                break
            }
            HoldKeys([keys[direction]],Min(250,Max(1,deadline-A_TickCount)))
        }
        if running && WinActive("ahk_exe RobloxPlayerBeta.exe") && IsMapTopLabel(destination)
            return true
        if running && WinActive("ahk_exe RobloxPlayerBeta.exe") && useWorldMapRecovery && IniRead(path,section,"recovery","0")="1" {
            NavProgress("Portal not confirmed; using explicitly configured recovery toward waystone center")
            AntiTrapRecovery([],source)
        }
        StopAll("Directed connection unconfirmed; replace portal crop or record a route")
        return false
    } finally {
        ReleaseMoveKeys()
    }
}
OcrFindConfiguredPortal(source,destination,&px := 0,&py := 0) {
    global portalPlayerX,portalPlayerY
    kv := OcrHttpGetKV("/configured_portal?source=" source "&destination=" destination,4000)
    if kv.Has("found") && kv["found"]="1" && kv.Has("x") && kv.Has("y") {
        px := Integer(kv["x"]), py := Integer(kv["y"])
        portalPlayerX := kv.Has("player_x") ? Integer(kv["player_x"]) : 0
        portalPlayerY := kv.Has("player_y") ? Integer(kv["player_y"]) : 0
        return true
    }
    return false
}

ManualTravelTimeout(*) {
    StopAll("Manual travel time limit reached")
}
