#Requires AutoHotkey v2.0
#Include "src/OcrVision.ahk"

EnsureOcrServerRunning()

mapName := ""
OcrDetectCurrentMap(&mapName)
FileAppend("Map=" mapName "`n", "*")

inTower := OcrIsInTower()
FileAppend("InTower=" inTower "`n", "*")

floorCleared := OcrIsFloorCleared()
FileAppend("FloorCleared=" floorCleared "`n", "*")

onWaystone := OcrIsOnWaystone()
FileAppend("OnWaystone=" onWaystone "`n", "*")

bossRaw := ""
OcrGetBossState(&bossRaw)
FileAppend("BossRaw=" bossRaw "`n", "*")
ExitApp()
