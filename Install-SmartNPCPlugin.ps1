$ErrorActionPreference = 'Stop'
$repo = 'Knight1253/smart-roblox-npc-system'
$branch = 'main'
$rawBase = "https://raw.githubusercontent.com/$repo/$branch"
$pluginSourceUrl = "$rawBase/plugin/SmartNPCInstaller.lua"

# Roblox Studio's local plugins folder on Windows.
$pluginsDir = Join-Path $env:LOCALAPPDATA 'Roblox\Plugins'
New-Item -ItemType Directory -Force -Path $pluginsDir | Out-Null

$tempSource = Join-Path $env:TEMP 'SmartNPCInstaller.lua'
$pluginFile = Join-Path $pluginsDir 'SmartNPCInstaller.rbxmx'

Write-Host "Downloading Smart NPC Installer from $repo..."
Invoke-WebRequest -Uri $pluginSourceUrl -OutFile $tempSource
$source = [System.IO.File]::ReadAllText($tempSource)

# Escape source as XML text in a Roblox model file. CDATA is split safely if
# the source ever contains the CDATA closing sequence.
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
Remove-Item $tempSource -Force -ErrorAction SilentlyContinue
Write-Host "Installed local plugin file: $pluginFile"
Write-Host 'Restart Roblox Studio to load it. In Studio, use Plugins > Smart NPC System.'
