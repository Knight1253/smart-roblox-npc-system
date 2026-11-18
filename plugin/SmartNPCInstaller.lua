-- Smart NPC System Studio plugin.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local REPO = "Knight1253/smart-roblox-npc-system"
local BRANCH = "main"
local FILES = {
	{ path = "src/ServerScriptService/SmartNPCSystem/NPCConfig.lua", name = "NPCConfig", className = "ModuleScript", destination = "server" },
	{ path = "src/ServerScriptService/SmartNPCSystem/NPCController.server.lua", name = "NPCController", className = "Script", destination = "server" },
	{ path = "src/ServerScriptService/SmartNPCSystem/NPCInteractions.server.lua", name = "NPCInteractions", className = "Script", destination = "server" },
	{ path = "src/ServerScriptService/SmartNPCSystem/NPCAdmin.server.lua", name = "NPCAdmin", className = "Script", destination = "server" },
	{ path = "src/StarterPlayer/StarterPlayerScripts/SmartNPCControlPanel.client.lua", name = "SmartNPCControlPanel", className = "LocalScript", destination = "client" },
}
local toolbar = plugin:CreateToolbar("Smart NPC System")
local openButton = toolbar:CreateButton("InstallSmartNPCSystem", "Fetch private repository scripts and install/update them", "")
openButton.ClickableWhenViewportHidden = true
local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 430, 250, 350, 200)
local widget = plugin:CreateDockWidgetPluginGui("SmartNPCPrivateRepoAuth", widgetInfo)
widget.Title = "Smart NPC System - Private Repo"
local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(1, 1); frame.BackgroundColor3 = Color3.fromRGB(35, 38, 45); frame.BorderSizePixel = 0; frame.Parent = widget
local info = Instance.new("TextLabel")
info.Position = UDim2.fromOffset(14, 12); info.Size = UDim2.new(1, -28, 0, 72); info.BackgroundTransparency = 1
info.Font = Enum.Font.Gotham; info.TextSize = 12; info.TextWrapped = true; info.TextColor3 = Color3.fromRGB(230, 230, 235)
info.TextXAlignment = Enum.TextXAlignment.Left; info.TextYAlignment = Enum.TextYAlignment.Top
info.Text = "Paste a fine-grained GitHub token restricted to this repository with Contents: Read-only. The token is used in memory for this fetch and is not saved."
info.Parent = frame
local tokenBox = Instance.new("TextBox")
tokenBox.Position = UDim2.fromOffset(14, 94); tokenBox.Size = UDim2.new(1, -28, 0, 34); tokenBox.BackgroundColor3 = Color3.fromRGB(24, 27, 33)
tokenBox.ClearTextOnFocus = false; tokenBox.Font = Enum.Font.Code; tokenBox.TextSize = 13; tokenBox.TextColor3 = Color3.new(1, 1, 1)
tokenBox.PlaceholderText = "github_pat_..."; tokenBox.Text = ""; tokenBox.Parent = frame
local install = Instance.new("TextButton")
install.Position = UDim2.fromOffset(14, 142); install.Size = UDim2.new(1, -28, 0, 34); install.BackgroundColor3 = Color3.fromRGB(45, 122, 85)
install.Font = Enum.Font.GothamBold; install.TextSize = 14; install.TextColor3 = Color3.new(1, 1, 1); install.Text = "Fetch and install"; install.Parent = frame
local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(14, 184); status.Size = UDim2.new(1, -28, 0, 50); status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham; status.TextSize = 12; status.TextWrapped = true; status.TextColor3 = Color3.fromRGB(215, 220, 230)
status.TextXAlignment = Enum.TextXAlignment.Left; status.TextYAlignment = Enum.TextYAlignment.Top; status.Text = ""; status.Parent = frame

local function fetchFile(path, token)
	local response = HttpService:RequestAsync({
		Url = "https://api.github.com/repos/" .. REPO .. "/contents/" .. path .. "?ref=" .. BRANCH,
		Method = "GET",
		Headers = { Authorization = "Bearer " .. token, Accept = "application/vnd.github+json", ["X-GitHub-Api-Version"] = "2022-11-28", ["User-Agent"] = "SmartRobloxNPCStudioPlugin" },
	})
	if not response.Success then error(("GitHub request failed (%d); check token access and rate limits."):format(response.StatusCode)) end
	local payload = HttpService:JSONDecode(response.Body)
	if type(payload.content) ~= "string" then error("GitHub response lacks source for " .. path) end
	return HttpService:Base64Decode(string.gsub(payload.content, "%s", ""))
end
local function setSource(instance, source)
	local ok, err = pcall(function() ScriptEditorService:UpdateSourceAsync(instance, function() return source end) end)
	if not ok then error("Couldn't update " .. instance.Name .. ": " .. tostring(err)) end
end
local function destinationFor(file)
	if file.destination == "client" then
		local scripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
		if not scripts then scripts = Instance.new("StarterPlayerScripts"); scripts.Parent = StarterPlayer end
		return scripts
	end
	local root = ServerScriptService:FindFirstChild("SmartNPCSystem")
	if not root then root = Instance.new("Folder"); root.Name = "SmartNPCSystem"; root.Parent = ServerScriptService end
	return root
end
openButton.Click:Connect(function() widget.Enabled = not widget.Enabled end)
install.Activated:Connect(function()
	local token = tokenBox.Text
	if token == "" then status.Text = "Paste a fine-grained read-only token first."; return end
	install.Active = false; install.Text = "Fetching..."; status.Text = "Downloading repository scripts..."
	local ok, err = pcall(function()
		local sources = {}
		for _, file in ipairs(FILES) do sources[file.name] = fetchFile(file.path, token) end
		for _, file in ipairs(FILES) do
			local destination = destinationFor(file)
			local object = destination:FindFirstChild(file.name)
			if object and not object:IsA(file.className) then object:Destroy(); object = nil end
			if not object then object = Instance.new(file.className); object.Name = file.name; object.Parent = destination end
			setSource(object, sources[file.name])
		end
		pcall(function() ChangeHistoryService:SetWaypoint("Installed Smart NPC System from private repository") end)
	end)
	tokenBox.Text = ""; token = nil; install.Active = true; install.Text = "Fetch and install"
	if ok then status.Text = "Installed. TopbarPlus must also be in ReplicatedStorage for the owner panel." else status.Text = "Install failed: " .. tostring(err); warn("Smart NPC install failed:", err) end
end)
print("Smart NPC Studio plugin ready. Open its toolbar panel and authenticate to fetch private repo sources.")
