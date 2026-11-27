#Requires AutoHotkey v2.0
#Include "PixelEmpireMacro.ahk"
#Include "src\RouteRecorder.ahk"
SetWorkingDir(A_ScriptDir)
OnExit(RouteActionCleanup)
Hotkey("Esc", (*) => RouteActionCancel("escape"))
Hotkey("F12", (*) => RouteActionCancel("manual_stop"))
running := true
RouteActionMain(A_Args)
ExitApp()
