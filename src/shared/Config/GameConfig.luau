--!strict
-- Central tunables for Kaiju Park.
--
-- !! Every number in this file is PROVISIONAL unless stated otherwise. The design documents in Docs/
-- do not define combat formulas, prices, chances or income rates. Each assumption is listed in
-- Docs/IMPLEMENTATION_DECISIONS.md. Change values here, not in gameplay code.

export type KLDef = {
	spawnWeight: number,
	incomePerSecond: number,
	cellsOnDefeat: number,
	enclosure: string,
	captureChance: number,
	modelScale: number,
}
export type EnclosureDef = {
	displayName: string,
	price: number,
	minKL: number,
	maxKL: number,
	footprint: number,
	order: number,
}
export type ChainDef = {
	tier: number,
	displayName: string,
	lengthMeters: number,
	maxKL: number,
	price: number,
}

local GameConfig = {}

-- Per-KL tuning. Documented: KL affects spawn frequency (KL1 most common, KL5 very rare),
-- required enclosure size (Small KL1-2, Medium KL3-4, Large KL5) and income (higher KL earns more).
-- Spawn weights, income and cell values are provisional.
local KLTable: { [number]: KLDef } = table.freeze({
	[1] = table.freeze({ spawnWeight = 60, incomePerSecond = 1, cellsOnDefeat = 10, enclosure = "Small", captureChance = 1.0, modelScale = 1.0 }),
	[2] = table.freeze({ spawnWeight = 25, incomePerSecond = 3, cellsOnDefeat = 25, enclosure = "Small", captureChance = 1.0, modelScale = 1.25 }),
	[3] = table.freeze({ spawnWeight = 10, incomePerSecond = 8, cellsOnDefeat = 60, enclosure = "Medium", captureChance = 1.0, modelScale = 1.5 }),
	[4] = table.freeze({ spawnWeight = 4, incomePerSecond = 20, cellsOnDefeat = 150, enclosure = "Medium", captureChance = 1.0, modelScale = 1.8 }),
	[5] = table.freeze({ spawnWeight = 1, incomePerSecond = 50, cellsOnDefeat = 400, enclosure = "Large", captureChance = 1.0, modelScale = 2.2 }),
}) :: any
GameConfig.KL = KLTable

-- Enclosure sizes and KL ranges are documented; prices and footprints are provisional.
local EnclosureTable: { [string]: EnclosureDef } = table.freeze({
	Small = table.freeze({ displayName = "Small Enclosure", price = 100, minKL = 1, maxKL = 2, footprint = 26, order = 1 }),
	Medium = table.freeze({ displayName = "Medium Enclosure", price = 1500, minKL = 3, maxKL = 4, footprint = 34, order = 2 }),
	Large = table.freeze({ displayName = "Large Enclosure", price = 12000, minKL = 5, maxKL = 5, footprint = 42, order = 3 }),
}) :: any
GameConfig.Enclosures = EnclosureTable

-- Documented concept: a longer chain lets you capture higher-KL kaijus; four upgrade steps,
-- the last one handles KL5. Names, lengths, KL limits and prices are provisional.
local ChainTable: { ChainDef } = table.freeze({
	table.freeze({ tier = 1, displayName = "Starter Chain", lengthMeters = 10, maxKL = 1, price = 0 }),
	table.freeze({ tier = 2, displayName = "Reinforced Chain", lengthMeters = 25, maxKL = 2, price = 600 }),
	table.freeze({ tier = 3, displayName = "Advanced Chain", lengthMeters = 60, maxKL = 4, price = 6000 }),
	table.freeze({ tier = 4, displayName = "Titan Chain", lengthMeters = 150, maxKL = 5, price = 40000 }),
}) :: any
GameConfig.Chains = ChainTable

-- Turn-based combat (documented actions: Attack / Defend / Save using action points).
-- The stat -> combat mapping below is a provisional assumption, see IMPLEMENTATION_DECISIONS.md.
GameConfig.Combat = table.freeze({
	teamSize = 1, -- kaijus per side (documented: "to be decided")
	hpBase = 20, -- maxHp = hpBase + durability * hpPerDurability
	hpPerDurability = 3,
	attackBase = 4, -- per-AP damage = attackBase + damage * damagePerPoint
	damagePerPoint = 0.5,
	chargeBonusPerExtraAp = 0.25, -- Attack spends ALL AP; each AP beyond the first adds +25% (rewards Save)
	apStart = 1,
	apPerRound = 1,
	apMaxBase = 3, -- maxAp = min(apMaxCap, apMaxBase + floor(stamina / apMaxStaminaStep))
	apMaxStaminaStep = 50,
	apMaxCap = 5,
	defendApCost = 1,
	defendReduction = 0.5, -- fraction of incoming damage blocked while defending
	maxRounds = 30, -- reaching this ends the battle as a draw (no rewards)
	-- Mobility decides who acts first each round (ties go to the player).
	-- Intelligence affects how often the wild AI picks the "smart" action.
	aiSmartBase = 0.3,
	aiSmartPerIntelligence = 1 / 200,
	aiSmartMax = 0.95,
	wildLevel = 1, -- level of wild kaijus
	actionTimeoutSeconds = 120, -- idle battles are forfeited after this long
})

-- Progression level (1..40) is separate from KL. Documented: Kaiju Cells level a kaiju up to 10;
-- reaching 11+ requires fusing two identical level-10 kaijus (not implemented in this milestone).
GameConfig.Progression = table.freeze({
	maxLevel = 40,
	fusionLevel = 10,
	levelUpCostBase = 10, -- cells to go from level L to L+1 = base + perLevel * (L - 1)
	levelUpCostPerLevel = 10,
	statGrowthPerLevel = 0.05, -- combat stats multiply by 1 + growth * (level - 1)
})

GameConfig.Economy = table.freeze({
	startingMoney = 250,
	startingCells = 0,
	incomeTickSeconds = 1, -- documented: park kaijus earn money every second
})

-- New players get one kaiju so they have something to battle with (the GDD has players fight with
-- their own kaijus, but doesn't say how the first one is obtained). Provisional.
GameConfig.Starter = table.freeze({
	speciesId = "kragmor",
	level = 1,
	enclosure = "Small", -- one free Small enclosure so the park loop can be shown immediately
})

GameConfig.Spawning = table.freeze({
	-- The documented target for the full world is ~20 wild kaijus; this test area holds fewer.
	guaranteed = table.freeze({ table.freeze({ speciesId = "kragmor", spawnPoint = 1 }) }),
	randomCount = 3,
	respawnDelaySeconds = 8,
	wanderRadius = 22,
	wanderSpeed = 5, -- studs per second
	wanderPauseMin = 2,
	wanderPauseMax = 6,
})

-- Riding your own kaijus (not in the GDD; provisional). Ride speed uses the documented Mobility stat.
GameConfig.Riding = table.freeze({
	speedBase = 14, -- walk speed = speedBase + mobility * speedPerMobility, capped at speedMax
	speedPerMobility = 0.1,
	speedMax = 32,
	seatLift = 1.6, -- studs between the saddle point and the rider's root part
})

GameConfig.Interaction = table.freeze({
	promptDistance = 16,
	keyboardKey = "E", -- documented: press E to start a fight
	gamepadKey = "ButtonX",
})

GameConfig.Park = table.freeze({
	maxPlots = 8,
	gridColumns = 3,
	gridRows = 3,
	slotSpacing = 48,
	-- Plots form a ring around the Wilds, leaving a gap where the hub and bridge are.
	ringRadius = 340, -- Wilds centre -> plot centre (studs)
	ringGapDegrees = 80, -- free arc centred on the hub direction
})

GameConfig.Persistence = table.freeze({
	dataStoreName = "KaijuPark_PlayerData_v1",
	keyPrefix = "player_",
	useDataStoreInStudio = false, -- Studio uses in-memory data unless you flip this (and enable API access)
	autosaveSeconds = 90,
	maxRetries = 3,
	sessionLockSeconds = 30 * 60,
})

GameConfig.Network = table.freeze({
	requestsPerSecond = 8,
	burst = 12,
})

return table.freeze(GameConfig)
