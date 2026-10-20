--!nonstrict
-- Builds the first-milestone test world from simple parts at server start:
--   * Hub island with the player spawn
--   * Wilds island (connected by a bridge) where wild kaijus roam
--   * Personal park plots in a ring around the Wilds, each with a grid of enclosure slots
-- All geometry is placeholder and lives under Workspace.World so it can later be replaced by a built map.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Palette = require(Shared.Visual.Palette)

local WorldBuilder = {}

export type PlotInfo = {
	index: number,
	model: Model,
	spawnCFrame: CFrame,
	slots: { BasePart }, -- slot pads, index = slot number
	sign: TextLabel,
}

export type WorldInfo = {
	root: Folder,
	hubSpawn: CFrame,
	wildsSpawn: CFrame,
	wildSpawnPoints: { Vector3 }, -- ground positions; index 1 is the guaranteed Kragmor spot
	wildsCenter: Vector3,
	wildsRadius: number,
	plots: { PlotInfo },
}

local GROUND_TOP = 0
local HUB_CENTER = Vector3.new(0, 0, 0)
local HUB_RADIUS = 70
local WILDS_CENTER = Vector3.new(0, 0, -290)
local WILDS_RADIUS = 150
local PLOT_RADIUS = 92

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	-- Shape first: changing Shape can resize a part, so Size/CFrame must be applied after it.
	if props.Shape then
		p.Shape = props.Shape
	end
	for key, value in props do
		if key ~= "Shape" then
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

-- Flat round island whose top surface sits at GROUND_TOP.
local function island(parent: Instance, name: string, center: Vector3, radius: number, color: Color3): Part
	local height = 12
	local top = part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(center.X, GROUND_TOP - height / 2, center.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = Enum.Material.Grass,
	})
	part(parent, {
		Name = name .. "Shore",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2 + 10, radius * 2 + 10),
		CFrame = CFrame.new(center.X, GROUND_TOP - height / 2 - 1.2, center.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Palette.World.sand,
		Material = Enum.Material.Sand,
	})
	return top
end

local function tree(parent: Instance, pos: Vector3, scale: number, leafColor: Color3)
	part(parent, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(10 * scale, 2.2 * scale, 2.2 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, 5 * scale, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Palette.World.wood,
		Material = Enum.Material.Wood,
	})
	part(parent, {
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 9 * scale,
		Position = pos + Vector3.new(0, 11 * scale, 0),
		Color = leafColor,
		Material = Enum.Material.Grass,
	})
	part(parent, {
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 6 * scale,
		Position = pos + Vector3.new(2.5 * scale, 14 * scale, 1 * scale),
		Color = leafColor:Lerp(Color3.new(1, 1, 1), 0.12),
		Material = Enum.Material.Grass,
	})
end

local function rock(parent: Instance, pos: Vector3, size: Vector3, rotation: number)
	part(parent, {
		Name = "Rock",
		Size = size,
		CFrame = CFrame.new(pos + Vector3.new(0, size.Y / 2 - 0.8, 0)) * CFrame.Angles(0.15, rotation, 0.1),
		Color = Palette.World.rock,
		Material = Enum.Material.Slate,
	})
end

local function sign(parent: Instance, pos: Vector3, facing: Vector3, text: string, width: number?): TextLabel
	local w = width or 16
	local board = part(parent, {
		Name = "Sign",
		Size = Vector3.new(w, 5, 0.6),
		CFrame = CFrame.lookAt(pos + Vector3.new(0, 7, 0), pos + Vector3.new(0, 7, 0) + facing),
		Color = Palette.World.wood,
		Material = Enum.Material.Wood,
	})
	part(parent, {
		Name = "SignPost",
		Size = Vector3.new(0.8, 5, 0.8),
		Position = pos + Vector3.new(0, 2.5, 0),
		Color = Palette.World.wood,
		Material = Enum.Material.Wood,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.3
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 244, 220)
	label.Text = text
	label.Parent = gui
	gui.Parent = board
	return label
end

local function setupLighting()
	Lighting.ClockTime = 15.2
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(70, 70, 90)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 160)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.3
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.32
		atmosphere.Offset = 0.15
		atmosphere.Color = Color3.fromRGB(206, 214, 236)
		atmosphere.Decay = Color3.fromRGB(120, 110, 160)
		atmosphere.Glare = 0.2
		atmosphere.Haze = 1.4
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Saturation = 0.12
		cc.Contrast = 0.05
		cc.Parent = Lighting
	end
end

local function buildHub(root: Folder): CFrame
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = root
	island(hub, "HubGround", HUB_CENTER, HUB_RADIUS, Palette.World.grass)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = HUB_CENTER + Vector3.new(0, 0.5, 20)
	spawn.Color = Palette.World.pad
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	local toWilds = (WILDS_CENTER - HUB_CENTER).Unit
	sign(hub, HUB_CENTER + toWilds * 30 + Vector3.new(-10, 0, 0), -toWilds, "Wilds  >>", 14)
	sign(hub, HUB_CENTER + Vector3.new(14, 0, 4), Vector3.new(0, 0, 1), "KAIJU PARK", 20)

	for i = 1, 7 do
		local angle = i * 0.9 + 0.4
		local pos = HUB_CENTER + Vector3.new(math.cos(angle) * 52, 0, math.sin(angle) * 52)
		if math.abs(pos.X) > 16 or pos.Z > 0 then
			tree(hub, pos, 1 + (i % 3) * 0.2, Palette.World.leaves)
		end
	end
	return spawn.CFrame + Vector3.new(0, 4, 0)
end

local function buildBridge(root: Folder)
	local bridge = Instance.new("Folder")
	bridge.Name = "Bridge"
	bridge.Parent = root
	local from = HUB_CENTER + Vector3.new(0, 0, -HUB_RADIUS + 6)
	local to = WILDS_CENTER + Vector3.new(0, 0, WILDS_RADIUS - 6)
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	part(bridge, {
		Name = "Deck",
		Size = Vector3.new(14, 1, length),
		CFrame = CFrame.lookAt(mid, to) + Vector3.new(0, -0.5, 0),
		Color = Palette.World.wood,
		Material = Enum.Material.WoodPlanks,
	})
	for _, side in { -1, 1 } do
		part(bridge, {
			Name = "Rail",
			Size = Vector3.new(0.8, 2.4, length),
			CFrame = CFrame.lookAt(mid, to) * CFrame.new(side * 7, 1.2, 0),
			Color = Palette.World.wood,
			Material = Enum.Material.Wood,
		})
	end
end

local function buildWilds(root: Folder): ({ Vector3 }, CFrame)
	local wilds = Instance.new("Folder")
	wilds.Name = "Wilds"
	wilds.Parent = root
	island(wilds, "WildsGround", WILDS_CENTER, WILDS_RADIUS, Palette.World.wildGrass)

	-- Spawn points: #1 sits right where the bridge lands so Kragmor is the first thing players meet.
	local points: { Vector3 } = {
		WILDS_CENTER + Vector3.new(0, 0, WILDS_RADIUS - 48),
		WILDS_CENTER + Vector3.new(-70, 0, 30),
		WILDS_CENTER + Vector3.new(70, 0, 20),
		WILDS_CENTER + Vector3.new(-40, 0, -70),
		WILDS_CENTER + Vector3.new(50, 0, -80),
		WILDS_CENTER + Vector3.new(0, 0, -20),
	}

	local rng = Random.new(42) -- fixed seed: same scenery every server
	for i = 1, 26 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(30, WILDS_RADIUS - 12)
		local pos = WILDS_CENTER + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		local nearPoint = false
		for _, p in points do
			if (p - pos).Magnitude < 26 then
				nearPoint = true
			end
		end
		if (pos - (WILDS_CENTER + Vector3.new(0, 0, WILDS_RADIUS))).Magnitude < 30 then
			nearPoint = true -- keep the bridge landing clear
		end
		if not nearPoint then
			if i % 3 == 0 then
				rock(wilds, pos, Vector3.new(rng:NextNumber(6, 14), rng:NextNumber(4, 10), rng:NextNumber(6, 14)), rng:NextNumber(0, 6))
			else
				tree(wilds, pos, rng:NextNumber(1, 1.7), if i % 5 == 0 then Palette.World.leavesAlt else Palette.World.leaves)
			end
		end
	end

	-- A few muted crystals for the "mysterious" tone.
	for i = 1, 5 do
		local angle = i * 1.25
		local pos = WILDS_CENTER + Vector3.new(math.cos(angle) * 110, 0, math.sin(angle) * 110)
		part(wilds, {
			Name = "Crystal",
			Size = Vector3.new(3, 9, 3),
			CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)) * CFrame.Angles(0.2, angle, 0.25),
			Color = Color3.fromRGB(150, 130, 220),
			Material = Enum.Material.Glass,
			Transparency = 0.15,
		})
	end

	local entry = WILDS_CENTER + Vector3.new(0, 4, WILDS_RADIUS - 14)
	sign(wilds, WILDS_CENTER + Vector3.new(12, 0, WILDS_RADIUS - 18), Vector3.new(0, 0, 1), "The Wilds", 14)
	return points, CFrame.lookAt(entry, entry + Vector3.new(0, 0, -1))
end

local function buildPlots(root: Folder): { PlotInfo }
	local parkFolder = Instance.new("Folder")
	parkFolder.Name = "Park"
	parkFolder.Parent = root

	local cfg = GameConfig.Park
	local plots: { PlotInfo } = {}
	-- Spread plots evenly over the ring, skipping the arc that faces the hub (where the bridge is).
	local toHub = HUB_CENTER - WILDS_CENTER
	local hubAngle = math.atan2(toHub.Z, toHub.X)
	local gap = math.rad(cfg.ringGapDegrees)
	local step = if cfg.maxPlots > 1 then (math.pi * 2 - gap) / (cfg.maxPlots - 1) else 0
	for index = 1, cfg.maxPlots do
		local angle = hubAngle + gap / 2 + (index - 1) * step
		local center = WILDS_CENTER + Vector3.new(math.cos(angle) * cfg.ringRadius, 0, math.sin(angle) * cfg.ringRadius)
		-- Plot frame: local +Z points at the Wilds; the entrance (spawn + sign) is on that side.
		local toWilds = Vector3.new(WILDS_CENTER.X - center.X, 0, WILDS_CENTER.Z - center.Z).Unit
		local plotCf = CFrame.lookAt(center, center - toWilds)
		local model = Instance.new("Model")
		model.Name = "Plot" .. index
		model:SetAttribute("PlotIndex", index)
		island(model, "Ground", center, PLOT_RADIUS, Palette.World.parkGround)

		local slotsFolder = Instance.new("Folder")
		slotsFolder.Name = "Slots"
		slotsFolder.Parent = model
		local slots: { BasePart } = {}
		local cols, rows = cfg.gridColumns, cfg.gridRows
		local slot = 0
		for r = 1, rows do
			for c = 1, cols do
				slot += 1
				local offset = Vector3.new((c - (cols + 1) / 2) * cfg.slotSpacing, 0.2, (r - (rows + 1) / 2) * cfg.slotSpacing - 6)
				-- Pads share the plot's rotation; their local +Z points to the entrance.
				local pad = part(slotsFolder, {
					Name = "Slot" .. slot,
					Size = Vector3.new(cfg.slotSpacing - 6, 0.4, cfg.slotSpacing - 6),
					CFrame = plotCf * CFrame.new(offset),
					Color = Palette.World.pad,
					Material = Enum.Material.Sand,
					CanCollide = true,
				})
				pad:SetAttribute("SlotIndex", slot)
				pad:SetAttribute("PlotIndex", index)
				slots[slot] = pad
			end
		end

		local enclosures = Instance.new("Folder")
		enclosures.Name = "Enclosures"
		enclosures.Parent = model

		local spawnPos = plotCf:PointToWorldSpace(Vector3.new(0, 4, PLOT_RADIUS - 14))
		local signLabel = sign(model, plotCf:PointToWorldSpace(Vector3.new(-14, 0, PLOT_RADIUS - 20)), toWilds, "Free plot", 22)

		model.Parent = parkFolder
		table.insert(plots, {
			index = index,
			model = model,
			spawnCFrame = CFrame.lookAt(spawnPos, center + Vector3.new(0, 4, 0)),
			slots = slots,
			sign = signLabel,
		})
	end
	return plots
end

function WorldBuilder.build(): WorldInfo
	local existing = Workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "World"
	root.Parent = Workspace

	setupLighting()

	part(root, {
		Name = "Sea",
		Size = Vector3.new(2048, 2, 2048),
		Position = Vector3.new(0, -4, 0),
		Color = Palette.World.water,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.1,
		Reflectance = 0.05,
	})

	local hubSpawn = buildHub(root)
	buildBridge(root)
	local points, wildsSpawn = buildWilds(root)
	local plots = buildPlots(root)

	return {
		root = root,
		hubSpawn = hubSpawn,
		wildsSpawn = wildsSpawn,
		wildSpawnPoints = points,
		wildsCenter = WILDS_CENTER,
		wildsRadius = WILDS_RADIUS,
		plots = plots,
	}
end

return WorldBuilder
