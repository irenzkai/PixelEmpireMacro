#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode("Event")
CoordMode("Pixel", "Screen")

; --- CORE MODULES ---
#Include "src\State.ahk"
#Include "src\Config.ahk"
#Include "src\VisionWindow.ahk"
#Include "src\Movement.ahk"

; --- FARMING MODES ---
#Include "src\modes\ModeControl.ahk"
#Include "src\modes\WaystoneMode.ahk"
#Include "src\modes\TowerMode.ahk"
#Include "src\modes\PerimeterCircle.ahk"
#Include "src\modes\ChaosTest.ahk"

; --- HOTKEYS & UI ---
#Include "src\Hotkeys.ahk"
#Include "src\GUI.ahk"

; --- INITIALIZATION ---
LoadConfig()
BuildGUI()
ApplyHotkeys()