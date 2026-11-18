# Smart Roblox NPC System

Sandbox NPC framework plus Windows Studio plugins. The installer uses GitHub CLI authentication for the private repository; install each local plugin by running `Install-SmartNPCPlugin.bat`, then restart Studio.

## Studio plugins

- **Smart NPC Installer**: install the bundled NPC scripts offline or fetch the latest private-repo sources with a fine-grained read-only GitHub token.
- **TopbarPlus Asset Installer**: explicit Studio-time insertion of official asset `92368439343389`.
- **Smart NPC Diagnostics**: Studio Output monitor, structural checker, safe command input, and setup helper.

## Diagnostics and setup helper

Open **Plugins > Smart NPC System** diagnostics. It captures Studio Output messages while Studio is open, including errors and warnings. Built-in commands are `help`, `scan`, `fix npc`, and `topbar`. The plugin does not execute arbitrary typed Lua, does not claim to understand every third-party system, and does not auto-rewrite arbitrary scripts.

**Create required NPC setup** creates only missing objects and preserves existing ones: `ServerStorage.NPCGear`, `ServerStorage.NPCLoot`, `ServerStorage.NPCShopItems`, `Workspace.NPCPatrols`, `Workspace.NPCSpawnRegion`, and a basic R6 `ServerStorage.NPC` template if none exists. The default spawn region is a visible 100x100 placeholder near origin; move/resize it over safe ground before play testing. If a custom `NPC` object exists but is incompatible, it is not overwritten. Replace the generated starter rig with a tested custom rig for production.

`scan` checks these dependencies, warns about anchored NPC body parts, and checks whether TopbarPlus is present. `topbar` tries inserting asset `92368439343389` into Studio's ReplicatedStorage; if Roblox denies the import, use Toolbox/Wally. Imported third-party code should be reviewed before publishing. Studio-time plugin actions affect the open place only when you explicitly click the action.

## Framework requirements and features

Required runtime objects are `ServerStorage.NPC` (Model with Humanoid/ HumanoidRootPart) and `Workspace.NPCSpawnRegion` (BasePart). Optional folders include NPCGear, NPCLoot, NPCShopItems, and NPCPatrols. Features include configurable spawn/respawn, pathfinding AI, idle/roam/investigate/search, gear, emotions, interactions and memory, persistence, and a server-validated owner TopbarPlus panel.

## Limits and safety

There is no safe universal auto-fixer for arbitrary games or scripts. Diagnostics supports general Studio log capture and explicit, allowlisted setup actions. It does not execute arbitrary code from chat, Output, or the command box. DataStores require appropriate Studio API access for testing. Review the project scripts and test in a private place before publishing.
