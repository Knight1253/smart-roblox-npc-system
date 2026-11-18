$ErrorActionPreference = 'Stop'
$repo = 'Knight1253/smart-roblox-npc-system'
$branch = 'main'
$pluginsDir = Join-Path $env:LOCALAPPDATA 'Roblox\Plugins'
New-Item -ItemType Directory -Force -Path $pluginsDir | Out-Null

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'GitHub CLI (gh) is required. Install gh, run gh auth login, then retry.' }
$token = (& gh auth token --hostname github.com 2>$null | Select-Object -First 1).Trim()
if (-not $token) { throw 'No GitHub CLI login. Run gh auth login with access to this private repository.' }
$headers = @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json'; 'X-GitHub-Api-Version' = '2022-11-28'; 'User-Agent' = 'SmartRobloxNPCPluginInstaller' }

function Install-PluginFile([string]$sourcePath, [string]$outputName, [string]$referent) {
    $url = "https://api.github.com/repos/$repo/contents/$sourcePath`?ref=$branch"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    if (-not $response.content) { throw "GitHub returned no contents for $sourcePath" }
    $source = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($response.content -replace '\s','')))
    $escaped = [System.Security.SecurityElement]::Escape($source)
    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<roblox version="4">
  <External>null</External>
  <External>nil</External>
  <Item class="Script" referent="$referent">
    <Properties>
      <bool name="Disabled">false</bool>
      <string name="Name">$outputName</string>
      <ProtectedString name="Source">$escaped</ProtectedString>
    </Properties>
  </Item>
</roblox>
"@
    $destination = Join-Path $pluginsDir "$outputName.rbxmx"
    [System.IO.File]::WriteAllText($destination, $xml, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Installed $outputName to $destination"
}

try {
    Install-PluginFile 'plugin/SmartNPCInstaller.lua' 'SmartNPCInstaller' 'RBXSMARTNPCPLUGIN'
    Install-PluginFile 'plugin/TopbarPlusAssetInstaller.lua' 'TopbarPlusAssetInstaller' 'RBXTOPBARPLUSINSTALLER'
    Install-PluginFile 'plugin/SmartNPCDiagnostics.lua' 'SmartNPCDiagnostics' 'RBXSMARTNPCDIAGNOSTICS'
    Install-PluginFile 'plugin/UniversalStudioMonitor.lua' 'UniversalStudioMonitor' 'RBXUNIVERSALSTUDIOMONITOR'
} finally {
    $headers.Authorization = $null
    $token = $null
}
Write-Host 'Restart Roblox Studio. Use Universal Studio Monitor for project-independent Output capture; NPC setup remains in Smart NPC Diagnostics.'
