--!nonstrict
-- Building primitives for hand-made placeholder kaiju models (see KaijuDesigns).
-- Coordinates are in design units: feet at y = 0, the creature faces -Z, X is left/right.
-- KaijuModelFactory rescales the finished model, so designs don't need to care about final size.

local ModelKit = {}
ModelKit.__index = ModelKit

export type Opts = {
	material: Enum.Material?,
	transparency: number?,
	shadow: boolean?,
}

export type AnimGroup = {
	pivot: Vector3, -- joint position in design units
	kind: string, -- "leg" | "arm" | "tail" | "wing" | "head" | "sway" (see KaijuAnimator)
	phase: number, -- 0..1 offset in the gait cycle
	side: number, -- -1 left, 1 right, 0 centre (wings flap mirrored)
	amp: number, -- amplitude multiplier
}

function ModelKit.new(model: Model, seed: number?)
	return setmetatable({ model = model, rng = Random.new(seed or 1), groups = {}, current = nil }, ModelKit)
end

-- Parts created inside fn() belong to animation group `name` and rotate around `pivot`
-- (legs swing, tails sway, wings flap...). Re-using a name adds more parts to that group.
function ModelKit:group(name: string, pivot: Vector3, kind: string, params: { phase: number?, side: number?, amp: number? }?, fn: () -> ())
	if not self.groups[name] then
		local p = params or {}
		self.groups[name] = { pivot = pivot, kind = kind, phase = p.phase or 0, side = p.side or 0, amp = p.amp or 1 }
	end
	local previous = self.current
	self.current = name
	fn()
	self.current = previous
end

function ModelKit:_part(className: string, size: Vector3, cf: CFrame, color: Color3, opts: Opts?): BasePart
	local p = Instance.new(className)
	p.Size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
	p.CFrame = cf
	p.Color = color
	p.Material = (opts and opts.material) or Enum.Material.SmoothPlastic
	p.Transparency = (opts and opts.transparency) or 0
	p.CastShadow = if opts and opts.shadow == false then false else true
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false -- kaijus never block raycasts (e.g. build-mode slot picking)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if self.current then
		p:SetAttribute("AnimGroup", self.current)
	end
	p.Parent = self.model
	return p
end

-- Ellipsoid. `rot` is an optional rotation (CFrame.Angles).
function ModelKit:ball(size: Vector3, pos: Vector3, color: Color3, opts: Opts?, rot: CFrame?): BasePart
	local p = self:_part("Part", size, CFrame.new(pos) * (rot or CFrame.identity), color, opts)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

function ModelKit:box(size: Vector3, cf: CFrame, color: Color3, opts: Opts?): BasePart
	return self:_part("Part", size, cf, color, opts)
end

function ModelKit:wedge(size: Vector3, cf: CFrame, color: Color3, opts: Opts?): BasePart
	return self:_part("WedgePart", size, cf, color, opts)
end

-- Cylinder from a to b.
function ModelKit:cylinder(a: Vector3, b: Vector3, radius: number, color: Color3, opts: Opts?): BasePart?
	local length = (b - a).Magnitude
	if length < 1e-3 then
		return nil
	end
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
	local p = self:_part("Part", Vector3.new(length, radius * 2, radius * 2), cf, color, opts)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Smooth tapered tube through `points` (cylinders + ball joints). `colors` alternates per segment.
function ModelKit:tube(points: { Vector3 }, r0: number, r1: number, color: Color3, opts: Opts?, colors: { Color3 }?)
	local n = #points
	for i = 1, n - 1 do
		local t0 = (i - 1) / math.max(1, n - 1)
		local t1 = i / math.max(1, n - 1)
		local ra = r0 + (r1 - r0) * t0
		local rb = r0 + (r1 - r0) * t1
		local c = if colors then colors[(i - 1) % #colors + 1] else color
		self:cylinder(points[i], points[i + 1], (ra + rb) / 2, c, opts)
		self:ball(Vector3.one * rb * 2, points[i + 1], c, opts)
	end
	self:ball(Vector3.one * r0 * 2, points[1], if colors then colors[1] else color, opts)
end

function ModelKit.bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, steps: number): { Vector3 }
	local out = {}
	for i = 0, steps do
		local t = i / steps
		local u = 1 - t
		out[i + 1] = p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t)
	end
	return out
end

-- Tapered spike (three stacked cylinders). Optional tip colour.
function ModelKit:spike(base: Vector3, tip: Vector3, radius: number, color: Color3, tipColor: Color3?, opts: Opts?)
	local a = base:Lerp(tip, 0.45)
	local b = base:Lerp(tip, 0.78)
	self:cylinder(base, a, radius, color, opts)
	self:cylinder(a, b, radius * 0.62, tipColor or color, opts)
	self:cylinder(b, tip, radius * 0.3, tipColor or color, opts)
end

-- Flat triangle a-b-c built from two wedges (wings, fins, crests, membranes).
function ModelKit:tri(a: Vector3, b: Vector3, c: Vector3, color: Color3, thickness: number?, opts: Opts?)
	local th = thickness or 0.2
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local cross = ac:Cross(ab)
	if cross.Magnitude < 1e-6 or bc.Magnitude < 1e-6 then
		return
	end
	local right = cross.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	self:wedge(Vector3.new(th, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back), color, opts)
	self:wedge(Vector3.new(th, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back), color, opts)
end

function ModelKit:quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color3, thickness: number?, opts: Opts?)
	self:tri(a, b, c, color, thickness, opts)
	self:tri(a, c, d, color, thickness, opts)
end

-- Flat blade along a path (scythes, sword, tail blades). `side` is the blade's width direction.
function ModelKit:blade(points: { Vector3 }, w0: number, w1: number, side: Vector3, color: Color3, thickness: number?, opts: Opts?)
	local n = #points
	for i = 1, n - 1 do
		local a, b = points[i], points[i + 1]
		local dir = b - a
		if dir.Magnitude > 1e-3 then
			local w = w0 + (w1 - w0) * ((i - 0.5) / (n - 1))
			local normal = dir:Cross(side)
			if normal.Magnitude < 1e-4 then
				normal = dir:Cross(Vector3.yAxis)
			end
			local widthDir = normal:Cross(dir).Unit
			-- right-handed basis: widthDir x normal = dir
			local cf = CFrame.fromMatrix((a + b) / 2, widthDir, normal.Unit, dir.Unit)
			self:box(Vector3.new(w, thickness or 0.25, dir.Magnitude + 0.1), cf, color, opts)
		end
	end
end

-- Eye looking along `dir` (default -Z). Pass glow=true for an emissive iris.
function ModelKit:eye(pos: Vector3, size: number, iris: Color3, opts: { dir: Vector3?, glow: boolean?, pupil: Color3?, sclera: Color3?, slit: boolean? }?)
	local o = opts or {}
	local dir = (o.dir or Vector3.new(0, 0, -1)).Unit
	if o.sclera ~= false then
		self:ball(Vector3.one * size, pos, o.sclera or Color3.new(1, 1, 1))
	end
	local irisPos = pos + dir * size * 0.32
	self:ball(Vector3.one * size * 0.62, irisPos, iris, if o.glow then { material = Enum.Material.Neon } else nil)
	local pupilSize = if o.slit then Vector3.new(size * 0.14, size * 0.5, size * 0.14) else Vector3.one * size * 0.3
	self:ball(pupilSize, irisPos + dir * size * 0.2, o.pupil or Color3.fromRGB(15, 15, 18))
end

-- Row of teeth from a to b, pointing along `dir`.
function ModelKit:teeth(a: Vector3, b: Vector3, count: number, size: number, dir: Vector3, color: Color3?)
	for i = 0, count - 1 do
		local t = if count > 1 then i / (count - 1) else 0.5
		local base = a:Lerp(b, t)
		self:cylinder(base, base + dir.Unit * size, size * 0.2, color or Color3.fromRGB(240, 236, 220))
	end
end

-- Calls fn(side) for side = -1 (left) and 1 (right).
function ModelKit.mirror(fn: (number) -> ())
	fn(-1)
	fn(1)
end

-- Evenly spread unit vectors on a sphere (fur, spots, crystals).
function ModelKit.sphereDirections(count: number): { Vector3 }
	local out = {}
	local golden = math.pi * (3 - math.sqrt(5))
	for i = 0, count - 1 do
		local y = 1 - (i / math.max(1, count - 1)) * 2
		local r = math.sqrt(math.max(0, 1 - y * y))
		local theta = golden * i
		out[i + 1] = Vector3.new(math.cos(theta) * r, y, math.sin(theta) * r)
	end
	return out
end

return ModelKit
