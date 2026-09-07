[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$ArchivePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require-Command([string]$Name, [string]$WingetId) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        & winget install --id $WingetId --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -ne 0) { throw "Could not install required tool: $Name" }
    }
}

function Copy-PortableSettings([string]$Source, [string]$Destination) {
    if (-not (Test-Path $Source -PathType Container)) { return }
    $backup = "$Destination.before-arch-migration-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if (Test-Path $Destination) {
        Copy-Item $Destination $backup -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Get-ChildItem -LiteralPath $Source -Force | Copy-Item -Destination $Destination -Recurse -Force
    Write-Host "Restored $Destination" -ForegroundColor Cyan
}

Require-Command 'age' 'FiloSottile.age'
Require-Command 'zstd' 'Facebook.Zstandard'

$staging = Join-Path $PSScriptRoot '.restore-staging'
Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $staging -Force | Out-Null

try {
    Write-Host 'Decrypting archive. age will ask for its password…' -ForegroundColor Cyan
    & age -d $ArchivePath | & zstd -d -c | & tar -xf - -C $staging
    if ($LASTEXITCODE -ne 0) { throw 'Could not decrypt or extract the archive.' }

    $config = Join-Path $staging '.config'
    $appData = $env:APPDATA

    Copy-PortableSettings (Join-Path $config 'Code/User') (Join-Path $appData 'Code/User')
    Copy-PortableSettings (Join-Path $config 'Windsurf/User') (Join-Path $appData 'Windsurf/User')
    Copy-PortableSettings (Join-Path $config 'zed') (Join-Path $appData 'Zed')
    Copy-PortableSettings (Join-Path $config 'obsidian') (Join-Path $appData 'obsidian')
    Copy-PortableSettings (Join-Path $config 'qBittorrent') (Join-Path $appData 'qBittorrent')
    Copy-PortableSettings (Join-Path $config 'libreoffice') (Join-Path $appData 'LibreOffice')
    Copy-PortableSettings (Join-Path $config 'GIMP') (Join-Path $appData 'GIMP')
    Copy-PortableSettings (Join-Path $config 'GitHub Desktop') (Join-Path $appData 'GitHub Desktop')
    Copy-PortableSettings (Join-Path $config 'vesktop') (Join-Path $appData 'Vesktop')

    $gitConfig = Join-Path $config 'git/config'
    if (Test-Path $gitConfig -PathType Leaf) {
        Copy-Item $gitConfig (Join-Path $env:USERPROFILE '.gitconfig') -Force
        Write-Host 'Restored Git configuration.' -ForegroundColor Cyan
    }

    Write-Host 'Compatible settings restored. Browser profiles were intentionally skipped; use browser sync.' -ForegroundColor Green
}
finally {
    Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
}
