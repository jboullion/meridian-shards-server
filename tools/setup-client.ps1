# Prepares upstream's Windows client in run\localclient (git-ignored) to play on our server.
# Build it first:  tools\build.cmd Bclient Bmodules   (and tools\build.cmd for the server and Kod)
#
#   powershell -File tools\setup-client.ps1 -ArtFolder "H:\Steam\steamapps\common\Meridian 59\resource"
#
# What goes where, and why:
#   - Art (bgf, ogg, wav, bsf, mp3, mid, xmi) comes from an installed client, e.g. the Steam one.
#     It never goes in git (AGENTS.md).
#   - Rooms come from this repo's resource\rooms, the same files the server reads, so the
#     room checksums match.
#   - Strings come from OUR Kod build. The build copies the .rsc files into the client
#     already, and this script merges them into rsc0000.rsb (the file our other clients
#     download). An installed client's rsc0000.rsb is never copied: its names and ids come
#     from someone else's build.
# Safe to run again: robocopy copies only changed files.
param(
    [Parameter(Mandatory = $true)][string]$ArtFolder
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dest = Join-Path $root 'run\localclient\resource'

if (-not (Test-Path (Join-Path $root 'run\localclient\meridian.exe'))) {
    throw 'run\localclient\meridian.exe is missing; build it with: tools\build.cmd Bclient Bmodules'
}
if (-not (Test-Path (Join-Path $ArtFolder '*.bgf'))) {
    throw "No .bgf files in $ArtFolder; point -ArtFolder at an installed client's resource folder."
}

# robocopy exit codes below 8 mean success
function Copy-Files([string]$from, [string[]]$patterns) {
    robocopy $from $dest @patterns /NJH /NJS /NDL /NFL /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy from $from failed ($LASTEXITCODE)" }
}

Write-Host "Copying art from $ArtFolder"
Copy-Files $ArtFolder @('*.bgf', '*.ogg', '*.wav', '*.bsf', '*.mp3', '*.mid', '*.xmi')

Write-Host 'Copying rooms from resource\rooms'
Copy-Files (Join-Path $root 'resource\rooms') @('*.roo')

Write-Host 'Merging our Kod strings into rsc0000.rsb'
if (-not (Test-Path (Join-Path $root 'run\server\rsc\*.rsc'))) {
    throw 'No .rsc files in run\server\rsc; build the Kod first: tools\build.cmd'
}
# A wildcard, not a file list: 1,100+ paths overflow the command line, and rscmerge
# expands wildcards itself (linked with setargv.obj, util/makefile:32)
& (Join-Path $root 'bin\rscmerge.exe') -o (Join-Path $dest 'rsc0000.rsb') (Join-Path $root 'run\server\rsc\*.rsc')
if ($LASTEXITCODE -ne 0) { throw "rscmerge failed ($LASTEXITCODE)" }

$count = (Get-ChildItem $dest -File).Count
Write-Host "Client ready: $count files in run\localclient\resource"
Write-Host 'Play on the local Shards server with:'
Write-Host '  cd run\localclient; .\meridian.exe /H:localhost /P:5960'
