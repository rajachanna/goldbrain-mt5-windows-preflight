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
if(-not $tp.HasExited){Stop-Process -Id $tp.Id -Force -ErrorAction SilentlyContinue}
Write-Output "NO_DEMO_REGISTRATION_SUBMITTED; NO_TICKS_OR_TRADES"
