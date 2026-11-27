; Map-only adapter for the pinned upstream AHK v2 library. Live vision is unchanged.
#Include "vendor\ShinsImageScanClass.ahk"

global fastMapScan := 0
global fastMapTemplateInitMs := 0

class NamedMapImageScan {
    __New() {
        this.native := ShinsImageScanClass()
        this.native.AutoUpdate := 0
        this.images := Map()
        this.roles := Map("header", [], "arrow", [], "waystone", [])
        this.header := 0
        this.captureMs := 0
    }

    AddImage(key, path, role := "", cx := 0, cy := 0, dx := 0, dy := 0) {
        if !FileExist(path)
            throw Error("Map reference missing: " path)
        if !this.native.CacheImage(path)
            throw Error("Cannot cache map reference: " path)
        this.native.GetImageDimensions(path, &w, &h)
        entry := {key:key,path:path,w:w,h:h,cx:cx,cy:cy,dx:dx,dy:dy}
        this.images[key] := entry
        if this.roles.Has(role)
            this.roles[role].Push(entry)
        return entry
    }

    Scan(x1, y1, x2, y2) {
        if (x2 <= x1 || y2 <= y1)
            return false
        this.x := x1, this.y := y1, this.w := x2-x1, this.h := y2-y1
        ; One capture, reused by all searches. Coordinates passed to the adapter
        ; are screen pixels; native buffer coordinates start at 0,0.
        started := GetQpcMs()
        this.native.Update(x1, y1, this.w, this.h)
        this.captureMs := GetQpcMs()-started
        return true
    }

    Find(key, &x := 0, &y := 0) {
        image := this.images[key]
        return this.native.ImageRegion(image.path, 0, 0, this.w, this.h, 0, &x, &y)
    }

    FindAll(key, box := 0) {
        image := this.images[key]
        x := 0, y := 0, w := this.w, h := this.h
        if IsObject(box) {
            left := Max(this.x, box.x1), top := Max(this.y, box.y1)
            right := Min(this.x+this.w, box.x2), bottom := Min(this.y+this.h, box.y2)
            if (right-left < image.w || bottom-top < image.h)
                return []
            x := left-this.x, y := top-this.y, w := right-left, h := bottom-top
        }
        hits := []
        ; Numeric zero is Shins' exact-match equivalent of ImageSearch *0.
        this.native.ImageArrayRegion(image.path, &hits, x, y, w, h, 0)
        return hits
    }

    HeaderFound() {
        this.header := 0
        for image in this.roles["header"] {
            if this.Find(image.key,&x,&y) {
                this.header := {x:x,y:y,key:image.key,scale:image.w/145}
                return true
            }
        }
        return false
    }

}

InitFastMapScan() {
    global fastMapScan, fastMapTemplateInitMs
    started := GetQpcMs()
    manifest := A_ScriptDir "\.task-output\fast_map_assets\manifest.ini"
    if !FileExist(manifest) {
        py := A_ScriptDir "\.venv\Scripts\python.exe"
        builder := A_ScriptDir "\scripts\prepare_fast_map_scan.py"
        RunWait('"' py '" "' builder '"', A_ScriptDir, "Hide")
    }
    scan := NamedMapImageScan()
    Loop Integer(IniRead(manifest, "meta", "images")) {
        section := "image_" A_Index
        scan.AddImage(IniRead(manifest,section,"key"), IniRead(manifest,section,"path"),
            IniRead(manifest,section,"role",""), Number(IniRead(manifest,section,"cx",0)),
            Number(IniRead(manifest,section,"cy",0)), Number(IniRead(manifest,section,"dx",0)),
            Number(IniRead(manifest,section,"dy",0)))
    }
    fastMapScan := scan
    fastMapTemplateInitMs := GetQpcMs()-started
}

CaptureFastMap() {
    global fastMapScan, mapBox
    return IsObject(fastMapScan) && fastMapScan.Scan(mapBox.x1,mapBox.y1,mapBox.x2,mapBox.y2)
}

FastMapHeaderFound() {
    global fastMapScan
    return CaptureFastMap() && fastMapScan.HeaderFound()
}

FastMapIcon(path, box, &x := 0, &y := 0) {
    global fastMapScan
    if !IsObject(fastMapScan)
        return false
    key := "path:" path
    if !fastMapScan.images.Has(key)
        fastMapScan.AddImage(key, path)
    return fastMapScan.Scan(box.x1,box.y1,box.x2,box.y2) && fastMapScan.Find(key,&x,&y)
}

