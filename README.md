# Pixel Empire Macro

A modular **AutoHotkey v2.0** automation macro for **Pixel Empire** on Roblox, featuring a monochrome Dark/Light GUI, Waystone image-homing farming, Tower Mode (Free Range), customizable directional movement timings, and dynamic hotkey rebinding.

## Features
- **Waystone 8-Star Farming (`F8` default)** — Uses `ImageSearch` to detect your Waystone prompt (`Return to Town (E)` or a shortened crop) and automatically homes back with anti-trap recovery.
- **Tower Mode / Free Range (`F5` default)** — Waystone-free octagonal perimeter sweep + full cross pattern with independently tunable move times.
- **Short & Very Wide Presets (`F6` default)** — Adjustable **Up (W)**, **Down (S)**, **Left (A)**, **Right (D)**, **Diagonal**, and **Return Max** millisecond timings.
- **Custom Prompt Image Import** — Import any cropped prompt image (`PNG`/`JPG`/`BMP`) and test detection live with screen-size proportional search scaling and adjustable tolerance.
- **Settings & Customization** — Live **Dark Mode / Light Mode** toggle, **Floating HUD** toggle, and click-to-bind **Hotkey Switch** (supports `Ctrl`/`Shift`/`Alt` combos + master `KEYS: ON/OFF`).
- **One-Shot Perimeter Circle (`F9`) & Chaos Stress Test (`F7`)** — Queue perimeter sweeps or verify Waystone homing reliability before farming.
- **Multi-Account Anti-AFK** — Periodically jumps on secondary Roblox windows.

## Requirements
- Windows 10 / 11
- [AutoHotkey v2.0+](https://www.autohotkey.com/)

## Getting Started
1. Download or clone this repository.
2. Run **`PixelEmpireMacro.ahk`** (do not run files inside `src/` directly).
3. In the **Macro** tab, click **Import...** to select your cropped `Return to Town (E)` (or shortened) Waystone prompt screenshot, then click **Test Waystone** while standing near the Waystone in-game.
4. Adjust directional move times or hotkeys as needed—all settings auto-save to `waystone_config.ini`.

## Credits
- **Developer:** [Chase (`@alphagamer121204`)](https://www.roblox.com/users/605992135/profile)
- **Contributor:** [kaze (`@kazefast`)](https://www.roblox.com/users/1676005584/profile)

## Contributing
Contributions are welcome! See [`CONTRIBUTING.md`](CONTRIBUTING.md) for guidelines.