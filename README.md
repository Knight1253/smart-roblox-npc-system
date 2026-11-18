# Smart Roblox NPC System

A configurable sandbox NPC framework. The Studio plugin fetches the maintained source files from this repository.

## Install on Windows

1. Download `Install-SmartNPCPlugin.bat` and `Install-SmartNPCPlugin.ps1`.
2. Run the batch file to install the local plugin, then restart Studio.
3. Click **Plugins > Smart NPC System**. The plugin downloads the config and runtime scripts from GitHub and installs them under `ServerScriptService.SmartNPCSystem`.
4. Allow HTTP requests in Studio if prompted. **GitHub raw download requires the repository to be publicly readable**; don't put a personal access token in a plugin.

## Required place setup

- `ServerStorage.NPC`: unanchored rig Model with `Humanoid` and `HumanoidRootPart`.
- `Workspace.NPCSpawnRegion`: BasePart covering the random spawn area.

## Optional content

- `ServerStorage.NPCGear`: Tools with attributes `WeaponType` (Melee/Ranged), `Damage`, `Range`, `Cooldown`, `MagazineSize`, and `ReloadTime`.
- `ServerStorage.NPCLoot`: Tools eligible for random death drops.
- `ServerStorage.NPCShopItems`: purchasable Tools with numeric `Price` attributes.
- `Workspace.NPCPatrols`: route folders containing ordered BaseParts. Set an NPC's `PatrolRoute` attribute to a route folder name; otherwise its faction or `Default` route is used.
- `Workspace.NPCNoise`: optional BindableEvent; server scripts can call `Fire(position, radius, source)` to make NPCs investigate a sound.
- NPC model attributes: `Faction`, `DialogueText`, `ShopEnabled`, `QuestName`, `QuestGoal`, `QuestReward`, `QuestTargetName`.
- Players may use a `Stealth` character attribute; it reduces NPC visual detection range.
- Put authorized user IDs in `AdminUserIds` for `/npc recall` and `/npc debug` chat commands.

## Features

Fifteen configurable NPCs by default; random region spawn, spacing, respawn; gear and per-weapon stats; server-side melee/ranged attacks, ammo/reload; vision with line-of-sight and stealth; faction targeting; pathfinding; idle, roaming, patrol, chase, investigation, search, flee, and return states; group alerts; script-triggerable hearing; emotions and overhead labels; random loot drops; talk/shop prompts; simple quests/rewards; coins and reputation leaderstats; optional DataStore persistence; debug attributes/admin commands.

This is an extensible sandbox foundation, not a finished production game. For reliable quest kill credit, combat damage code should tag the NPC Humanoid with a `creator` ObjectValue containing the responsible Player. Shops currently offer the first Tool in `NPCShopItems`; customize the interaction script for a selection UI. Persistence needs Studio API access for testing and should be tested in a published private experience.

## Configuration and source

Edit files under `src/ServerScriptService/SmartNPCSystem/`. The plugin fetches every file listed in `plugin/SmartNPCInstaller.lua` from the repository's `main` branch on each install/update.
