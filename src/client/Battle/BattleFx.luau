--!nonstrict
-- Client-only visual effects for the battle arena: damage popups, shields, charge rings, chains,
-- cell bursts and fades. Everything here is presentation; it never affects game state.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Visual.Palette)

local BattleFx = {}

BattleFx.Colors = table.freeze({
	damage = Color3.fromRGB(255, 90, 80),
	blocked = Color3.fromRGB(110, 180, 255),
	charge = Color3.fromRGB(255, 205, 70),
	shield = Color3.fromRGB(90, 170, 255),
	chain = Color3.fromRGB(150, 150, 160),
	cells = Palette.UI.cells,
})

local function anchoredPart(parent: Instance, props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	if props.Shape then
		p.Shape = props.Shape
	end
	for k, v in props do
		if k ~= "Shape" then
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function tween(inst: Instance, seconds: number, goal, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

-- Floating text that rises and fades (damage numbers, "+AP", "BLOCKED").
function BattleFx.popup(parent: Instance, position: Vector3, text: string, color: Color3, scale: number?)
	local s = scale or 1
	local anchor = anchoredPart(parent, { Size = Vector3.one, Transparency = 1, Position = position })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220 * s, 70 * s)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.StudsOffsetWorldSpace = Vector3.zero
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(20, 20, 26)
	label.Parent = gui
	gui.Parent = anchor
	tween(gui, 1, { StudsOffsetWorldSpace = Vector3.new(0, 7, 0) })
	task.delay(0.55, function()
		tween(label, 0.45, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	Debris:AddItem(anchor, 1.1)
end

-- Translucent energy bubble around a model. Returns the shield part.
function BattleFx.shield(parent: Instance, model: Model): BasePart
	local cf, size = model:GetBoundingBox()
	local shield = anchoredPart(parent, {
		Name = "Shield",
		Size = size * 1.25 + Vector3.one * 2,
		CFrame = cf,
		Color = BattleFx.Colors.shield,
		Material = Enum.Material.ForceField,
		Transparency = 0,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.one * 0.2
	mesh.Parent = shield
	tween(mesh, 0.3, { Scale = Vector3.one }, Enum.EasingStyle.Back)
	return shield
end

function BattleFx.pulseShield(shield: BasePart)
	local mesh = shield:FindFirstChildOfClass("SpecialMesh")
	if not mesh then
		return
	end
	mesh.Scale = Vector3.one * 1.15
	shield.Color = Color3.new(1, 1, 1)
	tween(mesh, 0.35, { Scale = Vector3.one }, Enum.EasingStyle.Elastic)
	tween(shield, 0.35, { Color = BattleFx.Colors.shield })
end

function BattleFx.removeShield(shield: BasePart)
	local mesh = shield:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		tween(mesh, 0.25, { Scale = Vector3.one * 0.05 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	Debris:AddItem(shield, 0.3)
end

-- Gold ring that expands from the feet, plus rising sparks (Save).
function BattleFx.chargeRing(parent: Instance, model: Model)
	local cf, size = model:GetBoundingBox()
	local feet = cf.Position - Vector3.new(0, size.Y / 2 - 0.3, 0)
	local radius = math.max(size.X, size.Z) * 0.5
	local ring = anchoredPart(parent, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, radius, radius),
		CFrame = CFrame.new(feet) * CFrame.Angles(0, 0, math.pi / 2),
		Color = BattleFx.Colors.charge,
		Transparency = 0.2,
	})
	tween(ring, 0.7, { Size = Vector3.new(0.3, radius * 2.6, radius * 2.6), Transparency = 1 })
	Debris:AddItem(ring, 0.75)
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		local start = feet + Vector3.new(math.cos(angle) * radius, 0.5, math.sin(angle) * radius)
		local spark = anchoredPart(parent, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.9,
			Position = start,
			Color = BattleFx.Colors.charge,
			Material = Enum.Material.Neon,
		})
		tween(spark, 0.8, { Position = start + Vector3.new(0, size.Y * 0.9 + 3, 0), Transparency = 1, Size = Vector3.one * 0.2 })
		Debris:AddItem(spark, 0.85)
	end
end

-- Briefly tints a model through its Highlight.
function BattleFx.flash(highlight: Highlight, color: Color3, seconds: number?)
	highlight.FillColor = color
	highlight.FillTransparency = 0.2
	tween(highlight, seconds or 0.4, { FillTransparency = 1 })
end

-- Chain rings that spin in and tighten around a model (capture). Returns the folder (caller destroys).
function BattleFx.chains(parent: Instance, model: Model, seconds: number): Folder
	local cf, size = model:GetBoundingBox()
	local folder = Instance.new("Folder")
	folder.Name = "Chains"
	folder.Parent = parent
	local radius = math.max(size.X, size.Z) * 0.55 + 1
	local linkSize = Vector3.new(0.6, 0.6, math.max(1.2, radius * 0.35))
	local rings = {}
	for r, heightFraction in { 0.25, 0.5, 0.75 } do
		local center = cf.Position + Vector3.new(0, (heightFraction - 0.5) * size.Y, 0)
		local links = {}
		for i = 1, 12 do
			links[i] = anchoredPart(folder, {
				Size = linkSize,
				Color = BattleFx.Colors.chain,
				Material = Enum.Material.Metal,
			})
		end
		rings[r] = { center = center, links = links, spin = if r % 2 == 0 then -1 else 1 }
	end
	local start = os.clock()
	task.spawn(function()
		while folder.Parent do
			local alpha = math.min(1, (os.clock() - start) / seconds)
			local eased = 1 - (1 - alpha) ^ 3
			local currentRadius = radius * (1.8 - 0.8 * eased)
			for _, ring in rings do
				for i, link in ring.links do
					local angle = i / #ring.links * math.pi * 2 + ring.spin * (1 - eased) * 6
					local pos = ring.center + Vector3.new(math.cos(angle) * currentRadius, 0, math.sin(angle) * currentRadius)
					local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
					link.CFrame = CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, 0, if i % 2 == 0 then math.pi / 2 else 0)
				end
			end
			task.wait()
		end
	end)
	return folder
end

-- Small cubes that float up and fade (Defeat for Kaiju Cells).
function BattleFx.cellsBurst(parent: Instance, model: Model)
	local cf, size = model:GetBoundingBox()
	local rng = Random.new()
	for _ = 1, 18 do
		local start = cf.Position + Vector3.new(rng:NextNumber(-0.5, 0.5) * size.X, rng:NextNumber(-0.5, 0.5) * size.Y, rng:NextNumber(-0.5, 0.5) * size.Z)
		local cube = anchoredPart(parent, {
			Size = Vector3.one * rng:NextNumber(0.6, 1.4),
			CFrame = CFrame.new(start) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0),
			Color = BattleFx.Colors.cells,
			Material = Enum.Material.Neon,
		})
		local rise = Vector3.new(rng:NextNumber(-3, 3), size.Y * 0.6 + rng:NextNumber(4, 10), rng:NextNumber(-3, 3))
		tween(cube, 1.3, { CFrame = CFrame.new(start + rise) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Transparency = 1 })
		Debris:AddItem(cube, 1.4)
	end
end

-- Fades every visible part of a model.
function BattleFx.fade(model: Model, seconds: number)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			tween(d, seconds, { Transparency = 1 })
		elseif d:IsA("BillboardGui") then
			d.Enabled = false
		end
	end
end

return BattleFx
