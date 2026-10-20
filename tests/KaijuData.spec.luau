--!strict
local T = require("./TestLib")
local KaijuRegistry = require("../src/shared/Data/KaijuRegistry")
local KaijuValidator = require("../src/shared/Data/KaijuValidator")
local KaijuSpecies = require("../src/shared/Data/KaijuSpecies")

local describe, it, eq, truthy = T.describe, T.it, T.eq, T.truthy

describe("Kaiju data", function()
	it("roster has no validation errors or warnings", function()
		for _, issue in KaijuRegistry.issues do
			print("  " .. KaijuValidator.format(issue))
		end
		eq(#KaijuRegistry.issues, 0, "issue count")
		eq(#KaijuRegistry.all(), #KaijuSpecies, "all species registered")
	end)

	it("Kragmor matches Docs/Kaju game.pdf page 1", function()
		local k = KaijuRegistry.get("kragmor")
		assert(k, "kragmor missing")
		eq(k.displayName, "Kragmor")
		eq(k.kl, 1)
		eq(k.threatRating, 1.2)
		eq(k.traits[1], "Vibration Sense")
		eq(k.traits[2], "Razor Claws")
		eq(k.traits[3], "Armored Carapace")
		eq(k.stats.durability, 30)
		eq(k.stats.damage, 20)
		eq(k.stats.mobility, 30)
		eq(k.stats.stamina, 10)
		eq(k.stats.intelligence, 10)
		eq(k.documentedTotal, 100)
		eq(k.dimensions[1].text, "Height 2,5m")
	end)

	it("contains the 18 documented species in the documented KL groups", function()
		local expected = {
			[1] = { "Kragmor", "Chomp Chomp", "Popcorn", "Eye bat" },
			[2] = { "Great tusk", "Jellqouia", "KillerSpotts" },
			[3] = { "Wormhole", "Obio 16" },
			[4] = { "Leazorn", "Hornet", "Night Angel", "Cataboulder", "Korand" },
			[5] = { "Cagn", "Doubt", "Yumir", "Emperor" },
		}
		local count = 0
		for kl, names in expected do
			local inKL = KaijuRegistry.byKL(kl)
			eq(#inKL, #names, "KL" .. kl .. " count")
			for _, name in names do
				local found = false
				for _, s in inKL do
					if s.displayName == name then
						found = true
					end
				end
				truthy(found, name .. " in KL" .. kl)
				count += 1
			end
		end
		eq(#KaijuRegistry.all(), count)
		eq(count, 18)
	end)

	it("every species' stats sum to its documented Total", function()
		for _, s in KaijuRegistry.all() do
			local st = s.stats
			eq(st.durability + st.damage + st.mobility + st.stamina + st.intelligence, s.documentedTotal, s.id)
		end
	end)

	it("preserves unusual documented spellings verbatim", function()
		local function trait(id: string, i: number): string
			local s = KaijuRegistry.get(id)
			assert(s, id)
			return s.traits[i]
		end
		eq(trait("obio_16", 2), "Het detector")
		eq(trait("leazorn", 1), "Tung trap")
		eq(trait("hornet", 1), "Hed stab")
		eq(trait("korand", 1), "Atomic breathe")
		eq(trait("killerspotts", 3), "Horne tackel")
		local wormhole = KaijuRegistry.get("wormhole")
		assert(wormhole and wormhole.statAnnotations)
		eq(wormhole.statAnnotations.mobility, "50 (150)")
		eq(wormhole.stats.mobility, 50)
	end)

	it("registry data is frozen", function()
		local k = KaijuRegistry.get("kragmor")
		assert(k)
		truthy(table.isfrozen(k), "species frozen")
		truthy(table.isfrozen(k.stats), "stats frozen")
		local ok = pcall(function()
			(k.stats :: any).damage = 999
		end)
		eq(ok, false, "mutation rejected")
	end)
end)

describe("KaijuValidator", function()
	local function valid(): any
		return {
			id = "test_kaiju",
			displayName = "Test",
			kl = 1,
			threatRating = 1,
			traits = { "A", "B", "C" },
			stats = { durability = 1, damage = 1, mobility = 1, stamina = 1, intelligence = 1 },
			documentedTotal = 5,
			dimensions = {},
			visual = { archetype = "blob", primary = { 1, 2, 3 }, secondary = { 1, 2, 3 }, accent = { 1, 2, 3 }, scale = 1 },
		}
	end

	local function errorsFor(mutate: (any) -> ()): number
		local s = valid()
		mutate(s)
		local n = 0
		for _, issue in KaijuValidator.validateSpecies(s, 1) do
			if issue.severity == "error" then
				n += 1
			end
		end
		return n
	end

	it("accepts a well-formed definition", function()
		eq(#KaijuValidator.validateSpecies(valid(), 1), 0)
	end)
	it("detects missing fields", function()
		truthy(errorsFor(function(s) s.displayName = nil end) > 0, "displayName")
		truthy(errorsFor(function(s) s.stats.stamina = nil end) > 0, "stamina")
		truthy(errorsFor(function(s) s.visual = nil end) > 0, "visual")
	end)
	it("detects invalid types and ranges", function()
		truthy(errorsFor(function(s) s.kl = "1" end) > 0, "kl string")
		truthy(errorsFor(function(s) s.kl = 6 end) > 0, "kl range")
		truthy(errorsFor(function(s) s.kl = 1.5 end) > 0, "kl fraction")
		truthy(errorsFor(function(s) s.threatRating = "high" end) > 0, "threat type")
		truthy(errorsFor(function(s) s.stats.damage = -1 end) > 0, "negative stat")
		truthy(errorsFor(function(s) s.stats.speed = 3 end) > 0, "unknown stat")
		truthy(errorsFor(function(s) s.id = "Has Spaces" end) > 0, "id format")
	end)
	it("detects malformed traits", function()
		truthy(errorsFor(function(s) s.traits = { "A", "B" } end) > 0, "two traits")
		truthy(errorsFor(function(s) s.traits = { "A", "B", 3 } end) > 0, "non-string trait")
	end)
	it("warns (does not correct) on documented total mismatch", function()
		local s = valid()
		s.documentedTotal = 6
		local issues = KaijuValidator.validateSpecies(s, 1)
		eq(#issues, 1)
		eq(issues[1].severity, "warning")
		eq(s.documentedTotal, 6, "value untouched")
	end)
	it("detects duplicate ids and names in a roster", function()
		local a, b = valid(), valid()
		local issues = KaijuValidator.validateRoster({ a, b })
		local dupId, dupName = false, false
		for _, issue in issues do
			if issue.message == "duplicate id" then dupId = true end
			if issue.message == "duplicate displayName" then dupName = true end
		end
		truthy(dupId, "duplicate id reported")
		truthy(dupName, "duplicate name reported")
	end)
	it("rejects a non-table entry", function()
		truthy(KaijuValidator.hasErrors(KaijuValidator.validateRoster({ 42 })), "non-table")
	end)
end)
return nil
