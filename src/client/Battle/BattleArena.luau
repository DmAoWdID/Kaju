--!nonstrict
-- Client-only 3D battle stage inspired by Jurassic World: The Game: the two kaijus face each other on a
-- floating arena, seen side-on, and act out the server's round events (attack, defend, save, knock-out,
-- capture). The arena exists only on the battling player's client, far from the shared world, so
-- several players can battle at once. It is purely presentation; outcomes always come from the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KaijuModelFactory = require(Shared.Visual.KaijuModelFactory)
local KaijuRegistry = require(Shared.Data.KaijuRegistry)
local Palette = require(Shared.Visual.Palette)

local BattleFx = require(script.Parent.BattleFx)

local BattleArena = {}

local ORIGIN = Vector3.new(0, 250, 6000) -- far from the shared world (which ends around |x|,|z| < 1100)
local GAP = 10 -- studs between the two kaijus' facing edges
local RENDER_STEP = "KaijuParkBattleArena"
local FOV = 50

type Actor = {
	side: string,
	model: Model,
	home: Vector3,
	baseCf: CFrame,
	worldOffset: Vector3, -- animated, world space
	localAction: CFrame, -- animated, model space (tilts, crouches)
	depth: number,
	height: number,
	alive: boolean,
	idlePhase: number,
	idleScale: number,
	highlight: Highlight,
	shield: BasePart?,
}

local stage: Folder? = nil
local actors: { [string]: Actor } = {}
local camCurrent = CFrame.new()
local camTarget = CFrame.new()
local shakeAmount = 0
local running = false

-- Runs `step(alpha)` every frame for `seconds`, with easing. Yields.
local function animate(seconds: number, style: Enum.EasingStyle, direction: Enum.EasingDirection, step: (number) -> ())
	local start = os.clock()
	while true do
		local raw = math.min(1, (os.clock() - start) / seconds)
		step(TweenService:GetValue(raw, style, direction))
		if raw >= 1 or not running then
			break
		end
		RunService.RenderStepped:Wait()
	end
end

local function other(side: string): string
	return if side == "player" then "wild" else "player"
end

function BattleArena.shake(amount: number)
	shakeAmount = math.max(shakeAmount, amount)
end

local function part(parent: Instance, props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
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

local function buildStage(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "KaijuBattleArena"
	local vertical = CFrame.Angles(0, 0, math.pi / 2)
	part(folder, {
		Name = "Ground",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(10, 190, 190),
		CFrame = CFrame.new(ORIGIN - Vector3.new(0, 5, 0)) * vertical,
		Color = Palette.World.grassDark,
		Material = Enum.Material.Grass,
	})
	part(folder, {
		Name = "Underside",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(36, 150, 150),
		CFrame = CFrame.new(ORIGIN - Vector3.new(0, 26, 0)) * vertical,
		Color = Palette.World.rockDark,
		Material = Enum.Material.Slate,
	})
	part(folder, {
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 130, 130),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 0.05, 0)) * vertical,
		Color = Palette.World.sand,
		Material = Enum.Material.Sand,
	})
	local rng = Random.new(7)
	for i = 1, 16 do
		local angle = i / 16 * math.pi * 2
		-- leave the camera side (+Z) open so pillars never block the view
		if math.sin(angle) < 0.55 then
			local height = rng:NextNumber(10, 26)
			local pos = ORIGIN + Vector3.new(math.cos(angle) * 84, height / 2 - 1, math.sin(angle) * 84)
			part(folder, {
				Name = "Pillar",
				Size = Vector3.new(7, height, 7),
				CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), angle, rng:NextNumber(-0.06, 0.06)),
				Color = Palette.World.rock,
				Material = Enum.Material.Slate,
			})
		end
	end
	for i = 1, 4 do
		local angle = math.pi + i * 0.55
		part(folder, {
			Name = "Crystal",
			Size = Vector3.new(4, 14, 4),
			CFrame = CFrame.new(ORIGIN + Vector3.new(math.cos(angle) * 72, 6, math.sin(angle) * 72)) * CFrame.Angles(0.25, angle, 0.2),
			Color = Color3.fromRGB(150, 130, 220),
			Material = Enum.Material.Glass,
			Transparency = 0.15,
		})
	end
	folder.Parent = Workspace
	return folder
end

local function frameCamera(instant: boolean?)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local minX, maxX, maxH = ORIGIN.X - 18, ORIGIN.X + 18, 10
	for _, actor in actors do
		minX = math.min(minX, actor.home.X - actor.depth / 2 - 3)
		maxX = math.max(maxX, actor.home.X + actor.depth / 2 + 3)
		maxH = math.max(maxH, actor.height)
	end
	local span = maxX - minX
	local mid = Vector3.new((minX + maxX) / 2, ORIGIN.Y, ORIGIN.Z)
	local viewport = camera.ViewportSize
	local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9
	local vHalf = math.rad(FOV / 2)
	local hHalf = math.atan(math.tan(vHalf) * aspect)
	local distance = math.max((span * 0.5 * 1.15) / math.tan(hHalf), (maxH * 1.5) / math.tan(vHalf)) + 8
	local focus = mid + Vector3.new(0, maxH * 0.45, 0)
	-- Lowering the camera (in its own frame) lifts the kaijus above the action bar at the bottom.
	camTarget = CFrame.lookAt(focus + Vector3.new(0, maxH * 0.3 + 5, distance), focus) * CFrame.new(0, -maxH * 0.28, 0)
	if instant then
		camCurrent = camTarget
	end
end

local function onRender(dt: number)
	local t = os.clock()
	for _, actor in actors do
		if actor.model.Parent then
			local idle = CFrame.identity
			if actor.alive then
				idle = CFrame.new(0, math.sin(t * 2.2 + actor.idlePhase) * 0.12 * actor.idleScale, 0)
					* CFrame.Angles(math.sin(t * 1.4 + actor.idlePhase) * 0.025, 0, 0)
			end
			KaijuModelFactory.place(actor.model, CFrame.new(actor.worldOffset) * actor.baseCf * actor.localAction * idle)
		end
	end
	local camera = Workspace.CurrentCamera
	if camera then
		camCurrent = camCurrent:Lerp(camTarget, 1 - math.exp(-dt * 4))
		local shake = CFrame.identity
		if shakeAmount > 0.02 then
			shake = CFrame.new((math.random() - 0.5) * shakeAmount, (math.random() - 0.5) * shakeAmount, 0)
			shakeAmount *= math.exp(-dt * 7)
		else
			shakeAmount = 0
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = FOV
		camera.CFrame = camCurrent * shake
	end
end

local function topOf(actor: Actor): Vector3
	local cf, size = actor.model:GetBoundingBox()
	return cf.Position + Vector3.new(0, size.Y / 2 + 1.5, 0)
end

local function spawnActor(side: string, speciesId: string): Actor?
	local species = KaijuRegistry.get(speciesId)
	if not species or not stage then
		return nil
	end
	local model = KaijuModelFactory.build(species)
	local _, size = model:GetBoundingBox() -- built at the origin, facing -Z
	local sign = if side == "player" then -1 else 1
	local depth = size.Z
	local home = ORIGIN + Vector3.new(sign * (GAP / 2 + depth / 2), 0, 0)
	-- Face the opponent, turned slightly towards the camera for a 3/4 view.
	local facing = Vector3.new(-sign, 0, 0.3).Unit
	local actor: Actor = {
		side = side,
		model = model,
		home = home,
		baseCf = CFrame.lookAt(home, home + facing),
		worldOffset = Vector3.new(0, 40, 0), -- starts in the air for the entrance drop
		localAction = CFrame.identity,
		depth = depth,
		height = size.Y,
		alive = true,
		idlePhase = if side == "player" then 0 else 1.7,
		idleScale = math.clamp(size.Y / 8, 0.6, 3),
		highlight = nil :: any,
		shield = nil,
	}
	KaijuModelFactory.place(model, CFrame.new(actor.worldOffset) * actor.baseCf)
	model.Parent = stage
	local highlight = Instance.new("Highlight")
	highlight.Adornee = model
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	actor.highlight = highlight
	actors[side] = actor
	frameCamera()
	return actor
end

-- Drops an actor into the arena. Yields.
local function entrance(actor: Actor)
	animate(0.7, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out, function(a)
		actor.worldOffset = Vector3.new(0, 40 * (1 - a), 0)
	end)
	actor.worldOffset = Vector3.zero
	BattleArena.shake(math.clamp(actor.height / 6, 0.6, 2.5))
end

-- Starts the arena with the wild kaiju (async entrance). Safe to call once per battle.
function BattleArena.start(wildSpeciesId: string)
	BattleArena.stop()
	running = true
	stage = buildStage()
	local wild = spawnActor("wild", wildSpeciesId)
	frameCamera(true)
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, onRender)
	if wild then
		task.spawn(entrance, wild)
	end
end

function BattleArena.hasPlayer(speciesId: string): boolean
	local actor = actors.player
	return actor ~= nil and actor.model:GetAttribute("SpeciesId") == speciesId
end

-- Brings in the player's kaiju. Yields until it has landed.
function BattleArena.setPlayer(speciesId: string)
	if not running or BattleArena.hasPlayer(speciesId) then
		return
	end
	if actors.player then
		actors.player.model:Destroy()
		actors.player = nil
	end
	local actor = spawnActor("player", speciesId)
	if actor then
		entrance(actor)
	end
end

local function recoil(target: Actor, strength: number)
	local away = Vector3.new(target.home.X - ORIGIN.X, 0, 0).Unit
	animate(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function(a)
		target.worldOffset = away * strength * a
		target.localAction = CFrame.Angles(math.rad(12) * a, 0, 0)
	end)
	animate(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, function(a)
		target.worldOffset = away * strength * (1 - a)
		target.localAction = CFrame.Angles(math.rad(12) * (1 - a), 0, 0)
	end)
	target.worldOffset = Vector3.zero
	target.localAction = if target.shield then CFrame.new(0, -0.4, 0) * CFrame.Angles(math.rad(-6), 0, 0) else CFrame.identity
end

-- Wind-up, lunge, impact, return. `onImpact` fires at the moment of contact. Yields.
local function attack(attacker: Actor, target: Actor, event, onImpact: () -> ())
	local toTarget = Vector3.new(target.home.X - attacker.home.X, 0, 0)
	local dir = toTarget.Unit
	local reach = math.max(1, toTarget.Magnitude - attacker.depth / 2 - target.depth / 2 + 1.5)
	local ap = event.ap or 1
	local windupDistance = 1.5 + ap * 0.6 -- bigger charge, bigger wind-up
	animate(0.12 + ap * 0.04, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function(a)
		attacker.worldOffset = -dir * windupDistance * a
		attacker.localAction = CFrame.Angles(math.rad(12) * a, 0, 0)
	end)
	animate(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function(a)
		attacker.worldOffset = dir * (-windupDistance + (reach + windupDistance) * a)
		attacker.localAction = CFrame.Angles(math.rad(12) * (1 - a) - math.rad(10) * a, 0, 0)
	end)

	-- impact
	onImpact()
	local damage = event.damage or 0
	local blocked = event.blocked or 0
	if target.shield and blocked > 0 then
		BattleFx.pulseShield(target.shield)
		BattleFx.flash(target.highlight, BattleFx.Colors.blocked, 0.35)
		BattleFx.popup(stage, topOf(target), "-" .. damage, BattleFx.Colors.damage, 1)
		BattleFx.popup(stage, topOf(target) + Vector3.new(0, 3, 0), "BLOCKED " .. math.floor(blocked + 0.5), BattleFx.Colors.blocked, 0.7)
	else
		BattleFx.flash(target.highlight, BattleFx.Colors.damage, 0.45)
		BattleFx.popup(stage, topOf(target), "-" .. damage, BattleFx.Colors.damage, 1 + math.min(0.6, damage / 80))
	end
	BattleArena.shake(math.clamp(damage / 14, 0.4, 3))
	task.spawn(recoil, target, math.clamp(damage / 10, 0.8, 4))

	animate(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function(a)
		attacker.worldOffset = dir * reach * (1 - a)
		attacker.localAction = CFrame.Angles(-math.rad(10) * (1 - a), 0, 0)
	end)
	attacker.worldOffset = Vector3.zero
	attacker.localAction = if attacker.shield then CFrame.new(0, -0.4, 0) * CFrame.Angles(math.rad(-6), 0, 0) else CFrame.identity
end

local function defend(actor: Actor)
	BattleFx.popup(stage, topOf(actor), "DEFEND", BattleFx.Colors.blocked, 0.8)
	actor.shield = BattleFx.shield(stage, actor.model)
	animate(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function(a)
		actor.localAction = CFrame.new(0, -0.4 * a, 0) * CFrame.Angles(math.rad(-6) * a, 0, 0)
	end)
end

local function save(actor: Actor)
	BattleFx.chargeRing(stage, actor.model)
	BattleFx.popup(stage, topOf(actor), "SAVE  +AP", BattleFx.Colors.charge, 0.8)
	animate(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function(a)
		actor.worldOffset = Vector3.new(0, 1.2 * a, 0)
	end)
	animate(0.25, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out, function(a)
		actor.worldOffset = Vector3.new(0, 1.2 * (1 - a), 0)
	end)
	actor.worldOffset = Vector3.zero
end

local function clearShields()
	for _, actor in actors do
		if actor.shield then
			BattleFx.removeShield(actor.shield)
			actor.shield = nil
			actor.localAction = CFrame.identity
		end
	end
end

-- Plays one round of server events in order. onImpact(targetSide, damage) lets the UI drop HP bars
-- exactly when a hit lands. Yields until the round has finished playing.
function BattleArena.playRound(events: { any }, onImpact: (string, number) -> ())
	if not running then
		return
	end
	local stances = {}
	for _, event in events do
		local actor = actors[event.side]
		if actor and (event.action == "Defend" or event.action == "Save") then
			table.insert(stances, task.spawn(if event.action == "Defend" then defend else save, actor))
		end
	end
	if #stances > 0 then
		task.wait(0.55)
	end
	for _, event in events do
		local attacker, target = actors[event.side], actors[other(event.side)]
		if event.action == "Attack" and attacker and target then
			attack(attacker, target, event, function()
				onImpact(target.side, event.damage or 0)
			end)
			task.wait(0.15)
		end
	end
	task.wait(0.2)
	clearShields()
end

-- Knock-out: tips over and sinks a little. Yields.
function BattleArena.knockOut(side: string)
	local actor = actors[side]
	if not actor or not running then
		return
	end
	actor.alive = false
	local tilt = if side == "player" then 1 else -1
	animate(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function(a)
		actor.localAction = CFrame.new(0, -actor.height * 0.12 * a, 0) * CFrame.Angles(0, 0, math.rad(80) * a * tilt)
	end)
	BattleArena.shake(math.clamp(actor.height / 5, 0.8, 3))
	task.wait(0.3)
end

-- Capture: chains wrap the wild kaiju, which vanishes in a flash. Yields.
function BattleArena.capture()
	local actor = actors.wild
	if not actor or not running then
		return
	end
	local chains = BattleFx.chains(stage, actor.model, 0.9)
	task.wait(1)
	actor.highlight.FillColor = Color3.new(1, 1, 1)
	TweenService:Create(actor.highlight, TweenInfo.new(0.35), { FillTransparency = 0 }):Play()
	task.wait(0.4)
	BattleFx.popup(stage, topOf(actor), "CAPTURED!", BattleFx.Colors.charge, 1.4)
	BattleFx.fade(actor.model, 0.3)
	for _, link in chains:GetChildren() do
		TweenService:Create(link, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	end
	BattleArena.shake(1.2)
	task.wait(0.45)
	chains:Destroy()
end

-- Defeat for Kaiju Cells: the wild kaiju dissolves into floating cells. Yields.
function BattleArena.dissolve(cells: number?)
	local actor = actors.wild
	if not actor or not running then
		return
	end
	BattleFx.cellsBurst(stage, actor.model)
	BattleFx.fade(actor.model, 0.8)
	if cells then
		BattleFx.popup(stage, topOf(actor), ("+%d Cells"):format(cells), BattleFx.Colors.cells, 1.3)
	end
	task.wait(1)
end

-- The wild kaiju breaks free and runs off (failed capture). Yields.
function BattleArena.escape()
	local actor = actors.wild
	if not actor or not running then
		return
	end
	actor.alive = true
	actor.localAction = CFrame.identity
	BattleFx.popup(stage, topOf(actor), "ESCAPED!", BattleFx.Colors.damage, 1.2)
	BattleFx.fade(actor.model, 0.8)
	animate(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function(a)
		actor.worldOffset = Vector3.new(60 * a, 0, -20 * a)
	end)
end

-- The player's kaiju backs away (retreat). Yields.
function BattleArena.retreat()
	local actor = actors.player
	if not actor or not running then
		return
	end
	BattleFx.fade(actor.model, 0.6)
	animate(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function(a)
		actor.worldOffset = Vector3.new(-40 * a, 0, 0)
	end)
end

function BattleArena.isRunning(): boolean
	return running
end

-- Tears the arena down and hands the camera back to the player.
function BattleArena.stop()
	if running then
		RunService:UnbindFromRenderStep(RENDER_STEP)
	end
	running = false
	for _, actor in actors do
		actor.model:Destroy()
	end
	table.clear(actors)
	if stage then
		stage:Destroy()
		stage = nil
	end
	shakeAmount = 0
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
	end
end

return BattleArena
