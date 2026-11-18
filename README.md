# Smart Roblox NPC System

A Rojo-ready Roblox NPC package with a local Studio plugin that fetches the actual scripts from this repository.

## Install on Windows

1. Download `Install-SmartNPCPlugin.bat` and `Install-SmartNPCPlugin.ps1` (or clone/download the repo).
2. Run the batch file. It locates the per-user Roblox Studio Plugins directory (Bloxstrap normally uses the same user plugin directory), downloads `plugin/SmartNPCInstaller.lua` from this repository, and installs the local plugin file.
3. Restart Studio. Under **Plugins > Smart NPC System**, click the toolbar button. The plugin fetches the current config and controller scripts from this repo and writes them into `ServerScriptService.SmartNPCSystem`.
4. In Studio, enable **Game Settings > Security > Allow HTTP Requests** if plugin HTTP downloads are blocked.

The installer only installs the local plugin file. The plugin only edits the currently open place after you click its button. Review the Lua sources before installing if you want to inspect the code first.

## Required place setup

- `ServerStorage.NPC`: a Model with a `Humanoid` and `HumanoidRootPart`. Keep its body parts unanchored.
- `Workspace.NPCSpawnRegion`: a `BasePart` covering the spawn area.
- Optional `ServerStorage.NPCGear`: Tools with optional numeric `Damage`, `Range`, and `Cooldown` attributes.

The package spawns 15 NPCs by default. It includes configurable spawning and respawning, random gear with per-tool combat stats, line-of-sight target detection, faction filtering, pathfinding chase, attacks, idle/wander, last-known-position investigation, searching, returning home, emotion/state attributes, and optional overhead emotion labels.

## Configuration

Edit `src/ServerScriptService/SmartNPCSystem/NPCConfig.lua` in the repository. When the plugin runs again, it fetches the latest repository version and updates the installed `NPCConfig` and `NPCController` scripts.

## Possible future features

Dialogue and interaction prompts; quests and schedules; patrol routes and guard posts; group alerts and ally support; ranged weapons, ammo and reloads; animation support; alertness/hearing and stealth; cover-taking and dodge behavior; combat roles/classes; loot drops and inventory; reputation/faction relationships; NPC shops; saveable NPC/player reputation; admin controls and spawn zones; performance budgets and debug visualization.

## Notes

- The batch installer is for Windows and requires PowerShell and internet access.
- Restart Studio after installing or updating the local plugin.
- Test in Studio's server mode and back up your place before publishing.
