--!strict
-- Pure rules for KL-based economy, chains, enclosures and the progression level.
-- KL (classification) and level (progression) are deliberately kept separate.

local GameConfig = require("../Config/GameConfig")

local Progression = {}

local KL = GameConfig.KL
local PROGRESSION = GameConfig.Progression

function Progression.klConfig(kl: number)
	local cfg = KL[kl]
	assert(cfg, "unknown KL " .. tostring(kl))
	return cfg
end

-- Combat-stat multiplier from the progression level. KL does not change with level.
function Progression.statMultiplier(level: number): number
	return 1 + PROGRESSION.statGrowthPerLevel * (level - 1)
end

function Progression.levelUpCost(level: number): number
	return PROGRESSION.levelUpCostBase + PROGRESSION.levelUpCostPerLevel * (level - 1)
end

-- Returns (ok, reason). Levels past fusionLevel require fusion, which is not implemented yet.
function Progression.canLevelUpWithCells(level: number, cells: number): (boolean, string?)
	if level >= PROGRESSION.maxLevel then
		return false, "Already at max level"
	end
	if level >= PROGRESSION.fusionLevel and level % PROGRESSION.fusionLevel == 0 then
		return false, ("Level %d requires fusion with an identical level %d kaiju (coming later)"):format(level + 1, level)
	end
	if level > PROGRESSION.fusionLevel then
		return false, "Levels above the fusion threshold are not implemented yet"
	end
	local cost = Progression.levelUpCost(level)
	if cells < cost then
		return false, ("Needs %d Kaiju Cells"):format(cost)
	end
	return true, nil
end

function Progression.chain(tier: number)
	return GameConfig.Chains[tier]
end

function Progression.maxChainTier(): number
	return #GameConfig.Chains
end

function Progression.canCapture(chainTier: number, kl: number): boolean
	local chain = GameConfig.Chains[chainTier]
	return chain ~= nil and kl <= chain.maxKL
end

-- The cheapest chain that can capture the given KL, if any.
function Progression.requiredChainFor(kl: number): GameConfig.ChainDef?
	for _, chain in GameConfig.Chains do
		if kl <= chain.maxKL then
			return chain
		end
	end
	return nil
end

function Progression.enclosureSizeFor(kl: number): string
	return Progression.klConfig(kl).enclosure
end

function Progression.enclosureFits(sizeId: string, kl: number): boolean
	local size = GameConfig.Enclosures[sizeId]
	return size ~= nil and kl >= size.minKL and kl <= size.maxKL
end

-- Money per income tick for a kaiju placed in the park. Level has no effect yet (provisional).
function Progression.incomePerSecond(kl: number, _level: number): number
	return Progression.klConfig(kl).incomePerSecond
end

function Progression.cellsForDefeat(kl: number): number
	return Progression.klConfig(kl).cellsOnDefeat
end

-- Weighted random KL from GameConfig.KL spawn weights. `roll` is a number in [0, 1).
function Progression.rollSpawnKL(roll: number, availableKLs: { [number]: boolean }?): number?
	local total = 0
	for kl, cfg in KL do
		if availableKLs == nil or availableKLs[kl] then
			total += cfg.spawnWeight
		end
	end
	if total <= 0 then
		return nil
	end
	local target = roll * total
	local acc = 0
	for kl = 1, #KL do
		if availableKLs == nil or availableKLs[kl] then
			acc += KL[kl].spawnWeight
			if target < acc then
				return kl
			end
		end
	end
	return #KL
end

return Progression
