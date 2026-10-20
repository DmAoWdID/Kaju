--!nonstrict
-- Personal park plots: plot assignment, enclosure placement, housing kaijus, passive income, travel.
-- The plot visuals are re-rendered from player data, so data stays the single source of truth.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local KaijuModelFactory = require(Shared.Visual.KaijuModelFactory)
local KaijuRegistry = require(Shared.Data.KaijuRegistry)
local Palette = require(Shared.Visual.Palette)
local PlayerDataSchema = require(Shared.PlayerData.PlayerDataSchema)
local Progression = require(Shared.Progression.Progression)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)

local ParkService = {}

local world = nil
local playerPlot: { [Player]: any } = {}
local plotOwner: { [number]: Player } = {}
local isInBattle: (Player) -> boolean = function()
	return false
end

local ENCLOSURE_FLOOR = {
	Small = Color3.fromRGB(150, 196, 120),
	Medium = Color3.fromRGB(176, 170, 120),
	Large = Color3.fromRGB(190, 150, 110),
}

local function slotCount(): number
	return GameConfig.Park.gridColumns * GameConfig.Park.gridRows
end

local function newPart(parent: Instance, props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function buildEnclosure(parent: Instance, pad: BasePart, enclosure, data): Model
	local size = GameConfig.Enclosures[enclosure.sizeId]
	local model = Instance.new("Model")
	model.Name = "Enclosure_" .. enclosure.enclosureId
	model:SetAttribute("EnclosureId", enclosure.enclosureId)
	local footprint = size.footprint
	-- Build in the pad's frame so enclosures follow the plot's rotation; local +Z faces the entrance.
	local base = pad.CFrame * CFrame.new(0, pad.Size.Y / 2, 0)

	newPart(model, {
		Name = "Floor",
		Size = Vector3.new(footprint, 0.3, footprint),
		CFrame = base * CFrame.new(0, 0.15, 0),
		Color = ENCLOSURE_FLOOR[enclosure.sizeId] or Palette.World.grass,
		Material = Enum.Material.Grass,
		CanCollide = true,
	})
	local half = footprint / 2
	local postHeight = 4 + size.order
	local postsPerSide = 3 + size.order
	for i = 0, postsPerSide do
		local t = -half + footprint * (i / postsPerSide)
		for _, offset in { Vector3.new(t, 0, -half), Vector3.new(t, 0, half), Vector3.new(-half, 0, t), Vector3.new(half, 0, t) } do
			newPart(model, {
				Name = "Post",
				Size = Vector3.new(0.8, postHeight, 0.8),
				CFrame = base * CFrame.new(offset + Vector3.new(0, postHeight / 2, 0)),
				Color = Palette.World.fence,
				Material = Enum.Material.Wood,
			})
		end
	end
	for _, rail in {
		{ Vector3.new(0, 0, -half), Vector3.new(footprint, 0.5, 0.4) },
		{ Vector3.new(0, 0, half), Vector3.new(footprint, 0.5, 0.4) },
		{ Vector3.new(-half, 0, 0), Vector3.new(0.4, 0.5, footprint) },
		{ Vector3.new(half, 0, 0), Vector3.new(0.4, 0.5, footprint) },
	} do
		for _, h in { postHeight * 0.45, postHeight * 0.9 } do
			newPart(model, {
				Name = "Rail",
				Size = rail[2],
				CFrame = base * CFrame.new(rail[1] + Vector3.new(0, h, 0)),
				Color = Palette.World.fence,
				Material = Enum.Material.Wood,
			})
		end
	end

	local occupant = enclosure.kaijuInstanceId and data.kaijus[enclosure.kaijuInstanceId]
	local species = occupant and KaijuRegistry.get(occupant.speciesId)
	local labelText = size.displayName .. "\n(empty)"
	if occupant and species then
		local kaiju = KaijuModelFactory.build(species, { nameplate = true, nameplateText = ("KL %d · Lv %d"):format(species.kl, occupant.level) })
		local _, bbox = kaiju:GetBoundingBox()
		local fit = (footprint * 0.7) / math.max(bbox.X, bbox.Z, 1)
		if fit < 1 then
			kaiju:ScaleTo(kaiju:GetScale() * fit) -- ScaleTo is absolute; keep the factory's scale
		end
		-- Kaiju models face their -Z; turn them around so they face the entrance (pad +Z).
		KaijuModelFactory.place(kaiju, base * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, math.pi, 0))
		kaiju.Parent = model
		labelText = ("+%d / sec"):format(Progression.incomePerSecond(species.kl, occupant.level))
	end

	local labelAnchor = newPart(model, {
		Name = "LabelAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = base * CFrame.new(0, postHeight + 2, half),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 44)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = if occupant then Palette.UI.money else Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = labelText
	label.Parent = gui
	gui.Parent = labelAnchor

	model.Parent = parent
	return model
end

function ParkService.render(player: Player)
	local plot = playerPlot[player]
	local data = DataService.get(player)
	if not plot or not data then
		return
	end
	local folder = plot.model:FindFirstChild("Enclosures")
	folder:ClearAllChildren()
	local used = {}
	for _, enclosure in data.enclosures do
		local pad = plot.slots[enclosure.slot]
		if pad then
			used[enclosure.slot] = true
			buildEnclosure(folder, pad, enclosure, data)
		end
	end
	for index, pad in plot.slots do
		pad.Transparency = if used[index] then 1 else 0
	end
end

local function assignPlot(player: Player)
	for _, plot in world.plots do
		if not plotOwner[plot.index] then
			plotOwner[plot.index] = player
			playerPlot[player] = plot
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			plot.sign.Text = player.DisplayName .. "'s Park"
			player:SetAttribute("PlotIndex", plot.index)
			return plot
		end
	end
	return nil
end

local function releasePlot(player: Player)
	local plot = playerPlot[player]
	if not plot then
		return
	end
	playerPlot[player] = nil
	plotOwner[plot.index] = nil
	plot.model:SetAttribute("OwnerUserId", nil)
	plot.sign.Text = "Free plot"
	plot.model:FindFirstChild("Enclosures"):ClearAllChildren()
	for _, pad in plot.slots do
		pad.Transparency = 0
	end
end

local function teleport(player: Player, cf: CFrame)
	local character = player.Character
	if character and character.PrimaryPart then
		character:PivotTo(cf)
	end
end

local function onPlaceEnclosure(player: Player, payload)
	local data = DataService.get(player)
	local plot = playerPlot[player]
	if not data or not plot then
		return false, "You don't have a park plot on this server"
	end
	local sizeId = payload.sizeId
	local slot = payload.slot
	local size = type(sizeId) == "string" and GameConfig.Enclosures[sizeId]
	if not size then
		return false, "Unknown enclosure"
	end
	if not NetService.isInt(slot, 1, slotCount()) then
		return false, "Invalid spot"
	end
	if PlayerDataSchema.enclosureAtSlot(data, slot) then
		return false, "That spot is already taken"
	end
	if data.money < size.price then
		return false, ("You need $%d"):format(size.price)
	end
	data.money -= size.price
	PlayerDataSchema.addEnclosure(data, sizeId, slot)
	ParkService.render(player)
	DataService.replicate(player, "full")
	return true, ("%s built!"):format(size.displayName)
end

local function onAssign(player: Player, payload)
	local data = DataService.get(player)
	if not data or not playerPlot[player] then
		return false, "You don't have a park plot on this server"
	end
	local instanceId = payload.instanceId
	if not NetService.isId(instanceId) then
		return false, "Invalid kaiju"
	end
	local owned = data.kaijus[instanceId]
	local species = owned and KaijuRegistry.get(owned.speciesId)
	if not owned or not species then
		return false, "You don't own that kaiju"
	end
	if PlayerDataSchema.enclosureOf(data, instanceId) then
		return false, "Already in your park"
	end

	local target = nil
	if payload.enclosureId ~= nil then
		if not NetService.isId(payload.enclosureId) then
			return false, "Invalid enclosure"
		end
		target = data.enclosures[payload.enclosureId]
		if not target then
			return false, "Unknown enclosure"
		end
		if target.kaijuInstanceId then
			return false, "That enclosure is occupied"
		end
		if not Progression.enclosureFits(target.sizeId, species.kl) then
			return false, "Wrong enclosure size for this KL"
		end
	else
		for slot = 1, slotCount() do
			local e = PlayerDataSchema.enclosureAtSlot(data, slot)
			if e and not e.kaijuInstanceId and Progression.enclosureFits(e.sizeId, species.kl) then
				target = e
				break
			end
		end
		if not target then
			local needed = Progression.enclosureSizeFor(species.kl)
			return false, ("No empty %s enclosure. Build one in your park first."):format(GameConfig.Enclosures[needed].displayName)
		end
	end

	target.kaijuInstanceId = instanceId
	ParkService.render(player)
	DataService.replicate(player, "full")
	return true, ("%s moved into your park"):format(species.displayName)
end

local function onUnassign(player: Player, payload)
	local data = DataService.get(player)
	if not data then
		return false, "Still loading"
	end
	if not NetService.isId(payload.instanceId) then
		return false, "Invalid kaiju"
	end
	local enclosure = PlayerDataSchema.enclosureOf(data, payload.instanceId)
	if not enclosure then
		return false, "That kaiju isn't in your park"
	end
	enclosure.kaijuInstanceId = nil
	ParkService.render(player)
	DataService.replicate(player, "full")
	return true
end

local function onTravel(player: Player, payload)
	if isInBattle(player) then
		return false, "Finish your battle first"
	end
	local destination = payload.destination
	if destination == "park" then
		local plot = playerPlot[player]
		if not plot then
			return false, "No park plot available on this server"
		end
		teleport(player, plot.spawnCFrame)
	elseif destination == "wilds" then
		teleport(player, world.wildsSpawn)
	elseif destination == "hub" then
		teleport(player, world.hubSpawn)
	else
		return false, "Unknown destination"
	end
	return true
end

function ParkService.init(worldInfo, battleCheck: (Player) -> boolean)
	world = worldInfo
	isInBattle = battleCheck

	DataService.onLoaded(function(player)
		if assignPlot(player) then
			ParkService.render(player)
		else
			NetService.notify(player, "All park plots on this server are taken. Park features are unavailable.", "error")
		end
	end)
	Players.PlayerRemoving:Connect(releasePlot)

	NetService.handle(Remotes.Actions.PlaceEnclosure, onPlaceEnclosure)
	NetService.handle(Remotes.Actions.AssignKaiju, onAssign)
	NetService.handle(Remotes.Actions.UnassignKaiju, onUnassign)
	NetService.handle(Remotes.Actions.Travel, onTravel)

	-- Passive income: every housed kaiju earns money each tick (documented: "every second").
	task.spawn(function()
		while true do
			task.wait(GameConfig.Economy.incomeTickSeconds)
			for _, player in DataService.loadedPlayers() do
				local data = DataService.get(player)
				if data and playerPlot[player] then
					local income = 0
					for _, enclosure in data.enclosures do
						local owned = enclosure.kaijuInstanceId and data.kaijus[enclosure.kaijuInstanceId]
						local species = owned and KaijuRegistry.get(owned.speciesId)
						if species then
							income += Progression.incomePerSecond(species.kl, owned.level)
						end
					end
					if income > 0 then
						data.money += income
						DataService.replicate(player, "currency")
					end
				end
			end
		end
	end)
end

return ParkService
