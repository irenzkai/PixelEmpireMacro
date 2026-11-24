# Contributing to Pixel Empire Macro

Thank you for your interest in contributing to **Pixel Empire Macro**!  
This guide explains how the project is structured, how to set up your local environment, coding and UI standards, and how to submit Pull Requests.

- **Developer:** [Chase (`@alphagamer121204`)](https://www.roblox.com/users/605992135/profile)
- **Contributor:** [kaze (`@kazefast`)](https://www.roblox.com/users/1676005584/profile)

---

## Table of Contents
1. [Prerequisites & Local Setup](#1-prerequisites--local-setup)
2. [Project Architecture](#2-project-architecture)
3. [How to Add a New Feature or Module](#3-how-to-add-a-new-feature-or-module)
4. [AutoHotkey v2.0 Coding Standards](#4-autohotkey-v20-coding-standards)
5. [GUI & Black-and-White Theme Guidelines](#5-gui--black-and-white-theme-guidelines)
6. [Files Not to Commit](#6-files-not-to-commit)
7. [Git & Pull Request Workflow](#7-git--pull-request-workflow)
8. [Pre-PR Testing Checklist](#8-pre-pr-testing-checklist)
9. [Reporting Bugs & Feature Requests](#9-reporting-bugs--feature-requests)

## 1. Prerequisites & Local Setup

### Requirements
- **OS:** Windows 10 or Windows 11
- **Runtime:** [AutoHotkey v2.0+](https://www.autohotkey.com/) (v1.x is **not** supported)
- **Git:** [Git for Windows](https://git-scm.com/) (or GitHub Desktop)
- **Recommended Editor:** VS Code with an AutoHotkey v2 extension

### Setup Steps
1. **Fork** this repository on GitHub.
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/PixelEmpireMacro.git
   cd PixelEmpireMacro
   ```
3. **Add the upstream remote** so you can stay up to date:
   ```bash
   git remote add upstream https://github.com/irenzkai/PixelEmpireMacro.git
   ```
4. **Run the macro** by launching **`PixelEmpireMacro.ahk`** directly.  
   > ⚠️ **Important:** Never run files inside `src/` individually—they rely on the entry-point `#Include` order and shared global state in `PixelEmpireMacro.ahk`.

---

## 2. Project Architecture

`PixelEmpireMacro.ahk` acts as the index/entry point and loads modular files from `src/` in a deliberate order:

| File | Responsibility |
| :--- | :--- |
| `PixelEmpireMacro.ahk` | Entry point (`#Requires`, `SendMode`, `CoordMode`), `#Include` index, and startup initialization (`LoadConfig`, `BuildGUI`, `ApplyHotkeys`). |
| `src/State.ahk` | Global flags, counters, default presets (`shortCfg`, `wideCfg`), Tower Mode defaults, and hotkey mappings. |
| `src/Config.ahk` | INI persistence (`waystone_config.ini`) via `LoadConfig()`, `SaveConfig()`, and safe integer validation via `ParseSetting()`. |
| `src/VisionWindow.ahk` | Roblox window discovery/sorting (`GetSortedRobloxWindows`), focusing, proportional search-box scaling, and `ImageSearch` (`IsOnWaystone`). |
| `src/Movement.ahk` | Key press/release safety (`HoldKeys`, `ReleaseMoveKeys`), homing loop (`ReturnUntilPrompt`), recovery (`AntiTrapRecovery`), and `AltAntiAFK`. |
| `src/Modes.ahk` | Farming modes (`ToggleWaystoneMode`, `ToggleTowerMode`, `ToggleShortWidePreset`, `QueuePerimeterCircle`, `StartChaosStressTest`) and loops. |
| `src/Hotkeys.ahk` | Dynamic `Hotkey()` registration (`ApplyHotkeys`), master toggle (`ToggleHotkeysEnabled`), conflict detection, and click-to-bind (`RebindHotkey`). |
| `src/GUI.ahk` | Monochrome Dark/Light UI, tabs (`MACRO`, `SETTINGS`, `CREDITS`), custom flat controls, theme engine (`ApplyTheme`), and HUD (`UpdateHUD`). |

---

## 3. How to Add a New Feature or Module

Keep features modular so the codebase stays easy to maintain:

1. **Small additions to existing behavior:** Place them in the matching file under `src/` (e.g., new movement patterns in `src/Movement.ahk`, new INI keys in `src/Config.ahk`).
2. **Major new features** (e.g., auto-skills, auto-sell, webhook notifications, multi-client sync):
   - Create a dedicated file in `src/`, such as `src/AutoSkills.ahk`.
   - Declare its defaults in `src/State.ahk`.
   - Persist any user settings in `src/Config.ahk`.
   - Add its `#Include "src\AutoSkills.ahk"` line to `PixelEmpireMacro.ahk` **before** `LoadConfig()` / `BuildGUI()`.
   - Add UI controls inside `src/GUI.ahk` (or a dedicated helper called from `BuildGUI()`).
   - If the feature needs a hotkey, register it dynamically through `src/Hotkeys.ahk` instead of static `Key::` labels so the **Hotkey Switch** and **KEYS: ON/OFF** toggle continue to work.

---

## 4. AutoHotkey v2.0 Coding Standards

- **Strict v2 syntax:** Use AHK v2 functions and objects (`Map`, `Array`, `{...}`), never v1 commands or legacy `%var%` syntax.
- **Global scope discipline:** Explicitly declare `global` inside any function that reads or modifies shared state.
- **Safe user input parsing:** Always validate numeric GUI/INI values with `ParseSetting(rawVal, fallback, minVal, maxVal)` so clearing an input box while typing never throws a `TypeError` on `Sleep()` or `Integer()`.
- **UI update guards:** Wrap programmatic Edit control updates in `isUpdatingUI := true` / `isUpdatingUI := false` so `OnSettingsChanged()` doesn't trigger recursive saves.
- **Movement key safety:** Any loop or abort path must check `if (!running) return` and clean up held keys via `ReleaseMoveKeys()`.
- **Dynamic hotkeys:** Do not use static `F8::` style labels—use `Hotkey()` in `src/Hotkeys.ahk` so users can rebind or disable all hotkeys cleanly.
- **Screen-size awareness:** Avoid hardcoded pixel regions when detecting game UI. Scale relative to `WinGetPos()` on the target Roblox window (see `InitVisionAndWindow` in `src/VisionWindow.ahk`).

---

## 5. GUI & Black-and-White Theme Guidelines

The GUI follows a strict **monochrome Black & White** design with live **Dark Mode / Light Mode** switching. When adding UI elements in `src/GUI.ahk`:

1. **Use the built-in component helpers** instead of raw `AddText`/`AddButton` wherever possible:
   - `AddCard(tabName, x, y, w, h)`
   - `AddCardTitle(tabName, x, y, w, text)`
   - `AddPrimaryLabel(...)` / `AddMutedLabel(...)`
   - `AddStyledEdit(...)`
   - `AddFlatButton(x, y, w, h, text, isPrimary, callback, tabName)`
2. **Never overlap solid backgrounds over controls:**
   - Borders are drawn with **4 non-overlapping 1px strips** via `AddRectBorder()`.
   - Card `fill` layers are pushed to `HWND_BOTTOM` inside `ApplyTheme()`—always register new cards in `themeCards` and labels in `themePrimaryText` / `themeMutedText` with `onCard: true/false`.
3. **Prevent `&` underline glitches:** Always include `+0x80` (`SS_NOPREFIX`) on `Text` controls so `&` renders literally.
4. **Register tab visibility:** Push every tab-specific control (including borders and fills) into `pageControls[tabName]` so `SwitchTab()` hides/shows them properly.
5. **Interactive cursor feedback:** Add clickable flat button `Hwnd`s to `clickableHwnds` so hovering displays the hand pointer cursor.
6. **Guard `WinRedraw`:** Only call `WinRedraw("ahk_id " mainGui.Hwnd)` when `WinExist("ahk_id " mainGui.Hwnd)` is true (startup `ApplyTheme()` runs before `mainGui.Show()`).

---

## 6. Files Not to Commit

Ensure the following never appear in a commit or Pull Request:
- `waystone_config.ini` (or any `*.ini` generated during local testing—contains personal paths and custom timings)
- Personal full-screen captures, logs (`*.log`), backups (`*.bak`), or temp files (`*.tmp`)

Always check `git status` before committing.

---

## 7. Git & Pull Request Workflow

1. **Sync your `main` branch** before starting work:
   ```bash
   git checkout main
   git fetch upstream
   git merge upstream/main
   ```
2. **Create a descriptive feature/fix branch:**
   ```bash
   git checkout -b feat/your-feature-name
   ```
   Suggested branch prefixes:
   - `feat/` — new features or modes
   - `fix/` — bug fixes
   - `ui/` — GUI or theme improvements
   - `refactor/` — code cleanup without behavior changes
   - `docs/` — documentation updates
3. **Make focused, atomic commits** using clear messages:
   ```bash
   git add .
   git commit -m "feat: add adjustable anti-trap sweep delay"
   ```
4. **Push your branch** to your fork:
   ```bash
   git push -u origin feat/your-feature-name
   ```
5. **Open a Pull Request** on GitHub against `main` with:
   - A short summary of **what** changed and **why**.
   - Screenshots/GIFs if your PR modifies the GUI (show **both Dark Mode and Light Mode**).
   - Notes on how you tested the change.

---

## 8. Pre-PR Testing Checklist

Before submitting a Pull Request, verify all of the following:

- [ ] `PixelEmpireMacro.ahk` launches cleanly with **zero** AutoHotkey v2 errors or warnings.
- [ ] Switching between **`MACRO`**, **`SETTINGS`**, and **`CREDITS`** tabs shows/hides all controls cleanly with no overlapping text.
- [ ] Both **Dark Mode** and **Light Mode** render with proper contrast on every tab and input field.
- [ ] Editing move times or tolerance saves cleanly to `waystone_config.ini` and persists across restarts.
- [ ] Rebinding hotkeys in **Hotkey Switch** (including `Ctrl`/`Shift`/`Alt` combos and `KEYS: ON/OFF`) updates Quick Action labels and fires properly.
- [ ] Stopping or exiting (`Esc` or Close button) releases all `W/A/S/D` movement keys cleanly.
- [ ] `git status` does **not** include `waystone_config.ini` or unrelated files.

---

## 9. Reporting Bugs & Feature Requests

If you find a bug or want to propose a feature, open a GitHub Issue with:
- **AutoHotkey version** (e.g., `v2.0.18`)
- **Windows version & screen resolution** (e.g., `Windows 11, 1920x1080`)
- **Mode affected** (`Waystone 8-Star`, `Tower Mode`, `Perimeter Circle`, `Chaos Test`, `GUI`, or `Hotkeys`)
- **Steps to reproduce** and any error dialog screenshot or exact message
