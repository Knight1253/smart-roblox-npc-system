-- Owner-only client control panel. Requires TopbarPlus v3 Icon module in ReplicatedStorage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SmartNPCControl")
local getSnapshot = remotes:WaitForChild("GetSnapshot")
local commandEvent = remotes:WaitForChild("Command")

local function findIconModule()
	local direct = ReplicatedStorage:FindFirstChild("Icon")
	if direct and direct:IsA("ModuleScript") then return direct end
	local packages = ReplicatedStorage:FindFirstChild("Packages")
	if packages then
		for _, name in ipairs({ "TopbarPlus", "Icon" }) do
			local package = packages:FindFirstChild(name)
			if package then
				if package:IsA("ModuleScript") then return package end
				local icon = package:FindFirstChild("Icon")
				if icon and icon:IsA("ModuleScript") then return icon end
			end
		end
	end
end

local iconModule = findIconModule()
if not iconModule then
	warn("Smart NPC panel needs TopbarPlus installed. Place its Icon ModuleScript at ReplicatedStorage.Icon or ReplicatedStorage.Packages.TopbarPlus.")
	return
end

local ok, Icon = pcall(require, iconModule)
if not ok or type(Icon) ~= "table" or type(Icon.new) ~= "function" then
	warn("Smart NPC panel couldn't load the TopbarPlus Icon module:", Icon)
	return
end

local gui = Instance.new("ScreenGui")
gui.Name = "SmartNPCControlPanel"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -18, 0, 72)
panel.Size = UDim2.fromOffset(360, 430)
panel.BackgroundColor3 = Color3.fromRGB(28, 31, 38)
panel.BorderSizePixel = 0
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel
local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(14, 10)
title.Size = UDim2.new(1, -28, 0, 28)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "NPC Control"
title.Parent = panel
local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(14, 42)
status.Size = UDim2.new(1, -28, 0, 40)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.TextColor3 = Color3.fromRGB(205, 210, 220)
status.TextXAlignment = Enum.TextXAlignment.Left
status.Text = "Owner controls"
status.Parent = panel
local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(14, 84)
list.Size = UDim2.new(1, -28, 1, -98)
list.BackgroundColor3 = Color3.fromRGB(21, 24, 30)
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.fromOffset(0, 0)
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.Parent = list

local function makeButton(text, callback, order)
	local button = Instance.new("TextButton")
	button.LayoutOrder = order
	button.Size = UDim2.new(1, -4, 0, 34)
	button.BackgroundColor3 = Color3.fromRGB(56, 68, 84)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 13
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = text
	button.Parent = list
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = button
	button.Activated:Connect(callback)
	return button
end

local function refresh()
	local success, data = pcall(function() return getSnapshot:InvokeServer() end)
	if not success or type(data) ~= "table" then status.Text = "Could not reach the server."; return end
	if not data.authorized then gui.Enabled = false; status.Text = "Owner/private-server-owner access only."; return end
	for _, child in list:GetChildren() do if child:IsA("TextLabel") or child:IsA("TextButton") then child:Destroy() end end
	local order = 1
	makeButton("AI: " .. (data.aiEnabled and "ON (click to pause)" or "PAUSED (click to enable)"), function()
		commandEvent:FireServer("SetAI", not data.aiEnabled)
		task.wait(0.2); refresh()
	end, order); order += 1
	makeButton("Spawning: " .. (data.spawningEnabled and "ON (click to stop)" or "STOPPED (click to start)"), function()
		commandEvent:FireServer("SetSpawning", not data.spawningEnabled)
		task.wait(0.2); refresh()
	end, order); order += 1
	makeButton("Recall all NPCs to spawn/home", function() commandEvent:FireServer("RecallAll"); status.Text = "Recall command sent." end, order); order += 1
	makeButton("Heal all NPCs", function() commandEvent:FireServer("HealAll"); status.Text = "Heal command sent." end, order); order += 1
	local states = {}
	for _, npc in ipairs(data.npcs or {}) do states[npc.state] = (states[npc.state] or 0) + 1 end
	local summary = Instance.new("TextLabel")
	summary.LayoutOrder = order
	summary.Size = UDim2.new(1, -4, 0, 46)
	summary.BackgroundTransparency = 1
	summary.Font = Enum.Font.GothamBold
	summary.TextSize = 13
	summary.TextColor3 = Color3.fromRGB(220, 225, 235)
	summary.TextXAlignment = Enum.TextXAlignment.Left
	summary.Text = ("Active NPCs: %d\n%s"):format(#(data.npcs or {}), "State counts below")
	summary.Parent = list; order += 1
	local sortedStates = {}
	for state, count in pairs(states) do table.insert(sortedStates, { state = state, count = count }) end
	table.sort(sortedStates, function(a, b) return a.state < b.state end)
	for _, entry in ipairs(sortedStates) do
		local row = Instance.new("TextLabel")
		row.LayoutOrder = order; row.Size = UDim2.new(1, -4, 0, 24); row.BackgroundTransparency = 1
		row.Font = Enum.Font.Gotham; row.TextSize = 12; row.TextColor3 = Color3.fromRGB(200, 205, 215)
		row.TextXAlignment = Enum.TextXAlignment.Left; row.Text = entry.state .. ": " .. entry.count; row.Parent = list
		order += 1
	end
	status.Text = "Authorized owner controls. Commands are checked again by the server."
	task.defer(function() list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 20) end)
end

local icon = Icon.new():setLabel("NPCs"):setOrder(8)
icon:bindEvent("selected", function()
	gui.Enabled = true
	refresh()
end)
icon:bindEvent("deselected", function()
	gui.Enabled = false
end)
```
