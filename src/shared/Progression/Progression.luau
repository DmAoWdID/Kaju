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

-- Documented: at level 10 a kaiju must fuse with an identical level-10 kaiju to reach 11, and the same
-- "leveling and fusion" progression continues to 40. Provisional reading: fusion gates at 10, 20 and 30.
function Progression.isFusionLevel(level: number): boolean
	return level >= PROGRESSION.fusionLevel and level % PROGRESSION.fusionLevel == 0 and level < PROGRESSION.maxLevel
end

-- Returns (ok, reason). Cells raise every level except the fusion gates.
function Progression.canLevelUpWithCells(level: number, cells: number): (boolean, string?)
	if level >= PROGRESSION.maxLevel then
		return false, "Already at max level"
	end
	if Progression.isFusionLevel(level) then
		return false, ("Level %d needs fusion with another level %d kaiju of the same species"):format(level + 1, level)
	end
	local cost = Progression.levelUpCost(level)
	if cells < cost then
		return false, ("Needs %d Kaiju Cells"):format(cost)
	end
	return true, nil
end

type FusionCandidate = { instanceId: string, speciesId: string, level: number }

-- Validates fusing `partner` into `primary`. Returns (ok, reason).
function Progression.canFuse(primary: FusionCandidate?, partner: FusionCandidate?): (boolean, string?)
	if not primary or not partner then
		return false, "Missing kaiju"
	end
	if primary.instanceId == partner.instanceId then
		return false, "A kaiju can't fuse with itself"
	end
	if primary.speciesId ~= partner.speciesId then
		return false, "Fusion needs two kaijus of the same species"
	end
	if not Progression.isFusionLevel(primary.level) then
		return false, ("Fusion happens at level %d, %d and %d"):format(
			PROGRESSION.fusionLevel,
			PROGRESSION.fusionLevel * 2,
			PROGRESSION.fusionLevel * 3
		)
	end
	if partner.level ~= primary.level then
		return false, ("Both kaijus must be level %d"):format(primary.level)
	end
	return true, nil
end

-- Picks a fusion partner for `primary` from `owned`, preferring kaijus that are not housed in the park.
-- Deterministic (lowest instanceId wins among equals). Returns nil if none qualifies.
function Progression.findFusionPartner(
	owned: { [string]: FusionCandidate },
	primary: FusionCandidate,
	isHoused: ((string) -> boolean)?
): FusionCandidate?
	local best: FusionCandidate? = nil
	local bestHoused = true
	for _, candidate in owned do
		if Progression.canFuse(primary, candidate) then
			local housed = if isHoused then isHoused(candidate.instanceId) else false
			local better = best == nil
				or (bestHoused and not housed)
				or (housed == bestHoused and candidate.instanceId < (best :: FusionCandidate).instanceId)
			if better then
				best, bestHoused = candidate, housed
			end
		end
	end
	return best
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
