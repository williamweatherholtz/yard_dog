# Yard Dog installer (Windows) — downloads the release binary, verifies its
# SHA256 against the published SHA256SUMS, and installs it to a per-user dir.
#   irm https://raw.githubusercontent.com/williamweatherholtz/yard_dog/main/install.ps1 | iex
$ErrorActionPreference = 'Stop'
$repo  = 'williamweatherholtz/yard_dog'
$asset = 'yd-x86_64-windows.exe'

Write-Host 'yd: resolving latest release...'
$tag  = (Invoke-RestMethod -Headers @{ 'User-Agent' = 'yd-install' } "https://api.github.com/repos/$repo/releases/latest").tag_name
if (-not $tag) { throw 'could not resolve latest release' }
$base = "https://github.com/$repo/releases/download/$tag"

$tmp  = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ("yd-" + [System.Guid]::NewGuid()))
$bin  = Join-Path $tmp 'yd.exe'
$sums = Join-Path $tmp 'SHA256SUMS'
Write-Host "yd: downloading $asset ($tag)..."
Invoke-WebRequest -Headers @{ 'User-Agent' = 'yd-install' } "$base/$asset"      -OutFile $bin
Invoke-WebRequest -Headers @{ 'User-Agent' = 'yd-install' } "$base/SHA256SUMS"  -OutFile $sums

$want = ((Get-Content $sums | Where-Object { $_ -match [regex]::Escape($asset) }) -split '\s+')[0]
$got  = (Get-FileHash $bin -Algorithm SHA256).Hash.ToLower()
if (-not $want) { throw "no checksum for $asset in SHA256SUMS" }
if ($want -ne $got) { throw "SHA256 mismatch - refusing to install (want $want got $got)" }
Write-Host 'yd: checksum OK'

$dest = Join-Path $env:LOCALAPPDATA 'Programs\yd'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item $bin (Join-Path $dest 'yd.exe') -Force
Remove-Item -Recurse -Force $tmp
Write-Host "yd: installed $tag to $dest\yd.exe"

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$dest*") {
  [Environment]::SetEnvironmentVariable('Path', "$userPath;$dest", 'User')
  Write-Host "yd: added $dest to your user PATH (restart the shell to pick it up)"
}
