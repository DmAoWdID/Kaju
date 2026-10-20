--!strict
-- Player save-data shape, defaults and migration. Pure Luau so it can be unit tested.
-- Owned kaijus store only instance data (species id + progression); species stats come from KaijuRegistry.

local GameConfig = require("../Config/GameConfig")
local Types = require("../Types")

type PlayerData = Types.PlayerData
type OwnedKaiju = Types.OwnedKaiju

local PlayerDataSchema = {}

PlayerDataSchema.VERSION = 1

function PlayerDataSchema.default(): PlayerData
	return {
		schemaVersion = PlayerDataSchema.VERSION,
		money = GameConfig.Economy.startingMoney,
		kaijuCells = GameConfig.Economy.startingCells,
		chainTier = 1,
		kaijus = {},
		enclosures = {},
		nextId = 1,
		starterGranted = false,
		stats = { battlesWon = 0, battlesLost = 0, captures = 0 },
	}
end

local function nonNegativeNumber(v: any, fallback: number): number
	if type(v) == "number" and v == v and v >= 0 and v < math.huge then
		return v
	end
	return fallback
end

-- Fills missing fields and drops malformed entries from loaded data. Never invents progress.
-- `isKnownSpecies` lets callers keep kaijus whose species was removed out of the roster visible in logs.
function PlayerDataSchema.reconcile(raw: any, isKnownSpecies: ((string) -> boolean)?): (PlayerData, { string })
	local warnings: { string } = {}
	local data = PlayerDataSchema.default()
	if type(raw) ~= "table" then
		if raw ~= nil then
			table.insert(warnings, "save data was not a table; using defaults")
		end
		return data, warnings
	end

	if type(raw.schemaVersion) == "number" and raw.schemaVersion > PlayerDataSchema.VERSION then
		-- Saved by a newer server version; caller must not overwrite it.
		error(("save schemaVersion %d is newer than supported %d"):format(raw.schemaVersion :: number, PlayerDataSchema.VERSION))
	end

	data.money = nonNegativeNumber(raw.money, data.money)
	data.kaijuCells = nonNegativeNumber(raw.kaijuCells, data.kaijuCells)
	if type(raw.chainTier) == "number" and GameConfig.Chains[raw.chainTier] then
		data.chainTier = raw.chainTier
	end
	data.starterGranted = raw.starterGranted == true
	data.nextId = math.max(1, math.floor(nonNegativeNumber(raw.nextId, 1)))
	if type(raw.stats) == "table" then
		data.stats.battlesWon = math.floor(nonNegativeNumber(raw.stats.battlesWon, 0))
		data.stats.battlesLost = math.floor(nonNegativeNumber(raw.stats.battlesLost, 0))
		data.stats.captures = math.floor(nonNegativeNumber(raw.stats.captures, 0))
	end

	if type(raw.kaijus) == "table" then
		for id, k in raw.kaijus do
			if type(id) == "string" and type(k) == "table" and type(k.speciesId) == "string" and k.instanceId == id then
				if isKnownSpecies and not isKnownSpecies(k.speciesId) then
					table.insert(warnings, ("kaiju %s has unknown species '%s'; kept but inactive"):format(id, k.speciesId))
				end
				local level = math.floor(nonNegativeNumber(k.level, 1))
				data.kaijus[id] = {
					instanceId = id,
					speciesId = k.speciesId,
					level = math.clamp(level, 1, GameConfig.Progression.maxLevel),
					capturedAt = nonNegativeNumber(k.capturedAt, 0),
					nickname = if type(k.nickname) == "string" then k.nickname else nil,
				}
			else
				table.insert(warnings, "dropped malformed kaiju entry " .. tostring(id))
			end
		end
	end

	if type(raw.enclosures) == "table" then
		local usedSlots: { [number]: boolean } = {}
		for id, e in raw.enclosures do
			local valid = type(id) == "string"
				and type(e) == "table"
				and e.enclosureId == id
				and type(e.sizeId) == "string"
				and GameConfig.Enclosures[e.sizeId] ~= nil
				and type(e.slot) == "number"
				and not usedSlots[e.slot]
			if valid then
				usedSlots[e.slot] = true
				local occupant = if type(e.kaijuInstanceId) == "string" and data.kaijus[e.kaijuInstanceId]
					then e.kaijuInstanceId
					else nil
				data.enclosures[id] = { enclosureId = id, sizeId = e.sizeId, slot = e.slot, kaijuInstanceId = occupant }
			else
				table.insert(warnings, "dropped malformed enclosure entry " .. tostring(id))
			end
		end
	end

	-- A kaiju can only live in one enclosure.
	local housed: { [string]: boolean } = {}
	for _, e in data.enclosures do
		if e.kaijuInstanceId then
			if housed[e.kaijuInstanceId] then
				table.insert(warnings, "kaiju " .. e.kaijuInstanceId .. " was in two enclosures; unassigned one")
				e.kaijuInstanceId = nil
			else
				housed[e.kaijuInstanceId] = true
			end
		end
	end

	data.schemaVersion = PlayerDataSchema.VERSION
	return data, warnings
end

local function allocateId(data: PlayerData, prefix: string): string
	local id = prefix .. tostring(data.nextId)
	data.nextId += 1
	return id
end

function PlayerDataSchema.addKaiju(data: PlayerData, speciesId: string, level: number, now: number): OwnedKaiju
	local kaiju: OwnedKaiju = {
		instanceId = allocateId(data, "k"),
		speciesId = speciesId,
		level = level,
		capturedAt = now,
	}
	data.kaijus[kaiju.instanceId] = kaiju
	return kaiju
end

function PlayerDataSchema.addEnclosure(data: PlayerData, sizeId: string, slot: number): Types.PlacedEnclosure
	local enclosure: Types.PlacedEnclosure = { enclosureId = allocateId(data, "e"), sizeId = sizeId, slot = slot }
	data.enclosures[enclosure.enclosureId] = enclosure
	return enclosure
end

-- Applies a fusion that the caller has already validated with Progression.canFuse:
-- `partnerId` is consumed (and leaves its enclosure), `primaryId` keeps its identity and gains one level.
-- Returns the primary kaiju.
function PlayerDataSchema.fuse(data: PlayerData, primaryId: string, partnerId: string): OwnedKaiju
	local primary = data.kaijus[primaryId]
	local partner = data.kaijus[partnerId]
	assert(primary and partner and primaryId ~= partnerId, "invalid fusion pair")
	for _, e in data.enclosures do
		if e.kaijuInstanceId == partnerId then
			e.kaijuInstanceId = nil
		end
	end
	data.kaijus[partnerId] = nil
	primary.level += 1
	return primary
end

function PlayerDataSchema.enclosureAtSlot(data: PlayerData, slot: number): Types.PlacedEnclosure?
	for _, e in data.enclosures do
		if e.slot == slot then
			return e
		end
	end
	return nil
end

function PlayerDataSchema.enclosureOf(data: PlayerData, instanceId: string): Types.PlacedEnclosure?
	for _, e in data.enclosures do
		if e.kaijuInstanceId == instanceId then
			return e
		end
	end
	return nil
end

return PlayerDataSchema
