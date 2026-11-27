; Local overlay bootstrap; never starts a macro mode or sends game input.
RestoreAgentOverlay(*) => AgentOverlayCommand("show")
ToggleAgentOverlay(*) => AgentOverlayCommand("toggle")
HideAgentOverlay(*) => AgentOverlayCommand("hide")
OpenReferenceSetup(*) {
    StopAll("Manual reference setup")
    AgentOverlayCommand("setup")
}
StartAgentRecording(*) {
    StopAll("Manual recording requested")
    ReleaseMoveKeys()
    AgentOverlayCommand("record")
}
OverlayRequest(action) {
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    req.SetProxy(1)
    req.SetTimeouts(150, 150, 300, 1800)
    req.Open(action = "health" ? "GET" : "POST", "http://127.0.0.1:8767/" action, false)
    req.Send()
    if req.Status != 200
        throw Error("Overlay HTTP " req.Status ": " SubStr(req.ResponseText,1,180))
    if action = "health" && !InStr(req.ResponseText,"PixelEmpireOverlay/2")
        throw Error("Port 8767 belongs to an older helper; restart ahk_agent.py")
    return true
}
AgentOverlayCommand(action) {
    global overlayPendingAction, overlayLaunchTick, overlayLaunchPid
    try {
        OverlayRequest("health")
        OverlayRequest(action)
        UpdateGuiStatus("Agent Overlay: " action)
        return
    }
    if action = "hide" {
        UpdateGuiStatus("Agent Overlay is not running")
        return
    }
    if IsSet(overlayLaunchTick) && A_TickCount-overlayLaunchTick < 12000 {
        overlayPendingAction := action
        return
    }
    python := A_ScriptDir "\.venv\Scripts\pythonw.exe"
    script := A_ScriptDir "\scripts\start_agent_overlay.py"
    if !FileExist(python) || !FileExist(script) {
        UpdateGuiStatus("Overlay cannot start: restore .venv Python and ahk_agent.py")
        return
    }
    try {
        try FileDelete(A_ScriptDir "\.task-output\agent_startup_error.txt")
        overlayPendingAction := action, overlayLaunchTick := A_TickCount
        Run('"' python '" "' script '"', A_ScriptDir, "Hide", &overlayLaunchPid)
        UpdateGuiStatus("Starting Agent Overlay; waiting for its window...")
        SetTimer(PollAgentOverlayStartup,200)
    } catch as err {
        overlayLaunchTick := 0
        UpdateGuiStatus("Overlay launch failed: " err.Message)
    }
}
PollAgentOverlayStartup() {
    global overlayPendingAction, overlayLaunchTick, overlayLaunchPid
    try {
        OverlayRequest("health")
        OverlayRequest(overlayPendingAction)
        SetTimer(PollAgentOverlayStartup,0)
        overlayLaunchTick := 0
        UpdateGuiStatus("Agent Overlay ready; automation stopped")
        return
    }
    errorPath := A_ScriptDir "\.task-output\agent_startup_error.txt"
    if FileExist(errorPath) {
        SetTimer(PollAgentOverlayStartup,0)
        overlayLaunchTick := 0
        UpdateGuiStatus("Overlay startup failed. Double-click this status for the error log.")
    } else if A_TickCount-overlayLaunchTick > 12000 {
        SetTimer(PollAgentOverlayStartup,0)
        overlayLaunchTick := 0
        UpdateGuiStatus("Overlay startup timed out. Check .venv/Tk and port 8767; see .task-output/agent_startup_error.txt")
    }
}

OpenAgentStartupLog(*) {
    path := A_ScriptDir "\.task-output\agent_startup_error.txt"
    if FileExist(path)
        Run('notepad.exe "' path '"')
    else
        UpdateGuiStatus("No overlay startup error recorded")
}
