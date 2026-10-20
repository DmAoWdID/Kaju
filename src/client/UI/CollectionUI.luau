--!nonstrict
-- Lists owned kaijus with species data (from the registry) and instance data (level, park status).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local KaijuRegistry = require(Shared.Data.KaijuRegistry)
local Palette = require(Shared.Visual.Palette)
local PlayerDataSchema = require(Shared.PlayerData.PlayerDataSchema)
local Progression = require(Shared.Progression.Progression)
local Remotes = require(Shared.Net.Remotes)

local ClientState = require(script.Parent.Parent.Controllers.ClientState)
local KaijuViewport = require(script.Parent.KaijuViewport)
local UIKit = require(script.Parent.UIKit)

local CollectionUI = {}

local C = UIKit.Colors
local frame: Frame = nil
local list: ScrollingFrame = nil
local summary: TextLabel = nil
local dirty = true

local function statLine(stats): string
	return ("DUR %d   DMG %d   MOB %d   STA %d   INT %d"):format(
		stats.durability,
		stats.damage,
		stats.mobility,
		stats.stamina,
		stats.intelligence
	)
end

local function card(order: number, owned, species, data)
	local enclosure = PlayerDataSchema.enclosureOf(data, owned.instanceId)
	local item = UIKit.new("Frame", {
		BackgroundColor3 = C.panelLight,
		Size = UDim2.new(1, -12, 0, 150),
		LayoutOrder = order,
		Parent = list,
	}, { UIKit.corner(12), UIKit.padding(10) })
	UIKit.new("Frame", {
		BackgroundColor3 = Palette.KL[species.kl],
		Size = UDim2.new(0, 6, 1, 0),
		BorderSizePixel = 0,
		Parent = item,
	}, { UIKit.corner(3) })
	local viewport = KaijuViewport.create({ Size = UDim2.fromOffset(110, 110), Position = UDim2.fromOffset(14, 10), Parent = item })
	KaijuViewport.show(viewport, species.id)

	local info = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(136, 0),
		Size = UDim2.new(1, -136 - 170, 1, 0),
		Parent = item,
	})
	UIKit.label(species.displayName, { Font = UIKit.FontTitle, TextSize = 24, Size = UDim2.new(1, 0, 0, 28), Parent = info })
	UIKit.klBadge(species.kl, { Position = UDim2.fromOffset(0, 32), Parent = info })
	UIKit.label(("Level %d   ·   Threat %.1f"):format(owned.level, species.threatRating), {
		TextSize = 16,
		TextColor3 = C.textDim,
		Position = UDim2.fromOffset(60, 33),
		Size = UDim2.new(1, -60, 0, 22),
		Parent = info,
	})
	UIKit.label(statLine(species.stats), { TextSize = 15, Font = UIKit.FontBold, Position = UDim2.fromOffset(0, 62), Parent = info })
	UIKit.label("Traits: " .. table.concat(species.traits, ", "), {
		TextSize = 15,
		TextColor3 = C.textDim,
		Position = UDim2.fromOffset(0, 86),
		Size = UDim2.new(1, 0, 0, 20),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = info,
	})
	local statusText = if enclosure
		then ("In your park  ·  +%d / sec"):format(Progression.incomePerSecond(species.kl, owned.level))
		else ("Not in park  ·  needs a %s"):format(GameConfig.Enclosures[Progression.enclosureSizeFor(species.kl)].displayName)
	UIKit.label(statusText, {
		TextSize = 15,
		TextColor3 = if enclosure then C.money else C.accent,
		Position = UDim2.fromOffset(0, 110),
		Parent = info,
	})

	local actions = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 160, 1, 0),
		Parent = item,
	}, { UIKit.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right) })

	local canLevel, reason = Progression.canLevelUpWithCells(owned.level, data.kaijuCells)
	local levelText = if owned.level >= GameConfig.Progression.fusionLevel
		then "Max (fusion\ncoming later)"
		else ("Level up\n%d Cells"):format(Progression.levelUpCost(owned.level))
	local levelButton = UIKit.button(levelText, Color3.fromRGB(60, 160, 140), function()
		ClientState.request(Remotes.Actions.LevelUpKaiju, { instanceId = owned.instanceId })
	end, { Size = UDim2.fromOffset(160, 56), TextSize = 16, LayoutOrder = 1, Parent = actions })
	UIKit.setEnabled(levelButton, canLevel)
	if not canLevel and reason then
		levelButton:SetAttribute("Reason", reason)
	end

	if enclosure then
		UIKit.button("Remove from park", Color3.fromRGB(150, 90, 70), function()
			ClientState.request(Remotes.Actions.UnassignKaiju, { instanceId = owned.instanceId })
		end, { Size = UDim2.fromOffset(160, 56), TextSize = 16, LayoutOrder = 2, Parent = actions })
	else
		UIKit.button("Place in park", Color3.fromRGB(80, 140, 200), function()
			ClientState.request(Remotes.Actions.AssignKaiju, { instanceId = owned.instanceId })
		end, { Size = UDim2.fromOffset(160, 56), TextSize = 16, LayoutOrder = 2, Parent = actions })
	end
end

local function rebuild()
	if not frame.Visible then
		dirty = true
		return
	end
	dirty = false
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local data = ClientState.data
	if not data then
		return
	end
	local entries = {}
	local speciesOwned = {}
	for _, owned in data.kaijus do
		local species = KaijuRegistry.get(owned.speciesId)
		if species then
			table.insert(entries, { owned = owned, species = species })
			speciesOwned[species.id] = true
		end
	end
	table.sort(entries, function(a, b)
		if a.species.kl ~= b.species.kl then
			return a.species.kl > b.species.kl
		end
		if a.owned.level ~= b.owned.level then
			return a.owned.level > b.owned.level
		end
		return a.owned.instanceId < b.owned.instanceId
	end)
	local speciesCount = 0
	for _ in speciesOwned do
		speciesCount += 1
	end
	summary.Text = ("%d kaijus  ·  %d / %d species collected"):format(#entries, speciesCount, #KaijuRegistry.all())
	for i, entry in entries do
		card(i, entry.owned, entry.species, data)
	end
	if #entries == 0 then
		UIKit.label("No kaijus yet. Battle one in the Wilds and capture it!", { TextColor3 = C.textDim, Parent = list })
	end
end

function CollectionUI.init(gui: ScreenGui, onClose: () -> ())
	local content
	frame, content = UIKit.panel(gui, "Collection", onClose)
	summary = UIKit.label("", { TextColor3 = C.textDim, TextSize = 16, Size = UDim2.new(1, 0, 0, 22), Parent = content })
	local listHolder = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 1, -28),
		Parent = content,
	})
	list = UIKit.scrolling(listHolder)
	ClientState.onChanged(function(scope)
		if scope == "full" then
			rebuild()
		end
	end)
	return frame
end

function CollectionUI.setVisible(visible: boolean)
	frame.Visible = visible
	if visible and dirty then
		rebuild()
	end
end

return CollectionUI
