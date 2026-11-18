# Smart Roblox NPC System

Sandbox NPC framework plus independent Windows Studio plugins. Run `Install-SmartNPCPlugin.bat` after authenticating with GitHub CLI, then restart Studio.

## Separate Studio plugins

- **Smart NPC Installer** installs bundled framework files or fetches the latest private-repo versions.
- **TopbarPlus Asset Installer** inserts TopbarPlus asset `92368439343389` into the open place at Studio edit time.
- **Smart NPC Setup** checks/creates only NPC-system objects and scripts prerequisites.
- **Universal Studio Monitor** is a separate, project-independent Output monitor usable in any Roblox Studio place. It captures Studio log events, filters text, pauses/resumes capture, clears entries, and can copy visible log text when Studio exposes clipboard support. Its input is a text filter—not a command prompt—and it never executes Lua or modifies the project.

## Universal monitor

Open **Plugins > Studio Monitor > Universal Studio Monitor**. It subscribes to Studio's `LogService.MessageOut` while the plugin is loaded. It classifies errors, warnings, and regular log output, keeps a bounded in-memory list, and supports literal substring filtering. It does not claim to monitor arbitrary network/device input or automatically repair third-party code. Use the standard Output window for full tracebacks and source navigation.

## Smart NPC setup helper

Open **Plugins > Smart NPC Setup**. Its allowlisted commands are `scan`, `fix npc`, `topbar`, and `help`. `fix npc` creates only missing NPC folders, a visible spawn-region placeholder, and a basic R6 template if `ServerStorage.NPC` is absent. Existing custom assets are preserved. Move and resize the generated region over safe ground and replace/test the sample rig before publishing.

## Safety and project requirements

Required NPC runtime assets: `ServerStorage.NPC` with `Humanoid` and `HumanoidRootPart`, and `Workspace.NPCSpawnRegion` as a BasePart. Diagnostics never evaluates arbitrary typed Lua, never rewrites arbitrary scripts, and never treats output text as commands. DataStores require appropriate Studio API access. Test in a private place and review scripts/assets before publishing.
