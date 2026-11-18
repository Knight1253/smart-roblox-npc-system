-- Dialogue, interactions, and persistent NPC recognition/memory.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Config = require(script.Parent:WaitForChild("NPCConfig"))
local npcFolder = workspace:WaitForChild(Config.SpawnedFolderName)
local store = Config.EnablePersistence and DataStoreService:GetDataStore(Config.DataStoreName) or nil
local memoriesByPlayer = {}
local saveBusy = {}

local function setMemoryAttribute(player)
	local ok, json = pcall(function() return HttpService:JSONEncode(memoriesByPlayer[player] or {}) end)
	if ok then player:SetAttribute("NPCMemories", json) end
end

local function setupPlayer(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then stats = Instance.new("Folder"); stats.Name = "leaderstats"; stats.Parent = player end
	local coins = stats:FindFirstChild("Coins") or Instance.new("IntValue")
	coins.Name = "Coins"; coins.Value = Config.StartingCoins; coins.Parent = stats
	local reputation = stats:FindFirstChild("Reputation") or Instance.new("IntValue")
	reputation.Name = "Reputation"; reputation.Value = Config.StartingReputation; reputation.Parent = stats
	local data
	if store then
		local ok, result = pcall(function() return store:GetAsync("player_" .. player.UserId) end)
		if ok and type(result) == "table" then data = result elseif not ok then warn("NPC data load failed:", result) end
	end
	memoriesByPlayer[player] = data and type(data.NPCMemories) == "table" and data.NPCMemories or {}
	if data then
		coins.Value = tonumber(data.Coins) or coins.Value
		reputation.Value = tonumber(data.Reputation) or reputation.Value
		player:SetAttribute("NPCQuest", data.QuestName or "")
		player:SetAttribute("NPCQuestProgress", tonumber(data.QuestProgress) or 0)
	else
		player:SetAttribute("NPCQuest", "")
		player:SetAttribute("NPCQuestProgress", 0)
	end
	setMemoryAttribute(player)
end

local function savePlayer(player)
	if not store or saveBusy[player] then return end
	saveBusy[player] = true
	local stats = player:FindFirstChild("leaderstats")
	local payload = {
		Coins = stats and stats:FindFirstChild("Coins") and stats.Coins.Value or Config.StartingCoins,
		Reputation = stats and stats:FindFirstChild("Reputation") and stats.Reputation.Value or Config.StartingReputation,
		QuestName = player:GetAttribute("NPCQuest") or "",
		QuestProgress = player:GetAttribute("NPCQuestProgress") or 0,
		NPCMemories = memoriesByPlayer[player] or {},
	}
	local ok, err = pcall(function()
		store:UpdateAsync("player_" .. player.UserId, function(old)
			old = type(old) == "table" and old or {}
			for key, value in pairs(payload) do old[key] = value end
			return old
		end)
	end)
	if not ok then warn("NPC data save failed:", err) end
	saveBusy[player] = nil
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player) savePlayer(player); memoriesByPlayer[player] = nil; saveBusy[player] = nil end)
for _, player in Players:GetPlayers() do task.spawn(setupPlayer, player) end
if store then
	task.spawn(function()
		while true do task.wait(Config.PersistenceSaveInterval); for _, player in Players:GetPlayers() do task.spawn(savePlayer, player) end end
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do task.spawn(savePlayer, player) end
		task.wait(3)
	end)
end

local function notify(player, message)
	player:SetAttribute("NPCNotice", message)
	print(("[SmartNPC] %s: %s"):format(player.Name, message))
end

local function inInteractionRange(player, npc)
	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	local npcRoot = npc:FindFirstChild("HumanoidRootPart")
	return playerRoot and npcRoot and (playerRoot.Position - npcRoot.Position).Magnitude <= 14
end

local function rememberInteraction(player, npc)
	local memories = memoriesByPlayer[player]
	if not memories then memories = {}; memoriesByPlayer[player] = memories end
	local key = tostring(npc:GetAttribute("MemoryKey") or npc.Name)
	local memory = memories[key] or { name = npc:GetAttribute("DisplayName") or npc.Name, meetings = 0, relationship = 0 }
	memory.meetings += 1
	memory.lastMet = os.time()
	memory.name = npc:GetAttribute("DisplayName") or npc.Name
	memory.relationship = math.clamp((memory.relationship or 0) + 1, -100, 100)
	memories[key] = memory
	local count = 0
	for _ in pairs(memories) do count += 1 end
	while count > (Config.MemoryLimit or 100) do
		local oldestKey, oldestTime
		for memoryKey, entry in pairs(memories) do
			local t = entry.lastMet or 0
			if not oldestTime or t < oldestTime then oldestKey, oldestTime = memoryKey, t end
		end
		if not oldestKey then break end
		memories[oldestKey] = nil
		count -= 1
	end
	setMemoryAttribute(player)
	return memory
end

local function addPrompt(npc, parent, name, action, callback)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText = name, action, npc:GetAttribute("DisplayName") or npc.Name
	prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0.25, 10, false
	prompt.Parent = parent
	prompt.Triggered:Connect(function(player)
		if inInteractionRange(player, npc) then callback(player) end
	end)
end

local function attachNPC(npc)
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not root or root:FindFirstChild("NPCInteractionPrompts") then return end
	local holder = Instance.new("Attachment")
	holder.Name = "NPCInteractionPrompts"; holder.Parent = root
	addPrompt(npc, holder, "Talk", "Talk", function(player)
		local memory = rememberInteraction(player, npc)
		local name = npc:GetAttribute("DisplayName") or npc.Name
		local greeting
		if memory.meetings == 1 then greeting = "Nice to meet you, " .. player.DisplayName .. "!"
		else greeting = "Good to see you again, " .. player.DisplayName .. "! (We've met " .. memory.meetings .. " times.)" end
		local text = npc:GetAttribute("DialogueText") or greeting
		notify(player, name .. ": " .. text)
		local questName = npc:GetAttribute("QuestName")
		if questName and questName ~= "" then
			player:SetAttribute("NPCQuest", questName)
			player:SetAttribute("NPCQuestProgress", 0)
			player:SetAttribute("NPCQuestGoal", npc:GetAttribute("QuestGoal") or 3)
			player:SetAttribute("NPCQuestReward", npc:GetAttribute("QuestReward") or 25)
			player:SetAttribute("NPCQuestTargetName", npc:GetAttribute("QuestTargetName") or "NPC")
			notify(player, "Quest started: " .. questName)
		end
	end)
	if npc:GetAttribute("ShopEnabled") == true then
		addPrompt(npc, holder, "Shop", "Shop", function(player)
			local items = ServerStorage:FindFirstChild("NPCShopItems")
			local stats = player:FindFirstChild("leaderstats")
			local coins = stats and stats:FindFirstChild("Coins")
			if not items or not coins then notify(player, "Shop unavailable."); return end
			local stock = items:GetChildren()
			if #stock == 0 then notify(player, "The shop is out of stock."); return end
			local item = stock[1]
			local price = item:GetAttribute("Price") or 10
			if coins.Value < price then notify(player, "Not enough coins."); return end
			local backpack = player:FindFirstChildOfClass("Backpack")
			if not backpack or not item:IsA("Tool") then notify(player, "Shop item is invalid."); return end
			coins.Value -= price
			item:Clone().Parent = backpack
			notify(player, "Purchased " .. item.Name .. " for " .. price .. " coins.")
		end)
	end
end

for _, npc in npcFolder:GetChildren() do attachNPC(npc) end
npcFolder.ChildAdded:Connect(function(npc) task.defer(attachNPC, npc) end)
npcFolder.ChildRemoved:Connect(function(npc)
	local creator = npc:FindFirstChild("creator")
	local player = creator and creator.Value
	if not player or not player:IsA("Player") then return end
	local questName = player:GetAttribute("NPCQuest")
	if not questName or questName == "" then return end
	local progress = (player:GetAttribute("NPCQuestProgress") or 0) + 1
	local goal = player:GetAttribute("NPCQuestGoal") or 3
	player:SetAttribute("NPCQuestProgress", progress)
	if progress >= goal then
		local stats = player:FindFirstChild("leaderstats")
		local coins, reputation = stats and stats:FindFirstChild("Coins"), stats and stats:FindFirstChild("Reputation")
		if coins then coins.Value += player:GetAttribute("NPCQuestReward") or 25 end
		if reputation then reputation.Value += 5 end
		player:SetAttribute("NPCQuest", "")
		player:SetAttribute("NPCQuestProgress", 0)
		notify(player, "Quest complete! Reward granted.")
	end
end)
