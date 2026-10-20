--!nonstrict
-- Client side of riding: plays a seated pose on the local character while riding and pulls the camera
-- back so big mounts fit on screen. The server owns the mount itself (RideService).

local Players = game:GetService("Players")

local RideController = {}

local player = Players.LocalPlayer
-- Roblox's default "sit" animations (same assets the built-in Animate script uses).
local SIT_ANIMATION = {
	[Enum.HumanoidRigType.R15] = "rbxassetid://2506281703",
	[Enum.HumanoidRigType.R6] = "rbxassetid://178130996",
}

local sitTrack: AnimationTrack? = nil
local defaultMinZoom = player.CameraMinZoomDistance
local defaultMaxZoom = player.CameraMaxZoomDistance
local listeners: { (boolean) -> () } = {}

local function stopSitting()
	if sitTrack then
		sitTrack:Stop(0.2)
		sitTrack:Destroy()
		sitTrack = nil
	end
end

local function startSitting()
	stopSitting()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 5)
	local id = SIT_ANIMATION[humanoid.RigType]
	if not animator or not id then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if ok and track then
		track.Priority = Enum.AnimationPriority.Action -- overrides the walk/idle animations
		track.Looped = true
		track:Play(0.2)
		sitTrack = track
	end
end

local function refresh()
	local riding = player:GetAttribute("RidingInstanceId") ~= nil
	if riding then
		startSitting()
		local height = player:GetAttribute("RidingHeight") or 8
		player.CameraMinZoomDistance = math.max(defaultMinZoom, height * 1.6)
		player.CameraMaxZoomDistance = math.max(defaultMaxZoom, height * 6)
	else
		stopSitting()
		player.CameraMinZoomDistance = defaultMinZoom
		player.CameraMaxZoomDistance = defaultMaxZoom
	end
	for _, fn in listeners do
		task.spawn(fn, riding)
	end
end

function RideController.isRiding(): boolean
	return player:GetAttribute("RidingInstanceId") ~= nil
end

function RideController.ridingInstanceId(): string?
	return player:GetAttribute("RidingInstanceId")
end

-- fn(isRiding) is called whenever the ride state changes.
function RideController.onChanged(fn: (boolean) -> ())
	table.insert(listeners, fn)
	task.spawn(fn, RideController.isRiding())
end

function RideController.init()
	player:GetAttributeChangedSignal("RidingInstanceId"):Connect(refresh)
	player:GetAttributeChangedSignal("RidingHeight"):Connect(refresh)
	player.CharacterAdded:Connect(function()
		sitTrack = nil
		task.defer(refresh)
	end)
	refresh()
end

return RideController
