[CmdletBinding()]
param(
    [string]$ArchivePath,
    [switch]$SkipSettings
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget is required. Install App Installer from Microsoft Store, then run this command again.'
}

$packages = @(
    @{ Name = 'Git'; Id = 'Git.Git' },
    @{ Name = 'GitHub CLI'; Id = 'GitHub.cli' },
    @{ Name = 'GitHub Desktop'; Id = 'GitHub.GitHubDesktop' },
    @{ Name = 'Windows Terminal'; Id = 'Microsoft.WindowsTerminal' },
    @{ Name = 'Visual Studio Code'; Id = 'Microsoft.VisualStudioCode' },
    @{ Name = 'Windsurf'; Id = 'Codeium.Windsurf' },
    @{ Name = 'Zed'; Id = 'ZedIndustries.Zed' },
    @{ Name = 'Node.js LTS'; Id = 'OpenJS.NodeJS.LTS' },
    @{ Name = 'Python 3.13'; Id = 'Python.Python.3.13' },
    @{ Name = 'Ollama'; Id = 'Ollama.Ollama' },
    @{ Name = 'ChatGPT'; Id = 'OpenAI.ChatGPT' },
    @{ Name = 'Firefox'; Id = 'Mozilla.Firefox' },
    @{ Name = 'Google Chrome'; Id = 'Google.Chrome' },
    @{ Name = 'Brave'; Id = 'Brave.Brave' },
    @{ Name = 'Vivaldi'; Id = 'Vivaldi.Vivaldi' },
    @{ Name = 'Yandex Browser'; Id = 'Yandex.Browser' },
    @{ Name = 'Spotify'; Id = 'Spotify.Spotify' },
    @{ Name = 'Discord'; Id = 'Discord.Discord' },
    @{ Name = 'Telegram'; Id = 'Telegram.TelegramDesktop' },
    @{ Name = 'Vesktop'; Id = 'Vencord.Vesktop' },
    @{ Name = 'LocalSend'; Id = 'LocalSend.LocalSend' },
    @{ Name = 'OBS Studio'; Id = 'OBSProject.OBSStudio' },
    @{ Name = 'GIMP'; Id = 'GIMP.GIMP' },
    @{ Name = 'LibreOffice'; Id = 'TheDocumentFoundation.LibreOffice' },
    @{ Name = 'Obsidian'; Id = 'Obsidian.Obsidian' },
    @{ Name = 'qBittorrent'; Id = 'qBittorrent.qBittorrent' },
    @{ Name = 'Steam'; Id = 'Valve.Steam' },
    @{ Name = 'Modrinth App'; Id = 'Modrinth.ModrinthApp' },
    @{ Name = 'Cloudflare WARP'; Id = 'Cloudflare.Warp' },
    @{ Name = 'Termius'; Id = 'Termius.Termius' },
    @{ Name = 'Wireshark'; Id = 'WiresharkFoundation.Wireshark' },
    @{ Name = 'Audacity'; Id = 'Audacity.Audacity' },
    @{ Name = 'Windows Subsystem for Linux'; Id = 'Microsoft.WSL' }
)

$failed = [System.Collections.Generic.List[string]]::new()
foreach ($package in $packages) {
    Write-Host "Installing $($package.Name)…" -ForegroundColor Cyan
    & winget install --id $package.Id --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        $failed.Add($package.Name)
        Write-Warning "Could not install $($package.Name). It may be unavailable in winget or require a manual installer."
    }
}

if (-not $SkipSettings -and -not $ArchivePath) {
    $archiveDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) 'archive'
    $archives = @(Get-ChildItem -LiteralPath $archiveDirectory -Filter '*.age' -File -ErrorAction SilentlyContinue)
    if ($archives.Count -eq 1) {
        $ArchivePath = $archives[0].FullName
    }
    elseif ($archives.Count -gt 1) {
        Write-Warning 'Several encrypted archives were found in archive/. Settings were not restored; pass -ArchivePath explicitly.'
    }
}

if (-not $SkipSettings -and $ArchivePath) {
    $restoreScript = Join-Path $PSScriptRoot 'Restore-WindowsSettings.ps1'
    & $restoreScript -ArchivePath $ArchivePath
}

if ($failed.Count -gt 0) {
    Write-Host "Not installed automatically: $($failed -join ', ')" -ForegroundColor Yellow
}

Write-Host 'Windows setup completed. Sign in to apps and enable browser sync.' -ForegroundColor Green
