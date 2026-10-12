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
    $invoke=$acctItem.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
    $invoke.Invoke()
    Write-Output "DEMO_WIZARD_MENU_INVOKED=True"
    Start-Sleep -Seconds 3
    $list=$desk.FindAll([System.Windows.Automation.TreeScope]::Children,[System.Windows.Automation.Condition]::TrueCondition)
    foreach($dialog in $list) {
      $text=[string]$dialog.Current.Name
      if($text -match "(?i)open an account|meta.?trader|broker|account") {
        Write-Output ("WIZARD_PRESENT=True")
        $nodes=$dialog.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)
        $allowed=@("MetaQuotes-Demo","Select a Server","Find your broker","Existing trade account",
                   "Open a demo account","Open a Demo Account","Open an account","First name","Last name",
                   "Name","Surname","Email","E-mail","Mobile","Phone","Next","Finish","Back","Cancel")
        $counts=@{}
        foreach($node in $nodes) {
           $name=[string]$node.Current.Name
           if($name -in $allowed) {
             $counts[$name]=1
           }
        }
        Write-Output ("WIZARD_SAFE_LABELS=" + (($counts.Keys | Sort-Object) -join ";"))
      }
    }
  } catch {Write-Output ("DEMO_WIZARD_MENU_INVOKED=False ERROR_TYPE="+$_.Exception.GetType().Name)}
}
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
if(-not $tp.HasExited){Stop-Process -Id $tp.Id -Force -ErrorAction SilentlyContinue}
Write-Output "NO_DEMO_REGISTRATION_SUBMITTED; NO_TICKS_OR_TRADES"
