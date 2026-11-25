# PixelEmpireMacro — Project & Agent Context Brief

> Feed this file (along with `AHK_V2_GUIDE.md`) to any new AI chat or local agent so it immediately knows the full architecture, OCR endpoints, and current status.

---

## 1. Project Overview

- **Target Game:** *Pixel Empire* (2D top-down/scrolling pixel-art RPG in Roblox, `ahk_exe RobloxPlayerBeta.exe`).
- **Location:** `C:\Users\DELL\Desktop\PixelEmpireMacro\`
- **Runtime Environment:** Windows 11, CPU-only laptop, 16GB RAM, AutoHotkey v2 (`AutoHotkey64.exe`), Python `.venv` in project root.
- **Coding Agent LLM:** Groq Free Tier (`openai/gpt-oss-120b` primary, auto-rotates to `qwen/qwen3.8-27b` and `openai/gpt-oss-20b` on 429/low TPM) with Ollama local fallback (`qwen3:4b`).
- **Goal:** Replace manual PNG `ImageSearch` templates with **automatic Roblox client capture + fast OpenCV pre-gates + RapidOCR**, plus an automated coding/testing agent (`ahk_agent.py`) with persistent SQLite memory and a live floating Roblox overlay.

---

## 2. System Architecture & Files

### Python OCR & Agent Layer (Project Root)
1. **`ocr_vision_server.py`** (HTTP server on `http://127.0.0.1:8765`)
   - Auto-locates visible `RobloxPlayerBeta.exe` / `"Roblox"` client rect (Per-Monitor DPI aware, works in both fullscreen and split-screen).
   - Captures via `mss`, applies zero-gap HSV binarization (white + pale-gold + red text masks), tight-crops text boxes, and runs `RapidOCR` (`Global.use_cls=False`).
   - Supports `?format=json` (default) and `?format=ahk` (`key=value` lines).
   - **Endpoints:**
     - `GET /ping` -> `{ok, windows}`
     - `GET /waystone_fast` -> **~8–15ms** blue-pill + white-text OpenCV gate; runs OCR only if `Warp back (E)` candidate exists
     - `GET /tower_fast` -> single-ROI `top_bar` check (`in_tower`, `floor_cleared`)
     - `GET /boss_fast` -> single-ROI `boss_banner` check (`active`, `kind` = Boss/Miniboss, `defeated`, `you_defeated`, `boss_state`, `boss_text`)
     - `GET /state?boss=1&prompt=1&debug=0` -> stitched single-pass full state (`ws_idx`, `ws_name`, `in_tower`, `floor_cleared`, `on_waystone`, `boss_state`, raw texts)
     - `GET /ocr?roi=<name>&preset=auto|fast|full&debug=0` -> OCR on one ROI
     - `GET /worldmap_vector?target=-1` -> World Map open check + HSV red player arrow & cyan waystone obelisk vector (`dx, dy`)
   - **ROIs (`ROIS`):**
     - `top_bar` `(0.28, 0.008, 0.72, 0.095)` — PVE zone pill + `Floor X/80 · Cleared! Walk through...`
     - `minimap_label` `(0.83, 0.145, 0.996, 0.285)` — Yellow zone name below minimap
     - `center_prompt` `(0.35, 0.140, 0.65, 0.560)` — `Warp back (E)` / `Return to Town (E)`
     - `boss_banner` `(0.30, 0.065, 0.70, 0.270)` — Boss/Miniboss coming, spawn, HP bar, defeated, `Defeated by ...`
     - `world_map` `(0.18, 0.200, 0.82, 0.820)` — World Map modal

2. **`ahk_agent.py`** (Groq + Ollama coding/testing agent CLI)
   - `MAX_ITERS = 6` per turn; auto-normalizes `\\n` in `.ahk` writes; strips UTF-8 BOM + injects `#Warn All, StdOut` during `/validate` and live runs; rotates Groq models cleanly on low TPM/429.
   - **Tools:** `list_files`, `read_file`, `write_file`, `patch_file`, `capture_roblox_and_ocr`, `test_ahk_script`, `save_note`, `get_notes`.
   - **Memory:** SQLite **`agent_memory.db`** (`messages` + `notes`, self-healing on interrupted tool calls).
   - **CLI commands:** `new`, `notes`, `history`, `copy`, `exit`.

3. **`agent_overlay.py`** (Floating Tkinter HUD + Win32 Clipboard + Focus)
   - Translucent (`0.88`), `WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW` overlay docked at left-middle of Roblox (outside all OCR ROIs).
   - `focus_roblox()` brings Roblox to foreground at prompt start using `AttachThreadInput` + `SwitchToThisWindow`.
   - Auto-copies turn output + `[Tool Runs]` + `[Groq Limits]` to Windows clipboard via Win32 `CF_UNICODETEXT`.

### AutoHotkey v2 Macro Layer (`PixelEmpireMacro.ahk` & `src\`)
- **`PixelEmpireMacro.ahk`** — Main entry script (compiles with **0 errors / 0 warnings**).
- **`src\OcrVision.ahk`** — Standalone OCR HTTP client (`EnsureOcrServerRunning`, `OcrServerReady`, `OcrDetectCurrentMap`, `OcrIsOnWaystone`, `OcrIsInTower`, `OcrIsFloorCleared`, `OcrGetBossState`, `OcrCheckBossBanner` with 350ms cache, `OcrScanWorldMapVector`).
- **`src\VisionWindow.ahk`** — OCR-first with PNG/GDI+ fallback for `IsOnWaystone`, `IsInTower`, `IsFloorCleared`, `IsNextFloorIndicator`, `IsMapTopLabel`, `DetectCurrentMapByTopLabel`, `ScanWorldMapVector`. Keeps PNG detection for non-text sprites (`FindWaystoneStatue`, `FindPortalSprite`).
- **`src\modes\MapCycleMode.ahk`** — `DetectActiveBossOrMiniboss`, `CheckAnyDefeatedBanner`, and `CheckYouDefeatedConfirmation` upgraded to OCR-first (`OcrCheckBossBanner`) with PNG fallback.
- **`src\modes\TowerMode.ahk`** — Uses `IsInTower()`, `IsFloorCleared()`, and `IsNextFloorIndicator()` (OCR-powered via `VisionWindow.ahk`).
- **Other modules:** `src\State.ahk`, `src\MapRoutes.ahk`, `src\Config.ahk`, `src\Movement.ahk`, `src\Hotkeys.ahk`, `src\modes\{ModeControl,WaystoneMode,PerimeterCircle,ChaosTest,ShortestPathMode}.ahk`, `src\gui\{Theme,Components,OverlayHUD,CaptureTool,Actions,MainWindow}.ahk`.

---

## 3. Game Zone Index (`WS0`–`WS30` + Tower)
- `-2`: `Tower of Trials`
- `0`: `Eldoria` | `1`: `Whisperwood` | `2`: `Elderwood Deep` | `3`: `Mirewood Bog` | `4`: `Sunscar Oasis` | `5`: `Dunes of Khar`
- `6`: `Emberfall Caldera` | `7`: `Fallen Outskirts` | `8`: `Ashen Ruins` | `9`: `Varn Necropolis` | `10`: `Abyssal Rift`
- `11`: `Frostvale Hills` | `12`: `Glacier Pass` | `13`: `Crown of Winter` | `14`: `Skyreach Spires` | `15`: `Blightwood Wastes`
- `16`: `Bonebleach Barrens` | `17`: `Shardglow Caverns` | `18`: `Starfall Isles` | `19`: `Coralhollow Reef` | `20`: `Ashveil Badlands`
- `21`: `The Crimson Deep` | `22`: `Rimeveil Abyss` | `23`: `Glimmerfen Hollows` | `24`: `The Sunforge` | `25`: `Drumfield Carnival`
- `26`: `Candlewax Abbey` | `27`: `Toppled Gameboard` | `28`: `Gilded Glass Palace` | `29`: `Mossbound Tribunal` | `30`: `Duskhollow of Lost Things`

---

## 4. Current Status & Next Steps

- **Completed:**
  - `ocr_vision_server.py` fast endpoints (`/waystone_fast`, `/tower_fast`, `/boss_fast`, `/state`, `/worldmap_vector`) working cleanly.
  - `src\OcrVision.ahk`, `src\VisionWindow.ahk`, and `src\modes\MapCycleMode.ahk` integrated with OCR-first + PNG fallback; `PixelEmpireMacro.ahk` validates with 0 errors.
  - `ahk_agent.py` + `agent_overlay.py` + `agent_memory.db` operational with Groq Free Tier + rate-limit tracking.
- **Next:**
  - Live in-game testing of `PixelEmpireMacro.ahk` across Waystone (`F8`), Tower (`F5`), and Map Cycle / Boss Hunt (`F4`), tuning any ROI/threshold if a specific map or banner is missed.