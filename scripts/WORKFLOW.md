Use **Show Agent Overlay** in the macro: it starts the local helper automatically. F10 toggles the same window; closing hides it. The VS Code task **Start Agent Overlay (manual testing)** remains available.

Reference Setup is a persistent manual checklist with saved drafts. Start by defining the top map-name label as the `map_name` OCR region and confirming its WS number. Crop/reference/notification/tooltip work is local; missing examples stay pending. See `PROJECT_CONTEXT.md` for controls and storage.

Double-click the main GUI status to open `.task-output/agent_startup_error.txt` after a startup failure. Reload utility: `scripts/reload_macro.ps1` releases keys and restarts stopped. Changed helpers may be restarted; no game tests or character control are authorized.

Recordings stay in `routes/demonstrations/`. The overlay displays the latest saved recording's name, full path, duration and completion status. **Copy Recording Summary** writes to the clipboard only when clicked; paste into the intended conversation yourself. Recording completion never sends to Codex, Groq or VS Code chat. Local history remains local.

Optional Groq text analysis: `.venv/Scripts/python.exe ahk_agent.py --analyze "your evidence"` with `GROQ_API_KEY`. Only the explicitly supplied evidence is sent; local history and recordings are not attached automatically. It has no execution tools. VS Code conversation capture does not exist here. Recording-summary behavior awaits manual testing.
