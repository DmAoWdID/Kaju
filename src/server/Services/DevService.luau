--!nonstrict
-- Developer cheats for testing. Registered ONLY when running in Roblox Studio, so live servers never
-- accept these commands (the client panel is also hidden outside Studio).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KaijuRegistry = require(Shared.Data.KaijuRegistry)
local PlayerDataSchema = require(Shared.PlayerData.PlayerDataSchema)
local Progression = require(Shared.Progression.Progression)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)
local WildKaijuService = require(script.Parent.WildKaijuService)

local DevService = {}

local GRANT_AMOUNT = 1000

-- Ground point in front of the player where a spawned kaiju should stand.
local function spawnSpotFor(player: Player, kl: number): (Vector3?, Vector3?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, nil
	end
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	forward = if forward.Magnitude > 1e-3 then forward.Unit else Vector3.new(0, 0, -1)
	local spot = root.Position + forward * (22 + kl * 6)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { character }
	local world = Workspace:FindFirstChild("World")
	local wildFolder = world and world:FindFirstChild("WildKaijus")
	if wildFolder then
		table.insert(exclude, wildFolder)
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(spot + Vector3.new(0, 80, 0), Vector3.new(0, -300, 0), params)
	local ground = if hit then hit.Position.Y else 0
	-- face the player
	return Vector3.new(spot.X, ground, spot.Z), -forward
end

local commands = {}

commands.cells = function(_, data)
	data.kaijuCells += GRANT_AMOUNT
	return true, ("[DEV] +%d Kaiju Cells"):format(GRANT_AMOUNT)
end

commands.money = function(_, data)
	data.money += GRANT_AMOUNT
	return true, ("[DEV] +$%d"):format(GRANT_AMOUNT)
end

commands.allKaijus = function(_, data)
	local count = 0
	for _, species in KaijuRegistry.all() do
		PlayerDataSchema.addKaiju(data, species.id, 1, os.time())
		count += 1
	end
	return true, ("[DEV] Added %d kaijus to your collection"):format(count)
end

commands.maxChain = function(_, data)
	data.chainTier = Progression.maxChainTier()
	local chain = Progression.chain(data.chainTier)
	return true, ("[DEV] %s equipped (captures up to KL %d)"):format(chain.displayName, chain.maxKL)
end

commands.spawn = function(player, _, payload)
	local species = KaijuRegistry.get(payload.speciesId)
	if not species then
		return false, "Unknown species"
	end
	local position, facing = spawnSpotFor(player, species.kl)
	if not position then
		return false, "No character to spawn near"
	end
	local ok, err = WildKaijuService.spawnCustom(species.id, position, facing)
	if not ok then
		return false, err
	end
	return true, ("[DEV] A wild %s appeared!"):format(species.displayName)
end

commands.clearSpawns = function()
	local removed = WildKaijuService.clearCustom()
	return true, ("[DEV] Removed %d spawned kaijus"):format(removed)
end

-- Commands that don't change player data (so no state push is needed).
local NO_DATA_CHANGE = { spawn = true, clearSpawns = true }

function DevService.init(isInBattle: (Player) -> boolean)
	if not RunService:IsStudio() then
		return
	end
	NetService.handle(Remotes.Actions.DevCommand, function(player, payload)
		local command = commands[payload.command]
		if type(payload.command) ~= "string" or not command then
			return false, "Unknown dev command"
		end
		local data = DataService.get(player)
		if not data then
			return false, "Still loading"
		end
		if payload.command == "spawn" and isInBattle(player) then
			return false, "Finish your battle first"
		end
		local ok, message = command(player, data, payload)
		if ok and not NO_DATA_CHANGE[payload.command] then
			DataService.replicate(player, "full")
		end
		return ok, message
	end)
	print("[DevService] Studio dev cheats enabled")
end

return DevService
