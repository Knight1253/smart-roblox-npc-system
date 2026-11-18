# Smart Roblox NPC System

A configurable sandbox NPC framework. The Studio plugin fetches maintained source files from this private GitHub repository.

## Install on Windows

1. Install [GitHub CLI](https://cli.github.com/) and run `gh auth login` using an account that can read this repository.
2. Download `Install-SmartNPCPlugin.bat` and `Install-SmartNPCPlugin.ps1`, then run the batch file. It uses the GitHub CLI's existing login to download the local Studio plugin, and does not embed credentials in the plugin file.
3. Restart Studio. Open **Plugins > Smart NPC System**. Create a GitHub fine-grained token scoped only to this repository with **Contents: Read-only**, paste it into the plugin window, and click **Fetch and install**. The plugin fetches the config and runtime scripts from GitHub and installs them under `ServerScriptService.SmartNPCSystem`.

The runtime plugin token is not saved by the plugin and is cleared from the input after the request. The plugin necessarily handles it in memory during the request; only use this with plugin source you trust. Never use a classic token or a token with write/admin permissions. Revoke the fine-grained token in GitHub settings when no longer needed. Private raw GitHub URLs do not provide authentication, so the plugin uses GitHub's Contents API.

## Required place setup

- `ServerStorage.NPC`: an unanchored rig Model with `Humanoid` and `HumanoidRootPart`.
- `Workspace.NPCSpawnRegion`: BasePart covering the random spawn area.

## Optional content

- `ServerStorage.NPCGear`: Tools with attributes `WeaponType` (Melee/Ranged), `Damage`, `Range`, `Cooldown`, `MagazineSize`, and `ReloadTime`.
- `ServerStorage.NPCLoot`: Tools eligible for random death drops.
- `ServerStorage.NPCShopItems`: purchasable Tools with numeric `Price` attributes.
- `Workspace.NPCPatrols`: route folders containing ordered BaseParts. Set an NPC's `PatrolRoute` attribute to a route folder name; otherwise its faction or `Default` route is used.
- `Workspace.NPCNoise`: optional BindableEvent; server scripts can call `Fire(position, radius, source)` to make NPCs investigate a sound.
- NPC model attributes: `Faction`, `DialogueText`, `ShopEnabled`, `QuestName`, `QuestGoal`, `QuestReward`, `QuestTargetName`.
- Players may use a `Stealth` character attribute; it reduces NPC visual detection range.
- Add authorized user IDs to `AdminUserIds` for optional chat commands.

## Features

Configurable spawn/respawn, gear and weapon stats, server-side melee/ranged attacks and reloads, line-of-sight and stealth detection, factions, pathfinding, idle/roam/patrol/chase/investigate/search/flee/return behavior, group alerts, hearing, emotions, loot, dialogue/shop prompts, simple quests and rewards, player coins/reputation, optional DataStore persistence, and admin/debug helpers.

This is an extensible sandbox starter, not a fully production-verified game. Test in a private Studio session. Persistence needs Studio API access for testing. Review the sources before installing.

## Repository source

Edit files under `src/ServerScriptService/SmartNPCSystem/`. The plugin fetches all files listed in `plugin/SmartNPCInstaller.lua` from the private repository's `main` branch on each update.
