--!nonstrict
-- Client-side mirror of the player's data (display only; the server is authoritative) and the single
-- entry point for sending requests to the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)

local ClientState = {}

ClientState.data = nil
ClientState.persistence = nil

local listeners: { (string) -> () } = {}
local toastHandler: ((string, string) -> ())? = nil

-- fn(scope): scope is "full" (anything may have changed) or "currency" (only money / cells changed).
function ClientState.onChanged(fn: (string) -> ()): () -> ()
	table.insert(listeners, fn)
	if ClientState.data then
		task.spawn(fn, "full")
	end
	return function()
		local i = table.find(listeners, fn)
		if i then
			table.remove(listeners, i)
		end
	end
end

local function emit(scope: string)
	for _, fn in listeners do
		task.spawn(fn, scope)
	end
end

function ClientState.setToastHandler(fn: (string, string) -> ())
	toastHandler = fn
end

function ClientState.toast(text: string, kind: string?)
	if toastHandler then
		toastHandler(text, kind or "info")
	end
end

-- Sends a request; shows the server's message as a toast. Returns the result table.
function ClientState.request(action: string, payload: { [string]: any }?, quiet: boolean?)
	local ok, result = pcall(function()
		return Remotes.func(Remotes.Functions.Request):InvokeServer(action, payload)
	end)
	if not ok or type(result) ~= "table" then
		ClientState.toast("Connection problem, please try again.", "error")
		return { ok = false }
	end
	if result.message and not quiet then
		ClientState.toast(result.message, if result.ok then "good" else "error")
	end
	return result
end

function ClientState.init()
	Remotes.event(Remotes.Events.StateSync).OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.scope == "full" then
			ClientState.data = payload.data
			ClientState.persistence = payload.persistence
		elseif payload.scope == "currency" and ClientState.data then
			ClientState.data.money = payload.money
			ClientState.data.kaijuCells = payload.kaijuCells
		else
			return
		end
		emit(payload.scope)
	end)
	Remotes.event(Remotes.Events.Notify).OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.text) == "string" then
			ClientState.toast(payload.text, payload.kind)
		end
	end)
	-- In case the first full sync fired before we connected.
	task.spawn(function()
		while not ClientState.data do
			ClientState.request(Remotes.Actions.GetState, nil, true)
			task.wait(2)
		end
	end)
end

return ClientState
