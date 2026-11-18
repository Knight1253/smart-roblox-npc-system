$ErrorActionPreference = 'Stop'
$repo = 'Knight1253/smart-roblox-npc-system'
$branch = 'main'
$pluginPath = 'plugin/SmartNPCInstaller.lua'
$apiUrl = "https://api.github.com/repos/$repo/contents/$pluginPath`?ref=$branch"

# Use GitHub CLI's existing OAuth session. Never write the credential to the
# plugin file or pass it on a command line as an argument.
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) is required to install this private-repository plugin. Install gh, run gh auth login, then retry.'
}
$token = (& gh auth token --hostname github.com 2>$null | Select-Object -First 1).Trim()
if (-not $token) {
    throw 'No GitHub CLI login found. Run gh auth login and ensure the account can read Knight1253/smart-roblox-npc-system.'
}

$headers = @{
    Authorization = "Bearer $token"
    Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent' = 'SmartRobloxNPCPluginInstaller'
}
Write-Host "Downloading local Studio plugin from private repo $repo..."
try {
    $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
} finally {
    $token = $null
    $headers.Authorization = $null
}
if (-not $response.content) { throw 'GitHub returned no plugin source. Check repository permissions and branch.' }
$encoded = ($response.content -replace '\s', '')
$source = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))

# Studio's Windows user Plugins directory is shared by the official Studio
# client and Bloxstrap-launched Studio. Bloxstrap changes the Roblox install,
# not the per-user plugin location.
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
[System.IO.File]::WriteAllText($pluginFile, $xml, [System.Text.UTF8Encoding]::new($false))
Write-Host "Installed plugin to: $pluginFile"
Write-Host 'The GitHub credential was used only for this download and was not saved in the plugin.'
Write-Host 'Restart Roblox Studio. The plugin will prompt for a fine-grained, read-only repo token when fetching scripts.'
