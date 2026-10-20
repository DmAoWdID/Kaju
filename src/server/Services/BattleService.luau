--!nonstrict
-- Server-authoritative battle sessions: select kaiju -> fight (turns) -> reward choice -> ended.
-- Phase transitions happen only here; clients send requests and receive snapshots via BattleSync.
-- A battle's reward is granted at most once (session.resolved is set before any reward is applied).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatEngine = require(Shared.Combat.CombatEngine)
local GameConfig = require(Shared.Config.GameConfig)
local KaijuRegistry = require(Shared.Data.KaijuRegistry)
local PlayerDataSchema = require(Shared.PlayerData.PlayerDataSchema)
local Progression = require(Shared.Progression.Progression)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)
local WildKaijuService = require(script.Parent.WildKaijuService)

local BattleService = {}

type Session = {
	player: Player,
	wildId: string,
	species: any,
	model: Model,
	phase: string, -- "select" | "fight" | "reward" | "ended"
	battle: any?,
	playerKaijuId: string?,
	lastActivity: number,
	resolved: boolean,
	rng: Random,
	saved: { walkSpeed: number, jumpHeight: number, jumpPower: number }?,
}

local COMBAT = GameConfig.Combat
local START_DISTANCE_SLACK = 10
local sessions: { [Player]: Session } = {}
local beforeStart: (Player) -> () = function() end

-- Called right before a battle starts (e.g. to dismount a ridden kaiju).
function BattleService.setBeforeStart(fn: (Player) -> ())
	beforeStart = fn
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

local function freeze(session: Session)
	local humanoid = humanoidOf(session.player)
	if humanoid then
		session.saved = { walkSpeed = humanoid.WalkSpeed, jumpHeight = humanoid.JumpHeight, jumpPower = humanoid.JumpPower }
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
		humanoid.JumpPower = 0
	end
end

local function unfreeze(session: Session)
	local humanoid = humanoidOf(session.player)
	if humanoid and session.saved then
		humanoid.WalkSpeed = session.saved.walkSpeed
		humanoid.JumpHeight = session.saved.jumpHeight
		humanoid.JumpPower = session.saved.jumpPower
	end
	session.saved = nil
end

local function rewardInfo(session: Session, data)
	local kl = session.species.kl
	local chain = Progression.chain(data.chainTier)
	local required = Progression.requiredChainFor(kl)
	return {
		canCapture = Progression.canCapture(data.chainTier, kl),
		chainName = chain and chain.displayName or "?",
		requiredChain = required and required.displayName or nil,
		captureChance = GameConfig.KL[kl].captureChance,
		cells = Progression.cellsForDefeat(kl),
	}
end

local function sync(session: Session, result: any?)
	local data = DataService.get(session.player)
	local payload = {
		phase = session.phase,
		wild = {
			speciesId = session.species.id,
			name = session.species.displayName,
			kl = session.species.kl,
			level = COMBAT.wildLevel,
		},
		model = session.model,
		snapshot = if session.battle then CombatEngine.snapshot(session.battle) else nil,
		reward = if session.phase == "reward" and data then rewardInfo(session, data) else nil,
		result = result,
	}
	NetService.fire(session.player, Remotes.Events.BattleSync, payload)
end

-- Ends the session. `wildOutcome`: "release" (back to roaming) or "remove" (gone from the world).
local function finish(session: Session, wildOutcome: string, result: any)
	if sessions[session.player] ~= session then
		return
	end
	sessions[session.player] = nil
	session.phase = "ended"
	if wildOutcome == "remove" then
		WildKaijuService.remove(session.wildId)
	else
		WildKaijuService.release(session.wildId)
	end
	unfreeze(session)
	sync(session, result)
end

local function startBattle(player: Player, wildId: string)
	if sessions[player] then
		return
	end
	local data = DataService.get(player)
	if not data then
		NetService.notify(player, "Still loading your data…", "info")
		return
	end
	local humanoid = humanoidOf(player)
	local position = rootPosition(player)
	if not humanoid or humanoid.Health <= 0 or not position then
		return
	end
	local wild = WildKaijuService.get(wildId)
	if not wild or wild.state ~= "roaming" then
		NetService.notify(player, "That kaiju is already in a battle.", "info")
		return
	end
	if WildKaijuService.distanceFrom(wildId, position) > GameConfig.Interaction.promptDistance + START_DISTANCE_SLACK then
		return
	end
	if next(data.kaijus) == nil then
		NetService.notify(player, "You need a kaiju of your own to battle.", "error")
		return
	end
	if not WildKaijuService.engage(wildId, player, position) then
		return
	end
	beforeStart(player)

	local session: Session = {
		player = player,
		wildId = wildId,
		species = wild.species,
		model = wild.model,
		phase = "select",
		battle = nil,
		playerKaijuId = nil,
		lastActivity = os.clock(),
		resolved = false,
		rng = Random.new(),
		saved = nil,
	}
	sessions[player] = session
	freeze(session)
	sync(session)
end

local function onChooseKaiju(player: Player, payload)
	local session = sessions[player]
	if not session or session.phase ~= "select" then
		return false, "Not choosing a kaiju right now"
	end
	local data = DataService.get(player)
	local instanceId = payload.instanceId
	if not data or not NetService.isId(instanceId) then
		return false, "Invalid kaiju"
	end
	local owned = data.kaijus[instanceId]
	local species = owned and KaijuRegistry.get(owned.speciesId)
	if not owned or not species then
		return false, "You don't own that kaiju"
	end
	session.playerKaijuId = instanceId
	session.battle = CombatEngine.newBattle(
		CombatEngine.newCombatant(species, owned.level),
		CombatEngine.newCombatant(session.species, COMBAT.wildLevel)
	)
	session.phase = "fight"
	session.lastActivity = os.clock()
	sync(session)
	return true
end

local function onAction(player: Player, payload)
	local session = sessions[player]
	if not session or session.phase ~= "fight" or not session.battle then
		return false, "No battle in progress"
	end
	local action = payload.action
	if type(action) ~= "string" or not table.find(CombatEngine.ACTIONS, action) then
		return false, "Unknown action"
	end
	local battle = session.battle
	if not CombatEngine.canUse(battle.player, action) then
		return false, "Not enough action points"
	end
	local wildAction = CombatEngine.chooseAiAction(battle, function()
		return session.rng:NextNumber()
	end)
	CombatEngine.resolveRound(battle, action, wildAction)
	session.lastActivity = os.clock()

	local data = DataService.get(player)
	if battle.state == "victory" then
		session.phase = "reward"
		if data then
			data.stats.battlesWon += 1
		end
		sync(session)
	elseif battle.state == "defeat" or battle.state == "draw" then
		if data then
			data.stats.battlesLost += 1
		end
		local text = if battle.state == "defeat"
			then ("%s was too strong this time."):format(session.species.displayName)
			else "The battle dragged on too long. Both kaijus retreat."
		finish(session, "release", { outcome = battle.state, text = text })
	else
		sync(session)
	end
	return true
end

local function onResolve(player: Player, payload)
	local session = sessions[player]
	if not session or session.phase ~= "reward" or session.resolved then
		return false, "Nothing to claim"
	end
	local data = DataService.get(player)
	if not data then
		return false, "Still loading"
	end
	local choice = payload.choice
	local kl = session.species.kl

	if choice == "capture" then
		if not Progression.canCapture(data.chainTier, kl) then
			local required = Progression.requiredChainFor(kl)
			return false, ("Your chain is too short for a KL %d kaiju. You need the %s."):format(kl, required and required.displayName or "next chain")
		end
		session.resolved = true
		if session.rng:NextNumber() < GameConfig.KL[kl].captureChance then
			local owned = PlayerDataSchema.addKaiju(data, session.species.id, COMBAT.wildLevel, os.time())
			data.stats.captures += 1
			DataService.replicate(player, "full")
			finish(session, "remove", {
				outcome = "captured",
				text = ("You captured %s! Find it in your Collection."):format(session.species.displayName),
				instanceId = owned.instanceId,
			})
		else
			finish(session, "remove", { outcome = "escaped", text = ("%s broke the chain and escaped!"):format(session.species.displayName) })
		end
		return true
	elseif choice == "cells" then
		session.resolved = true
		local cells = Progression.cellsForDefeat(kl)
		data.kaijuCells += cells
		DataService.replicate(player, "full")
		finish(session, "remove", {
			outcome = "cells",
			text = ("%s was defeated. +%d Kaiju Cells"):format(session.species.displayName, cells),
			cells = cells,
		})
		return true
	end
	return false, "Unknown choice"
end

local function forfeit(player: Player, reason: string)
	local session = sessions[player]
	if not session then
		return
	end
	if session.phase == "reward" then
		-- Victory already earned: never lose the reward to a timeout; default to Kaiju Cells.
		if not session.resolved and player.Parent then
			onResolve(player, { choice = "cells" })
			return
		end
		finish(session, "remove", { outcome = "forfeit", text = reason })
		return
	end
	finish(session, "release", { outcome = "forfeit", text = reason })
end

function BattleService.init()
	NetService.handle(Remotes.Actions.BattleChooseKaiju, onChooseKaiju)
	NetService.handle(Remotes.Actions.BattleAction, onAction)
	NetService.handle(Remotes.Actions.BattleResolve, onResolve)
	NetService.handle(Remotes.Actions.BattleForfeit, function(player)
		local session = sessions[player]
		if not session or (session.phase ~= "select" and session.phase ~= "fight") then
			return false, "You can't leave right now"
		end
		forfeit(player, "You retreated from the battle.")
		return true
	end)

	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			sessions[player] = nil
			if session.phase == "reward" then
				WildKaijuService.remove(session.wildId)
			else
				WildKaijuService.release(session.wildId)
			end
		end
	end)

	local function watchCharacter(player: Player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid then
				humanoid.Died:Connect(function()
					forfeit(player, "Battle ended.")
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(watchCharacter)
	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end

	task.spawn(function()
		while true do
			task.wait(5)
			local cutoff = os.clock() - COMBAT.actionTimeoutSeconds
			for player, session in sessions do
				if session.lastActivity < cutoff then
					forfeit(player, "The battle timed out.")
				end
			end
		end
	end)
end

-- Called by WildKaijuService when a player triggers a wild kaiju's prompt.
function BattleService.onPromptTriggered(player: Player, wildId: string)
	startBattle(player, wildId)
end

function BattleService.isInBattle(player: Player): boolean
	return sessions[player] ~= nil
end

return BattleService
