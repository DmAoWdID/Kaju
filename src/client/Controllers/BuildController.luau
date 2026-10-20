--!nonstrict
-- Build mode: highlights the free enclosure slots in YOUR plot; click or tap one to place the chosen
-- enclosure. The server re-checks ownership, slot, price and money.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Net.Remotes)

local ClientState = require(script.Parent.ClientState)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local BuildController = {}

local player = Players.LocalPlayer
local banner: Frame = nil
local bannerText: TextLabel = nil
local activeSize: string? = nil
local highlights: { Instance } = {}
local placing = false

local function myPlot(): Model?
	local world = Workspace:FindFirstChild("World")
	local park = world and world:FindFirstChild("Park")
	if not park then
		return nil
	end
	for _, plot in park:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function clearHighlights()
	for _, h in highlights do
		h:Destroy()
	end
	table.clear(highlights)
end

local function refreshHighlights()
	clearHighlights()
	local plot = myPlot()
	local slots = plot and plot:FindFirstChild("Slots")
	if not slots then
		return
	end
	for _, pad in slots:GetChildren() do
		if pad:IsA("BasePart") and pad.Transparency < 1 then
			local box = Instance.new("SelectionBox")
			box.Adornee = pad
			box.Color3 = Color3.fromRGB(120, 230, 140)
			box.LineThickness = 0.25
			box.SurfaceColor3 = Color3.fromRGB(120, 230, 140)
			box.SurfaceTransparency = 0.6
			box.Parent = pad
			table.insert(highlights, box)
		end
	end
end

function BuildController.stop()
	activeSize = nil
	clearHighlights()
	if banner then
		banner.Visible = false
	end
end

function BuildController.start(sizeId: string)
	local size = GameConfig.Enclosures[sizeId]
	if not size then
		return
	end
	if not myPlot() then
		ClientState.toast("You don't have a park plot on this server.", "error")
		return
	end
	activeSize = sizeId
	bannerText.Text = ("Tap a glowing spot in your park to build a %s ($%s)"):format(size.displayName, UIKit.formatNumber(size.price))
	banner.Visible = true
	ClientState.request(Remotes.Actions.Travel, { destination = "park" }, true)
	task.delay(0.3, refreshHighlights)
end

local function tryPlace(screenPos: Vector2)
	if not activeSize or placing then
		return
	end
	local camera = Workspace.CurrentCamera
	-- InputObject.Position excludes the top-bar inset, which is what ScreenPointToRay expects.
	local ray = camera:ScreenPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	if not hit then
		return
	end
	local slot = hit.Instance:GetAttribute("SlotIndex")
	local plotIndex = hit.Instance:GetAttribute("PlotIndex")
	if not slot or plotIndex ~= player:GetAttribute("PlotIndex") then
		return
	end
	placing = true
	local result = ClientState.request(Remotes.Actions.PlaceEnclosure, { sizeId = activeSize, slot = slot })
	placing = false
	if result.ok then
		BuildController.stop()
	end
end

function BuildController.init(gui: ScreenGui)
	banner = UIKit.new("Frame", {
		Name = "BuildBanner",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(640, 70),
		BackgroundColor3 = UIKit.Colors.panel,
		Visible = false,
		Parent = gui,
	}, { UIKit.corner(14), UIKit.stroke(UIKit.Colors.good, 2), UIKit.padding(10) })
	UIKit.autoScale(banner)
	bannerText = UIKit.label("", {
		Font = UIKit.FontBold,
		TextSize = 17,
		Size = UDim2.new(1, -130, 1, 0),
		Parent = banner,
	})
	UIKit.button("Cancel", UIKit.Colors.bad, BuildController.stop, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(116, 48),
		Parent = banner,
	})

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not activeSize then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			tryPlace(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
	ClientState.onChanged(function()
		if activeSize then
			refreshHighlights()
		end
	end)
end

function BuildController.isActive(): boolean
	return activeSize ~= nil
end

return BuildController
