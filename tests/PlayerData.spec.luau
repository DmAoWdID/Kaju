--!strict
local T = require("./TestLib")
local Schema = require("../src/shared/PlayerData/PlayerDataSchema")
local GameConfig = require("../src/shared/Config/GameConfig")

local describe, it, eq, truthy = T.describe, T.it, T.eq, T.truthy

describe("PlayerDataSchema", function()
	it("creates defaults from config", function()
		local d = Schema.default()
		eq(d.money, GameConfig.Economy.startingMoney)
		eq(d.chainTier, 1)
		eq(next(d.kaijus), nil)
	end)

	it("allocates unique ids for kaijus and enclosures", function()
		local d = Schema.default()
		local a = Schema.addKaiju(d, "kragmor", 1, 0)
		local b = Schema.addKaiju(d, "kragmor", 1, 0)
		local e = Schema.addEnclosure(d, "Small", 1)
		truthy(a.instanceId ~= b.instanceId and b.instanceId ~= e.enclosureId, "unique")
		eq(d.kaijus[a.instanceId], a)
		eq(Schema.enclosureAtSlot(d, 1), e)
	end)

	it("round-trips a valid save", function()
		local d = Schema.default()
		local k = Schema.addKaiju(d, "kragmor", 3, 100)
		local e = Schema.addEnclosure(d, "Small", 4)
		e.kaijuInstanceId = k.instanceId
		d.money = 1234
		local r, warnings = Schema.reconcile(d)
		eq(#warnings, 0)
		eq(r.money, 1234)
		eq(r.kaijus[k.instanceId].level, 3)
		eq(r.enclosures[e.enclosureId].kaijuInstanceId, k.instanceId)
		eq(r.nextId, d.nextId)
	end)

	it("sanitises malformed data without inventing progress", function()
		local r, warnings = Schema.reconcile({
			money = -50,
			kaijuCells = 0 / 0,
			chainTier = 77,
			kaijus = { k1 = { instanceId = "k1", speciesId = "kragmor", level = 999 }, bad = "x" },
			enclosures = {
				e1 = { enclosureId = "e1", sizeId = "Small", slot = 1, kaijuInstanceId = "k1" },
				e2 = { enclosureId = "e2", sizeId = "Small", slot = 1 }, -- same slot
				e3 = { enclosureId = "e3", sizeId = "Huge", slot = 2 },
			},
		})
		eq(r.money, GameConfig.Economy.startingMoney)
		eq(r.kaijuCells, GameConfig.Economy.startingCells)
		eq(r.chainTier, 1)
		eq(r.kaijus.k1.level, GameConfig.Progression.maxLevel)
		eq(r.kaijus.bad, nil)
		eq(r.enclosures.e3, nil)
		local slotOneCount = 0
		for _, e in r.enclosures do
			if e.slot == 1 then
				slotOneCount += 1
			end
		end
		eq(slotOneCount, 1)
		truthy(#warnings >= 3, "warnings reported")
	end)

	it("drops enclosure occupants that are not owned", function()
		local r = Schema.reconcile({
			enclosures = { e1 = { enclosureId = "e1", sizeId = "Small", slot = 1, kaijuInstanceId = "ghost" } },
		})
		eq(r.enclosures.e1.kaijuInstanceId, nil)
	end)

	it("refuses to load saves from a newer schema", function()
		eq(pcall(Schema.reconcile, { schemaVersion = Schema.VERSION + 1 }), false)
	end)
end)

return nil
