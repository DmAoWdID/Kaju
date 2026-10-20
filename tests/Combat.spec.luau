--!strict
local T = require("./TestLib")
local CombatEngine = require("../src/shared/Combat/CombatEngine")
local KaijuRegistry = require("../src/shared/Data/KaijuRegistry")
local GameConfig = require("../src/shared/Config/GameConfig")

local describe, it, eq, truthy = T.describe, T.it, T.eq, T.truthy
local C = GameConfig.Combat

local function combatant(id: string, level: number?)
	local s = KaijuRegistry.get(id)
	assert(s, id)
	return CombatEngine.newCombatant(s, level or 1)
end

describe("CombatEngine", function()
	it("derives combat values from documented stats via config", function()
		local k = combatant("kragmor")
		eq(k.maxHp, C.hpBase + 30 * C.hpPerDurability)
		eq(k.hp, k.maxHp)
		eq(k.ap, C.apStart)
		eq(k.maxAp, C.apMaxBase) -- stamina 10 adds nothing
		eq(k.perApDamage, C.attackBase + 20 * C.damagePerPoint)
		eq(k.initiative, 30)
	end)

	it("higher level scales stats but not KL", function()
		local lv1, lv5 = combatant("kragmor", 1), combatant("kragmor", 5)
		truthy(lv5.maxHp > lv1.maxHp, "hp grows")
		eq(lv5.kl, lv1.kl)
	end)

	it("Attack spends all AP and saving makes attacks stronger", function()
		local k = combatant("kragmor")
		truthy(CombatEngine.attackDamage(k, 3) > 3 * CombatEngine.attackDamage(k, 1), "charge bonus")
		local b = CombatEngine.newBattle(combatant("kragmor"), combatant("kragmor"))
		CombatEngine.resolveRound(b, "Save", "Save")
		eq(b.player.ap, 2)
		local events = CombatEngine.resolveRound(b, "Attack", "Save")
		eq(events[2].ap, 2)
		eq(b.player.ap, 1, "0 after attack, +1 next round")
		eq(b.wild.hp, b.wild.maxHp - math.floor(CombatEngine.attackDamage(b.player, 2) + 0.5))
	end)

	it("Defend costs AP and reduces incoming damage", function()
		local b = CombatEngine.newBattle(combatant("kragmor"), combatant("kragmor"))
		local raw = CombatEngine.attackDamage(b.wild, 1)
		CombatEngine.resolveRound(b, "Defend", "Attack")
		eq(b.player.hp, b.player.maxHp - math.floor(raw * (1 - C.defendReduction) + 0.5))
		eq(b.player.ap, C.apStart - C.defendApCost + C.apPerRound)
		eq(b.player.defending, false, "defend lasts one round")
	end)

	it("rejects actions without enough AP", function()
		local b = CombatEngine.newBattle(combatant("kragmor"), combatant("kragmor"))
		CombatEngine.resolveRound(b, "Attack", "Save")
		b.player.ap = 0
		eq(CombatEngine.canUse(b.player, "Attack"), false)
		eq(CombatEngine.canUse(b.player, "Defend"), false)
		eq(CombatEngine.canUse(b.player, "Save"), true)
		eq(CombatEngine.canUse(b.player, "Explode"), false)
		local ok = pcall(CombatEngine.resolveRound, b, "Attack", "Save")
		eq(ok, false)
	end)

	it("faster combatant strikes first; a knocked-out one does not strike back", function()
		local b = CombatEngine.newBattle(combatant("kragmor"), combatant("chomp_chomp")) -- mobility 30 vs 40
		b.player.hp = 1
		local events = CombatEngine.resolveRound(b, "Attack", "Attack")
		eq(b.state, "defeat")
		local attacks = 0
		for _, e in events do
			if e.action == "Attack" then
				attacks += 1
			end
		end
		eq(attacks, 1)
		eq(events[1].side, "wild")
	end)

	it("reports victory when the wild kaiju reaches 0 HP and stops further rounds", function()
		local b = CombatEngine.newBattle(combatant("kragmor"), combatant("popcorn"))
		b.wild.hp = 1
		CombatEngine.resolveRound(b, "Attack", "Save")
		eq(b.state, "victory")
		eq(pcall(CombatEngine.resolveRound, b, "Save", "Save"), false)
	end)

	it("ends as a draw after maxRounds", function()
		local b = CombatEngine.newBattle(combatant("kragmor"), combatant("kragmor"))
		for _ = 1, C.maxRounds do
			CombatEngine.resolveRound(b, "Save", "Save")
		end
		eq(b.state, "draw")
	end)

	it("AI only picks usable actions and full simulated battles terminate", function()
		local rng = T.seededRng(1234)
		local outcomes: { [string]: number } = { victory = 0, defeat = 0, draw = 0 }
		for _ = 1, 200 do
			local b = CombatEngine.newBattle(combatant("kragmor"), combatant("kragmor"))
			local guard = 0
			while b.state == "active" do
				guard += 1
				assert(guard <= C.maxRounds + 1, "battle did not terminate")
				local wildAction = CombatEngine.chooseAiAction(b, rng)
				assert(CombatEngine.canUse(b.wild, wildAction), "AI picked unusable " .. wildAction)
				-- simple player policy: save to 2 AP then attack
				local playerAction: CombatEngine.Action = if b.player.ap >= 2 then "Attack" else "Save"
				CombatEngine.resolveRound(b, playerAction, wildAction)
			end
			outcomes[b.state] += 1
		end
		print(
			("    Kragmor mirror (save-to-2 policy, 200 sims): %d wins / %d losses / %d draws"):format(
				outcomes.victory,
				outcomes.defeat,
				outcomes.draw
			)
		)
		truthy(outcomes.victory > 0, "player can win")
		truthy(outcomes.defeat > 0, "player can lose")
	end)

	it("snapshot exposes only display values", function()
		local b = CombatEngine.newBattle(combatant("kragmor"), combatant("popcorn"))
		local snap = CombatEngine.snapshot(b)
		eq(snap.wild.name, "Popcorn")
		eq(snap.available.Attack, true)
		eq((snap.player :: any).perApDamage, nil)
	end)
end)

return nil
