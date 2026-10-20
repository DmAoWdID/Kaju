--!nonstrict
-- Riding owned kaijus. The server builds the kaiju, welds it under the player's character and raises the
-- Humanoid's HipHeight so the rider sits on the saddle while the kaiju's feet touch the ground. The
-- player then steers with normal movement controls; the kaiju is part of the character assembly, so it
-- moves with the client-owned character and replicates to everyone. The client plays the sit pose
-- (RideController) and KaijuAnimator animates the kaiju's legs from its movement.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local KaijuModelFactory = require(Shared.Visual.KaijuModelFactory)
local KaijuRegistry = require(Shared.Data.KaijuRegistry)
local Progression = require(Shared.Progression.Progression)
local Remotes = require(Shared.Net.Remotes)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)

local RideService = {}

type RideState = {
	instanceId: string,
	model: Model,
	humanoid: Humanoid,
	saved: { hipHeight: number, walkSpeed: number, jumpHeight: number, jumpPower: number },
}

local riders: { [Player]: RideState } = {}
local isInBattle: (Player) -> boolean = function()
	return false
end
local onChanged: (Player) -> () = function() end

local function clearAttributes(player: Player)
	player:SetAttribute("RidingInstanceId", nil)
	player:SetAttribute("RidingHeight", nil)
end

-- Ends a ride (safe to call when not riding). Returns true if the player was riding.
function RideService.dismount(player: Player): boolean
	local state = riders[player]
	if not state then
		return false
	end
	riders[player] = nil
	local humanoid = state.humanoid
	if humanoid.Parent then
		humanoid.HipHeight = state.saved.hipHeight
		humanoid.WalkSpeed = state.saved.walkSpeed
		humanoid.JumpHeight = state.saved.jumpHeight
		humanoid.JumpPower = state.saved.jumpPower
	end
	if state.model.Parent then
		state.model:Destroy()
	end
	clearAttributes(player)
	onChanged(player)
	return true
end

function RideService.isRiding(player: Player, instanceId: string?): boolean
	local state = riders[player]
	return state ~= nil and (instanceId == nil or state.instanceId == instanceId)
end

local function mount(player: Player, instanceId: string): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "Still loading"
	end
	if isInBattle(player) then
		return false, "Finish your battle first"
	end
	local owned = data.kaijus[instanceId]
	local species = owned and KaijuRegistry.get(owned.speciesId)
	if not owned or not species then
		return false, "You don't own that kaiju"
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp or humanoid.Health <= 0 then
		return false, "You need to be alive to ride"
	end
	if riders[player] then
		local same = riders[player].instanceId == instanceId
		RideService.dismount(player)
		if same then
			return true, nil
		end
	end

	local model = KaijuModelFactory.build(species)
	model.Name = "Mount"
	local root = model.PrimaryPart
	local saddle: Vector3 = model:GetAttribute("SaddleOffset") or Vector3.new(0, 6, 0)
	local rideHeight = saddle.Y + GameConfig.Riding.seatLift -- rider root height above the ground

	-- The kaiju's feet pivot sits on the ground below the rider, offset so the saddle is under them.
	local pivotFromRoot = CFrame.new(-saddle.X, -rideHeight, -saddle.Z)
	-- Lift the character first so the kaiju doesn't spawn into the ground.
	local currentHeight = hrp.Size.Y / 2 + humanoid.HipHeight
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		currentHeight = 3 + humanoid.HipHeight
	end
	character:PivotTo(character:GetPivot() + Vector3.new(0, math.max(0, rideHeight - currentHeight), 0))

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	model:PivotTo(hrp.CFrame * pivotFromRoot)
	local weld = Instance.new("Weld")
	weld.Name = "MountWeld"
	weld.Part0 = hrp
	weld.Part1 = root
	weld.C0 = pivotFromRoot
	weld.C1 = root.PivotOffset
	weld.Parent = root
	-- Inside the character so the Humanoid's floor checks and the camera ignore it.
	model.Parent = character

	local saved = {
		hipHeight = humanoid.HipHeight,
		walkSpeed = humanoid.WalkSpeed,
		jumpHeight = humanoid.JumpHeight,
		jumpPower = humanoid.JumpPower,
	}
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		humanoid.HipHeight = rideHeight - 3
	else
		humanoid.HipHeight = rideHeight - hrp.Size.Y / 2
	end
	humanoid.WalkSpeed = Progression.rideSpeed(species.stats.mobility)
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0

	riders[player] = { instanceId = instanceId, model = model, humanoid = humanoid, saved = saved }
	player:SetAttribute("RidingInstanceId", instanceId)
	player:SetAttribute("RidingHeight", rideHeight)
	onChanged(player)
	return true, ("Riding %s"):format(species.displayName)
end

-- hooks: isInBattle(player), onChanged(player) (e.g. re-render the park while a kaiju is out riding)
function RideService.init(hooks: { isInBattle: (Player) -> boolean, onChanged: (Player) -> () })
	isInBattle = hooks.isInBattle
	onChanged = hooks.onChanged

	NetService.handle(Remotes.Actions.RideKaiju, function(player, payload)
		if not NetService.isId(payload.instanceId) then
			return false, "Invalid kaiju"
		end
		return mount(player, payload.instanceId)
	end)
	NetService.handle(Remotes.Actions.Dismount, function(player)
		if not RideService.dismount(player) then
			return false, "You're not riding"
		end
		return true
	end)

	local function watch(player: Player)
		player.CharacterRemoving:Connect(function()
			-- the mount lives inside the character and is destroyed with it
			if riders[player] then
				riders[player] = nil
				clearAttributes(player)
				onChanged(player)
			end
		end)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid then
				humanoid.Died:Connect(function()
					RideService.dismount(player)
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		riders[player] = nil
	end)
end

return RideService
