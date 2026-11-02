param(
    [string]$ReleasePath = 'build/windows/x64/runner/Release',
    [string]$OutputPath = 'ttalk-windows-x64.zip',
    [string]$LauncherPath = 'build/windows/x64/launcher/Release/TTalk.exe'
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
Assert-X64 $LauncherPath
# Stage separately: leave Flutter's build/run layout intact for development.
$staging = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
try {
    $appPath = New-Item (Join-Path $staging 'app') -ItemType Directory -Force
    Copy-Item "$ReleasePath/*" $appPath.FullName -Recurse -Force
    # Older builds may still carry the readme inside their output directory.
    Remove-Item (Join-Path $appPath.FullName 'LIRE-MOI.txt') -ErrorAction SilentlyContinue
    Copy-Item $LauncherPath (Join-Path $staging 'TTalk.exe')
    Copy-Item 'docs/WINDOWS_PACKAGE.txt' (Join-Path $staging 'LIRE-MOI.txt')
    Compress-Archive -Path "$staging/*" -DestinationPath $OutputPath -Force
} finally {
    if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
}
$hash = (Get-FileHash $OutputPath -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([System.IO.Path]::GetFileName($OutputPath))" |
    Set-Content "$OutputPath.sha256" -Encoding ascii

# Validate the archive itself and launch the extracted app without a relay.
$extracted = Join-Path ([System.IO.Path]::GetTempPath()) ('TTalk test ' + [guid]::NewGuid().ToString())
$launcher = $null
$process = $null
$second = $null
try {
    Expand-Archive -Path $OutputPath -DestinationPath $extracted
    $rootEntries = @(Get-ChildItem $extracted | Select-Object -ExpandProperty Name | Sort-Object)
    if (($rootEntries -join '|') -ne 'app|LIRE-MOI.txt|TTalk.exe') {
        throw "Racine du ZIP inattendue : $rootEntries"
    }
    Assert-X64 (Join-Path $extracted 'TTalk.exe')
    $appPath = Join-Path $extracted 'app'
    foreach ($file in @('ttalk.exe', 'flutter_windows.dll', 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll', 'data/app.so', 'data/icudtl.dat')) {
        if (-not (Test-Path (Join-Path $appPath $file))) { throw "ZIP incomplet : $file" }
    }
    # Start from an unrelated working directory, with spaces in the extracted path.
    $launcher = Start-Process (Join-Path $extracted 'TTalk.exe') -WorkingDirectory $env:SystemRoot -PassThru
    Start-Sleep -Seconds 8
    $launcher.Refresh()
    if ($launcher.HasExited) { throw "Le lanceur s’est arrêté : $($launcher.ExitCode)" }
    $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $($launcher.Id) AND Name = 'ttalk.exe'")
    if ($children.Count -ne 1) { throw 'Le lanceur ne démarre pas une application unique' }
    $process = Get-Process -Id $children[0].ProcessId
    if ($process.Path -ne (Join-Path $appPath 'ttalk.exe')) { throw 'Application lancée depuis un chemin inattendu' }
    $process.Refresh()
    if ($process.HasExited) { throw "TTalk s’est arrêté au démarrage : $($process.ExitCode)" }
    if ($process.MainWindowHandle -eq 0) { throw "La fenêtre TTalk ne s’est pas ouverte" }
    $second = Start-Process (Join-Path $extracted 'TTalk.exe') -WorkingDirectory $env:SystemRoot -PassThru
    if (-not $second.WaitForExit(5000)) {
        Stop-Process -Id $second.Id -Force
        throw 'Une deuxième instance peut accéder au même coffre'
    }
    if ($second.ExitCode -ne 0) { throw 'Le contrôle de seconde instance a échoué' }
    Write-Host "Package x64 vérifié ; fenêtre ouverte hors ligne. SHA256 : $hash"
} finally {
    foreach ($owned in @($second, $process, $launcher)) {
        if ($null -eq $owned) { continue }
        if (-not $owned.HasExited) {
            # The launcher may exit naturally as soon as its child is stopped.
            # Kill through the owned process handle and tolerate that exact race.
            try { $owned.Kill() } catch {
                if (-not $owned.HasExited) { throw }
            }
        }
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
