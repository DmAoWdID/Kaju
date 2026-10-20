--!nonstrict
-- Loads, holds, replicates and saves player data.
--
-- Persistence modes:
--   * "datastore": live servers (and Studio if GameConfig.Persistence.useDataStoreInStudio = true).
--     Uses UpdateAsync with a session lock so two servers never write the same player at once.
--   * "memory": default in Studio. Data lives only for the session and is NEVER written anywhere.
-- If a load fails, the player gets temporary data and that session is never saved, so real saves
-- can't be overwritten by defaults.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local KaijuRegistry = require(Shared.Data.KaijuRegistry)
local PlayerDataSchema = require(Shared.PlayerData.PlayerDataSchema)
local Remotes = require(Shared.Net.Remotes)
local NetService = require(script.Parent.NetService)

local DataService = {}

type Profile = {
	data: any,
	persistent: boolean, -- false = never write to the DataStore
	key: string,
}

local CFG = GameConfig.Persistence
local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (Player, any) -> () } = {}
local pendingReplication: { [Player]: string } = {}
local store: DataStore? = nil
DataService.mode = "memory"

local function deepCopy(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local copy = {}
	for k, v in t do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function keyFor(player: Player): string
	return CFG.keyPrefix .. player.UserId
end

local function now(): number
	return os.time()
end

-- Returns (status, rawData). status: "ok" | "locked" | "error"
local function tryLoad(key: string): (string, any)
	assert(store)
	local status, raw = "error", nil
	local success, err = pcall(function()
		store:UpdateAsync(key, function(record)
			record = if type(record) == "table" then record else {}
			local lock = record.lock
			if type(lock) == "table" and lock.jobId ~= game.JobId and now() - (tonumber(lock.time) or 0) < CFG.sessionLockSeconds then
				status = "locked"
				return nil -- cancel: another server still owns this session
			end
			record.lock = { jobId = game.JobId, time = now() }
			status, raw = "ok", record.data
			return record
		end)
	end)
	if not success then
		warn("[DataService] load error for " .. key .. ": " .. tostring(err))
		return "error", nil
	end
	return status, raw
end

local function trySave(key: string, data: any, release: boolean): boolean
	assert(store)
	local snapshot = deepCopy(data)
	local stolen = false
	local success, err = pcall(function()
		store:UpdateAsync(key, function(record)
			record = if type(record) == "table" then record else {}
			local lock = record.lock
			if type(lock) == "table" and lock.jobId ~= game.JobId then
				stolen = true
				return nil -- someone else owns the session now; never overwrite their data
			end
			record.data = snapshot
			record.savedAt = now()
			record.lock = if release then nil else { jobId = game.JobId, time = now() }
			return record
		end)
	end)
	if not success then
		warn("[DataService] save error for " .. key .. ": " .. tostring(err))
		return false
	end
	if stolen then
		warn("[DataService] session lock for " .. key .. " is held by another server; save skipped")
	end
	return not stolen
end

local function save(player: Player, release: boolean)
	local profile = profiles[player]
	if not profile or not profile.persistent or not store then
		return
	end
	for attempt = 1, CFG.maxRetries do
		if trySave(profile.key, profile.data, release) then
			return
		end
		if attempt < CFG.maxRetries then
			task.wait(2 * attempt)
		end
	end
end

local function onPlayerAdded(player: Player)
	local key = keyFor(player)
	local data, persistent = nil, false

	if DataService.mode == "datastore" then
		local status, raw = "error", nil
		for attempt = 1, CFG.maxRetries do
			status, raw = tryLoad(key)
			if status == "ok" then
				break
			end
			if not player.Parent then
				return
			end
			task.wait(if status == "locked" then 5 else 2 * attempt)
		end
		if status == "locked" then
			player:Kick("Your Kaiju Park data is still being saved by another server. Please rejoin in a moment.")
			return
		end
		if status == "ok" then
			local ok, result, warnings = pcall(PlayerDataSchema.reconcile, raw, KaijuRegistry.exists)
			if ok then
				data, persistent = result, true
				for _, w in warnings do
					warn("[DataService] " .. player.Name .. ": " .. w)
				end
			else
				-- e.g. saved by a newer game version. Do not touch it.
				warn("[DataService] could not reconcile data for " .. player.Name .. ": " .. tostring(result))
			end
		end
	else
		data = PlayerDataSchema.default()
	end

	if not player.Parent then
		return -- left while loading; nothing to release because we never wrote progress
	end

	if not data then
		data = PlayerDataSchema.default()
		persistent = false
		task.delay(3, function()
			NetService.notify(player, "Your saved data could not be loaded. Progress this session will NOT be saved.", "error")
		end)
	end

	profiles[player] = { data = data, persistent = persistent, key = key }
	player:SetAttribute("DataLoaded", true)
	for _, callback in loadedCallbacks do
		local ok, err = pcall(callback, player, data)
		if not ok then
			warn("[DataService] onLoaded callback failed: " .. tostring(err))
		end
	end
	DataService.replicate(player, "full")
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		save(player, true)
		profiles[player] = nil
	end
	pendingReplication[player] = nil
end

function DataService.init()
	local wantStore = not RunService:IsStudio() or CFG.useDataStoreInStudio
	if wantStore then
		local ok, result = pcall(function()
			return game:GetService("DataStoreService"):GetDataStore(CFG.dataStoreName)
		end)
		if ok then
			store = result
			DataService.mode = "datastore"
		else
			warn("[DataService] DataStore unavailable, falling back to memory mode: " .. tostring(result))
		end
	end
	print(("[DataService] persistence mode: %s%s"):format(
		DataService.mode,
		if DataService.mode == "memory" then " (nothing is saved between sessions)" else ""
	))

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		local threads = {}
		for player in profiles do
			table.insert(threads, task.spawn(save, player, true))
		end
		-- give saves time to finish (BindToClose allows ~30s)
		local deadline = os.clock() + 20
		while os.clock() < deadline do
			local busy = false
			for _, thread in threads do
				if coroutine.status(thread) ~= "dead" then
					busy = true
				end
			end
			if not busy then
				break
			end
			task.wait(0.25)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(CFG.autosaveSeconds)
			for player in profiles do
				task.spawn(save, player, false)
			end
		end
	end)

	NetService.handle(Remotes.Actions.GetState, function(player)
		local profile = profiles[player]
		if not profile then
			return false, "Still loading"
		end
		DataService.replicate(player, "full")
		return true
	end)
end

function DataService.onLoaded(callback: (Player, any) -> ())
	table.insert(loadedCallbacks, callback)
end

-- Returns the live data table for a loaded player (server-side only), or nil while loading.
function DataService.get(player: Player): any?
	local profile = profiles[player]
	return profile and profile.data
end

function DataService.loadedPlayers(): { Player }
	local list = {}
	for player in profiles do
		table.insert(list, player)
	end
	return list
end

-- Queues a state push to the client. "full" supersedes "currency"; multiple calls in a frame coalesce.
function DataService.replicate(player: Player, scope: string?)
	local wanted = scope or "full"
	local pending = pendingReplication[player]
	if pending == "full" or pending == wanted then
		return
	end
	local first = pending == nil
	pendingReplication[player] = wanted
	if not first then
		return
	end
	task.defer(function()
		local which = pendingReplication[player]
		pendingReplication[player] = nil
		local profile = profiles[player]
		if not which or not profile then
			return
		end
		if which == "full" then
			NetService.fire(player, Remotes.Events.StateSync, {
				scope = "full",
				data = deepCopy(profile.data),
				persistence = { mode = DataService.mode, saving = profile.persistent },
			})
		else
			NetService.fire(player, Remotes.Events.StateSync, {
				scope = "currency",
				money = profile.data.money,
				kaijuCells = profile.data.kaijuCells,
			})
		end
	end)
end

return DataService
