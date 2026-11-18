# Smart Roblox NPC System

A private, Rojo-ready Roblox NPC starter and Windows local-plugin installer.

## Install the Studio plugin (Windows)

1. Download this repository or its `Install-SmartNPCPlugin.bat` and `Install-SmartNPCPlugin.ps1` files.
2. Run `Install-SmartNPCPlugin.bat`. It downloads the plugin source from this repository's `main` branch, packages it as a Roblox XML model, and places it in `%LOCALAPPDATA%\Roblox\Plugins`.
3. Restart Roblox Studio. Use **Plugins > Smart NPC System** and click the toolbar button to add/update the server scripts in the currently open place.

The installer only writes the local plugin file; the plugin changes the open place only when you click its install button. Review the source before running if you prefer to audit what it installs.

## Place requirements

- `ServerStorage.NPC`: a Model with a `Humanoid` and `HumanoidRootPart`.
- `Workspace.NPCSpawnRegion`: a BasePart covering the desired spawn area.
- Optional `ServerStorage.NPCGear`: Tools. Each Tool can have numeric `Damage`, `Range`, and `Cooldown` attributes.
- NPC model parts should be unanchored.

The installed package appears under `ServerScriptService.SmartNPCSystem` and includes `NPCConfig` plus `NPCController`. It spawns 15 NPCs by default, supports idle/roam/investigate/search/chase/attack/return states, configurable gear and factions, emotion/state attributes, and respawning.

## Notes

- The batch installer is for Windows and requires PowerShell and internet access.
- Restart Studio after installing/updating the local plugin.
- Run a Studio server test before publishing. Back up your place first.
- This project does not silently download or install Roblox Studio itself or modify other place files.
