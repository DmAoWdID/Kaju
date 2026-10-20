--!nonstrict
-- Spawns wild kaijus at the world's spawn points, makes them wander, and exposes a server-side
-- ProximityPrompt ("E") on each one. Battles lock a wild kaiju so only one player can fight it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local KaijuRegistry = require(Shared.Data.KaijuRegistry)
local KaijuModelFactory = require(Shared.Visual.KaijuModelFactory)
local Progression = require(Shared.Progression.Progression)

local WildKaijuService = {}

export type Wild = {
	id: string,
	species: any,
	model: Model,
	prompt: ProximityPrompt,
	pointIndex: number?, -- world spawn point; nil for dev-spawned kaijus (no respawn, free roaming)
	home: Vector3,
	position: Vector3,
	facing: Vector3,
	target: Vector3?,
	pauseUntil: number,
	state: string, -- "roaming" | "engaged"
	engagedBy: Player?,
	hover: number, -- vertical bob amplitude for flyers/jellies
	bobSeed: number,
}

local SPAWN = GameConfig.Spawning
local HOVER_ARCHETYPES = { flyer = 0.8, jelly = 0.6, fish = 0.4 }

local world = nil
local folder: Folder = nil
local wilds: { [string]: Wild } = {}
local occupiedPoints: { [number]: string } = {}
local guaranteedByPoint: { [number]: string } = {}
local nextId = 0
local rng = Random.new()
local triggerCallback: ((Player, string) -> ())? = nil

local function pickRandomSpecies()
	local available = {}
	for kl = 1, #GameConfig.KL do
		if #KaijuRegistry.byKL(kl) > 0 then
			available[kl] = true
		end
	end
	local kl = Progression.rollSpawnKL(rng:NextNumber(), available)
	if not kl then
		return nil
	end
	local candidates = KaijuRegistry.byKL(kl)
	return candidates[rng:NextInteger(1, #candidates)]
end

local function clampToWilds(pos: Vector3): Vector3
	local center = world.wildsCenter
	local offset = Vector3.new(pos.X - center.X, 0, pos.Z - center.Z)
	local maxDist = world.wildsRadius - 18
	if offset.Magnitude > maxDist then
		offset = offset.Unit * maxDist
	end
	return Vector3.new(center.X + offset.X, 0, center.Z + offset.Z)
end

local function createWild(species, home: Vector3, facing: Vector3, pointIndex: number?): Wild
	nextId += 1
	local id = "w" .. nextId
	local model = KaijuModelFactory.build(species, { nameplate = true, ring = true })
	model.Name = species.displayName
	model:SetAttribute("WildId", id)

	local root = model.PrimaryPart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BattlePrompt"
	prompt.ActionText = "Battle"
	prompt.ObjectText = ("%s  ·  KL %d"):format(species.displayName, species.kl)
	prompt.KeyboardKeyCode = Enum.KeyCode[GameConfig.Interaction.keyboardKey]
	prompt.GamepadKeyCode = Enum.KeyCode[GameConfig.Interaction.gamepadKey]
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = GameConfig.Interaction.promptDistance + math.max(root.Size.X, root.Size.Z) / 2
	prompt.Parent = root

	local wild: Wild = {
		id = id,
		species = species,
		model = model,
		prompt = prompt,
		pointIndex = pointIndex,
		home = home,
		position = home,
		facing = facing,
		target = nil,
		pauseUntil = os.clock() + rng:NextNumber(1, 3),
		state = "roaming",
		engagedBy = nil,
		hover = HOVER_ARCHETYPES[species.visual.archetype] or 0,
		bobSeed = nextId,
	}
	KaijuModelFactory.place(model, CFrame.lookAt(home, home + facing))
	model.Parent = folder

	prompt.Triggered:Connect(function(player)
		if triggerCallback then
			triggerCallback(player, id)
		end
	end)

	wilds[id] = wild
	return wild
end

local function spawnAt(pointIndex: number, speciesId: string?)
	if occupiedPoints[pointIndex] then
		return
	end
	local species = if speciesId then KaijuRegistry.get(speciesId) else pickRandomSpecies()
	if not species then
		warn("[WildKaijuService] no valid species for spawn point " .. pointIndex)
		return
	end
	local wild = createWild(species, world.wildSpawnPoints[pointIndex], Vector3.new(0, 0, 1), pointIndex)
	occupiedPoints[pointIndex] = wild.id
end

local function step(dt: number)
	local t = os.clock()
	for _, wild in wilds do
		if wild.state ~= "roaming" then
			continue
		end
		if t >= wild.pauseUntil then
			if not wild.target then
				local angle = rng:NextNumber(0, math.pi * 2)
				local dist = rng:NextNumber(4, SPAWN.wanderRadius)
				local target = wild.home + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
				-- world spawns stay on the Wilds island; dev spawns roam around wherever they were placed
				wild.target = if wild.pointIndex then clampToWilds(target) else Vector3.new(target.X, wild.home.Y, target.Z)
			end
			local target = wild.target :: Vector3
			local delta = target - wild.position
			local distance = delta.Magnitude
			local move = SPAWN.wanderSpeed * dt
			if distance <= move then
				wild.position = target
				wild.target = nil
				wild.pauseUntil = t + rng:NextNumber(SPAWN.wanderPauseMin, SPAWN.wanderPauseMax)
			else
				local dir = delta / distance
				wild.position += dir * move
				wild.facing = wild.facing:Lerp(dir, math.min(1, dt * 4))
			end
		end
		local bob = if wild.hover > 0 then math.sin(t * 2 + wild.bobSeed) * wild.hover else 0
		local pos = wild.position + Vector3.new(0, bob, 0)
		local flatFacing = Vector3.new(wild.facing.X, 0, wild.facing.Z)
		if flatFacing.Magnitude < 1e-3 then
			flatFacing = Vector3.new(0, 0, 1)
		end
		-- models face -Z (= LookVector), so lookAt points their front along the movement direction
		KaijuModelFactory.place(wild.model, CFrame.lookAt(pos, pos + flatFacing.Unit))
	end
end

function WildKaijuService.init(worldInfo, onTriggered: (Player, string) -> ())
	world = worldInfo
	triggerCallback = onTriggered
	folder = Instance.new("Folder")
	folder.Name = "WildKaijus"
	folder.Parent = worldInfo.root

	for _, entry in SPAWN.guaranteed do
		if KaijuRegistry.exists(entry.speciesId) and world.wildSpawnPoints[entry.spawnPoint] then
			guaranteedByPoint[entry.spawnPoint] = entry.speciesId
			spawnAt(entry.spawnPoint, entry.speciesId)
		else
			warn("[WildKaijuService] invalid guaranteed spawn " .. tostring(entry.speciesId))
		end
	end
	local spawned = 0
	for index = 1, #world.wildSpawnPoints do
		if spawned >= SPAWN.randomCount then
			break
		end
		if not guaranteedByPoint[index] and not occupiedPoints[index] then
			spawnAt(index, nil)
			spawned += 1
		end
	end

	RunService.Heartbeat:Connect(step)
end

function WildKaijuService.get(id: string): Wild?
	return wilds[id]
end

function WildKaijuService.distanceFrom(id: string, position: Vector3): number
	local wild = wilds[id]
	if not wild then
		return math.huge
	end
	local root = wild.model.PrimaryPart
	local center = if root then root.Position else wild.position
	local radius = if root then math.max(root.Size.X, root.Size.Z) / 2 else 0
	local flat = Vector3.new(center.X - position.X, 0, center.Z - position.Z)
	return math.max(0, flat.Magnitude - radius)
end

-- Locks a roaming wild kaiju for one player's battle. Returns false if unavailable.
function WildKaijuService.engage(id: string, player: Player, facePosition: Vector3?): boolean
	local wild = wilds[id]
	if not wild or wild.state ~= "roaming" then
		return false
	end
	wild.state = "engaged"
	wild.engagedBy = player
	wild.target = nil
	wild.prompt.Enabled = false
	if facePosition then
		local dir = Vector3.new(facePosition.X - wild.position.X, 0, facePosition.Z - wild.position.Z)
		if dir.Magnitude > 1e-3 then
			wild.facing = dir.Unit
			KaijuModelFactory.place(wild.model, CFrame.lookAt(wild.position, wild.position + dir.Unit))
		end
	end
	return true
end

-- Frees an engaged wild kaiju (player lost, fled or left).
function WildKaijuService.release(id: string)
	local wild = wilds[id]
	if not wild then
		return
	end
	wild.state = "roaming"
	wild.engagedBy = nil
	wild.pauseUntil = os.clock() + 2
	wild.prompt.Enabled = true
end

-- Removes a wild kaiju from the world (captured or defeated) and schedules a replacement.
function WildKaijuService.remove(id: string)
	local wild = wilds[id]
	if not wild then
		return
	end
	wilds[id] = nil
	wild.model:Destroy()
	local pointIndex = wild.pointIndex
	if pointIndex then
		occupiedPoints[pointIndex] = nil
		task.delay(SPAWN.respawnDelaySeconds, function()
			spawnAt(pointIndex, guaranteedByPoint[pointIndex])
		end)
	end
end

-- Dev/testing: spawns a wild kaiju at an arbitrary ground position. It never respawns.
-- Returns (ok, message).
local DEV_SPAWN_LIMIT = 12
function WildKaijuService.spawnCustom(speciesId: string, groundPosition: Vector3, facing: Vector3): (boolean, string?)
	local species = KaijuRegistry.get(speciesId)
	if not species then
		return false, "Unknown species"
	end
	local count = 0
	for _, wild in wilds do
		if not wild.pointIndex then
			count += 1
		end
	end
	if count >= DEV_SPAWN_LIMIT then
		return false, ("Dev spawn limit reached (%d). Clear them first."):format(DEV_SPAWN_LIMIT)
	end
	createWild(species, groundPosition, facing, nil)
	return true, nil
end

-- Removes every dev-spawned kaiju that is not currently in a battle. Returns how many were removed.
function WildKaijuService.clearCustom(): number
	local removed = 0
	for id, wild in wilds do
		if not wild.pointIndex and wild.state == "roaming" then
			WildKaijuService.remove(id)
			removed += 1
		end
	end
	return removed
end

return WildKaijuService
