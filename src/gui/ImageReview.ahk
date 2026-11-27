; Local companion UI: no LLM service or agent session is needed.
OpenImageReview(*) {
    python := A_ScriptDir "\.venv\Scripts\pythonw.exe"
    script := A_ScriptDir "\scripts\image_review.py"
    try {
        if (!FileExist(python) || !FileExist(script))
            throw Error("Image Review requires the project .venv and scripts/image_review.py")
        Run('"' python '" "' script '"', A_ScriptDir)
    } catch as err {
        UpdateGuiStatus("Image Review: " err.Message)
    }
}
