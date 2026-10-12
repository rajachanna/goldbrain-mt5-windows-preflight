$ErrorActionPreference = "Stop"
$base = Join-Path $env:RUNNER_TEMP "gb_mt5"
New-Item -ItemType Directory -Force -Path $base | Out-Null
$url = "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
$installer = Join-Path $base "mt5setup.exe"
Write-Output "Installing official MetaTrader 5, demo and read-only only."
Invoke-WebRequest -Uri $url -OutFile $installer -TimeoutSec 75
Write-Output ("Installer size bytes: " + (Get-Item $installer).Length)
$p = Start-Process -FilePath $installer -ArgumentList "/auto" -PassThru
try { Wait-Process -Id $p.Id -Timeout 150 -ErrorAction Stop }
catch {
  Write-Output "Installer wait exceeded; checking installed executable."
  Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
}
$root = "C:\Program Files\MetaTrader 5"
$terminal = Join-Path $root "terminal64.exe"
if (-not (Test-Path $terminal)) { throw "MT5_TERMINAL_MISSING" }
Write-Output "WIN_NATIVE_TERMINAL_PRESENT"
$editor = Join-Path $root "MetaEditor64.exe"
if (-not (Test-Path $editor)) { throw "METAEDITOR64_MISSING" }
$src = Join-Path $PWD "GoldBrain_MT5_RealTick_Export.mq5"
$destdir = Join-Path $root "MQL5\Scripts"
New-Item -ItemType Directory -Force -Path $destdir | Out-Null
$dest = Join-Path $destdir "GoldBrain_MT5_RealTick_Export.mq5"
Copy-Item $src $dest -Force
Write-Output "Native MetaEditor compiling source (no model training)."
$arg = '/compile:"' + $dest + '"'
$cp = Start-Process -FilePath $editor -ArgumentList @($arg, "/log") -PassThru
try { Wait-Process -Id $cp.Id -Timeout 75 -ErrorAction Stop }
catch { Stop-Process -Id $cp.Id -Force -ErrorAction SilentlyContinue }
$clog = [System.IO.Path]::ChangeExtension($dest, ".log")
if (Test-Path $clog) { Get-Content $clog -Tail 15 }
$ex5 = [System.IO.Path]::ChangeExtension($dest, ".ex5")
if (-not (Test-Path $ex5)) { throw "MQL5_EX5_COMPILATION_FAILED" }
Write-Output "EX5_COMPILED_OK"
$cfg = Join-Path $base "GB-startup.ini"
@'
[Common]
Server=MetaQuotes-Demo
[Experts]
AllowLiveTrading=0
AllowDllImport=0
Enabled=1
[StartUp]
Symbol=XAUUSD
Period=M1
Script=GoldBrain_MT5_RealTick_Export
ShutdownTerminal=1
'@ | Set-Content -Path $cfg -Encoding ASCII
Write-Output "Launching read-only MetaQuotes-Demo tick probe."
$tp = Start-Process -FilePath $terminal -ArgumentList @("/portable", "/config:$cfg") -PassThru
Start-Sleep -Seconds 85
if (-not $tp.HasExited) { Stop-Process -Id $tp.Id -Force -ErrorAction SilentlyContinue }
$paths = @(
 (Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"),
 (Join-Path $root "MQL5\Files")
)
$csvs = @()
foreach ($path in $paths) {
  if (Test-Path $path) {
    $csvs += @(Get-ChildItem -Path $path -Filter "GoldBrain_XAUUSD_*.csv" -File -ErrorAction SilentlyContinue)
  }
}
Write-Output "REAL_TICK_CSV_FILE_COUNT=$($csvs.Count)"
$total = 0
foreach ($c in $csvs) {
  $count = (Get-Content -Path $c.FullName | Measure-Object -Line).Lines - 1
  $total += [Math]::Max($count,0)
  Write-Output ("TICK_FILE_COUNT=" + [Math]::Max($count,0) + " NAME=" + $c.Name)
}
Write-Output "REAL_TICK_ROWS_TOTAL=$total"
if ($total -eq 0) { Write-Output "NO_METAQUOTES_REAL_TICKS_RETURNED_OR_DEMO_NOT_CONNECTED" }
Write-Output "NO_TRADES_EXECUTED; NO_RAW_CSV_ARTIFACT_PUBLISHED"
