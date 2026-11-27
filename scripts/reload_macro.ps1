param([switch]$StopOnly)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$script=Join-Path $root 'PixelEmpireMacro.ahk'
$registryPath=Join-Path $root '.task-output\macro_window.ini'
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class MacroReloadNative {
 public delegate bool EnumProc(IntPtr hwnd,IntPtr lp);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb,IntPtr lp);
 [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hwnd);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd,int command);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hwnd,StringBuilder text,int size);
 [DllImport("user32.dll",SetLastError=true)] public static extern IntPtr SendMessageTimeout(IntPtr hwnd,uint msg,UIntPtr wp,IntPtr lp,uint flags,uint timeout,out UIntPtr result);
 public static IntPtr ScriptWindow(uint process) {
  IntPtr found=IntPtr.Zero;
  EnumWindows((h,l)=>{uint owner;GetWindowThreadProcessId(h,out owner);if(owner==process){var name=new StringBuilder(256);GetClassName(h,name,256);if(name.ToString()=="AutoHotkey"){found=h;return false;}}return true;},IntPtr.Zero);
  return found;
 }
}
"@
# Explicitly stop/close verified copies; do not use the internal /restart flag.
$copies=@(Get-CimInstance Win32_Process | Where-Object {
 $_.Name -like 'AutoHotkey*.exe' -and $_.CommandLine -and
 $_.CommandLine.IndexOf(('"'+$script+'"'),[StringComparison]::OrdinalIgnoreCase) -ge 0
})
$stranded=@()
$stopAcknowledged=$false
foreach ($copy in $copies) {
 $scriptWindow=[MacroReloadNative]::ScriptWindow([uint32]$copy.ProcessId)
 if ($scriptWindow -eq [IntPtr]::Zero) {
  $desktopProcess=Get-Process -Id $copy.ProcessId -ErrorAction SilentlyContinue
  if ($desktopProcess) { $scriptWindow=$desktopProcess.MainWindowHandle }
 }
 if ($scriptWindow -eq [IntPtr]::Zero -and (Test-Path -LiteralPath $registryPath)) {
  $currentRegistration=Get-Content -LiteralPath $registryPath
  $candidate=($currentRegistration | Where-Object {$_ -match '^hwnd='}) -replace '^hwnd=',''
  if ($candidate) {
   [uint32]$candidateOwner=0
   [void][MacroReloadNative]::GetWindowThreadProcessId([IntPtr]([long]$candidate),[ref]$candidateOwner)
   if ($candidateOwner -eq [uint32]$copy.ProcessId) { $scriptWindow=[IntPtr]([long]$candidate) }
  }
 }
 if ($scriptWindow -eq [IntPtr]::Zero) { $stranded += $copy; continue }
 [UIntPtr]$ackResult=[UIntPtr]::Zero
 $ack=[MacroReloadNative]::SendMessageTimeout($scriptWindow,0x8003,[UIntPtr]::Zero,[IntPtr]::Zero,2,2000,[ref]$ackResult)
 if ($ack -eq [IntPtr]::Zero -or $ackResult.ToUInt64() -ne 1) { throw ('PID '+$copy.ProcessId+' did not acknowledge StopAll/key release; reload cancelled') }
 $stopAcknowledged=$true
 [UIntPtr]$closeResult=[UIntPtr]::Zero
 [void][MacroReloadNative]::SendMessageTimeout($scriptWindow,0x0010,[UIntPtr]::Zero,[IntPtr]::Zero,2,2000,[ref]$closeResult)
 $exitDeadline=[DateTime]::UtcNow.AddSeconds(4)
 while ((Get-Process -Id $copy.ProcessId -ErrorAction SilentlyContinue) -and [DateTime]::UtcNow -lt $exitDeadline) { Start-Sleep -Milliseconds 100 }
 if (Get-Process -Id $copy.ProcessId -ErrorAction SilentlyContinue) { throw ('Stopped PID '+$copy.ProcessId+' did not exit; no new instance launched') }
 Write-Output ('Stopped and closed verified macro PID '+$copy.ProcessId)
}
foreach ($copy in $stranded) {
 if (!$stopAcknowledged) { throw 'No desktop runtime acknowledged key release; refusing stranded-process cleanup' }
 # These exact-script processes have no accessible macro window. Desktop copies
 # have already stopped/released keys; remove duplicates before launching anew.
 $identity=Get-CimInstance Win32_Process -Filter ('ProcessId = '+$copy.ProcessId)
 if ($identity -and $identity.CommandLine -eq $copy.CommandLine) {
  [System.Diagnostics.Process]::GetProcessById([int]$copy.ProcessId).Kill()
  Write-Output ('Closed stranded exact-script PID '+$copy.ProcessId)
 }
}
if ($StopOnly) { Write-Output 'All verified macro copies stopped; no new runtime launched.'; return }
$ahk='C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
$process=Start-Process -FilePath $ahk -ArgumentList @('/ErrorStdOut=UTF-8',('"'+$script+'"')) -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root '.task-output\macro_startup.log') -RedirectStandardError (Join-Path $root '.task-output\macro_startup_error.log') -PassThru
$readyDeadline=[DateTime]::UtcNow.AddSeconds(20)
while ([DateTime]::UtcNow -lt $readyDeadline) {
 if ($process.HasExited) { throw ('Macro startup failed: '+(Get-Content -LiteralPath (Join-Path $root '.task-output\macro_startup_error.log') -Raw)) }
 if (Test-Path -LiteralPath $registryPath) {
  try { $registration=Get-Content -LiteralPath $registryPath }
  catch [System.IO.IOException] { Start-Sleep -Milliseconds 100; continue }
  $registeredProcess=($registration | Where-Object {$_ -match '^pid='}) -replace '^pid=',''
  $registeredWindow=($registration | Where-Object {$_ -match '^hwnd='}) -replace '^hwnd=',''
  if ($registeredProcess -eq [string]$process.Id -and $registeredWindow -and [MacroReloadNative]::IsWindow([IntPtr]([long]$registeredWindow))) {
   [void][MacroReloadNative]::ShowWindow([IntPtr]([long]$registeredWindow),4)
   Write-Output ('Macro registered PID '+$process.Id+'; automation starts stopped.')
   return
  }
 }
 Start-Sleep -Milliseconds 100
}
throw ('Macro PID '+$process.Id+' did not register within 20 seconds; inspect startup logs.')
