--!strict
local T = require("./TestLib")
local Progression = require("../src/shared/Progression/Progression")
local GameConfig = require("../src/shared/Config/GameConfig")

local describe, it, eq, truthy = T.describe, T.it, T.eq, T.truthy

describe("Progression", function()
	it("maps KL to documented enclosure sizes", function()
		eq(Progression.enclosureSizeFor(1), "Small")
		eq(Progression.enclosureSizeFor(2), "Small")
		eq(Progression.enclosureSizeFor(3), "Medium")
		eq(Progression.enclosureSizeFor(4), "Medium")
		eq(Progression.enclosureSizeFor(5), "Large")
		eq(Progression.enclosureFits("Small", 2), true)
		eq(Progression.enclosureFits("Small", 3), false)
		eq(Progression.enclosureFits("Large", 4), false)
		eq(Progression.enclosureFits("Bogus", 1), false)
	end)

	it("income and spawn weight follow KL ordering", function()
		for kl = 2, 5 do
			truthy(Progression.incomePerSecond(kl, 1) > Progression.incomePerSecond(kl - 1, 1), "income KL" .. kl)
			truthy(GameConfig.KL[kl].spawnWeight < GameConfig.KL[kl - 1].spawnWeight, "rarity KL" .. kl)
		end
	end)

	it("chains gate capture by KL; final chain handles KL5", function()
		eq(Progression.canCapture(1, 1), true)
		eq(Progression.canCapture(1, 2), false)
		eq(Progression.canCapture(Progression.maxChainTier(), 5), true)
		eq(Progression.canCapture(99, 1), false)
		local req = Progression.requiredChainFor(3)
		assert(req)
		eq(req.tier, 3)
	end)

	it("cell leveling stops at the fusion level", function()
		eq((Progression.canLevelUpWithCells(1, 0)), false)
		eq((Progression.canLevelUpWithCells(1, Progression.levelUpCost(1))), true)
		eq((Progression.canLevelUpWithCells(9, 1e9)), true)
		local ok, reason = Progression.canLevelUpWithCells(GameConfig.Progression.fusionLevel, 1e9)
		eq(ok, false)
		truthy(reason and string.find(reason, "fusion") ~= nil, "mentions fusion")
		eq((Progression.canLevelUpWithCells(40, 1e9)), false)
	end)

	it("rolls spawn KLs proportionally to weights", function()
		eq(Progression.rollSpawnKL(0), 1)
		eq(Progression.rollSpawnKL(0.9999), 5)
		eq(Progression.rollSpawnKL(0.5, { [3] = true }), 3)
		eq(Progression.rollSpawnKL(0.5, {}), nil)
		local rng = T.seededRng(7)
		local counts = { 0, 0, 0, 0, 0 }
		for _ = 1, 10000 do
			local kl = Progression.rollSpawnKL(rng())
			assert(kl)
			counts[kl] += 1
		end
		truthy(
			counts[1] > counts[2] and counts[2] > counts[3] and counts[3] > counts[4] and counts[4] > counts[5],
			"monotonic rarity"
		)
	end)
end)

return nil
