$ErrorActionPreference = 'Stop'
$repo = 'Knight1253/smart-roblox-npc-system'
$branch = 'main'
$rawBase = "https://raw.githubusercontent.com/$repo/$branch"
$pluginSourceUrl = "$rawBase/plugin/SmartNPCInstaller.lua"

function Get-StudioPluginDirectories {
    $candidates = [System.Collections.Generic.List[string]]::new()

    # Standard Roblox/Bloxstrap user-data locations. Bloxstrap normally launches
    # the official Studio executable and does not change this shared user plugin path.
    if ($env:LOCALAPPDATA) {
        $candidates.Add((Join-Path $env:LOCALAPPDATA 'Roblox\Plugins'))
    }

    # Honor an explicitly configured Studio/Roblox data directory if present.
    foreach ($name in @('BLOXSTRAP_ROBLOX_PATH', 'ROBLOX_APP_DATA')) {
        $value = [Environment]::GetEnvironmentVariable($name)
        if ($value) {
            $candidates.Add((Join-Path $value 'Plugins'))
            $candidates.Add((Join-Path $value 'Roblox\Plugins'))
        }
    }

    # Look up the Studio install location for diagnostics and possible custom
    # user-data layouts. Never install into the application install directory.
    $studioRoots = [System.Collections.Generic.List[string]]::new()
    $uninstallKeys = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($key in $uninstallKeys) {
        if (Test-Path $key) {
            Get-ItemProperty $key -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -match 'Roblox' -and $_.InstallLocation } |
                ForEach-Object { $studioRoots.Add([string]$_.InstallLocation) }
        }
    }

    $bloxstrapSettings = @(
        (Join-Path $env:LOCALAPPDATA 'Bloxstrap\Settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Bloxstrap\Modifications\ClientSettings\ClientAppSettings.json')
    )
    foreach ($settingsFile in $bloxstrapSettings) {
        if (Test-Path $settingsFile) {
            try {
                $settings = Get-Content -Raw $settingsFile | ConvertFrom-Json
                foreach ($property in @(' RobloxPath', 'RobloxPath', 'InstallLocation', 'DataDirectory')) {
                    $value = $settings.$property
                    if ($value -and (Test-Path $value)) { $studioRoots.Add([string]$value) }
                }
            } catch {
                Write-Verbose "Couldn't parse optional Bloxstrap settings at $settingsFile"
            }
        }
    }

    # Roblox plugins are user-specific, not stored beside the Studio binary.
    # Include the standard path first; add any user-profile Roblox data folders
    # found while inspecting custom Bloxstrap/Studio locations as fallbacks.
    foreach ($root in $studioRoots) {
        if ($root -and (Test-Path $root)) {
            $parent = Split-Path -Parent $root
            if ($parent -and (Split-Path -Leaf $parent) -eq 'Versions') {
                $candidates.Add((Join-Path (Split-Path -Parent $parent) 'Plugins'))
            }
        }
    }

    $seen = @{}
    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            $full = [System.IO.Path]::GetFullPath($candidate)
            if (-not $seen.ContainsKey($full)) {
                $seen[$full] = $true
                Write-Host "Checking Studio plugin location: $full"
                return $full
            }
        }
    }

    throw 'Could not determine the Roblox Studio plugin directory. Set LOCALAPPDATA or check your Windows user profile.'
}

$pluginsDir = Get-StudioPluginDirectories
New-Item -ItemType Directory -Force -Path $pluginsDir | Out-Null

$tempSource = Join-Path $env:TEMP 'SmartNPCInstaller.lua'
$pluginFile = Join-Path $pluginsDir 'SmartNPCInstaller.rbxmx'

Write-Host "Downloading Smart NPC Installer from $repo..."
Invoke-WebRequest -Uri $pluginSourceUrl -OutFile $tempSource
$source = [System.IO.File]::ReadAllText($tempSource)
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
Write-Host 'Bloxstrap normally uses the same per-user Roblox Studio Plugins directory.'
Write-Host 'Restart Roblox Studio to load it. In Studio, use Plugins > Smart NPC System.'
