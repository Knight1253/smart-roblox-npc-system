-- Smart NPC System Studio plugin.
-- Authenticates to a private GitHub repo using a user-pasted, fine-grained
-- read-only token. The token exists only in this click handler's memory and is
-- never persisted by the plugin or written into the place.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local ServerScriptService = game:GetService("ServerScriptService")

local REPO = "Knight1253/smart-roblox-npc-system"
local BRANCH = "main"
local FILES = {
	{ path = "src/ServerScriptService/SmartNPCSystem/NPCConfig.lua", name = "NPCConfig", className = "ModuleScript" },
	{ path = "src/ServerScriptService/SmartNPCSystem/NPCController.server.lua", name = "NPCController", className = "Script" },
	{ path = "src/ServerScriptService/SmartNPCSystem/NPCInteractions.server.lua", name = "NPCInteractions", className = "Script" },
}

local toolbar = plugin:CreateToolbar("Smart NPC System")
local openButton = toolbar:CreateButton("InstallSmartNPCSystem", "Fetch private repository scripts and install/update them", "")
openButton.ClickableWhenViewportHidden = true
local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 430, 250, 350, 200)
local widget = plugin:CreateDockWidgetPluginGui("SmartNPCPrivateRepoAuth", widgetInfo)
widget.Title = "Smart NPC System - Private Repo"

local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(1, 1)
frame.BackgroundColor3 = Color3.fromRGB(35, 38, 45)
frame.BorderSizePixel = 0
frame.Parent = widget
local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(14, 10)
title.Size = UDim2.new(1, -28, 0, 28)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Private GitHub repository access"
title.Parent = frame
local info = Instance.new("TextLabel")
info.Position = UDim2.fromOffset(14, 42)
info.Size = UDim2.new(1, -28, 0, 54)
info.BackgroundTransparency = 1
info.Font = Enum.Font.Gotham
info.TextSize = 12
info.TextWrapped = true
info.TextColor3 = Color3.fromRGB(215, 220, 230)
info.TextXAlignment = Enum.TextXAlignment.Left
info.TextYAlignment = Enum.TextYAlignment.Top
info.Text = "Paste a fine-grained GitHub token limited to this repository with Contents: Read-only. It is not saved; trusted plugin code can access it while fetching."
info.Parent = frame
local tokenBox = Instance.new("TextBox")
tokenBox.Position = UDim2.fromOffset(14, 102)
tokenBox.Size = UDim2.new(1, -28, 0, 34)
tokenBox.BackgroundColor3 = Color3.fromRGB(24, 27, 33)
tokenBox.BorderSizePixel = 0
tokenBox.ClearTextOnFocus = false
tokenBox.Font = Enum.Font.Code
tokenBox.TextSize = 13
tokenBox.TextColor3 = Color3.new(1, 1, 1)
tokenBox.PlaceholderColor3 = Color3.fromRGB(145, 150, 160)
tokenBox.PlaceholderText = "github_pat_..."
tokenBox.TextXAlignment = Enum.TextXAlignment.Left
tokenBox.Text = ""
tokenBox.Parent = frame
local install = Instance.new("TextButton")
install.Position = UDim2.fromOffset(14, 146)
install.Size = UDim2.new(1, -28, 0, 34)
install.BackgroundColor3 = Color3.fromRGB(45, 122, 85)
install.BorderSizePixel = 0
install.Font = Enum.Font.GothamBold
install.TextSize = 14
install.TextColor3 = Color3.new(1, 1, 1)
install.Text = "Fetch and install from GitHub"
install.Parent = frame
local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(14, 188)
status.Size = UDim2.new(1, -28, 0, 48)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.TextColor3 = Color3.fromRGB(215, 220, 230)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = ""
status.Parent = frame

local function apiFileUrl(path)
	return "https://api.github.com/repos/" .. REPO .. "/contents/" .. path .. "?ref=" .. BRANCH
end

local function fetchFile(path, token)
	local response = HttpService:RequestAsync({
		Url = apiFileUrl(path),
		Method = "GET",
		Headers = {
			Authorization = "Bearer " .. token,
			Accept = "application/vnd.github+json",
			["X-GitHub-Api-Version"] = "2022-11-28",
			["User-Agent"] = "SmartRobloxNPCStudioPlugin",
		},
	})
	if not response.Success then
		error(("GitHub request failed (%d). Check token permissions, repo access, and rate limits."):format(response.StatusCode))
	end
	local payload = HttpService:JSONDecode(response.Body)
	if type(payload.content) ~= "string" then error("GitHub response did not contain file content for " .. path) end
	local compact = string.gsub(payload.content, "%s", "")
	return HttpService:Base64Decode(compact)
end

local function updateSource(instance, source)
	local ok, err = pcall(function()
		ScriptEditorService:UpdateSourceAsync(instance, function() return source end)
	end)
	if not ok then error("Couldn't update " .. instance.Name .. ": " .. tostring(err)) end
end

openButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

install.Activated:Connect(function()
	local token = tokenBox.Text
	if token == "" then status.Text = "Paste a read-only fine-grained token first."; return end
	install.Active = false
	install.Text = "Fetching..."
	status.Text = "Downloading source files from the private repository..."
	local ok, err = pcall(function()
		-- Complete every network request before editing the current place.
		local sources = {}
		for _, file in ipairs(FILES) do sources[file.name] = fetchFile(file.path, token) end
		local root = ServerScriptService:FindFirstChild("SmartNPCSystem")
		if not root then
			root = Instance.new("Folder")
			root.Name = "SmartNPCSystem"
			root.Parent = ServerScriptService
		end
		for _, file in ipairs(FILES) do
			local object = root:FindFirstChild(file.name)
			if object and not object:IsA(file.className) then object:Destroy(); object = nil end
			if not object then
				object = Instance.new(file.className)
				object.Name = file.name
				object.Parent = root
			end
			updateSource(object, sources[file.name])
		end
		pcall(function() ChangeHistoryService:SetWaypoint("Installed Smart NPC System from private GitHub repo") end)
	end)
	-- Clear the text box and local reference after each attempt; never store the token.
	tokenBox.Text = ""
	token = nil
	install.Active = true
	install.Text = "Fetch and install from GitHub"
	if ok then
		status.Text = "Installed successfully. Add ServerStorage.NPC and Workspace.NPCSpawnRegion, then test in Studio."
		print("Smart NPC scripts fetched from the configured private GitHub repository.")
	else
		status.Text = "Install failed: " .. tostring(err)
		warn("Smart NPC private repo install failed: " .. tostring(err))
	end
end)

print("Smart NPC plugin loaded. Open its toolbar button and provide a fine-grained read-only repo token to fetch private source.")
