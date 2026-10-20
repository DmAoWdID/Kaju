--!strict
-- Builds placeholder kaiju models. Each species has a hand-built design (KaijuDesigns, following the
-- concept art); species without one fall back to a generic body plan from species.visual.archetype.
--
-- REPLACING WITH REAL MODELS: put a Model named after the species id (e.g. "kragmor") inside
-- ReplicatedStorage.KaijuModels. Its pivot must sit at the feet, facing -Z. The factory then clones that
-- model instead of building a placeholder. Nothing else needs to change.
--
-- Built models: non-colliding, pivot at the feet facing -Z, PrimaryPart "Root" (invisible, anchored box).
-- Every other part is welded to Root, so moving the model only needs Root's CFrame (cheap to replicate).
-- Use KaijuModelFactory.place(model, cframe) to move it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require("../Config/GameConfig")
local KaijuDesigns = require("./KaijuDesigns")
local ModelKit = require("./ModelKit")
local Palette = require("./Palette")
local Types = require("../Types")

local KaijuModelFactory = {}

export type BuildOptions = {
	scale: number?, -- extra multiplier (e.g. smaller inside park enclosures)
	nameplate: boolean?,
	nameplateText: string?,
	ring: boolean?,
}

local BASE_UNIT = 1.6 -- studs per placeholder unit at KL scale 1 (generic body plans)
-- Hand-built designs are rescaled so their "presence" = max(height, 0.6 * max(width, length)) equals
-- DESIGN_PRESENCE studs x KL modelScale x species.visual.scale.
local DESIGN_PRESENCE = 11

local function newPart(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.Parent = model
	return p
end

type Builder = {
	model: Model,
	s: number,
	v: (x: number, y: number, z: number) -> Vector3,
	ellipsoid: (name: string, size: Vector3, pos: Vector3, color: Color3) -> Part,
	limb: (name: string, a: Vector3, b: Vector3, thickness: number, color: Color3) -> Part,
	block: (name: string, size: Vector3, cf: CFrame, color: Color3) -> Part,
	eyes: (pos: Vector3, spacing: number, size: number, iris: Color3?) -> (),
}

local function makeBuilder(model: Model, s: number): Builder
	local b = {} :: Builder
	b.model = model
	b.s = s
	b.v = function(x, y, z)
		return Vector3.new(x, y, z) * s
	end
	-- size/pos are already in studs (use b.v)
	b.ellipsoid = function(name, size, pos, color)
		local p = newPart(model, name, size, CFrame.new(pos), color)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return p
	end
	b.limb = function(name, a, c, thickness, color)
		local length = (c - a).Magnitude
		local cf = CFrame.lookAt((a + c) / 2, c)
		return newPart(model, name, Vector3.new(thickness, thickness, math.max(length, 0.05)), cf, color)
	end
	b.block = function(name, size, cf, color)
		return newPart(model, name, size, cf, color)
	end
	b.eyes = function(pos, spacing, size, iris)
		for _, side in { -1, 1 } do
			local eyePos = pos + Vector3.new(side * spacing, 0, 0)
			b.ellipsoid("Eye", Vector3.one * size, eyePos, Color3.new(1, 1, 1))
			b.ellipsoid(
				"Pupil",
				Vector3.one * size * 0.5,
				eyePos + Vector3.new(0, 0, -size * 0.38),
				iris or Color3.fromRGB(20, 20, 24)
			)
		end
	end
	return b
end

local ARCHETYPES: { [string]: (b: Builder, p: Color3, s2: Color3, a: Color3) -> () } = {}

ARCHETYPES.crawler = function(b, p, s2, a)
	local v = b.v
	b.ellipsoid("Body", v(7, 3, 9), v(0, 3.2, 0), s2)
	b.ellipsoid("Carapace", v(8.4, 2.6, 10), v(0, 4.4, 0.6), p)
	for i, z in { -2.6, 0.4, 3.2 } do
		b.block("Plate" .. i, v(6.5 - i, 0.8, 1.6), CFrame.new(v(0, 5.6 - i * 0.15, z)) * CFrame.Angles(math.rad(-15), 0, 0), p:Lerp(Color3.new(1, 1, 1), 0.15))
	end
	b.ellipsoid("Head", v(3.6, 2.4, 3.2), v(0, 3, -5), s2)
	b.eyes(v(0, 3.7, -6.2), 0.8 * b.s, 0.7 * b.s)
	for _, side in { -1, 1 } do
		b.limb("Mandible", v(side * 1.1, 2.7, -6), v(side * 0.3, 2.1, -7.8), 0.55 * b.s, a)
		for i, z in { -2.6, 0, 2.6 } do
			local hip, knee, foot = v(side * 3.2, 3.2, z), v(side * 6.2, 4.8, z * 1.15), v(side * 7.6, 0, z * 1.35)
			b.limb("Leg" .. i .. "A", hip, knee, 0.75 * b.s, a)
			b.limb("Leg" .. i .. "B", knee, foot, 0.6 * b.s, a)
		end
	end
end

ARCHETYPES.blob = function(b, p, s2, a)
	local v = b.v
	b.ellipsoid("Body", v(8, 7.5, 8), v(0, 4.4, 0), p)
	b.eyes(v(0, 5.6, -3.4), 1.6 * b.s, 2.1 * b.s)
	b.block("Mouth", v(3.2, 0.6, 0.6), CFrame.new(v(0, 3.3, -3.8)), a)
	for i, offset in { -1, 0, 1 } do
		b.ellipsoid("Tuft" .. i, v(1.6, 2.4, 1.6), v(offset * 1.2, 8.4 - math.abs(offset) * 0.5, 0), s2)
	end
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			b.ellipsoid("Foot", v(2, 1, 2.6), v(x * 2.2, 0.5, z * 1.8), s2)
		end
	end
end

ARCHETYPES.flyer = function(b, p, s2, a)
	local v = b.v
	b.ellipsoid("Body", v(3, 4.2, 3.4), v(0, 6, 0), p)
	b.ellipsoid("Head", v(2.8, 2.6, 2.8), v(0, 8.7, -0.6), p)
	b.eyes(v(0, 9, -1.8), 0.7 * b.s, 0.9 * b.s, a)
	for _, side in { -1, 1 } do
		b.block("WingInner", v(7, 0.3, 4), CFrame.new(v(side * 4.6, 7.2, 0.4)) * CFrame.Angles(0, 0, math.rad(side * 12)), s2)
		b.block("WingOuter", v(5, 0.3, 3), CFrame.new(v(side * 9.6, 8.4, 0.8)) * CFrame.Angles(0, math.rad(side * 10), math.rad(side * 24)), s2)
		b.limb("Claw", v(side * 0.8, 4.4, 0), v(side * 1.1, 2.6, 0.3), 0.4 * b.s, a)
		b.limb("Ear", v(side * 0.8, 9.8, -0.4), v(side * 1.4, 11.2, 0), 0.5 * b.s, p)
	end
	b.limb("Tail", v(0, 5, 1.5), v(0, 3.4, 5.5), 0.6 * b.s, s2)
end

ARCHETYPES.fish = function(b, p, s2, a)
	local v = b.v
	b.ellipsoid("Body", v(4.2, 4.2, 12), v(0, 4.4, 0), p)
	b.ellipsoid("Belly", v(3.6, 2.4, 10), v(0, 3.4, -0.4), p:Lerp(Color3.new(1, 1, 1), 0.35))
	b.ellipsoid("Head", v(3.6, 3.4, 4.6), v(0, 4.6, -6.6), p)
	b.eyes(v(0, 5.6, -8.2), 1.3 * b.s, 0.8 * b.s, a)
	b.block("Dorsal", v(0.4, 3.2, 3.2), CFrame.new(v(0, 7, 0.4)) * CFrame.Angles(math.rad(25), 0, 0), s2)
	b.block("TailTop", v(0.4, 4, 2.4), CFrame.new(v(0, 6.6, 7.2)) * CFrame.Angles(math.rad(-35), 0, 0), s2)
	b.block("TailBottom", v(0.4, 3.2, 2.2), CFrame.new(v(0, 2.8, 7)) * CFrame.Angles(math.rad(35), 0, 0), s2)
	for _, side in { -1, 1 } do
		b.limb("Tusk", v(side * 1.1, 4.4, -8.4), v(side * 2, 6.8, -10.6), 0.6 * b.s, a)
		b.block("Fin", v(3, 0.3, 2), CFrame.new(v(side * 2.6, 3, -1.5)) * CFrame.Angles(0, 0, math.rad(side * -25)), s2)
	end
end

ARCHETYPES.jelly = function(b, p, s2, a)
	local v = b.v
	b.ellipsoid("Dome", v(10, 6, 10), v(0, 9.4, 0), p)
	local inner = b.ellipsoid("Core", v(7.6, 3, 7.6), v(0, 7.4, 0), a)
	inner.Transparency = 0.25
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2
		local top = v(math.cos(angle) * 3.2, 7, math.sin(angle) * 3.2)
		local mid = v(math.cos(angle + 0.5) * 3.9, 3.8, math.sin(angle + 0.5) * 3.9)
		local bottom = v(math.cos(angle) * 4.6, 0.4, math.sin(angle) * 4.6)
		local color = if i % 2 == 0 then s2 else p
		b.limb("TentacleA", top, mid, 0.5 * b.s, color)
		b.limb("TentacleB", mid, bottom, 0.4 * b.s, color)
	end
	b.eyes(v(0, 9.8, -4.6), 1.6 * b.s, 1 * b.s)
end

ARCHETYPES.quadruped = function(b, p, s2, a)
	local v = b.v
	b.ellipsoid("Torso", v(5.2, 4.6, 10), v(0, 5.6, 0), p)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local hip, knee, foot = v(x * 2.1, 5, z * 3.3), v(x * 2.7, 2.6, z * 3.6), v(x * 2.7, 0, z * 3.2)
			b.limb("LegA", hip, knee, 1.4 * b.s, p)
			b.limb("LegB", knee, foot, 1.2 * b.s, s2)
			b.ellipsoid("Paw", v(1.8, 0.8, 2.2), foot + v(0, 0.4, -0.4), s2)
		end
	end
	b.limb("Neck", v(0, 6.6, -4.4), v(0, 8, -6.6), 2.2 * b.s, p)
	b.ellipsoid("Head", v(3.2, 2.8, 4.2), v(0, 8.3, -8), p)
	b.ellipsoid("Jaw", v(2.6, 1.2, 3.2), v(0, 7.2, -8.6), s2)
	b.eyes(v(0, 9, -9.4), 0.95 * b.s, 0.8 * b.s, a)
	local prev = v(0, 5.6, 5)
	for i = 1, 4 do
		local nextPos = v(0, 5.4 - i * 0.7, 5 + i * 1.8)
		b.limb("Tail" .. i, prev, nextPos, (1.6 - i * 0.28) * b.s, p)
		prev = nextPos
	end
	for i, z in { -3, -1, 1, 3 } do
		b.block("Spike" .. i, v(0.5, 1.6 - math.abs(z) * 0.12, 1), CFrame.new(v(0, 8, z)) * CFrame.Angles(math.rad(-20), 0, 0), a)
	end
end

ARCHETYPES.serpent = function(b, p, s2, a)
	local v = b.v
	local segments = 9
	local first: Vector3? = nil
	for i = 0, segments - 1 do
		local r = 2.6 - i * 0.17
		local pos = v(math.sin(i * 0.9) * 3.6, r, -5 + i * 2.5)
		if i == 0 then
			first = pos
		end
		b.ellipsoid("Segment" .. i, v(r * 2, r * 2, r * 2.4), pos, if i % 2 == 0 then p else s2)
		b.ellipsoid("Stripe" .. i, v(r * 1.2, r * 0.5, r * 1.6), pos + v(0, r * 0.85, 0), a)
	end
	assert(first)
	local headPos = v(0, 7.6, -9)
	b.limb("Neck", first, headPos, 3.2 * b.s, p)
	b.limb("NeckStripe", first + v(0, 0, -1.4), headPos + v(0, -0.6, -1.4), 1.2 * b.s, a)
	b.ellipsoid("Head", v(3.6, 2.8, 4.4), headPos, p)
	b.eyes(headPos + v(0, 0.7, -1.8), 1 * b.s, 0.8 * b.s, a)
end

ARCHETYPES.biped = function(b, p, s2, a)
	local v = b.v
	for _, side in { -1, 1 } do
		b.limb("Thigh", v(side * 1.8, 6.4, 0), v(side * 2.1, 3.2, -0.4), 2.1 * b.s, p)
		b.limb("Shin", v(side * 2.1, 3.2, -0.4), v(side * 2.1, 0.4, 0), 1.8 * b.s, s2)
		b.block("Foot", v(2.2, 0.8, 3), CFrame.new(v(side * 2.1, 0.4, -0.6)), s2)
		b.limb("UpperArm", v(side * 3.6, 11.4, 0), v(side * 4.8, 8.6, -0.8), 1.6 * b.s, p)
		b.limb("Forearm", v(side * 4.8, 8.6, -0.8), v(side * 4.6, 6.2, -1.8), 1.4 * b.s, p)
		b.ellipsoid("Fist", v(1.8, 1.8, 1.8), v(side * 4.6, 5.8, -2), s2)
		b.limb("Horn", v(side * 1, 15, 0), v(side * 2.3, 17.2, 0.6), 0.6 * b.s, s2)
		b.ellipsoid("Shoulder", v(2.6, 2, 2.6), v(side * 3.4, 11.8, 0), a)
	end
	b.ellipsoid("Torso", v(6, 7.4, 4.6), v(0, 9.6, 0), p)
	b.ellipsoid("Chest", v(3.8, 4.4, 1), v(0, 10, -2.1), s2)
	b.ellipsoid("Head", v(3, 3, 3.2), v(0, 14, -0.4), p)
	b.eyes(v(0, 14.4, -1.8), 0.75 * b.s, 0.75 * b.s, a)
	b.limb("Tail", v(0, 7, 2), v(0, 2.6, 6.4), 1.8 * b.s, p)
	for i = 1, 3 do
		b.block("BackSpike" .. i, v(0.5, 1.6, 1), CFrame.new(v(0, 13 - i * 1.8, 2.3)) * CFrame.Angles(math.rad(30), 0, 0), a)
	end
end

function KaijuModelFactory.scaleFor(species: Types.KaijuSpecies): number
	local klScale = GameConfig.KL[species.kl].modelScale
	return BASE_UNIT * klScale * species.visual.scale
end

local function addNameplate(model: Model, root: BasePart, species: Types.KaijuSpecies, text: string?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromOffset(220, 54)
	gui.StudsOffsetWorldSpace = Vector3.new(0, root.Size.Y / 2 + 2.5, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 180
	gui.LightInfluence = 0
	gui.Adornee = root

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.6, 0)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.4
	name.Text = species.displayName
	name.Parent = gui

	local badge = Instance.new("TextLabel")
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.new(0.5, 0, 0.6, 0)
	badge.Size = UDim2.new(0.6, 0, 0.4, 0)
	badge.BackgroundColor3 = Palette.KL[species.kl]
	badge.Font = Enum.Font.GothamBold
	badge.TextScaled = true
	badge.TextColor3 = Color3.fromRGB(20, 20, 24)
	badge.Text = text or ("KL " .. species.kl)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = badge
	badge.Parent = gui

	gui.Parent = model
end

local function finalize(model: Model, species: Types.KaijuSpecies, opts: BuildOptions?)
	local bboxCf, bboxSize = model:GetBoundingBox()
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = bboxSize
	root.CFrame = bboxCf
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = true
	root.Parent = model
	model.PrimaryPart = root
	-- Keep the pivot at the build origin (the feet), not Root's centre.
	root.PivotOffset = root.CFrame:ToObjectSpace(CFrame.new())

	if opts and opts.ring then
		local radius = math.max(bboxSize.X, bboxSize.Z) * 0.6
		local ring = Instance.new("Part")
		ring.Name = "KLRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.2, radius * 2, radius * 2)
		ring.CFrame = CFrame.new(model.WorldPivot.Position + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Color = Palette.KL[species.kl]
		ring.Transparency = 0.55
		ring.Material = Enum.Material.SmoothPlastic
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanTouch = false
		ring.CanQuery = false
		ring.CastShadow = false
		ring.Parent = model
	end
	if opts and opts.nameplate then
		addNameplate(model, root, species, opts.nameplateText)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			d.Anchored = false
			d.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
		end
	end
	model:SetAttribute("SpeciesId", species.id)
end

-- Moves a factory-built model so its feet pivot lands on `cf`.
-- Welds only work inside the Workspace: outside it, moving Root alone would leave the body behind
-- (and the welds would then lock in that wrong offset once parented). So:
--   * not yet in the Workspace -> PivotTo moves every part together
--   * in the Workspace         -> move only Root; the welded body follows (cheap to replicate)
function KaijuModelFactory.place(model: Model, cf: CFrame)
	local root = model.PrimaryPart
	if root and model:IsDescendantOf(workspace) then
		root.CFrame = cf * root.PivotOffset:Inverse()
	else
		model:PivotTo(cf)
	end
end

local function prepareOverride(template: Model, species: Types.KaijuSpecies, scale: number): Model
	local model = template:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	if scale ~= 1 then
		model:ScaleTo(model:GetScale() * scale)
	end
	model:PivotTo(CFrame.new())
	return model
end

-- Returns a model with its pivot at the origin (feet, facing -Z). Position it with KaijuModelFactory.place
-- (in the world) or PivotTo (inside a ViewportFrame, where welds are not simulated).
function KaijuModelFactory.build(species: Types.KaijuSpecies, opts: BuildOptions?): Model
	local extra = (opts and opts.scale) or 1
	local overrides = ReplicatedStorage:FindFirstChild("KaijuModels")
	local template = overrides and overrides:FindFirstChild(species.id)
	local model: Model
	local design = (KaijuDesigns :: any)[species.id]
	if template and template:IsA("Model") then
		model = prepareOverride(template, species, extra)
	elseif design then
		model = Instance.new("Model")
		design(ModelKit.new(model, #species.id))
		model.WorldPivot = CFrame.new()
		local _, size = model:GetBoundingBox()
		local presence = math.max(size.Y, 0.6 * math.max(size.X, size.Z))
		local target = DESIGN_PRESENCE * GameConfig.KL[species.kl].modelScale * species.visual.scale * extra
		if presence > 0 then
			model:ScaleTo(target / presence)
		end
	else
		model = Instance.new("Model")
		local visual = species.visual
		local build = ARCHETYPES[visual.archetype] or ARCHETYPES.blob
		build(
			makeBuilder(model, KaijuModelFactory.scaleFor(species) * extra),
			Palette.rgb(visual.primary),
			Palette.rgb(visual.secondary),
			Palette.rgb(visual.accent)
		)
		model.WorldPivot = CFrame.new()
	end
	model.Name = species.displayName
	finalize(model, species, opts)
	return model
end

return KaijuModelFactory
