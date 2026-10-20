--!strict
-- Pure gait math for procedural kaiju animation (no Roblox APIs, so it can be previewed and tested).
-- Each animation group (see ModelKit:group) rotates around its pivot by the angles returned here.
-- Angles are applied as CFrame.Angles(x, y, z) in the model's frame:
--   x = pitch (legs/arms swing forward-back, heads nod), y = yaw (tails swish), z = roll (wings flap).

local KaijuGait = {}

-- Base amplitude in radians per kind; a group's `amp` multiplies it.
local AMPLITUDE: { [string]: number } = table.freeze({
	leg = 0.5,
	arm = 0.35,
	tail = 0.22,
	wing = 0.45,
	head = 0.1,
	sway = 0.12,
}) :: any
KaijuGait.AMPLITUDE = AMPLITUDE

local TAU = math.pi * 2

-- cycle: gait position in cycles (advances with distance walked); walk: 0 (still) .. 1 (walking);
-- t: time in seconds (drives idle motion and wing beats).
function KaijuGait.angles(kind: string, phase: number, side: number, amp: number, cycle: number, walk: number, t: number): (number, number, number)
	local a = (AMPLITUDE[kind] or 0.2) * amp
	local stride = math.sin((cycle + phase) * TAU)
	if kind == "leg" then
		return stride * a * walk, 0, 0
	elseif kind == "arm" then
		local idle = math.sin(t * 1.3 + phase * TAU) * 0.04 * (1 - walk)
		return stride * a * walk + idle, 0, 0
	elseif kind == "tail" then
		local swish = math.sin(t * 1.6 + phase * TAU) * a * (0.45 + 0.55 * walk)
		return math.sin((cycle + phase) * TAU * 2) * a * 0.25 * walk, swish, 0
	elseif kind == "wing" then
		local beat = math.sin(t * TAU * (0.9 + 1.1 * walk) + phase * TAU)
		return 0, 0, beat * a * (0.55 + 0.45 * walk) * (if side == 0 then 1 else side)
	elseif kind == "head" then
		local bob = math.sin((cycle + phase) * TAU * 2) * a * walk
		local idle = math.sin(t * 0.9 + phase * TAU) * a * 0.35
		return bob + idle, 0, 0
	elseif kind == "sway" then
		return math.sin(t * 1.1 + phase * TAU) * a, 0, math.cos(t * 0.8 + phase * TAU) * a * 0.7
	end
	return 0, 0, 0
end

return KaijuGait
