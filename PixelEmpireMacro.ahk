#Requires AutoHotkey v2.0
#SingleInstance Force
InstallKeybdHook()
SendMode("Event")
CoordMode("Pixel", "Screen")
CoordMode("Mouse", "Screen")

; --- CORE MODULES ---
#Include "src\State.ahk"
#Include "src\MapRoutes.ahk"
#Include "src\Config.ahk"
#Include "src\VisionWindow.ahk"
#Include "src\FastMapScan.ahk"
#Include "src\Movement.ahk"
#Include "src\ManualNavigation.ahk"

; --- FARMING MODES ---
#Include "src\modes\ModeControl.ahk"
#Include "src\modes\WaystoneMode.ahk"
#Include "src\modes\TowerMode.ahk"
#Include "src\modes\PerimeterCircle.ahk"
#Include "src\modes\ChaosTest.ahk"
#Include "src\modes\MapCycleMode.ahk"
#Include "src\modes\ShortestPathMode.ahk"

; --- HOTKEYS & GUI ---
#Include "src\Hotkeys.ahk"
#Include "src\gui\AgentControls.ahk"
#Include "src\gui\Theme.ahk"
#Include "src\gui\Components.ahk"
#Include "src\gui\OverlayHUD.ahk"
#Include "src\gui\CaptureTool.ahk"
#Include "src\gui\Actions.ahk"
#Include "src\gui\SpaciousLayout.ahk"
#Include "src\gui\MainWindow.ahk"
#Include "src\gui\ImageReview.ahk"
#Include "src\gui\AssetPicker.ahk"

; --- INITIALIZATION ---
if (A_LineFile = A_ScriptFullPath) {
    LoadConfig()
    InitFastMapScan()
    LoadShortestRoutes()
    BuildGUI()
    ApplyHotkeys()
    InitAssetPicker()
    InitManualSetup()
    IniWrite(f8Build, A_ScriptDir "\.task-output\macro_window.ini", "Runtime", "build")
    IniWrite("stopped", A_ScriptDir "\.task-output\macro_window.ini", "Runtime", "startup_state")
    OnExit((*) => ReleaseMoveKeys())
    StopAll("Ready; automation stopped")
    SetTimer(RestoreAgentOverlay, -500)
}
