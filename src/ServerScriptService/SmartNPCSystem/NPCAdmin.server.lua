-- Server-authoritative owner-only NPC control panel remotes.
-- Access: experience creator (or group owner for group-owned games), or private-server owner.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(script.Parent:WaitForChild("NPCConfig"))
local npcFolder = workspace:WaitForChild(Config.SpawnedFolderName)

local remotes = ReplicatedStorage:FindFirstChild("SmartNPCControl") or Instance.new("Folder")
remotes.Name = "SmartNPCControl"
remotes.Parent = ReplicatedStorage
local getSnapshot = remotes:FindFirstChild("GetSnapshot") or Instance.new("RemoteFunction")
getSnapshot.Name = "GetSnapshot"
getSnapshot.Parent = remotes
local commandEvent = remotes:FindFirstChild("Command") or Instance.new("RemoteEvent")
commandEvent.Name = "Command"
commandEvent.Parent = remotes

local lastRequest = {}
local REQUEST_COOLDOWN = 0.5

local function isAuthorized(player)
	if table.find(Config.AdminUserIds or {}, player.UserId) then return true end
	if game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0 and player.UserId == game.PrivateServerOwnerId then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
		if ok and rank == 255 then return true end
	end
	return false
end

local function getSnapshot(player)
	if not isAuthorized(player) then return { authorized = false } end
	local rows = {}
	for _, npc in npcFolder:GetChildren() do
		local hum = npc:FindFirstChildOfClass("Humanoid")
		local root = npc:FindFirstChild("HumanoidRootPart")
		if hum and root then
			table.insert(rows, {
				name = npc.Name,
				state = npc:GetAttribute("AIState") or "Unknown",
				emotion = npc:GetAttribute("Emotion") or "Calm",
				faction = npc:GetAttribute("Faction") or "Neutral",
				health = math.floor(hum.Health),
				maxHealth = math.floor(hum.MaxHealth),
				gear = npc:GetAttribute("GearName") or "Unarmed",
			})
		end
	end
	return {
		authorized = true,
		npcs = rows,
		aiEnabled = workspace:GetAttribute("SmartNPCAIEnabled") ~= false,
		spawningEnabled = workspace:GetAttribute("SmartNPCSpawningEnabled") ~= false,
	}
end

getSnapshot.OnServerInvoke = function(player)
	return getSnapshot(player)
end

commandEvent.OnServerEvent:Connect(function(player, action, value)
	local now = os.clock()
	if now - (lastRequest[player] or 0) < REQUEST_COOLDOWN then return end
	lastRequest[player] = now
	if not isAuthorized(player) then
		warn(("[SmartNPC] Blocked unauthorized control-panel request from %s (%d)"):format(player.Name, player.UserId))
		return
	end
	if action == "SetAI" and typeof(value) == "boolean" then
		workspace:SetAttribute("SmartNPCAIEnabled", value)
	elseif action == "SetSpawning" and typeof(value) == "boolean" then
		workspace:SetAttribute("SmartNPCSpawningEnabled", value)
	elseif action == "RecallAll" then
		for _, npc in npcFolder:GetChildren() do
			local root = npc:FindFirstChild("HumanoidRootPart")
			local home = npc:GetAttribute("HomePosition")
			if root and typeof(home) == "Vector3" then
				root.AssemblyLinearVelocity = Vector3.zero
				root.CFrame = CFrame.new(home + Vector3.new(0, 3, 0))
			end
		end
	elseif action == "HealAll" then
		for _, npc in npcFolder:GetChildren() do
			local hum = npc:FindFirstChildOfClass("Humanoid")
			if hum then hum.Health = hum.MaxHealth end
		end
	else
		return
	end
	print(("[SmartNPC] Owner control action %s by %s"):format(action, player.Name))
end)

Players.PlayerRemoving:Connect(function(player) lastRequest[player] = nil end)
if workspace:GetAttribute("SmartNPCAIEnabled") == nil then workspace:SetAttribute("SmartNPCAIEnabled", true) end
if workspace:GetAttribute("SmartNPCSpawningEnabled") == nil then workspace:SetAttribute("SmartNPCSpawningEnabled", true) end
