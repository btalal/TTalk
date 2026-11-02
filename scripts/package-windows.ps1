param(
    [string]$ReleasePath = 'build/windows/x64/runner/Release',
    [string]$OutputPath = 'ttalk-windows-x64.zip'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-X64([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $Path))
    if ($bytes.Length -lt 64 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) {
        throw "Fichier PE invalide : $Path"
    }
    $offset = [BitConverter]::ToInt32($bytes, 0x3c)
    if ($offset -lt 0 -or $offset + 6 -gt $bytes.Length -or
        [BitConverter]::ToUInt32($bytes, $offset) -ne 0x4550 -or
        [BitConverter]::ToUInt16($bytes, $offset + 4) -ne 0x8664) {
        throw "Binaire Windows x64 attendu : $Path"
    }
}

foreach ($file in @('ttalk.exe', 'flutter_windows.dll', 'data/icudtl.dat', 'data/app.so')) {
    if (-not (Test-Path (Join-Path $ReleasePath $file) -PathType Leaf)) {
        throw "Fichier indispensable absent : $file"
    }
}
if (-not (Test-Path (Join-Path $ReleasePath 'data/flutter_assets') -PathType Container)) {
    throw 'Assets Flutter absents'
}
Assert-X64 (Join-Path $ReleasePath 'ttalk.exe')
Assert-X64 (Join-Path $ReleasePath 'flutter_windows.dll')

# Bundle the redistributable x64 CRT from the Visual Studio installation.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or -not $vs) { throw 'Installation MSVC introuvable' }
$redist = Join-Path $vs 'VC/Redist/MSVC'
$runtime = Get-ChildItem $redist -Directory |
    Where-Object { $_.Name -match '^\d+(\.\d+){1,3}$' } |
    Sort-Object { [version]$_.Name } -Descending |
    ForEach-Object { Join-Path $_.FullName 'x64/Microsoft.VC143.CRT' } |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $runtime) { $runtime = Join-Path $redist 'v143/x64/Microsoft.VC143.CRT' }
if (-not (Test-Path $runtime)) { throw 'Runtime Microsoft VC143 x64 introuvable' }
foreach ($dll in Get-ChildItem $runtime -Filter '*.dll' -File) {
    Copy-Item $dll.FullName $ReleasePath -Force
    Assert-X64 (Join-Path $ReleasePath $dll.Name)
}
Copy-Item 'docs/WINDOWS_PACKAGE.txt' (Join-Path $ReleasePath 'LIRE-MOI.txt') -Force

Compress-Archive -Path "$ReleasePath/*" -DestinationPath $OutputPath -Force
$hash = (Get-FileHash $OutputPath -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([System.IO.Path]::GetFileName($OutputPath))" |
    Set-Content "$OutputPath.sha256" -Encoding ascii

# Validate the archive itself and launch the extracted app without a relay.
$extracted = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
$process = $null
$second = $null
try {
    Expand-Archive -Path $OutputPath -DestinationPath $extracted
    foreach ($file in @('ttalk.exe', 'flutter_windows.dll', 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll', 'data/app.so', 'data/icudtl.dat')) {
        if (-not (Test-Path (Join-Path $extracted $file))) { throw "ZIP incomplet : $file" }
    }
    $process = Start-Process (Join-Path $extracted 'ttalk.exe') -WorkingDirectory $extracted -PassThru
    Start-Sleep -Seconds 8
    $process.Refresh()
    if ($process.HasExited) { throw "TTalk s’est arrêté au démarrage : $($process.ExitCode)" }
    if ($process.MainWindowHandle -eq 0) { throw "La fenêtre TTalk ne s’est pas ouverte" }
    $second = Start-Process (Join-Path $extracted 'ttalk.exe') -WorkingDirectory $extracted -PassThru
    if (-not $second.WaitForExit(5000)) {
        Stop-Process -Id $second.Id -Force
        throw 'Une deuxième instance peut accéder au même coffre'
    }
    if ($second.ExitCode -ne 0) { throw 'Le contrôle de seconde instance a échoué' }
    Write-Host "Package x64 vérifié ; fenêtre ouverte hors ligne. SHA256 : $hash"
} finally {
    foreach ($owned in @($second, $process)) {
        if ($null -eq $owned) { continue }
        if (-not $owned.HasExited) { Stop-Process -Id $owned.Id -Force }
        if (-not $owned.WaitForExit(10000)) { throw 'Le processus de test ne se ferme pas' }
        $owned.Dispose()
    }
    # Windows can release executable mappings shortly after TerminateProcess.
    for ($attempt = 0; $attempt -lt 5; $attempt++) {
        try {
            if (Test-Path $extracted) { Remove-Item $extracted -Recurse -Force }
            break
        } catch {
            if ($attempt -eq 4) { throw }
            Start-Sleep -Milliseconds 250
        }
    }
}
