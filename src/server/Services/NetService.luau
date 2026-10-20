--!nonstrict
-- Owns all remotes. Client requests arrive through one RemoteFunction and are dispatched to handlers
-- registered by gameplay services. Every handler must validate its payload; this layer only enforces
-- shape (string action, table-or-nil payload), rate limiting and error isolation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Net.Remotes)

local NetService = {}

export type Result = { ok: boolean, message: string?, data: any? }
type Handler = (player: Player, payload: { [any]: any }) -> (boolean, string?, any?)

local handlers: { [string]: Handler } = {}
local buckets: { [Player]: { tokens: number, last: number } } = {}
local events: { [string]: RemoteEvent } = {}

local function allow(player: Player): boolean
	local cfg = GameConfig.Network
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { tokens = cfg.burst, last = now }
		buckets[player] = bucket
	end
	bucket.tokens = math.min(cfg.burst, bucket.tokens + (now - bucket.last) * cfg.requestsPerSecond)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function dispatch(player: Player, action: any, payload: any): Result
	if type(action) ~= "string" then
		return { ok = false, message = "Bad request" }
	end
	local handler = handlers[action]
	if not handler then
		return { ok = false, message = "Unknown action" }
	end
	if payload ~= nil and type(payload) ~= "table" then
		return { ok = false, message = "Bad request" }
	end
	if not allow(player) then
		return { ok = false, message = "Slow down a little!" }
	end
	local success, ok, message, data = pcall(handler, player, payload or {})
	if not success then
		warn(("[NetService] %s from %s failed: %s"):format(action, player.Name, tostring(ok)))
		return { ok = false, message = "Something went wrong" }
	end
	return { ok = ok == true, message = message, data = data }
end

function NetService.init()
	local folder = Remotes.createAll()
	for _, name in Remotes.Events do
		events[name] = folder:FindFirstChild(name) :: RemoteEvent
	end
	local request = folder:FindFirstChild(Remotes.Functions.Request) :: RemoteFunction
	request.OnServerInvoke = dispatch
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

function NetService.handle(action: string, handler: Handler)
	assert(Remotes.Actions[action] == action, "unregistered action name: " .. action)
	assert(handlers[action] == nil, "duplicate handler: " .. action)
	handlers[action] = handler
end

function NetService.fire(player: Player, eventName: string, payload: any)
	local event = events[eventName]
	assert(event, "unknown event " .. eventName)
	if player.Parent then
		event:FireClient(player, payload)
	end
end

function NetService.notify(player: Player, text: string, kind: string?)
	NetService.fire(player, Remotes.Events.Notify, { text = text, kind = kind or "info" })
end

-- Validation helpers shared by handlers.
function NetService.isId(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= 32 and string.match(value, "^[%w_]+$") ~= nil
end

function NetService.isInt(value: any, min: number, max: number): boolean
	return type(value) == "number" and value == math.floor(value) and value >= min and value <= max
end

return NetService
