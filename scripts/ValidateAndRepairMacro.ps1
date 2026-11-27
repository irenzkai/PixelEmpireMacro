# Compatibility launcher; no automated validation, repair, or game input.
param([switch]$VerifyRepair, [switch]$ManualSession)
$repoRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $repoRoot '.venv\Scripts\python.exe') (Join-Path $repoRoot 'ahk_agent.py')
