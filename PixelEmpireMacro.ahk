#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode("Event")
CoordMode("Pixel", "Screen")

; --- MODULE IMPORTS ---
#Include "src\State.ahk"
#Include "src\Config.ahk"
#Include "src\VisionWindow.ahk"
#Include "src\Movement.ahk"
#Include "src\Modes.ahk"
#Include "src\Hotkeys.ahk"
#Include "src\GUI.ahk"

; --- INITIALIZATION ---
LoadConfig()
BuildGUI()
ApplyHotkeys()