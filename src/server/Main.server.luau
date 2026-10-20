--!nonstrict
-- Server entry point. Boot order matters:
--   remotes -> data -> world -> collection (starter grant) -> park (renders after the grant) -> wilds -> battles

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KaijuRegistry = require(Shared.Data.KaijuRegistry)

local Services = script.Parent.Services
local NetService = require(Services.NetService)
local DataService = require(Services.DataService)
local KaijuCollectionService = require(Services.KaijuCollectionService)
local ParkService = require(Services.ParkService)
local ShopService = require(Services.ShopService)
local WildKaijuService = require(Services.WildKaijuService)
local BattleService = require(Services.BattleService)
local DevService = require(Services.DevService)
local RideService = require(Services.RideService)
local WorldBuilder = require(script.Parent.World.WorldBuilder)

local clean = KaijuRegistry.report(function(line)
	warn("[KaijuData] " .. line)
end)
print(("[KaijuPark] %d kaiju species loaded%s"):format(#KaijuRegistry.all(), if clean then "" else " (with data ERRORS, see warnings)"))

NetService.init()
local world = WorldBuilder.build()
-- onLoaded callbacks run in registration order: starter grant must precede the park render.
KaijuCollectionService.init({
	isInBattle = BattleService.isInBattle,
	onParkChanged = ParkService.render,
	onKaijuRemoved = function(player, instanceId)
		if RideService.isRiding(player, instanceId) then
			RideService.dismount(player)
		end
	end,
})
ParkService.init(world, BattleService.isInBattle)
ShopService.init()
BattleService.init()
WildKaijuService.init(world, BattleService.onPromptTriggered)
DevService.init(BattleService.isInBattle) -- Studio-only cheats; does nothing on live servers
RideService.init({ isInBattle = BattleService.isInBattle, onChanged = ParkService.render })
ParkService.setRideCheck(RideService.isRiding)
BattleService.setBeforeStart(RideService.dismount)
DataService.init() -- last: starts handling players once every service is listening

print("[KaijuPark] server ready")
