; ==============================================================================
; GLOBAL STATE, PRESETS, SETTINGS & HOTKEY DEFINITIONS
; ==============================================================================

running := false
circleRequested := false
chaosTestRunning := false
freeCircleMode := false
mapCycleMode := false
shortestPathRunning := false
manualRecordRunning := false
wideStarMode := false
isUpdatingUI := false
isBindingHotkey := false
overlayVisible := false

step := 0
completedLoops := 0
recoveryCount := 0

; --- MAP CYCLE, SHORTEST PATH & BOSS HUNT STATE ---
currentWaystoneIdx := 0
maxWaystoneIdx     := 30
cycleDir           := 1
bossesHunted       := 0
cycleSearchMatches := []
cycleSearchCursor  := 0

shortestRoutes      := Map()
shortestRoutesIni   := A_ScriptDir "\shortest_routes.ini"
shortestRoutesLog   := A_ScriptDir "\shortest_routes_log.txt"
shortestTaskQueue   := []
manualRecFromIdx    := 0
manualRecCrossedIdx := -1
manualRecLegs       := []

iniFile := A_ScriptDir "\waystone_config.ini"
defaultWaystoneImg := A_ScriptDir "\public\waystone_prompt.png"
legacyWardImg := FileExist(A_ScriptDir "\public\ward_prompt.png") ? A_ScriptDir "\public\ward_prompt.png" : A_ScriptDir "\ward_prompt.png"
promptImg := FileExist(defaultWaystoneImg) ? defaultWaystoneImg : legacyWardImg

recoveryImg          := A_ScriptDir "\public\waystone.png"
recoveryOffImg       := A_ScriptDir "\public\waystone_off.png"
recoveryTolerance    := 50
recoverySearchPrefix := ""
recoveryOffPrefix    := ""
lastMatchedStatueImg := ""

; --- UPPER-CENTER BOSS & MINIBOSS BANNER IMAGES ---
bossComingImg        := A_ScriptDir "\public\boss_coming.png"
bossSpawnImg         := A_ScriptDir "\public\boss_spawn.png"
bossAlreadyInImg     := A_ScriptDir "\public\boss_already_in.png"
bossDefeatedImg      := A_ScriptDir "\public\boss_defeated.png"

minibossComingImg    := A_ScriptDir "\public\miniboss_coming.png"
minibossSpawnImg     := A_ScriptDir "\public\miniboss_spawn.png"
minibossAlreadyInImg := A_ScriptDir "\public\miniboss_already_in.png"
minibossDefeatedImg  := A_ScriptDir "\public\miniboss_defeated.png"

youDefeatedBossImg   := A_ScriptDir "\public\you_defeated_boss_confirmation.png"

bossBannerTol   := 65
bossMaskedCache := Map()

; --- MAP TOP LABEL, AREA & PORTAL VISION ---
topLabelTol         := 65
topLabelPrefixes    := Map()
topLabelMaskedCache := Map()
mapAreaPrefixes     := Map()
mapAreaStripCache   := Map()
textSigCache        := Map()
portalTol           := 60
portalPrefixes      := Map()
portalStripCache    := Map()

; --- CAPTURE STUDIO STATE ---
captureCategoryIdx  := 1
captureItemIdx      := 1
captureOneGo        := true
captureBarVisible   := false

; --- TOWER AUTOMATION TUNING & IMAGES ---
towerCenterMs   := 500
towerRadiusMs   := 500
towerPortalMs   := 1000

towerBase       := {center: 500, radius: 500, portal: 1000}
towerRangePct   := 100

inTowerImg      := A_ScriptDir "\public\in_tower.png"
towerClearedImg := A_ScriptDir "\public\floor_cleared.png"
towerNextImg    := A_ScriptDir "\public\next_floor_indicator.png"
inTowerPrefix      := ""
towerClearedPrefix := ""
towerNextPrefix    := ""
towerMaskedCache   := Map()
towerImgTol     := 50
floorsCleared   := 0
towerPhase      := "Ready"
towerPosX       := 0.0
towerPosY       := 0.0

; --- WORLD MAP (M) RECOVERY ---
mapOpenImg          := A_ScriptDir "\public\map_open.png"
mapArrowImg         := A_ScriptDir "\public\map_arrow.png"
mapWaystoneImg      := A_ScriptDir "\public\map_waystone.png"
mapWaystoneOffImg   := A_ScriptDir "\public\map_waystone_off.png"
mapTolerance        := 55
mapMsPerPx          := 42
useWorldMapRecovery := true
mapOpenPrefix       := ""
mapArrowPrefix      := ""
mapWayPrefix        := ""
mapWayOffPrefix     := ""
isScanningMap       := false
lastMapScanTick     := 0

; --- APPEARANCE & UI SETTINGS ---
darkMode := true
hudEnabled := true
activeTab := "WAYSTONE"
wayCardView := "SPRITES"
overlayCustomPos := false
overlayX := -1
overlayY := -1

; --- HOTKEY SWITCH CONFIGURATION ---
hotkeysEnabled := true
hotkeys := {
    waystone: "F8",
    tower:    "F5",
    mapCycle: "F4",
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

; --- F7 CHAOS STRESS TEST TUNING + RATIO RANGE % ---
chaosCfg  := {angle: 1750, zigDiag: 450, zigSide: 500}
chaosBase := {angle: 1750, zigDiag: 450, zigSide: 500}
chaosPct  := 100

searchBox       := {x1: 0, y1: 0, x2: 0, y2: 0}
robloxWinBox    := {x1: 0, y1: 0, x2: 0, y2: 0}
statueSearchBox := {x1: 0, y1: 0, x2: 0, y2: 0}
mapBox          := {x1: 0, y1: 0, x2: 0, y2: 0}
topLabelBox     := {x1: 0, y1: 0, x2: 0, y2: 0}
hudStatus := "Ready"

; --- MARKED WAYSTONE ORIGIN DISPLACEMENT ---
wayPosX := 0.0
wayPosY := 0.0
wayOriginMarked := false