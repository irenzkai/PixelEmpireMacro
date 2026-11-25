# AutoHotkey v2 Comprehensive Guide (For PixelEmpireMacro & Coding Agents)

> **CRITICAL FOR LLMs:** AutoHotkey v2 (`#Requires AutoHotkey v2.0`) is **NOT** backwards-compatible with AutoHotkey v1, and it is **NOT** JavaScript/C/Python. Follow every rule below strictly.

---

## 1. Golden Syntax Rules (Top Mistakes to Avoid)

| Mistake (WRONG) | Correct AHK v2 | Why |
|---|---|---|
| `FileAppend, text, *` | `FileAppend("text`n", "*")` | **No v1 comma commands.** All functions require `(...)`. |
| `MsgBox, Hello` | `MsgBox("Hello")` | `MsgBox` is a function call. |
| `x := 1;` | `x := 1` | **`;` starts a comment in AHK!** Never end lines with `;`. |
| `x = 1` | `x := 1` | Always use `:=` for assignment. `=` is comparison only. |
| `"line1\nline2"` | `"line1`nline2"` | Escape char in AHK is **backtick `` ` ``**, NOT backslash `\`. |
| `a + b` (strings) | `a . b` or `a " " b` | Concatenate strings with space or `.`, never `+`. |
| `arr[0]` | `arr[1]` | Arrays and `StrSplit()` are **1-indexed** in AHK v2. |
| `if x = "abc"` | `if (x = "abc")` | Parentheses around conditions are standard; `=` is case-insensitive, `==` is case-sensitive. |

---

## 2. Script Header & Includes

Every standalone `.ahk` script should start with:
```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
```
Include files relative to the script directory (`A_ScriptDir`):
```ahk
#Include "src/OcrVision.ahk"
```
If the script lives inside `src\`, use `#Include "OcrVision.ahk"` or `#Include "*i ..."` only when optional.

---

## 3. Variables, Scope & `global`

In AHK v2, functions are **assume-local** by default:
- Reading a global variable inside a function works **only if** no local assignment touches that name—**best practice: always declare `global varName` explicitly** inside functions that read/write shared state.
- Declare script-wide variables at top level (like in `src/State.ahk`):
```ahk
global running := false
global currentWaystoneIdx := 0

StartBot() {
    global running
    running := true
}
```
- **Output (`ByRef`) parameters** use `&` in **both** the definition and the call:
```ahk
GetMap(&mapName := "") {
    mapName := "Eldoria"
    return 0
}

idx := GetMap(&name)   ; MUST pass &name at call site too
```

---

## 4. Data Structures: Arrays, Maps & Objects

### Arrays (`[...]`, **1-based**)
```ahk
keys := ["w", "a", "s", "d"]
first := keys[1]          ; "w"
len := keys.Length        ; 4
keys.Push("e")
for idx, val in keys {
    FileAppend(idx ": " val "`n", "*")
}
```

### Maps (`Map(...)`, key-value dictionary)
Use `Map` for dynamic string/integer keys (never `{}` for arbitrary keys):
```ahk
m := Map("w", false, "a", true)
m["s"] := false
if m.Has("a") && m["a"] {
    SendEvent("{a down}")
}
for k, v in m {
    ...
}
```

### Literal Objects (`{prop: val}`)
Use `{...}` for fixed-property structs:
```ahk
cfg := {up: 1050, down: 1300}
val := cfg.up
cfg.up := 1100
```

---

## 5. Strings, Numbers & Stdout (`FileAppend`)

- **Escape sequences** (backtick `` ` ``):
  - `` `n `` = newline (LF)
  - `` `r `` = carriage return
  - `` `t `` = tab
  - `` `" `` or single-quoted `'...'` = literal double quote inside string
- **Stdout printing** (captured by Python `subprocess` / terminal):
```ahk
FileAppend("Map=" idx " (" mapName ")`n", "*")
```
- **Type checks & conversions**:
```ahk
if IsInteger(raw)
    num := Integer(raw)
str := String(num)
low := StrLower(text)
has := InStr(low, "cleared")   ; returns 1-based index (0 if not found)
```

---

## 6. Control Flow, Loops & Timers

```ahk
if (a > 0 && b != "") {
    ...
} else if (c = 1 || d = 2) {
    ...
} else {
    ...
}

Loop 5 {
    Sleep(100)
    if (A_Index = 3)
        break
}

while (running) {
    Sleep(50)
}

; Non-blocking timer (ms, negative = one-shot)
SetTimer(CheckLoop, 250)
SetTimer(CheckLoop, 0)  ; stop timer
```

---

## 7. Input, Windows & Safety (Roblox Macro Patterns)

- **Always release held movement keys on stop/exit**:
```ahk
SendEvent("{w down}")
Sleep(300)
SendEvent("{w up}")
```
- **Window helpers**:
```ahk
hwnds := WinGetList("ahk_exe RobloxPlayerBeta.exe")
if (hwnds.Length > 0) {
    WinActivate("ahk_id " hwnds[1])
    WinGetClientPos(&wx, &wy, &ww, &wh, "ahk_id " hwnds[1])
}
```
- **Dynamic hotkeys** (callback receives hotkey name `*`):
```ahk
Hotkey("F8", ToggleBot, "On")
ToggleBot(*) {
    ...
}
```

---

## 8. HTTP Requests (`WinHttp.WinHttpRequest.5.1`)

Used by `src/OcrVision.ahk` to talk to `ocr_vision_server.py`:
```ahk
req := ComObject("WinHttp.WinHttpRequest.5.1")
req.SetTimeouts(400, 400, 1500, 5000)
req.Open("GET", "http://127.0.0.1:8765/state?format=ahk", false)
req.Send()
if (req.Status = 200)
    body := req.ResponseText
```

---

## 9. Error Handling (`try / catch`)

AHK v2 throws exceptions strictly on missing map keys, failed `WinHttp`, or missing windows:
```ahk
try {
    WinGetClientPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
} catch as err {
    FileAppend("Error: " err.Message "`n", "*")
}
```

---

## 10. Validation & Testing From CLI

Always validate syntax before running live:
```powershell
"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /validate /ErrorStdOut=utf-8 script.ahk
```
Or inside `ahk_agent.py`, call:
`test_ahk_script("script.ahk", 0)` for syntax-only, or `test_ahk_script("script.ahk", 5)` for a 5-second live test with stdout + before/after OCR.
```