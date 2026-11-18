$ErrorActionPreference = 'Stop'
$repo = 'Knight1253/smart-roblox-npc-system'
$branch = 'main'
$pluginPath = 'plugin/SmartNPCInstaller.lua'
$apiUrl = "https://api.github.com/repos/$repo/contents/$pluginPath`?ref=$branch"
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'GitHub CLI (gh) is required. Install gh, run gh auth login, then retry.' }
$token = (& gh auth token --hostname github.com 2>$null | Select-Object -First 1).Trim()
if (-not $token) { throw 'No GitHub CLI login. Run gh auth login with access to this private repository.' }
$headers = @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json'; 'X-GitHub-Api-Version' = '2022-11-28'; 'User-Agent' = 'SmartRobloxNPCPluginInstaller' }
try { $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get } finally { $headers.Authorization = $null; $token = $null }
if (-not $response.content) { throw 'GitHub returned no plugin source.' }
$source = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($response.content -replace '\s','')))
$pluginsDir = Join-Path $env:LOCALAPPDATA 'Roblox\Plugins'
New-Item -ItemType Directory -Force -Path $pluginsDir | Out-Null
$pluginFile = Join-Path $pluginsDir 'SmartNPCInstaller.rbxmx'
$escaped = [System.Security.SecurityElement]::Escape($source)
$xml = @"
<?xml version="1.0" encoding="utf-8"?>
<roblox version="4">
  <External>null</External>
  <External>nil</External>
  <Item class="Script" referent="RBXSMARTNPCPLUGIN">
    <Properties>
      <bool name="Disabled">false</bool>
      <string name="Name">SmartNPCInstaller</string>
      <ProtectedString name="Source">$escaped</ProtectedString>
    </Properties>
  </Item>
</roblox>
"@
[System.IO.File]::WriteAllText($pluginFile,$xml,[System.Text.UTF8Encoding]::new($false))
Write-Host "Installed standalone .rbxmx plugin: $pluginFile"
Write-Host 'The plugin includes offline bundled scripts; a token is only needed for optional latest-repo updates.'
Write-Host 'Restart Roblox Studio to load it.'
