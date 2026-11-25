; ==============================================================================
; REUSABLE BLACK & WHITE GUI COMPONENT BUILDERS
; ==============================================================================

AddRectBorder(x, y, w, h, tabName := "") {
    global mainGui, pageControls
    top := mainGui.AddText("x" x " y" y " w" w " h1 Disabled +0x04000000", "")
    bot := mainGui.AddText("x" x " y" (y + h - 1) " w" w " h1 Disabled +0x04000000", "")
    lft := mainGui.AddText("x" x " y" (y + 1) " w1 h" (h - 2) " Disabled +0x04000000", "")
    rgt := mainGui.AddText("x" (x + w - 1) " y" (y + 1) " w1 h" (h - 2) " Disabled +0x04000000", "")
    edges := [top, bot, lft, rgt]
    if (tabName != "" && pageControls.Has(tabName)) {
        for e in edges
            pageControls[tabName].Push(e)
    }
    return edges
}

AddCard(tabName, x, y, w, h) {
    global mainGui, pageControls, themeCards
    edges := AddRectBorder(x, y, w, h, tabName)
    fill  := mainGui.AddText("x" (x + 1) " y" (y + 1) " w" (w - 2) " h" (h - 2) " Disabled +0x04000000", "")
    themeCards.Push({edges: edges, fill: fill})
    if (tabName != "" && pageControls.Has(tabName))
        pageControls[tabName].Push(fill)
}

AddDivider(x, y, w) {
    global mainGui, themeDividers
    line := mainGui.AddText("x" x " y" y " w" w " h1 Disabled +0x04000000", "")
    themeDividers.Push(line)
    return line
}

AddCardTitle(tabName, x, y, w, text) {
    global mainGui, pageControls, themeMutedText
    ctrl := mainGui.AddText("x" x " y" y " w" w " h16 +0x80 +0x04000000", text)
    ctrl.SetFont("s8 Bold", "Segoe UI")
    themeMutedText.Push({ctrl: ctrl, onCard: true})
    if (tabName != "" && pageControls.Has(tabName))
        pageControls[tabName].Push(ctrl)
    return ctrl
}

AddPrimaryLabel(tabName, x, y, w, text, fontSize := 9, isBold := false) {
    global mainGui, pageControls, themePrimaryText
    ctrl := mainGui.AddText("x" x " y" y " w" w " h22 +0x80 +0x04000000", text)
    ctrl.SetFont("s" fontSize (isBold ? " Bold" : ""), "Segoe UI")
    themePrimaryText.Push({ctrl: ctrl, onCard: true})
    if (tabName != "" && pageControls.Has(tabName))
        pageControls[tabName].Push(ctrl)
    return ctrl
}

AddMutedLabel(tabName, x, y, w, text, alignOpt := "") {
    global mainGui, pageControls, themeMutedText
    ctrl := mainGui.AddText("x" x " y" y " w" w " h18 " alignOpt " +0x80 +0x04000000", text)
    ctrl.SetFont("s8", "Segoe UI")
    themeMutedText.Push({ctrl: ctrl, onCard: true})
    if (tabName != "" && pageControls.Has(tabName))
        pageControls[tabName].Push(ctrl)
    return ctrl
}

AddSubMutedLabel(tabName, subKey, x, y, w, text, alignOpt := "") {
    global wayCardSubControls
    ctrl := AddMutedLabel(tabName, x, y, w, text, alignOpt)
    wayCardSubControls[subKey].Push(ctrl)
    return ctrl
}

AddStyledEdit(tabName, x, y, w, h, defaultVal, extraOpts := "") {
    global mainGui, pageControls, themeEdits
    ctrl := mainGui.AddEdit("x" x " y" y " w" w " h" h " " extraOpts, defaultVal)
    ctrl.SetFont("s9", "Segoe UI")
    themeEdits.Push(ctrl)
    if (tabName != "" && pageControls.Has(tabName))
        pageControls[tabName].Push(ctrl)
    return ctrl
}

AddSubStyledEdit(tabName, subKey, x, y, w, h, defaultVal, extraOpts := "") {
    global wayCardSubControls
    ctrl := AddStyledEdit(tabName, x, y, w, h, defaultVal, extraOpts)
    wayCardSubControls[subKey].Push(ctrl)
    return ctrl
}

AddFlatButton(x, y, w, h, text, isPrimary, callback, tabName := "") {
    global mainGui, pageControls, clickableHwnds, themePrimaryBtns, themeSecondaryBtns

    edges := AddRectBorder(x, y, w, h, tabName)
    btn   := mainGui.AddText("x" (x + 1) " y" (y + 1) " w" (w - 2) " h" (h - 2) " Center 0x200 +0x80 +0x04000000", text)
    btn.SetFont("s8 Bold", "Segoe UI")
    btn.OnEvent("Click", callback)
    clickableHwnds[btn.Hwnd] := true

    entry := {edges: edges, btn: btn}
    if (isPrimary)
        themePrimaryBtns.Push(entry)
    else
        themeSecondaryBtns.Push(entry)

    if (tabName != "" && pageControls.Has(tabName))
        pageControls[tabName].Push(btn)
    return entry
}

AddSubFlatButton(tabName, subKey, x, y, w, h, text, isPrimary, callback) {
    global wayCardSubControls
    entry := AddFlatButton(x, y, w, h, text, isPrimary, callback, tabName)
    for e in entry.edges
        wayCardSubControls[subKey].Push(e)
    wayCardSubControls[subKey].Push(entry.btn)
    return entry
}

AddTabButton(tabKey, x, y, w, h, label) {
    global mainGui, clickableHwnds, themeTabs
    edges := AddRectBorder(x, y, w, h)
    btn   := mainGui.AddText("x" (x + 1) " y" (y + 1) " w" (w - 2) " h" (h - 2) " Center 0x200 +0x80 +0x04000000", label)
    btn.SetFont("s8 Bold", "Segoe UI")
    btn.OnEvent("Click", (*) => SwitchTab(tabKey))
    clickableHwnds[btn.Hwnd] := true
    entry := {edges: edges, btn: btn}
    themeTabs[tabKey] := entry
    return entry
}

AddHotkeyRow(actionKey, label, y) {
    global mainGui, pageControls, themeSecondaryBtns, hkBadges

    AddPrimaryLabel("SETTINGS", 36, y + 2, 240, label)

    edges := AddRectBorder(290, y, 102, 22, "SETTINGS")
    badge := mainGui.AddText("x291 y" (y + 1) " w100 h20 Center 0x200 +0x80 +0x04000000", "")
    badge.SetFont("s8 Bold", "Segoe UI")
    themeSecondaryBtns.Push({edges: edges, btn: badge})
    pageControls["SETTINGS"].Push(badge)
    hkBadges[actionKey] := badge

    AddFlatButton(400, y, 104, 22, "Change", false, (*) => RebindHotkey(actionKey), "SETTINGS")
}