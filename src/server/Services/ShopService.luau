--!nonstrict
-- Chain shop. Enclosures are bought at placement time (ParkService.PlaceEnclosure).
-- Prices always come from GameConfig; the client only says which tier it wants.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = require(Shared.Progression.Progression)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)

local ShopService = {}

local function onBuyChain(player: Player, payload)
	local data = DataService.get(player)
	if not data then
		return false, "Still loading"
	end
	local tier = payload.tier
	if not NetService.isInt(tier, 1, Progression.maxChainTier()) then
		return false, "Unknown chain"
	end
	if tier <= data.chainTier then
		return false, "You already own this chain"
	end
	if tier ~= data.chainTier + 1 then
		return false, "Buy the previous chain first"
	end
	local chain = Progression.chain(tier)
	if data.money < chain.price then
		return false, ("You need $%d"):format(chain.price)
	end
	data.money -= chain.price
	data.chainTier = tier
	DataService.replicate(player, "full")
	return true, ("%s equipped! You can now capture up to KL %d."):format(chain.displayName, chain.maxKL)
end

function ShopService.init()
	NetService.handle(Remotes.Actions.BuyChain, onBuyChain)
end

return ShopService
