; ==============================================================================
; CHARACTER MOVEMENT, HOMING, RECOVERY & ALT ANTI-AFK
; ==============================================================================

HoldKeys(keys, duration) {
    for k in keys
        SendEvent("{" k " down}")
    Sleep(duration)
    ReleaseMoveKeys()
}

ReleaseMoveKeys() {
    for key in ["w", "a", "s", "d"] {
        SendEvent("{" key " up}")
    }
}

GetOppositeKeys(keys) {
    opp := []
    for k in keys {
        if (k = "w")
            opp.Push("s")
        else if (k = "s")
            opp.Push("w")
        else if (k = "a")
            opp.Push("d")
        else if (k = "d")
            opp.Push("a")
    }
    return opp
}

ReturnUntilPrompt(keys, limitMs) {
    global running, microStepMs
    elapsed := 0

    for k in keys
        SendEvent("{" k " down}")

    while (running && elapsed < limitMs) {
        Sleep(microStepMs)
        elapsed += microStepMs

        if (elapsed >= 350 && IsOnWaystone()) {
            ReleaseMoveKeys()
            return true
        }
    }

    ReleaseMoveKeys()
    return IsOnWaystone()
}

AntiTrapRecovery() {
    global running, recoveryCount, hudStatus
    recoveryCount += 1

    hudStatus := "Recovery #" recoveryCount ": Local Spiral..."
    localSpiral := [
        {keys: ["w"], dur: 240},
        {keys: ["d"], dur: 240},
        {keys: ["s"], dur: 480},
        {keys: ["a"], dur: 480},
        {keys: ["w"], dur: 720},
        {keys: ["d"], dur: 720}
    ]
    if (RunSearchSequence(localSpiral))
        return

    hudStatus := "Recovery #" recoveryCount ": Fence/Tree Escape!"
    escapeMoves := [
        {keys: ["s", "a"], dur: 1100},
        {keys: ["s"],      dur: 1100},
        {keys: ["s", "d"], dur: 900},
        {keys: ["w", "d"], dur: 700},
        {keys: ["w", "a"], dur: 700}
    ]
    if (RunSearchSequence(escapeMoves))
        return

    hudStatus := "Recovery #" recoveryCount ": Wide Homing Sweep..."
    wideSweep := [
        {keys: ["s"], dur: 1400},
        {keys: ["a"], dur: 1400},
        {keys: ["w"], dur: 1800},
        {keys: ["d"], dur: 1800}
    ]
    RunSearchSequence(wideSweep)
}

RunSearchSequence(moveList) {
    global running, hudStatus
    for move in moveList {
        if (!running)
            return true

        moved := 0
        for k in move.keys
            SendEvent("{" k " down}")

        while (running && moved < move.dur) {
            Sleep(70)
            moved += 70
            if (IsOnWaystone()) {
                ReleaseMoveKeys()
                hudStatus := "Recovered Point 0!"
                return true
            }
        }
        ReleaseMoveKeys()
    }
    return false
}

AltAntiAFK() {
    global running
    if (!running)
        return

    windows := GetSortedRobloxWindows()
    if (windows.Length <= 1)
        return

    mainHwnd := windows[1]
    Loop windows.Length - 1 {
        altHwnd := windows[A_Index + 1]
        if WinExist("ahk_id " altHwnd) {
            WinActivate("ahk_id " altHwnd)
            Sleep(60)
            SendEvent("{Space down}")
            Sleep(60)
            SendEvent("{Space up}")
            Sleep(40)
        }
    }
    if WinExist("ahk_id " mainHwnd) {
        WinActivate("ahk_id " mainHwnd)
    }
}