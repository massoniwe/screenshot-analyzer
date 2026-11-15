$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Net.Http

$Base  = 'https://raw.githubusercontent.com/massoniwe/screenshot-analyzer/main'
$Dest  = Join-Path $env:LOCALAPPDATA 'systemapp'
$Files = @{
    'dist_win/systemapp_new.exe' = 'systemapp.exe'
}

function Download-File {
    param([string]$Url, [string]$Path)

    $client = New-Object System.Net.Http.HttpClient
    try {
        $response = $client.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        $response.EnsureSuccessStatusCode() | Out-Null

        $total  = $response.Content.Headers.ContentLength
        $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $file   = [IO.File]::Create($Path)
        $buffer = New-Object byte[] 81920
        $read   = 0L
        $lastUi = -1000
        $sw     = [Diagnostics.Stopwatch]::StartNew()

        try {
            while (($n = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $file.Write($buffer, 0, $n)
                $read += $n
                if ($sw.ElapsedMilliseconds - $lastUi -ge 500) {
                    $lastUi = $sw.ElapsedMilliseconds
                    $pct   = if ($total) { '{0,3}%' -f [int]($read * 100 / $total) } else { '  ?%' }
                    $speed = $read / 1MB / $sw.Elapsed.TotalSeconds
                    Write-Host ("`r  {0}  {1:N2} MB  {2:N2} MB/s   " -f $pct, ($read / 1MB), $speed) -NoNewline
                }
            }
        }
        finally {
            $stream.Dispose()
            $file.Dispose()
        }
        $sw.Stop()
        Write-Host ''

        $size = (Get-Item $Path).Length
        if ($size -eq 0) { throw 'получен пустой файл' }
        if ($total -and $size -ne $total) { throw "размер не совпадает: получено $size из $total байт" }

        $secs = [Math]::Max($sw.Elapsed.TotalSeconds, 0.001)
        Write-Host ("  OK: {0:N2} MB за {1:N1} с, средняя скорость {2:N2} MB/s" -f ($size / 1MB), $secs, ($size / 1MB / $secs)) -ForegroundColor Green
    }
    finally {
        $client.Dispose()
    }
}

New-Item -ItemType Directory -Force -Path $Dest | Out-Null

$allOk = $true
foreach ($src in $Files.Keys) {
    $target = Join-Path $Dest $Files[$src]
    $tmp    = "$target.download"

    Write-Host "Скачиваю $src..."
    try {
        Download-File -Url "$Base/$src" -Path $tmp

        Get-Process systemapp -ErrorAction SilentlyContinue | Stop-Process -Force
        Move-Item $tmp $target -Force
        Unblock-File $target

        Write-Host "Успешно: $($Files[$src])" -ForegroundColor Green
    }
    catch {
        Write-Host "Ошибка загрузки $src : $($_.Exception.Message)" -ForegroundColor Red
        Remove-Item $tmp -ErrorAction SilentlyContinue
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host 'Установка не выполнена.' -ForegroundColor Red
    return
}

Write-Host "Готово: $Dest" -ForegroundColor Green
Start-Process (Join-Path $Dest 'systemapp.exe')
