; Presentation only. Existing control callbacks and runtime modes are preserved.
InitSpaciousMainWindow() {
    global mainGui, spaciousOriginal, spaciousExtra, spaciousViews, spaciousReady, spaciousBusy
    global spaciousX, spaciousY, spaciousWidth, spaciousHeight, themeTabs, btnThemeQuick, themePrimaryText, themeMutedText, spaciousPreviewCard
    spaciousOriginal := [], spaciousExtra := [], spaciousViews := []
    spaciousX := 0, spaciousY := 0, spaciousReady := false, spaciousBusy := false
    spaciousWidth := 1240, spaciousHeight := 952
    tabs := Map(), order := ["WAYSTONE","TOWER","CYCLE","F9F7","CAPTURE","SETTINGS","CREDITS"]
    for index, key in order {
        entry := themeTabs[key]
        tabs[entry.btn.Hwnd] := {index:index,part:0}
        for side, edge in entry.edges
            tabs[edge.Hwnd] := {index:index,part:side}
        entry.btn.Text := Map("WAYSTONE","Waystone","TOWER","Tower","CYCLE","Maps & routes","F9F7","Movement modes","CAPTURE","Capture","SETTINGS","Settings","CREDITS","About")[key]
    }
    for ctrl in mainGui {
        ctrl.GetPos(&x,&y,&w,&h)
        entry := {ctrl:ctrl,x:x,y:y,w:w,h:h,role:"body"}
        if tabs.Has(ctrl.Hwnd) {
            entry.role := "nav", entry.nav := tabs[ctrl.Hwnd]
        } else if y < 106 {
            entry.role := "header"
        } else if y = 106 {
            entry.role := "divider"
        }
        spaciousOriginal.Push(entry)
        if ctrl.Type = "Edit"
            ctrl.SetFont("s11", "Segoe UI")
        else if ctrl.Type = "Text" && ctrl.Text != "" {
            ctrl.SetFont("s11", "Segoe UI")
            if entry.role = "nav"
                ctrl.SetFont("s11 Bold", "Segoe UI")
            else if x = 20 && y = 14 {
                ctrl.Text := "Pixel Empire Macro"
                ctrl.SetFont("s21 Bold", "Segoe UI")
            } else if x = 20 && y = 38 {
                ctrl.Text := "Manual setup  /  Step 1 of 13: GUI review"
                ctrl.SetFont("s11", "Segoe UI")
            }
        }
    }
    SpaciousText(24,558,158,30,"GUI REVIEW",true)
    SpaciousText(24,594,158,112,"Check text, spacing, tabs, scrolling and previews. Reply in VS Code before we continue.")
    SpaciousText(24,730,158,80,"F10  Agent Overlay`nF12  Stop`n`nSaved-file previews only.")
    spaciousPreviewCard := AddCard("",912,118,304,718)
    SpaciousText(932,136,264,28,"REFERENCE PREVIEW",true,"right")
    SpaciousText(932,172,264,48,"Saved images for the selected section. No detection or game capture runs here.",false,"right")
    loop 2 {
        top := A_Index = 1 ? 232 : 528
        title := SpaciousText(932,top,264,44,"",true,"right")
        image := mainGui.AddPicture("x932 y" (top+52) " w264 h192", "")
        caption := SpaciousText(932,top+248,264,40,"",false,"right")
        spaciousViews.Push({title:title,image:image,caption:caption,top:top,path:"",stamp:"",iw:0,ih:0})
    }
    mainGui.OnEvent("Size", SpaciousMainSize)
    OnMessage(0x115, SpaciousMainScroll)
    OnMessage(0x114, SpaciousMainScroll)
    OnMessage(0x20A, SpaciousMainWheel)
    spaciousReady := true
    MonitorGetWorkArea(, &left,&top,&right,&bottom)
    dpi := A_ScreenDPI/96
    initialW := Min(1280,Max(800,Floor((right-left)/dpi)-80))
    initialH := Min(940,Max(520,Floor((bottom-top)/dpi)-100))
    mainGui.Show("w" initialW " h" initialH)
    SpaciousMainSize(mainGui,0,initialW,initialH)
    RefreshMainPreviews()
}
SpaciousText(x,y,w,h,text,bold := false,anchor := "left") {
    global mainGui,spaciousExtra,themePrimaryText,themeMutedText
    ctrl := mainGui.AddText("x" x " y" y " w" w " h" h " +0x04000000",text)
    ctrl.SetFont("s11" (bold ? " Bold" : ""),"Segoe UI")
    spaciousExtra.Push({ctrl:ctrl,x:x,y:y,w:w,h:h,anchor:anchor})
    if bold
        themePrimaryText.Push({ctrl:ctrl,onCard:anchor="right"})
    else
        themeMutedText.Push({ctrl:ctrl,onCard:anchor="right"})
    return ctrl
}
SpaciousMainSize(gui, minMax, *) {
    global mainGui,spaciousReady,spaciousBusy,spaciousOriginal,spaciousExtra,spaciousViews
    global spaciousWidth,spaciousHeight,spaciousX,spaciousY
    if !IsSet(spaciousReady) || !spaciousReady || spaciousBusy || minMax=-1 || gui.Hwnd!=mainGui.Hwnd
        return
    spaciousBusy := true
    try {
        dpi := A_ScreenDPI/96
        rect := Buffer(16)
        DllCall("GetClientRect","ptr",mainGui.Hwnd,"ptr",rect)
        clientW := NumGet(rect,8,"int")/dpi, clientH := NumGet(rect,12,"int")/dpi
        spaciousWidth := Max(1240,clientW)
        spaciousX := Max(0,Min(spaciousX,spaciousWidth-clientW))
        spaciousY := Max(0,Min(spaciousY,spaciousHeight-clientH))
        SpaciousSetScroll(0,spaciousWidth,clientW,spaciousX)
        SpaciousSetScroll(1,spaciousHeight,clientH,spaciousY)
        bodyWidth := spaciousWidth-560, sx := bodyWidth/500, sy := 1.6
        for item in spaciousOriginal {
            x := item.x, y := item.y, w := item.w, h := item.h
            if item.role="nav" {
                part := item.nav.part, nx := 24, ny := 126+(item.nav.index-1)*56, nw := 158, nh := 44
                switch part {
                    case 0: x:=nx+1,y:=ny+1,w:=nw-2,h:=nh-2
                    case 1: x:=nx,y:=ny,w:=nw,h:=1
                    case 2: x:=nx,y:=ny+nh-1,w:=nw,h:=1
                    case 3: x:=nx,y:=ny+1,w:=1,h:=nh-2
                    case 4: x:=nx+nw-1,y:=ny+1,w:=1,h:=nh-2
                }
            } else if item.role="header" {
                if item.x >= 406 {
                    x := spaciousWidth-24-(520-item.x)*1.2, y := 28+(item.y-18)*1.3
                    w := Max(1,item.w*1.2), h := Max(1,item.h*1.3)
                } else if item.y=14 {
                    x:=24,y:=22,w:=700,h:=42
                } else if item.y=38 {
                    x:=26,y:=70,w:=750,h:=24
                }
            } else if item.role="divider" {
                x:=24,y:=106,w:=spaciousWidth-48,h:=1
            } else {
                x:=208+(item.x-20)*sx,y:=118+(item.y-116)*sy
                w:=Max(1,item.w*sx),h:=item.h=1 ? 1 : Max(1,item.h*sy)
                if item.y>=594
                    w:=spaciousWidth-232
            }
            item.ctrl.Move(Round(x-spaciousX),Round(y-spaciousY),Round(w),Round(h))
        }
        for item in spaciousExtra {
            dx := item.anchor="right" ? spaciousWidth-1240 : 0
            item.ctrl.Move(Round(item.x+dx-spaciousX),Round(item.y-spaciousY),item.w,item.h)
        }
        ; Preview card consists of borders and fill created after the original layout snapshot.
        global spaciousPreviewCard
        if IsSet(spaciousPreviewCard) {
            x:=spaciousWidth-328
            spaciousPreviewCard.fill.Move(Round(x+1-spaciousX),Round(119-spaciousY),302,716)
            positions := [[x,118,304,1],[x,835,304,1],[x,119,1,716],[x+303,119,1,716]]
            for i,edge in spaciousPreviewCard.edges {
                p:=positions[i]
                edge.Move(Round(p[1]-spaciousX),Round(p[2]-spaciousY),p[3],p[4])
            }
        }
        for view in spaciousViews
            SpaciousPositionImage(view)
    } finally {
        spaciousBusy := false
    }
}
SpaciousSetScroll(bar,total,page,position) {
    global mainGui
    dpi:=A_ScreenDPI/96
    info:=Buffer(28,0)
    NumPut("uint",28,"uint",0x17,"int",0,"int",Max(0,Round(total*dpi)-1),"uint",Max(1,Floor(page*dpi)),"int",Round(position*dpi),info)
    DllCall("SetScrollInfo","ptr",mainGui.Hwnd,"int",bar,"ptr",info,"int",true)
}
SpaciousScrollTo(x,y) {
    global mainGui,spaciousX,spaciousY
    spaciousX:=x,spaciousY:=y
    SpaciousMainSize(mainGui,0)
}
SpaciousMainScroll(wParam,lParam,msg,hwnd) {
    global mainGui,spaciousX,spaciousY,spaciousHeight,spaciousWidth
    if hwnd!=mainGui.Hwnd || lParam
        return
    axis:=msg=0x115 ? 1 : 0, info:=Buffer(28,0)
    NumPut("uint",28,"uint",0x17,info)
    DllCall("GetScrollInfo","ptr",hwnd,"int",axis,"ptr",info)
    code:=wParam & 0xFFFF, dpi:=A_ScreenDPI/96
    pos:=axis ? spaciousY : spaciousX, page:=NumGet(info,16,"uint")/dpi
    switch code {
        case 0:pos-=36
        case 1:pos+=36
        case 2:pos-=page*.85
        case 3:pos+=page*.85
        case 4,5:pos:=NumGet(info,24,"int")/dpi
        case 6:pos:=0
        case 7:pos:=axis ? spaciousHeight : spaciousWidth
        default:return 0
    }
    SpaciousScrollTo(axis ? spaciousX : pos,axis ? pos : spaciousY)
    return 0
}
SpaciousMainWheel(wParam,lParam,msg,hwnd) {
    global mainGui,spaciousX,spaciousY
    if hwnd!=mainGui.Hwnd && !DllCall("IsChild","ptr",mainGui.Hwnd,"ptr",hwnd)
        return
    delta:=(wParam>>16)&0xFFFF
    if delta>=32768
        delta-=65536
    SpaciousScrollTo(spaciousX,spaciousY-delta/120*76)
    return 0
}
SpaciousPositionImage(view) {
    global spaciousWidth,spaciousX,spaciousY
    w:=view.iw ? view.iw : 264,h:=view.ih ? view.ih : 192
    x:=spaciousWidth-308+(264-w)/2,y:=view.top+52+(192-h)/2
    view.image.Move(Round(x-spaciousX),Round(y-spaciousY),Round(w),Round(h))
}
RefreshMainPreviews(*) {
    global spaciousReady,spaciousViews,activeTab,wayCardView,promptImg,recoveryImg
    global mapOpenImg,mapArrowImg,mapWaystoneImg,inTowerImg,towerClearedImg,currentWaystoneIdx,bossComingImg,bossSpawnImg
    if !IsSet(spaciousReady) || !spaciousReady
        return
    items := [{title:"Interaction / ward prompt",path:promptImg},{title:"Waystone animation frames",path:recoveryImg}]
    if activeTab="WAYSTONE" && wayCardView="WORLDMAP"
        items := [{title:"World Map open",path:mapOpenImg},{title:"Map player arrow",path:mapArrowImg}]
    else if activeTab="TOWER"
        items := [{title:"Inside tower",path:inTowerImg},{title:"Floor cleared",path:towerClearedImg}]
    else if activeTab="CYCLE"
        items := [{title:"Current map area",path:GetMapAreaPath(currentWaystoneIdx)},{title:"Map center waystone",path:mapWaystoneImg}]
    else if activeTab="CAPTURE" {
        item:=GetCurrentCaptureItem()
        if IsObject(item)
            items := [{title:item.name,path:item.path},{title:"Waystone animation frames",path:recoveryImg}]
    }
    for i,view in spaciousViews {
        item:=items[i]
        stamp := FileExist(item.path) ? FileGetTime(item.path,"M") FileGetSize(item.path) : "missing"
        view.title.Text:=item.title
        if view.path!=item.path || view.stamp!=stamp {
            view.path:=item.path,view.stamp:=stamp
            view.image.Value:="",view.iw:=0,view.ih:=0
            try {
                if stamp="missing"
                    throw Error("Reference file is unavailable")
                if !GetImageDimensions(item.path,&iw,&ih) || iw<1 || ih<1
                    throw Error("Preview unavailable")
                scale:=Min(264/iw,192/ih,6)
                view.iw:=Max(1,Round(iw*scale)),view.ih:=Max(1,Round(ih*scale))
                view.image.Value:="*w" view.iw " *h" view.ih " " item.path
                SplitPath(item.path,&name)
                view.caption.Text:=name "`n" iw " x " ih " px"
            } catch {
                view.caption.Text:="Image unavailable. Its configured path is preserved."
            }
        }
        SpaciousPositionImage(view)
    }
}
