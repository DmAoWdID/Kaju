--!strict
-- Single list of network endpoints. The server creates them; clients wait for them.
--
-- Client -> server traffic goes through ONE RemoteFunction ("Request") carrying an action name and a
-- payload table. The server validates every action in NetService; nothing the client sends is trusted.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.FOLDER_NAME = "KaijuParkRemotes"

Remotes.Events = table.freeze({
	StateSync = "StateSync", -- S->C player data snapshot ({scope="full"|"currency", ...})
	BattleSync = "BattleSync", -- S->C battle phase + snapshot
	Notify = "Notify", -- S->C toast {text, kind}
})

Remotes.Functions = table.freeze({
	Request = "Request", -- C->S (action: string, payload: table?) -> {ok, message?, data?}
})

-- Request action names (C->S). Keep in sync with the server handlers.
Remotes.Actions = table.freeze({
	BattleChooseKaiju = "BattleChooseKaiju",
	BattleAction = "BattleAction",
	BattleResolve = "BattleResolve",
	BattleForfeit = "BattleForfeit",
	LevelUpKaiju = "LevelUpKaiju",
	AssignKaiju = "AssignKaiju",
	UnassignKaiju = "UnassignKaiju",
	PlaceEnclosure = "PlaceEnclosure",
	BuyChain = "BuyChain",
	Travel = "Travel",
	GetState = "GetState",
})

local folder: Folder? = nil

function Remotes.createAll(): Folder
	assert(RunService:IsServer(), "Remotes.createAll is server-only")
	local existing = ReplicatedStorage:FindFirstChild(Remotes.FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = Remotes.FOLDER_NAME
	for _, name in Remotes.Events do
		local e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = f
	end
	for _, name in Remotes.Functions do
		local fn = Instance.new("RemoteFunction")
		fn.Name = name
		fn.Parent = f
	end
	f.Parent = ReplicatedStorage
	folder = f
	return f
end

local function getFolder(): Folder
	if folder then
		return folder
	end
	local f = ReplicatedStorage:WaitForChild(Remotes.FOLDER_NAME) :: Folder
	folder = f
	return f
end

function Remotes.event(name: string): RemoteEvent
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return getFolder():WaitForChild(name) :: RemoteFunction
end

return Remotes
