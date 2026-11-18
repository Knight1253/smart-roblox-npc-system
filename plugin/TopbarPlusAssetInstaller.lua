-- Studio-only helper to install official TopbarPlus asset into the open place.
-- Runtime games cannot InsertService:LoadAsset; install this dependency in Studio before publishing.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TOPBAR_ASSET_ID = 92368439343389
local toolbar = plugin:CreateToolbar("Smart NPC System")
local button = toolbar:CreateButton(
	"InstallTopbarPlus",
	"Add the official TopbarPlus asset required by the owner NPC panel",
	""
)
button.ClickableWhenViewportHidden = true

local widget = plugin:CreateDockWidgetPluginGui(
	"SmartNPC_TopbarPlusInstaller",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 390, 180, 320, 140)
)
widget.Title = "Install TopbarPlus"

local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(1, 1)
frame.BackgroundColor3 = Color3.fromRGB(34, 37, 44)
frame.Parent = widget

local info = Instance.new("TextLabel")
info.Position = UDim2.fromOffset(12, 12)
info.Size = UDim2.new(1, -24, 0, 76)
info.BackgroundTransparency = 1
info.Font = Enum.Font.Gotham
info.TextSize = 13
info.TextWrapped = true
info.TextColor3 = Color3.new(1, 1, 1)
info.Text = "TopbarPlus is a Studio-time dependency. Click below to insert asset 92368439343389 into ReplicatedStorage. The owner panel uses it when the game runs."
info.Parent = frame

local install = Instance.new("TextButton")
install.Position = UDim2.fromOffset(12, 98)
install.Size = UDim2.new(1, -24, 0, 36)
install.BackgroundColor3 = Color3.fromRGB(45, 122, 85)
install.Font = Enum.Font.GothamBold
install.TextSize = 14
install.TextColor3 = Color3.new(1, 1, 1)
install.Text = "Insert TopbarPlus asset"
install.Parent = frame

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(12, 138)
status.Size = UDim2.new(1, -24, 0, 32)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.TextColor3 = Color3.fromRGB(220, 220, 225)
status.Text = ""
status.Parent = frame

local function findIcon(root)
	if root:IsA("ModuleScript") and root.Name == "Icon" then
		return root
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("ModuleScript") and descendant.Name == "Icon" then
			return descendant
		end
	end
	return nil
end

local function existingIcon()
	return findIcon(ReplicatedStorage)
end

button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

install.Activated:Connect(function()
	if existingIcon() then
		status.Text = "TopbarPlus Icon module is already in ReplicatedStorage."
		return
	end

	install.Active = false
	install.Text = "Loading asset..."
	status.Text = "Requesting asset from Roblox Studio..."

	local ok, result = pcall(function()
		return InsertService:LoadAsset(TOPBAR_ASSET_ID)
	end)

	if not ok or not result then
		status.Text = "Asset insert failed. Check Studio permissions or add TopbarPlus via Toolbox/Wally."
		warn("TopbarPlus asset load failed:", result)
		install.Active = true
		install.Text = "Insert TopbarPlus asset"
		return
	end

	local iconModule = findIcon(result)
	if not iconModule then
		result:Destroy()
		status.Text = "Loaded asset did not contain an Icon ModuleScript; nothing was added."
		install.Active = true
		install.Text = "Insert TopbarPlus asset"
		return
	end

	local packages = ReplicatedStorage:FindFirstChild("Packages")
	if not packages then
		packages = Instance.new("Folder")
		packages.Name = "Packages"
		packages.Parent = ReplicatedStorage
	end

	result.Name = "TopbarPlusAsset"
	result.Parent = packages
	pcall(function()
		ChangeHistoryService:SetWaypoint("Inserted TopbarPlus asset 92368439343389")
	end)
	status.Text = "TopbarPlus added to ReplicatedStorage.Packages. Test in Play mode before publishing."
	install.Active = true
	install.Text = "Insert TopbarPlus asset"
end)

print("TopbarPlus installer ready. Use the Smart NPC System toolbar to insert asset " .. TOPBAR_ASSET_ID .. ".")
