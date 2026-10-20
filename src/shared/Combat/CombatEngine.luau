--!strict
-- Pure, deterministic turn-based combat rules (no Roblox APIs). The server owns battle state and calls
-- these functions; the client only ever receives snapshots.
--
-- Documented: Attack spends action points to deal damage, Defend spends points to reduce incoming damage,
-- Save keeps points for stronger attacks later. Everything numeric is provisional (GameConfig.Combat).

local GameConfig = require("../Config/GameConfig")
local Progression = require("../Progression/Progression")
local Types = require("../Types")

local CombatEngine = {}

export type Action = "Attack" | "Defend" | "Save"
export type Side = "player" | "wild"
export type BattleState = "active" | "victory" | "defeat" | "draw"

export type Combatant = {
	speciesId: string,
	name: string,
	kl: number,
	level: number,
	maxHp: number,
	hp: number,
	ap: number,
	maxAp: number,
	perApDamage: number,
	initiative: number,
	intelligence: number,
	defending: boolean,
}

export type Event = {
	side: Side,
	action: Action,
	ap: number?, -- AP spent
	damage: number?,
	blocked: number?,
	text: string,
}

export type Battle = {
	round: number,
	state: BattleState,
	player: Combatant,
	wild: Combatant,
	lastEvents: { Event },
}

CombatEngine.ACTIONS = table.freeze({ "Attack", "Defend", "Save" })

local COMBAT = GameConfig.Combat

function CombatEngine.newCombatant(species: Types.KaijuSpecies, level: number): Combatant
	local mult = Progression.statMultiplier(level)
	local stats = species.stats
	local maxHp = math.floor((COMBAT.hpBase + stats.durability * COMBAT.hpPerDurability) * mult + 0.5)
	local maxAp = math.min(COMBAT.apMaxCap, COMBAT.apMaxBase + math.floor(stats.stamina / COMBAT.apMaxStaminaStep))
	return {
		speciesId = species.id,
		name = species.displayName,
		kl = species.kl,
		level = level,
		maxHp = maxHp,
		hp = maxHp,
		ap = math.min(COMBAT.apStart, maxAp),
		maxAp = maxAp,
		perApDamage = (COMBAT.attackBase + stats.damage * COMBAT.damagePerPoint) * mult,
		initiative = stats.mobility * mult,
		intelligence = stats.intelligence,
		defending = false,
	}
end

function CombatEngine.newBattle(player: Combatant, wild: Combatant): Battle
	return { round = 1, state = "active", player = player, wild = wild, lastEvents = {} }
end

-- Raw damage for spending `ap` points on one Attack (before defence).
function CombatEngine.attackDamage(attacker: Combatant, ap: number): number
	if ap <= 0 then
		return 0
	end
	return attacker.perApDamage * ap * (1 + COMBAT.chargeBonusPerExtraAp * (ap - 1))
end

function CombatEngine.canUse(c: Combatant, action: any): boolean
	if action == "Attack" then
		return c.ap >= 1
	elseif action == "Defend" then
		return c.ap >= COMBAT.defendApCost
	elseif action == "Save" then
		return true
	end
	return false
end

function CombatEngine.availableActions(c: Combatant): { [string]: boolean }
	local result = {}
	for _, action in CombatEngine.ACTIONS do
		result[action] = CombatEngine.canUse(c, action)
	end
	return result
end

-- Wild AI. Intelligence raises the chance of picking the sensible option. `rng` returns [0, 1).
function CombatEngine.chooseAiAction(battle: Battle, rng: () -> number): Action
	local me, foe = battle.wild, battle.player
	if me.ap <= 0 then
		return "Save"
	end
	local smartChance = math.min(COMBAT.aiSmartMax, COMBAT.aiSmartBase + me.intelligence * COMBAT.aiSmartPerIntelligence)
	if rng() < smartChance then
		if CombatEngine.attackDamage(me, me.ap) >= foe.hp then
			return "Attack"
		end
		if me.ap >= me.maxAp then
			return "Attack"
		end
		if foe.ap >= 2 and me.hp < me.maxHp * 0.5 and CombatEngine.canUse(me, "Defend") then
			return "Defend"
		end
		return if me.ap >= 2 then "Attack" else "Save"
	end
	local roll = rng()
	if roll < 0.5 then
		return "Attack"
	elseif roll < 0.8 then
		return "Save"
	end
	return if CombatEngine.canUse(me, "Defend") then "Defend" else "Save"
end

local function sideOf(battle: Battle, side: Side): (Combatant, Combatant)
	if side == "player" then
		return battle.player, battle.wild
	end
	return battle.wild, battle.player
end

-- Resolves one round. Both actions must be valid (callers validate first; invalid input errors).
-- Order: Defend/Save take effect first, then Attacks in initiative order (ties: player first).
-- A combatant knocked out before its attack does not attack.
function CombatEngine.resolveRound(battle: Battle, playerAction: Action, wildAction: Action): { Event }
	assert(battle.state == "active", "battle is not active")
	assert(CombatEngine.canUse(battle.player, playerAction), "invalid player action")
	assert(CombatEngine.canUse(battle.wild, wildAction), "invalid wild action")

	local events: { Event } = {}
	local actions: { [Side]: Action } = { player = playerAction, wild = wildAction }

	for _, side: Side in { "player", "wild" } :: { Side } do
		local me = sideOf(battle, side)
		local action = actions[side]
		if action == "Defend" then
			me.ap -= COMBAT.defendApCost
			me.defending = true
			local ev: Event = { side = side, action = "Defend", ap = COMBAT.defendApCost, text = me.name .. " braces to defend." }
			table.insert(events, ev)
		elseif action == "Save" then
			local ev: Event = { side = side, action = "Save", ap = 0, text = me.name .. " saves its action points." }
			table.insert(events, ev)
		end
	end

	local order: { Side } = if battle.wild.initiative > battle.player.initiative then { "wild", "player" } else { "player", "wild" }
	for _, side in order do
		if actions[side] == "Attack" then
			local me, foe = sideOf(battle, side)
			if me.hp > 0 then
				local spent = me.ap
				local raw = CombatEngine.attackDamage(me, spent)
				local dealt = raw
				local blocked = 0
				if foe.defending then
					dealt = raw * (1 - COMBAT.defendReduction)
					blocked = raw - dealt
				end
				dealt = math.max(1, math.floor(dealt + 0.5))
				me.ap = 0
				foe.hp = math.max(0, foe.hp - dealt)
				local text = ("%s attacks with %d AP for %d damage"):format(me.name, spent, dealt)
				if blocked > 0 then
					text ..= (" (%d blocked)"):format(math.floor(blocked + 0.5))
				end
				local ev: Event = { side = side, action = "Attack", ap = spent, damage = dealt, blocked = blocked, text = text .. "." }
				table.insert(events, ev)
			end
		end
	end

	if battle.wild.hp <= 0 then
		battle.state = "victory"
	elseif battle.player.hp <= 0 then
		battle.state = "defeat"
	else
		battle.round += 1
		if battle.round > COMBAT.maxRounds then
			battle.state = "draw"
		end
		for _, c in { battle.player, battle.wild } do
			c.defending = false
			c.ap = math.min(c.maxAp, c.ap + COMBAT.apPerRound)
		end
	end
	battle.lastEvents = events
	return events
end

-- Plain-table snapshot for sending to a client.
function CombatEngine.snapshot(battle: Battle)
	local function c(x: Combatant)
		return {
			speciesId = x.speciesId,
			name = x.name,
			kl = x.kl,
			level = x.level,
			hp = x.hp,
			maxHp = x.maxHp,
			ap = x.ap,
			maxAp = x.maxAp,
		}
	end
	return {
		round = battle.round,
		state = battle.state,
		player = c(battle.player),
		wild = c(battle.wild),
		events = battle.lastEvents,
		available = CombatEngine.availableActions(battle.player),
	}
end

return CombatEngine
