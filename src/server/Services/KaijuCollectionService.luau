--!nonstrict
-- Owned-kaiju operations: the provisional starter grant, Kaiju Cell leveling and fusion.
-- (Named KaijuCollectionService to avoid confusion with Roblox's CollectionService.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local KaijuRegistry = require(Shared.Data.KaijuRegistry)
local PlayerDataSchema = require(Shared.PlayerData.PlayerDataSchema)
local Progression = require(Shared.Progression.Progression)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)

local KaijuCollectionService = {}

export type Hooks = {
	isInBattle: (Player) -> boolean,
	onParkChanged: (Player) -> (), -- re-render the player's park (a fused partner may leave an enclosure)
}

local hooks: Hooks = {
	isInBattle = function()
		return false
	end,
	onParkChanged = function() end,
}

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

-- payload: { instanceId = kaiju that levels up, partnerId = identical kaiju that is consumed }
local function onFuse(player: Player, payload)
	local data = DataService.get(player)
	if not data then
		return false, "Still loading"
	end
	if hooks.isInBattle(player) then
		return false, "Finish your battle first"
	end
	if not NetService.isId(payload.instanceId) or not NetService.isId(payload.partnerId) then
		return false, "Invalid kaiju"
	end
	local primary = data.kaijus[payload.instanceId]
	local partner = data.kaijus[payload.partnerId]
	if not primary or not partner then
		return false, "You don't own that kaiju"
	end
	local species = KaijuRegistry.get(primary.speciesId)
	if not species then
		return false, "Unknown species"
	end
	local ok, reason = Progression.canFuse(primary, partner)
	if not ok then
		return false, reason
	end
	PlayerDataSchema.fuse(data, primary.instanceId, partner.instanceId)
	hooks.onParkChanged(player)
	DataService.replicate(player, "full")
	return true, ("Fusion complete! %s is now level %d."):format(species.displayName, primary.level)
end

-- Studio-only: grants money/cells so long progressions (leveling to 10, fusion) can be tested quickly.
-- Never registered on live servers.
local function onDevGrant(player: Player, payload)
	local data = DataService.get(player)
	if not data then
		return false, "Still loading"
	end
	local amount = 1000
	if payload.kind == "cells" then
		data.kaijuCells += amount
	elseif payload.kind == "money" then
		data.money += amount
	else
		return false, "Unknown grant"
	end
	DataService.replicate(player, "full")
	return true, ("[DEV] +%d %s"):format(amount, payload.kind)
end

function KaijuCollectionService.init(options: Hooks?)
	if options then
		hooks = options
	end
	DataService.onLoaded(grantStarter)
	NetService.handle(Remotes.Actions.LevelUpKaiju, onLevelUp)
	NetService.handle(Remotes.Actions.FuseKaiju, onFuse)
	if RunService:IsStudio() then
		NetService.handle(Remotes.Actions.DevGrant, onDevGrant)
	end
end

return KaijuCollectionService
