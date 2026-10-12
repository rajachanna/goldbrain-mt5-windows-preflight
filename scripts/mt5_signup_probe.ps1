$ErrorActionPreference="Stop"
$base=Join-Path $env:RUNNER_TEMP "gb_signup_probe"
New-Item -ItemType Directory -Force -Path $base | Out-Null
$exe=Join-Path $base "mt5setup.exe"
Invoke-WebRequest "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe" -OutFile $exe -TimeoutSec 65
$ip=Start-Process -FilePath $exe -ArgumentList "/auto" -PassThru
try { Wait-Process -Id $ip.Id -Timeout 125 -ErrorAction Stop } catch { Stop-Process -Id $ip.Id -Force -ErrorAction SilentlyContinue }
$mt5="C:\Program Files\MetaTrader 5\terminal64.exe"
if(-not (Test-Path $mt5)) { throw "MT5_NOT_INSTALLED" }
$tp=Start-Process -FilePath $mt5 -PassThru
Start-Sleep -Seconds 22
Write-Output ("RUNNER_INTERACTIVE=" + [Environment]::UserInteractive)
Write-Output ("MT5_PROCESS_ACTIVE=" + (-not $tp.HasExited))
Add-Type -AssemblyName UIAutomationClient
$desk=[System.Windows.Automation.AutomationElement]::RootElement
$all=$desk.FindAll([System.Windows.Automation.TreeScope]::Children,[System.Windows.Automation.Condition]::TrueCondition)
$cnt=0
foreach($w in $all) {
  $name=[string]$w.Current.Name
  if($name -match "(?i)meta.?trader|open an account|connect to an account|demo account|broker|authorization") {
    $cnt++
    if($name.Length -gt 95) {$name=$name.Substring(0,95)}
    $safe=$name -replace "[0-9]","X" 
    Write-Output ("MT5_WINDOW_CATEGORY=" + $safe)
    $desc=$w.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)
    $labels=@("Open an account","Open a Demo Account","MetaQuotes-Demo","Connect to an account","Login","Password","Name","Surname","E-mail","Email","Mobile","Phone","Next","Finish")
    $matching=0
    foreach($el in $desc) { if([string]$el.Current.Name -in $labels) {$matching++} }
    Write-Output ("KNOWN_REGISTRATION_CONTROL_COUNT=" + $matching)
  }
}
Write-Output ("RELEVANT_GUI_WINDOWS="+$cnt)
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class GBFocus {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
  public static void Click(int x,int y) { SetCursorPos(x,y); System.Threading.Thread.Sleep(120); mouse_event(0x0002,0,0,0,UIntPtr.Zero); mouse_event(0x0004,0,0,0,UIntPtr.Zero); }
}
"@
[GBFocus]::SetForegroundWindow($tp.MainWindowHandle) | Out-Null
Start-Sleep -Seconds 1
[System.Windows.Forms.SendKeys]::SendWait("%f")
Start-Sleep -Seconds 2
$menuLabels=@("File","New Chart","Open an Account","Open Account","Login to Trade Account","Trade Accounts","Close","Exit")
$all2=$desk.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)
$found=0
foreach($e in $all2) {
  if($found -ge 15){break}
  $txt=[string]$e.Current.Name
  if($txt -in $menuLabels) {
    $found++
    Write-Output ("SAFE_MENU_LABEL="+$txt)
  }
}
Write-Output ("SAFE_MENU_LABELS_FOUND="+$found)
$acctItem=$null
foreach($e in $all2) {
  if([string]$e.Current.Name -eq "Open an Account") { $acctItem=$e;break }
}
if($null -ne $acctItem) {
  try {
    $r=$acctItem.Current.BoundingRectangle
    Write-Output ("OPEN_ACCOUNT_MENU_BOUNDS_VALID="+($r.Width -gt 5 -and $r.Height -gt 5))
    if($r.Width -gt 5 -and $r.Height -gt 5) {
      [GBFocus]::Click([int]($r.Left+$r.Width/2),[int]($r.Top+$r.Height/2))
      Write-Output "OPEN_ACCOUNT_MENU_PHYSICALLY_CLICKED=True"
    } else {
      [System.Windows.Forms.SendKeys]::SendWait("{ESC}")
      [GBFocus]::SetForegroundWindow($tp.MainWindowHandle) | Out-Null
      [System.Windows.Forms.SendKeys]::SendWait("%f")
      [System.Windows.Forms.SendKeys]::SendWait("a")
      Write-Output "OPEN_ACCOUNT_MENU_KEYBOARD_ACCELERATOR_ATTEMPTED=True"
    }
    Start-Sleep -Seconds 4
    $screen=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    if($screen.Width -eq 1024 -and $screen.Height -eq 768) {
      # Stable coordinates from screenshot of a fresh, empty MetaQuotes wizard.
      [GBFocus]::Click(299,241)
      Start-Sleep -Seconds 1
      [GBFocus]::Click(728,607)
      Write-Output "METAQUOTES_COMPANY_AND_NEXT_STEP_ATTEMPTED=True"
      Start-Sleep -Seconds 5
      # The next page defaults to a demo account, never live trading.
      [GBFocus]::Click(728,608)
      Write-Output "DEFAULT_DEMO_OPTION_NEXT_STEP_ATTEMPTED=True"
      Start-Sleep -Seconds 5
    } else {Write-Output "GUI_SCREEN_SIZE_UNEXPECTED_SKIPPING_CLICK"}
    $windows=$desk.FindAll([System.Windows.Automation.TreeScope]::Children,[System.Windows.Automation.Condition]::TrueCondition)
    $labels=@("MetaQuotes-Demo","Select a Server","Find your broker","Existing trade account",
              "Open a demo account","Open a Demo Account","Open an account","First name","Last name",
              "Name","Surname","Email","E-mail","Mobile","Phone","Next","Finish","Back","Cancel",
              "Search","Company","Start","Demo account")
    $safeNames=[System.Collections.Generic.HashSet[string]]::new()
    foreach($dialog in $windows) {
      $windowName=[string]$dialog.Current.Name
      if($windowName -match "(?i)open an account|meta.?trader|broker|account|server") {
        Write-Output "POSSIBLE_MT5_DIALOG_PRESENT=True"
        $nodes=$dialog.FindAll([System.Windows.Automation.TreeScope]::Descendants,
                               [System.Windows.Automation.Condition]::TrueCondition)
        $kindCounts=@{}
        $sampleNames=[System.Collections.Generic.HashSet[string]]::new()
        foreach($node in $nodes) {
          $n=[string]$node.Current.Name
          $t=[string]$node.Current.ControlType.ProgrammaticName
          if(-not $kindCounts.ContainsKey($t)){$kindCounts[$t]=0}
          $kindCounts[$t]++
          if($n -in $labels) { $safeNames.Add($n)|Out-Null }
          # Only static UI strings; suppress text with @, digits or colon (may be identifiers).
          if($n.Length -gt 1 -and $n.Length -lt 55 -and
             $n -match '^[a-zA-Z ]+$' -and
             $sampleNames.Count -lt 30) {$sampleNames.Add($n)|Out-Null}
        }
        Write-Output ("WIZARD_CONTROL_TYPES="+(($kindCounts.Keys | Sort-Object | ForEach-Object {$_+"="+$kindCounts[$_]})-join ";"))
        Write-Output ("WIZARD_STATIC_LABELS="+(($sampleNames | Sort-Object)-join ";"))
      }
    }
    Write-Output ("WIZARD_SAFE_LABELS="+(($safeNames | Sort-Object)-join ";"))
    # Blank ephemeral hosted Windows VM; no user/account data is entered.
    Add-Type -AssemblyName System.Drawing
    $bounds=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp=New-Object System.Drawing.Bitmap($bounds.Width,$bounds.Height)
    $graphics=[System.Drawing.Graphics]::FromImage($bmp)
    try {
      $graphics.CopyFromScreen($bounds.Location,[System.Drawing.Point]::Empty,$bounds.Size)
      $target=Join-Path $env:GITHUB_WORKSPACE "blank_mt5_wizard.png"
      $bmp.Save($target,[System.Drawing.Imaging.ImageFormat]::Png)
      Write-Output "BLANK_GUI_DIAGNOSTIC_SCREENSHOT_SAVED=True"
    } finally {$graphics.Dispose();$bmp.Dispose()}
  } catch {
    Write-Output ("WIZARD_INSPECTION_ERROR_TYPE="+$_.Exception.GetType().Name)
  }
}
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
if(-not $tp.HasExited){Stop-Process -Id $tp.Id -Force -ErrorAction SilentlyContinue}
Write-Output "NO_DEMO_REGISTRATION_SUBMITTED; NO_TICKS_OR_TRADES"
