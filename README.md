# Smart Roblox NPC System

A sandbox NPC framework with a **standalone `.rbxmx` Studio plugin**. The plugin contains built-in copies of the framework scripts for offline installation, with optional authenticated updates from this private repository.

## Install the plugin

1. On Windows, install GitHub CLI and run `gh auth login` with repository access.
2. Run `Install-SmartNPCPlugin.bat`. It downloads the plugin source and packages it as `%LOCALAPPDATA%\Roblox\Plugins\SmartNPCInstaller.rbxmx`. This user plugin folder also works when Studio is launched through Bloxstrap.
3. Restart Studio. Open **Plugins > Smart NPC System**.
4. Choose **Install bundled scripts** for the embedded offline version. No token or HTTP access is needed for this mode.
5. Optionally enter a fine-grained token restricted to this repository with **Contents: Read-only**, then choose **Fetch latest from private GitHub** to update beyond the embedded bundle. The plugin clears the text field after fetching and doesn't save the token.

The `.rbxmx` plugin includes its bundled config, NPC controller, interaction/memory script, owner authorization server script, and TopbarPlus control panel LocalScript. Extracted scripts are installed into `ServerScriptService.SmartNPCSystem` and `StarterPlayerScripts`.

## Requirements in the place

- `ServerStorage.NPC`: unanchored rig Model with `Humanoid` and `HumanoidRootPart`.
- `Workspace.NPCSpawnRegion`: BasePart covering the desired spawn area.
- For the owner panel, install TopbarPlus v3 (1ForeverHD/TopbarPlus) in `ReplicatedStorage` as `Icon` or `Packages.TopbarPlus`.
- Optional content folders: `ServerStorage.NPCGear`, `ServerStorage.NPCLoot`, `ServerStorage.NPCShopItems`; `Workspace.NPCPatrols`.

## Features

Configurable population and respawn; gear and melee/ranged weapon stats; pathfinding; idle, roaming, chase, investigate, search, flee, and return behaviors; line-of-sight and stealth detection; emotions; dialogue prompts and persistent NPC recognition; shops and quests; coins/reputation persistence; TopbarPlus owner control panel with server-validated AI/spawn toggles, recall, heal, and NPC status. Access checks are performed by the server for game creator, group owner, private server owner, and explicitly configured admin IDs.

This is a starter framework: test the bundled version in a private Studio session, enable Studio API access for DataStore tests, and review scripts before publishing. The bundled source is a snapshot; use the authenticated update option to fetch current repository scripts.
