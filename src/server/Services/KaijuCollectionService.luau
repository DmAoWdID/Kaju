--!nonstrict
-- Owned-kaiju operations: the provisional starter grant and Kaiju Cell leveling.
-- (Named KaijuCollectionService to avoid confusion with Roblox's CollectionService.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local KaijuRegistry = require(Shared.Data.KaijuRegistry)
local PlayerDataSchema = require(Shared.PlayerData.PlayerDataSchema)
local Progression = require(Shared.Progression.Progression)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)

local KaijuCollectionService = {}

-- Provisional: new players receive one starter kaiju housed in a free enclosure (see GameConfig.Starter).
local function grantStarter(player: Player, data)
	if data.starterGranted then
		return
	end
	local starter = GameConfig.Starter
	if not KaijuRegistry.exists(starter.speciesId) then
		warn("[KaijuCollectionService] starter species missing: " .. starter.speciesId)
		return
	end
	data.starterGranted = true
	local kaiju = PlayerDataSchema.addKaiju(data, starter.speciesId, starter.level, os.time())
	if starter.enclosure and GameConfig.Enclosures[starter.enclosure] and not PlayerDataSchema.enclosureAtSlot(data, 1) then
		local enclosure = PlayerDataSchema.addEnclosure(data, starter.enclosure, 1)
		enclosure.kaijuInstanceId = kaiju.instanceId
	end
	local species = KaijuRegistry.get(starter.speciesId)
	task.delay(2, function()
		NetService.notify(player, ("Welcome! Your first kaiju, %s, is waiting in your park."):format(species.displayName), "good")
	end)
end

local function onLevelUp(player: Player, payload)
	local data = DataService.get(player)
	if not data then
		return false, "Still loading"
	end
	if not NetService.isId(payload.instanceId) then
		return false, "Invalid kaiju"
	end
	local owned = data.kaijus[payload.instanceId]
	if not owned or not KaijuRegistry.exists(owned.speciesId) then
		return false, "You don't own that kaiju"
	end
	local ok, reason = Progression.canLevelUpWithCells(owned.level, data.kaijuCells)
	if not ok then
		return false, reason
	end
	data.kaijuCells -= Progression.levelUpCost(owned.level)
	owned.level += 1
	DataService.replicate(player, "full")
	return true, ("Level up! Now level %d"):format(owned.level)
end

function KaijuCollectionService.init()
	DataService.onLoaded(grantStarter)
	NetService.handle(Remotes.Actions.LevelUpKaiju, onLevelUp)
end

return KaijuCollectionService
