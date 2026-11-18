## Player interaction and private control panel

NPCs can greet players differently after meeting them, track per-player meeting counts and relationship points, and persist those memories in the configured DataStore. Memories are stored as JSON in the player's `NPCMemories` attribute while online. Add `MemoryKey` and `DisplayName` attributes to the NPC template to keep a stable identity across respawns; otherwise the spawned NPC name is used.

The owner-only panel is built with TopbarPlus. Install TopbarPlus v3 using Wally (`wally install`, then sync the package into `ReplicatedStorage`) or place its `Icon` ModuleScript at `ReplicatedStorage.Icon`. The panel appears under a TopbarPlus `NPCs` icon. It shows live NPC state counts and offers server-validated AI/spawn toggles, recall, and heal commands. Access is checked on the server for every request: user-owned experience creator, group owner (rank 255), or current private-server owner. Set `AdminUserIds` only if you intentionally want additional administrators. Never rely on client-side hiding alone for security.

The plugin installs `NPCAdmin.server.lua` into the framework folder and the panel LocalScript into `StarterPlayerScripts`; it still fetches all Lua sources from the private repository using the read-only token entered in Studio.
