--!nonstrict
-- Procedural kaiju animation on the client. Every model tagged "AnimatedKaiju" (wild kaijus, park
-- kaijus, battle-arena kaijus) gets its limb motors driven each frame:
--   * how far the model moved since last frame advances its gait cycle (feet stay in sync with movement)
--   * its smoothed speed blends between idle motion and a full walk
-- The server only moves the model's Root; Motor6D.Transform is local to this client and never replicates.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KaijuGait = require(Shared.Visual.KaijuGait)
local KaijuModelFactory = require(Shared.Visual.KaijuModelFactory)

local KaijuAnimator = {}

local MAX_DISTANCE = 400 -- don't animate kaijus further than this from the camera
local FULL_WALK_SPEED = 2.5 -- studs/s at which the walk blend reaches 1

type Joint = { motor: Motor6D, kind: string, phase: number, side: number, amp: number }
type State = {
	root: BasePart,
	joints: { Joint },
	lastPos: Vector3,
	speed: number,
	walk: number,
	cycle: number,
	stride: number,
	timeOffset: number,
}

local tracked: { [Model]: State } = {}
local rng = Random.new()

local function track(model: Instance)
	if tracked[model] or not model:IsA("Model") or not model:IsDescendantOf(Workspace) then
		return
	end
	local root = model.PrimaryPart
	if not root then
		return
	end
	local joints: { Joint } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Name == "AnimMotor" and d.Part1 then
			local bone = d.Part1
			table.insert(joints, {
				motor = d,
				kind = bone:GetAttribute("AnimKind") or "sway",
				phase = bone:GetAttribute("AnimPhase") or 0,
				side = bone:GetAttribute("AnimSide") or 0,
				amp = bone:GetAttribute("AnimAmp") or 1,
			})
		end
	end
	if #joints == 0 then
		return
	end
	tracked[model] = {
		root = root,
		joints = joints,
		lastPos = root.Position,
		speed = 0,
		walk = 0,
		cycle = rng:NextNumber(),
		stride = math.max(1, model:GetAttribute("AnimStride") or 6),
		timeOffset = rng:NextNumber(0, 10), -- so a group of kaijus doesn't move in lockstep
	}
end

local function untrack(model: Instance)
	local state = tracked[model]
	if not state then
		return
	end
	tracked[model] = nil
	for _, joint in state.joints do
		if joint.motor.Parent then
			joint.motor.Transform = CFrame.identity
		end
	end
end

local function step(_, dt: number)
	local camera = Workspace.CurrentCamera
	local camPos = camera and camera.CFrame.Position
	local now = os.clock()
	for model, state in tracked do
		local root = state.root
		if not model.Parent or not root.Parent then
			tracked[model] = nil
			continue
		end
		local pos = root.Position
		local delta = Vector3.new(pos.X - state.lastPos.X, 0, pos.Z - state.lastPos.Z).Magnitude
		state.lastPos = pos
		if delta > state.stride * 3 then
			delta = 0 -- teleported / respawned: don't count it as walking
		end
		local instantSpeed = delta / math.max(dt, 1 / 240)
		state.speed += (instantSpeed - state.speed) * math.min(1, dt * 6)
		state.walk += (math.clamp(state.speed / FULL_WALK_SPEED, 0, 1) - state.walk) * math.min(1, dt * 5)
		state.cycle = (state.cycle + delta / state.stride) % 1

		if camPos and (pos - camPos).Magnitude > MAX_DISTANCE then
			continue
		end
		local t = now + state.timeOffset
		for _, joint in state.joints do
			local x, y, z = KaijuGait.angles(joint.kind, joint.phase, joint.side, joint.amp, state.cycle, state.walk, t)
			joint.motor.Transform = CFrame.Angles(x, y, z)
		end
	end
end

function KaijuAnimator.init()
	local tag = KaijuModelFactory.ANIMATED_TAG
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(model)
		-- parts/motors may still be arriving this frame
		task.defer(track, model)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(untrack)
	for _, model in CollectionService:GetTagged(tag) do
		track(model)
	end
	-- Stepped runs before physics, so the new Transforms are used when joints are solved this frame.
	RunService.Stepped:Connect(step)
end

return KaijuAnimator
