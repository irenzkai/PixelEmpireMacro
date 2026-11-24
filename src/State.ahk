; ==============================================================================
; GLOBAL STATE, PRESETS, SETTINGS & HOTKEY DEFINITIONS
; ==============================================================================

running := false
circleRequested := false
chaosTestRunning := false
freeCircleMode := false
wideStarMode := false
isUpdatingUI := false
isBindingHotkey := false
overlayVisible := false

step := 0
completedLoops := 0
recoveryCount := 0

iniFile := A_ScriptDir "\waystone_config.ini"
defaultWaystoneImg := A_ScriptDir "\waystone_prompt.png"
legacyWardImg := A_ScriptDir "\ward_prompt.png"
promptImg := FileExist(defaultWaystoneImg) ? defaultWaystoneImg : (FileExist(legacyWardImg) ? legacyWardImg : defaultWaystoneImg)

; --- APPEARANCE & UI SETTINGS ---
darkMode := true
hudEnabled := true
activeTab := "MACRO"
overlayCustomPos := false
overlayX := -1
overlayY := -1

; --- HOTKEY SWITCH CONFIGURATION ---
hotkeysEnabled := true
hotkeys := {
    waystone: "F8",
    tower:    "F5",
    preset:   "F6",
    circle:   "F9",
    chaos:    "F7",
    exit:     "Esc"
}
registeredHotkeys := []

; --- F6 / F8 WAYSTONE 8-STAR PRESETS (Short vs Very Wide + Ratio Range %) ---
shortCfg  := {up: 1050, down: 1300, left: 1300, right: 1300, diag: 1050, ret: 1850}
shortBase := {up: 1050, down: 1300, left: 1300, right: 1300, diag: 1050, ret: 1850}
shortPct  := 100

wideCfg  := {up: 1650, down: 1950, left: 1950, right: 1950, diag: 1650, ret: 2600}
wideBase := {up: 1650, down: 1950, left: 1950, right: 1950, diag: 1650, ret: 2600}
widePct  := 100

microStepMs  := 80
imgTolerance := 45

; --- F9 ONE-SHOT PERIMETER CIRCLE TUNING + RATIO RANGE % ---
circleCfg  := {out: 1350, edge: 800, card: 960, diag: 960, ret: 2600}
circleBase := {out: 1350, edge: 800, card: 960, diag: 960, ret: 2600}
circlePct  := 100

; --- F5 TOWER MODE (FREE RANGE MODE) TUNING + RATIO RANGE % ---
f5RingEdgeMs := 1150
f5UpMs       := 1750
f5DownMs     := 1750
f5LeftMs     := 1750
f5RightMs    := 1750
f5DiagMs     := 1750
f5Base       := {ring: 1150, up: 1750, down: 1750, left: 1750, right: 1750, diag: 1750}
f5Pct        := 100

; --- F7 CHAOS STRESS TEST TUNING + RATIO RANGE % ---
chaosCfg  := {angle: 1750, zigDiag: 450, zigSide: 500}
chaosBase := {angle: 1750, zigDiag: 450, zigSide: 500}
chaosPct  := 100

searchBox := {x1: 0, y1: 0, x2: 0, y2: 0}
hudStatus := "Ready"