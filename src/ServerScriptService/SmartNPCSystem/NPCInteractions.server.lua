-- Dialogue, quest, shop, and player data services for Smart NPC System.
-- Configure NPCs with attributes: DialogueText, ShopEnabled, QuestName,
-- QuestGoal, QuestReward, and QuestTargetName. Shop tools go in ServerStorage.NPCShopItems.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local Config = require(script.Parent:WaitForChild("NPCConfig"))
local npcFolder = workspace:WaitForChild(Config.SpawnedFolderName)
local store = Config.EnablePersistence and DataStoreService:GetDataStore(Config.DataStoreName) or nil
local saveBusy = {}

local function setupPlayer(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player
	local coins = Instance.new("IntValue")
	coins.Name, coins.Value, coins.Parent = "Coins", Config.StartingCoins, stats
	local reputation = Instance.new("IntValue")
	reputation.Name, reputation.Value, reputation.Parent = "Reputation", Config.StartingReputation, stats
	local data
	if store then
		local ok, result = pcall(function() return store:GetAsync("player_" .. player.UserId) end)
		if ok and type(result) == "table" then data = result else if not ok then warn("NPC data load failed:", result) end end
	end
	if data then
		coins.Value = tonumber(data.Coins) or coins.Value
		reputation.Value = tonumber(data.Reputation) or reputation.Value
		player:SetAttribute("NPCQuest", data.QuestName or "")
		player:SetAttribute("NPCQuestProgress", tonumber(data.QuestProgress) or 0)
	else
		player:SetAttribute("NPCQuest", "")
		player:SetAttribute("NPCQuestProgress", 0)
	end
end

local function savePlayer(player)
	if not store or saveBusy[player] then return end
	saveBusy[player] = true
	local stats = player:FindFirstChild("leaderstats")
	local data = {
		Coins = stats and stats:FindFirstChild("Coins") and stats.Coins.Value or Config.StartingCoins,
		Reputation = stats and stats:FindFirstChild("Reputation") and stats.Reputation.Value or Config.StartingReputation,
		QuestName = player:GetAttribute("NPCQuest") or "",
		QuestProgress = player:GetAttribute("NPCQuestProgress") or 0,
	}
	local ok, err = pcall(function() store:SetAsync("player_" .. player.UserId, data) end)
	if not ok then warn("NPC data save failed:", err) end
	saveBusy[player] = nil
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player) savePlayer(player) end)
for _, player in Players:GetPlayers() do task.spawn(setupPlayer, player) end
if store then
	task.spawn(function()
		while true do
			task.wait(Config.PersistenceSaveInterval)
			for _, player in Players:GetPlayers() do task.spawn(savePlayer, player) end
		end
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

local function addPrompt(npc, parent, name, action, callback)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText = name, action, npc.Name
	prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0.25, 10, false
	prompt.Parent = parent
	prompt.Triggered:Connect(callback)
end

local function attachNPC(npc)
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not root or root:FindFirstChild("NPCInteractionPrompts") then return end
	local holder = Instance.new("Attachment")
	holder.Name = "NPCInteractionPrompts"
	holder.Parent = root
	addPrompt(npc, holder, "Talk", "Talk", function(player)
		local text = npc:GetAttribute("DialogueText") or ("Hello, " .. player.DisplayName .. "!")
		notify(player, text)
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

-- Award quest progress when a player-caused NPC death is explicitly tagged with
-- creator ObjectValue; reward logic stays server-side.
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
		local coins = stats and stats:FindFirstChild("Coins")
		local rep = stats and stats:FindFirstChild("Reputation")
		if coins then coins.Value += player:GetAttribute("NPCQuestReward") or 25 end
		if rep then rep.Value += 5 end
		player:SetAttribute("NPCQuest", "")
		player:SetAttribute("NPCQuestProgress", 0)
		notify(player, "Quest complete! Reward granted.")
	end
end)
