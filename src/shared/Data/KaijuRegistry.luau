--!strict
-- Read-only lookup over the validated species roster. All code should go through this module
-- instead of reading KaijuSpecies directly. Malformed entries are excluded and reported, never patched.

local Types = require("../Types")
local KaijuSpecies = require("./KaijuSpecies")
local KaijuValidator = require("./KaijuValidator")

type KaijuSpecies = Types.KaijuSpecies

local KaijuRegistry = {}

local issues = KaijuValidator.validateRoster(KaijuSpecies)
local badIds: { [string]: boolean } = {}
for _, issue in issues do
	if issue.severity == "error" then
		badIds[issue.speciesId] = true
	end
end

local function deepFreeze(t: any): any
	if type(t) == "table" and not table.isfrozen(t) then
		for _, v in t do
			deepFreeze(v)
		end
		table.freeze(t)
	end
	return t
end

local byId: { [string]: KaijuSpecies } = {}
local ordered: { KaijuSpecies } = {}
for _, species in KaijuSpecies do
	if type(species) == "table" and type(species.id) == "string" and not badIds[species.id] and not byId[species.id] then
		deepFreeze(species)
		byId[species.id] = species
		table.insert(ordered, species)
	end
end
table.sort(ordered, function(a: KaijuSpecies, b: KaijuSpecies): boolean
	if a.kl ~= b.kl then
		return a.kl < b.kl
	end
	return a.threatRating < b.threatRating
end)
table.freeze(ordered)

KaijuRegistry.issues = table.freeze(issues)

function KaijuRegistry.get(id: string): KaijuSpecies?
	return byId[id]
end

function KaijuRegistry.exists(id: any): boolean
	return type(id) == "string" and byId[id] ~= nil
end

function KaijuRegistry.all(): { KaijuSpecies }
	return ordered
end

function KaijuRegistry.byKL(kl: number): { KaijuSpecies }
	local result = {}
	for _, species in ordered do
		if species.kl == kl then
			table.insert(result, species)
		end
	end
	return result
end

-- Prints validation results once (call from server boot). Returns true if the roster is clean of errors.
function KaijuRegistry.report(log: (string) -> ()): boolean
	for _, issue in issues do
		log(KaijuValidator.format(issue))
	end
	return not KaijuValidator.hasErrors(issues)
end

return KaijuRegistry
