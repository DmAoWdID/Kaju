--!nonstrict
-- Hand-built placeholder models for each species, following the concept art in Docs/Kaju game.pdf.
-- Each design draws in its own units (feet at y = 0, facing -Z); KaijuModelFactory rescales the result
-- by KL, so relative sizes between species come from config, not from these numbers.
-- These are presentation only. Replace any of them with a real model via ReplicatedStorage.KaijuModels.

local ModelKit = require("./ModelKit")

local V = Vector3.new
local C = Color3.fromRGB
local bez = ModelKit.bezier
local mirror = ModelKit.mirror
local NEON = { material = Enum.Material.Neon }
local SLATE = { material = Enum.Material.Slate }
local METAL = { material = Enum.Material.Metal }
local GLASS = { material = Enum.Material.Glass, transparency = 0.1 }

local Designs = {}

-- Gait phase for a leg: front/back index (1 = front) and side (-1/1). Diagonal pairs move together.
local function diagonal(front: boolean, s: number): number
	return if (front and s < 0) or (not front and s > 0) then 0 else 0.5
end

-- ───────────────────────────── KL 1 ─────────────────────────────

-- Hunched crawler: angular grey carapace hood, crimson face and long crimson mantis arms, dark hind legs.
Designs.kragmor = function(k)
	k:saddle(V(0, 10.4, 0.2))
	local shell, shellLight, dark, crimson, tooth = C(112, 112, 128), C(150, 150, 166), C(52, 52, 60), C(190, 26, 62), C(232, 214, 186)
	mirror(function(s)
		for i, z in { 1.2, 3.6 } do
			local hip, knee, foot = V(s * 1.8, 5.6, z), V(s * 4.2, 6.8 - i * 0.4, z + 1.4), V(s * 4.8, 0.3, z + 2.6)
			k:group("leg" .. i .. s, hip, "leg", { phase = diagonal(i == 1, s), side = s }, function()
				k:tube({ hip, knee, foot }, 0.45, 0.3, dark)
				k:spike(foot, foot + V(s * 0.4, 0, -1.2), 0.25, dark)
			end)
		end
	end)
	k:ball(V(5, 3.6, 7.5), V(0, 6.2, 1), dark, nil, CFrame.Angles(math.rad(12), 0, 0))
	-- carapace: overlapping angled plates forming a hood that overhangs the head
	local plates = { { -6, 7.4, -30 }, { -3.6, 9.2, -16 }, { -1, 10, -4 }, { 1.8, 9.8, 8 }, { 4.4, 8.6, 22 } }
	for i, p in plates do
		local width = 7.6 - math.abs(i - 3) * 0.7
		k:box(V(width, 0.9, 3.4), CFrame.new(0, p[2], p[1]) * CFrame.Angles(math.rad(p[3]), 0, 0), if i % 2 == 0 then shellLight else shell)
		mirror(function(s)
			local edge = V(s * width / 2, p[2] - 0.2, p[1])
			k:tri(edge + V(0, 0, -1.4), edge + V(0, 0, 1.4), edge + V(s * 0.9, -2.2, 0.4), shell, 0.3)
		end)
	end
	k:tri(V(-2.6, 7.6, -7.4), V(2.6, 7.6, -7.4), V(0, 6.4, -9.2), shell, 0.4)
	-- face under the hood
	k:ball(V(3, 2.6, 3), V(0, 5.6, -5.6), crimson)
	k:ball(V(2, 1.3, 0.8), V(0, 5, -7), C(40, 8, 16))
	k:teeth(V(-0.8, 5.6, -7.2), V(0.8, 5.6, -7.2), 4, 0.7, V(0, -1, -0.2), tooth)
	k:eye(V(-0.9, 6.4, -6.8), 0.45, C(255, 220, 120), { sclera = C(30, 30, 30) })
	k:eye(V(0.9, 6.4, -6.8), 0.45, C(255, 220, 120), { sclera = C(30, 30, 30) })
	-- crimson mantis arms with hooked, jagged claws
	mirror(function(s)
		local shoulder, elbow, wrist = V(s * 1.6, 6.2, -3.6), V(s * 2.8, 7.8, -8.4), V(s * 3, 3, -10.8)
		k:group("arm" .. s, shoulder, "arm", { phase = diagonal(true, s), side = s }, function()
			k:tube({ shoulder, elbow }, 0.9, 0.75, crimson)
			k:tube({ elbow, wrist, V(s * 3, 0.8, -9.6), V(s * 3, 1.6, -8.2) }, 0.75, 0.3, crimson)
			for j = 1, 3 do
				local base = elbow:Lerp(wrist, j / 4)
				k:tri(base + V(0, 0.5, 0), base - V(0, 0.5, 0), base + V(s * 0.3, -0.2, 1.4), crimson, 0.25)
			end
		end)
	end)
end

local function chompBall(k, center: Vector3, scale: number, tag: string)
	local fur, furDark, white, mouth, blush, legA, legB =
		C(42, 42, 48), C(26, 26, 30), C(250, 250, 250), C(30, 8, 12), C(190, 110, 130), C(36, 36, 40), C(120, 66, 92)
	local r = 4 * scale
	k:ball(V(8, 7.6, 8) * scale, center, fur)
	-- shaggy fur
	for i, dir in ModelKit.sphereDirections(if scale < 1 then 40 else 64) do
		if dir.Y > -0.6 and not (dir.Z < -0.62 and dir.Y > -0.45 and dir.Y < 0.6) then
			local base = center + dir * r * 0.88
			local tuft = (dir + V(math.sin(i) * 0.3, 0.2, math.cos(i) * 0.3)).Unit
			k:cylinder(base, base + tuft * (1.2 + (i % 3) * 0.35) * scale, (0.42 - (i % 2) * 0.1) * scale, if i % 2 == 0 then fur else furDark)
		end
	end
	-- big white oval eyes
	mirror(function(s)
		local eyePos = center + V(s * 1.5, 1.2, -3.5) * scale
		k:ball(V(1.9, 2.5, 0.8) * scale, eyePos, white, nil, CFrame.Angles(0, 0, math.rad(-s * 12)))
		k:ball(V(0.75, 0.9, 0.4) * scale, eyePos + V(s * 0.25, -0.1, -0.35) * scale, C(10, 10, 12))
		k:ball(V(1.2, 0.5, 0.3) * scale, center + V(s * 2.7, -0.3, -3.1) * scale, blush)
	end)
	-- wide grin full of teeth
	k:ball(V(5.2, 1.5, 1.2) * scale, center + V(0, -0.9, -3.4) * scale, mouth)
	for i = -5, 5 do
		local x = i * 0.42 * scale
		local y = -0.9 * scale + (i * i) * 0.02 * scale
		k:cylinder(center + V(x, y + 0.6 * scale, -3.9 * scale), center + V(x, y - 0.1 * scale, -4.05 * scale), 0.13 * scale, white)
		k:cylinder(center + V(x, y - 0.6 * scale, -3.9 * scale), center + V(x, y + 0.1 * scale, -4.05 * scale), 0.13 * scale, white)
	end
	-- eight striped spider legs
	mirror(function(s)
		for j, z in { -2.4, -0.8, 0.8, 2.4 } do
			local hip = center + V(s * 3, -2.2, z) * scale
			local knee = center + V(s * 6.2, -0.6 + (j % 2) * 0.5, z * 1.5) * scale
			local foot = V(center.X + s * 8.2 * scale, 0.2, center.Z + z * 1.9 * scale)
			k:group(tag .. "leg" .. j .. s, hip, "leg", { phase = ((j + (if s > 0 then 1 else 0)) % 2) * 0.5, side = s, amp = 0.8 }, function()
				k:tube({ hip, knee }, 0.32 * scale, 0.26 * scale, legA)
				k:tube({ knee, foot }, 0.26 * scale, 0.14 * scale, legA, nil, { legB, legA })
			end)
		end
	end)
end

-- A pair of fuzzy black grinning spider-balls (the sheet shows two).
Designs.chomp_chomp = function(k)
	k:saddle(V(-2.2, 9.3, 0.4))
	chompBall(k, V(-2.2, 5.6, 0), 1, "a")
	chompBall(k, V(6.2, 3.9, 3.2), 0.68, "b")
end

-- Round white chick with a red heart comb, orange beak and pink cheeks.
Designs.popcorn = function(k)
	k:saddle(V(0, 9.5, 2))
	local white, red, orange, pink, black = C(248, 246, 238), C(170, 18, 30), C(244, 150, 40), C(250, 160, 170), C(25, 25, 25)
	k:ball(V(9, 9.4, 8.6), V(0, 5.2, 0), white)
	-- heart comb
	k:ball(V(2.6, 2.8, 1.6), V(-0.9, 10.6, -0.6), red)
	k:ball(V(2.8, 3, 1.6), V(1.1, 11, -0.2), red)
	k:tri(V(-2.1, 10.2, -0.4), V(2.4, 10.6, 0), V(0.2, 8.8, -0.6), red, 1.2)
	k:ball(V(0.5, 1.2, 0.3), V(-1.1, 11.3, -1.4), C(255, 120, 120))
	-- face
	k:ball(V(1.5, 1, 1.4), V(0, 6.9, -4.4), orange)
	k:ball(V(1, 0.5, 0.8), V(0, 6.3, -4.3), C(214, 110, 20))
	mirror(function(s)
		k:ball(V(0.55, 0.85, 0.3), V(s * 1.7, 7.4, -4), black)
		k:ball(V(0.2, 0.25, 0.1), V(s * 1.6, 7.7, -4.15), C(255, 255, 255))
		k:ball(V(1.3, 0.7, 0.3), V(s * 2.6, 6.2, -3.7), pink)
		-- little wings
		k:group("wing" .. s, V(s * 4.2, 6.2, -0.6), "wing", { side = s, amp = 0.8 }, function()
			k:ball(V(0.9, 2.2, 1.8), V(s * 4.4, 5.2, -0.6), white, nil, CFrame.Angles(0, 0, math.rad(s * 20)))
		end)
		k:group("foot" .. s, V(s * 1.6, 1.2, -1), "leg", { phase = if s < 0 then 0 else 0.5, side = s }, function()
			k:ball(V(1.4, 0.6, 2), V(s * 1.6, 0.3, -1.4), orange)
		end)
	end)
	-- tail feathers
	for i = -1, 1 do
		k:tri(V(i * 0.7, 6.4, 3.8), V(i * 0.7 + 0.6, 6.8, 3.8), V(i * 1, 8, 4.8), white, 0.4)
	end
end

-- Cyclops bat: one huge red eye, lolling tongue, membrane wings, spindly legs, spade tail. Hovers.
Designs.eye_bat = function(k)
	k:saddle(V(0, 9.9, 1.6))
	local body, bodyDark, membrane, bone, red, tongue = C(122, 52, 84), C(86, 34, 60), C(84, 40, 72), C(150, 70, 104), C(214, 26, 40), C(214, 70, 100)
	k:ball(V(3, 3.8, 3), V(0, 8.2, 0.2), body)
	k:ball(V(3.6, 3.4, 3.2), V(0, 10.6, -0.4), body)
	k:eye(V(0, 10.9, -1.6), 2.3, red, { slit = true })
	k:ball(V(0.4, 0.4, 0.2), V(0.5, 11.6, -2.85), C(255, 255, 255))
	k:ball(V(2.2, 1, 1), V(0, 9.1, -1.4), C(40, 10, 20))
	k:teeth(V(-0.8, 9.5, -1.9), V(0.8, 9.5, -1.9), 5, 0.5, V(0, -1, 0))
	k:tube(bez(V(0, 9, -1.8), V(0.3, 7.6, -2.8), V(-0.4, 6.4, -2.4), V(0.2, 5.4, -2), 5), 0.4, 0.22, tongue)
	mirror(function(s)
		k:tri(V(s * 0.6, 12, -0.4), V(s * 1.6, 11.6, 0), V(s * 1.6, 13.6, 0.2), body, 0.3)
		-- wing
		local shoulder, elbow, wrist = V(s * 1.4, 10, 0.4), V(s * 4.6, 12.2, 0.8), V(s * 7, 13.2, 1.2)
		k:group("wing" .. s, shoulder, "wing", { side = s, amp = 1.2 }, function()
			k:tube({ shoulder, elbow, wrist }, 0.4, 0.28, bone)
			local tips = { V(s * 12.4, 14.6, 1.8), V(s * 13.2, 10.4, 2), V(s * 11, 6.6, 1.6), V(s * 7.6, 5.4, 1.2) }
			for _, tip in tips do
				k:tube({ wrist, tip }, 0.22, 0.1, bone)
			end
			for i = 1, #tips - 1 do
				k:tri(wrist, tips[i], tips[i + 1], membrane, 0.15)
			end
			k:tri(elbow, wrist, tips[#tips], membrane, 0.15)
			k:tri(V(s * 1.2, 7.4, 0.5), elbow, tips[#tips], membrane, 0.15)
		end)
		-- spindly legs and little arms
		k:group("leg" .. s, V(s * 0.9, 6.8, 0.4), "sway", { phase = if s < 0 then 0 else 0.5, side = s }, function()
			k:tube({ V(s * 0.9, 6.8, 0.4), V(s * 1.4, 4.6, -0.6), V(s * 1.1, 2.4, 0.2) }, 0.32, 0.18, bodyDark)
			k:spike(V(s * 1.1, 2.4, 0.2), V(s * 1.2, 1.4, -0.6), 0.18, bodyDark)
		end)
		k:tube({ V(s * 1.2, 8, -0.8), V(s * 1.7, 6.6, -1.6) }, 0.25, 0.18, bodyDark)
	end)
	local tail = bez(V(0, 6.8, 1.2), V(0, 4.6, 2.6), V(1.4, 3, 4.8), V(0.4, 2.2, 6.4), 6)
	k:group("tail", tail[1], "tail", nil, function()
		k:tube(tail, 0.4, 0.14, bodyDark)
		local tip = tail[#tail]
		k:tri(tip + V(0, 0.6, 0.2), tip + V(-0.9, -0.4, 0.4), tip + V(0.2, -0.6, 1.6), bodyDark, 0.2)
		k:tri(tip + V(0, 0.6, 0.2), tip + V(0.9, -0.4, 0.4), tip + V(0.2, -0.6, 1.6), bodyDark, 0.2)
	end)
end

-- ───────────────────────────── KL 2 ─────────────────────────────

-- Shark with a sawfish snout, two dark horns, a huge round toothy maw and a dark tail. Hovers.
Designs.great_tusk = function(k)
	k:saddle(V(0, 8.5, -3.6))
	local skin, belly, dark, fin, maw, horn = C(150, 120, 110), C(196, 172, 156), C(96, 72, 66), C(110, 50, 40), C(64, 14, 20), C(54, 20, 22)
	k:ball(V(5, 5, 16), V(0, 6, 1), skin)
	k:ball(V(4.2, 2.8, 13), V(0, 4.8, 0.4), belly)
	k:group("tail", V(0, 6.2, 6), "tail", { amp = 1.4 }, function()
		k:ball(V(3, 3, 8), V(0, 6.3, 9.6), skin)
		k:tri(V(0, 7.6, 7), V(0, 7.6, 8.8), V(0, 9.2, 9.2), skin, 0.3)
		k:tri(V(0, 6.6, 12.2), V(0, 7.2, 14.2), V(0, 12.4, 17.6), fin, 0.4)
		k:tri(V(0, 6, 12.2), V(0, 5.4, 14.2), V(0, 1.4, 16.4), fin, 0.4)
	end)
	k:ball(V(4.4, 4.2, 6.4), V(0, 6.3, -6.8), skin)
	k:tube({ V(0, 6.5, -9.4), V(0, 6.3, -13), V(0, 6.1, -17) }, 0.95, 0.25, dark)
	-- gaping round maw with a ring of teeth
	k:ball(V(3.8, 3.8, 1.4), V(0, 4.4, -8.4), maw, nil, CFrame.Angles(math.rad(-20), 0, 0))
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local rim = V(math.cos(a) * 1.7, 4.4 + math.sin(a) * 1.7, -9)
		k:spike(rim, rim + V(-math.cos(a) * 0.8, -math.sin(a) * 0.8, -0.2), 0.2, C(236, 226, 206))
	end
	mirror(function(s)
		k:tube(bez(V(s * 1.1, 8, -7.4), V(s * 1.6, 11, -7.8), V(s * 1.8, 13, -6.4), V(s * 1.3, 14.6, -4.2), 6), 0.75, 0.14, horn)
		k:eye(V(s * 2.05, 7.1, -8.2), 0.7, C(20, 20, 20), { dir = V(s, 0, -0.4) })
		for g = 0, 3 do
			k:box(V(0.3, 2.2 - g * 0.15, 0.35), CFrame.new(s * 2.35, 6, -4.6 + g * 0.7), C(150, 40, 40))
		end
		k:group("fin" .. s, V(s * 2.2, 4.7, -0.5), "wing", { side = s, amp = 0.5 }, function()
			k:tri(V(s * 2.2, 4.6, -2), V(s * 2.2, 4.8, 1), V(s * 5.6, 2.2, 2.4), fin, 0.3)
		end)
		k:tri(V(s * 1.6, 4.4, 5), V(s * 1.6, 4.6, 6.6), V(s * 3.4, 2.6, 7.6), fin, 0.25)
	end)
	k:tri(V(0, 8.3, -1.4), V(0, 8.3, 3), V(0, 11.8, 2.8), skin, 0.4)
end

-- Jellyfish-sequoia: wide magenta bell on a stalk over a cascading tree of arrow-shaped tentacles.
Designs.jellqouia = function(k)
	k:saddle(V(0, 23.2, 0))
	local bell, bellDark, glow, arrowA, arrowB = C(226, 40, 164), C(170, 18, 120), C(255, 196, 236), C(240, 52, 176), C(255, 120, 210)
	k:ball(V(15, 6.4, 15), V(0, 20, 0), bell, { transparency = 0.12 })
	k:ball(V(8, 2.2, 8), V(0, 22.4, 0), glow, { transparency = 0.25 })
	k:ball(V(13.4, 2.4, 13.4), V(0, 17.6, 0), bellDark)
	k:tube({ V(0, 18, 0), V(0, 13.4, 0) }, 0.9, 0.7, C(220, 40, 90))
	-- tiers of downward arrows, widening towards the ground like a tree
	k:group("tentacles", V(0, 13.4, 0), "sway", { amp = 0.5 }, function()
	local tiers = 7
	for tier = 1, tiers do
		local t = (tier - 1) / (tiers - 1)
		local y = 13.6 - t * 12.4
		local radius = 0.8 + t * 8.6
		local count = 4 + tier * 2
		for i = 1, count do
			local a = (i + (tier % 2) * 0.5) / count * math.pi * 2
			local out = V(math.cos(a), 0, math.sin(a))
			local side = V(-math.sin(a), 0, math.cos(a))
			local center = out * radius + V(0, y, 0)
			local size = 0.7 + t * 0.9
			k:tri(center + side * size + V(0, size * 0.4, 0), center - side * size + V(0, size * 0.4, 0), center + out * 0.4 - V(0, size * 1.4, 0), if (i + tier) % 2 == 0 then arrowA else arrowB, 0.2)
			if tier < tiers and i % 2 == 0 then
				local nextCenter = out * (0.8 + (tier / (tiers - 1)) * 8.6) + V(0, 13.6 - (tier / (tiers - 1)) * 12.4, 0)
				k:cylinder(center, nextCenter, 0.14, bellDark)
			end
		end
	end
	end)
end

-- Lean spotted pack-hunter: dark grey with white spots, red-tipped spike crest and spiked tail club.
Designs.killerspotts = function(k)
	k:saddle(V(0, 7.9, 1))
	local hide, belly, spot, black, red, claw = C(74, 74, 80), C(188, 188, 194), C(214, 214, 220), C(28, 28, 30), C(196, 24, 34), C(170, 20, 30)
	k:ball(V(4.4, 4, 11.5), V(0, 5.8, 0), hide)
	k:ball(V(3.6, 2.4, 9.4), V(0, 4.7, 0), belly)
	k:tube({ V(0, 6.4, -4.6), V(0, 6.6, -7) }, 1.5, 1.2, hide)
	k:ball(V(2.6, 2.2, 4.6), V(0, 6.6, -8.8), hide)
	k:ball(V(2.2, 1.1, 3.6), V(0, 5.8, -9.4), belly)
	k:spike(V(0, 7.6, -9.4), V(0, 8.8, -11.4), 0.4, black, red)
	mirror(function(s)
		k:eye(V(s * 1, 7, -10.2), 0.5, C(230, 150, 40), { dir = V(s * 0.5, 0, -1), slit = true })
		for j, z in { -3.4, 3.6 } do
			local front = j == 1
			local top = V(s * 2, 5.2, z)
			local mid = if front then V(s * 3.2, 3, z - 0.6) else V(s * 3.2, 3.4, z + 1.2)
			local foot = V(s * 3, 0.3, z - 0.6)
			k:group("leg" .. j .. s, top, "leg", { phase = diagonal(front, s), side = s }, function()
				k:tube({ top, mid, foot }, 0.95, 0.55, hide)
				for c = -1, 1 do
					k:spike(foot, foot + V(c * 0.4, -0.1, -1), 0.16, claw)
				end
			end)
		end
	end)
	-- spots
	local rng = Random.new(16)
	for _ = 1, 40 do
		local a = rng:NextNumber(-1.4, 1.4)
		local z = rng:NextNumber(-5.2, 5.2)
		local p = V(math.sin(a) * 2.15, 5.8 + math.cos(a) * 1.95, z)
		k:ball(V(1, 1, 1) * rng:NextNumber(0.6, 1.4), p, spot)
	end
	-- spine crest
	for i = 0, 9 do
		local z = -8.6 + i * 1.5
		local y = if z < -4.5 then 7.6 else 7.8 - math.abs(z) * 0.08
		k:spike(V(0, y - 0.4, z), V(0, y + 1.6 - i * 0.05, z + 1.1), 0.32, black, red)
	end
	local tail = bez(V(0, 5.6, 5.4), V(0, 4.6, 9.6), V(0, 3.2, 13), V(0, 3.6, 16.4), 7)
	k:group("tail", tail[1], "tail", nil, function()
		k:tube(tail, 1.1, 0.35, hide)
		local tip = tail[#tail]
		for i, dir in { V(0, 1, 0.4), V(0.8, 0.6, 0.6), V(-0.8, 0.6, 0.6), V(0.5, -0.2, 1), V(-0.5, -0.2, 1) } do
			k:spike(tip, tip + dir.Unit * (1.8 - i * 0.1), 0.26, black, red)
		end
	end)
end

-- ───────────────────────────── KL 3 ─────────────────────────────

-- Colossal brown serpent: piled coils, a tall arch, raised cobra neck with an orange, veined throat.
Designs.wormhole = function(k)
	k:saddle(V(0, 12.7, -8))
	local brown, brownDark, throat, vein, eye = C(92, 52, 30), C(62, 34, 20), C(204, 106, 40), C(70, 200, 210), C(255, 110, 50)
	-- piled coils
	local coil = {}
	for i = 0, 22 do
		local a = i / 22 * math.pi * 3.6
		local r = 7 - i * 0.12
		coil[#coil + 1] = V(math.cos(a) * r, 1.9 + (i / 22) * 3.2, math.sin(a) * r + 1.5)
	end
	k:tube(coil, 2, 1.8, brown, nil, { brown, brownDark })
	-- tall arching loop behind
	k:tube(bez(coil[#coil], V(4, 16, 9), V(-4, 18, 9), V(-6, 2, 6), 9), 1.8, 1.4, brown, nil, { brownDark, brown })
	-- raised neck from the front of the coil
	local neck = bez(V(1.5, 3, -4.5), V(1.5, 7, -5.2), V(0, 9.2, -5.6), V(0, 11, -6.6), 6)
	k:group("neck", V(1.5, 3, -4.5), "sway", { amp = 0.8 }, function()
	k:tube(neck, 1.7, 1.3, brown)
	local belly = {}
	for i, p in neck do
		belly[i] = p + V(0, -0.2, -1.05)
	end
	k:tube(belly, 1, 0.8, throat)
	for i = 2, #belly - 1, 2 do
		k:cylinder(belly[i] + V(-0.6, 0, -0.75), belly[i + 1] + V(0.4, 0, -0.75), 0.08, vein, NEON)
	end
	-- cobra head
	k:ball(V(3.4, 2.2, 4.4), V(0, 11.6, -8.4), brown)
	k:ball(V(2.8, 1, 3.4), V(0, 10.9, -8.8), brownDark)
	mirror(function(s)
		k:ball(V(0.45, 0.45, 0.45), V(s * 1.15, 12.1, -9.6), eye, NEON)
	end)
	end)
end

-- Armoured mech-knight with a huge sword, rusted plates, a "16" mark and infecting vines with yellow bulbs.
Designs.obio_16 = function(k)
	k:saddle(V(4.6, 16, 0))
	local metal, metalDark, rust, visor, vine, bulb, green = C(140, 140, 148), C(70, 70, 78), C(196, 150, 96), C(40, 44, 40), C(96, 64, 36), C(246, 220, 40), C(60, 210, 70)
	mirror(function(s)
		k:group("leg" .. s, V(s * 2, 9.2, 0), "leg", { phase = if s < 0 then 0 else 0.5, side = s, amp = 0.7 }, function()
			k:box(V(2.6, 4, 2.8), CFrame.new(s * 2, 7.2, 0) * CFrame.Angles(math.rad(-6), 0, 0), metal, METAL)
			k:box(V(2.4, 1.4, 2.6), CFrame.new(s * 2.1, 4.9, -0.7), metalDark, METAL)
			k:box(V(2.8, 4.2, 3), CFrame.new(s * 2.1, 2.7, -0.1), metal, METAL)
			k:box(V(3, 1.2, 4.4), CFrame.new(s * 2.1, 0.6, -0.6), metalDark, METAL)
			k:box(V(0.2, 1.4, 1), CFrame.new(s * 3.45, 2.8, -0.4), rust)
		end)
		-- shoulders and arms
		k:ball(V(4, 3.2, 4), V(s * 4.6, 14.4, 0), metal, METAL)
		k:group("arm" .. s, V(s * 4.8, 13.6, 0), "arm", { phase = if s < 0 then 0.5 else 0, side = s, amp = 0.6 }, function()
			k:box(V(2.2, 3.6, 2.4), CFrame.new(s * 4.9, 11.6, -0.2), metalDark, METAL)
			k:box(V(2.6, 3.8, 2.8), CFrame.new(s * 5.1, 8.2, -0.8) * CFrame.Angles(math.rad(14), 0, 0), metal, METAL)
			k:ball(V(2.4, 2.2, 2.4), V(s * 5.2, 5.9, -1.4), metalDark, METAL)
		end)
	end)
	k:box(V(6.2, 1.5, 3.6), CFrame.new(0, 9.5, 0), metalDark, METAL)
	k:box(V(1.4, 1.4, 0.4), CFrame.new(0, 9.5, -1.85), rust)
	k:box(V(7.6, 5.2, 4.4), CFrame.new(0, 12.8, 0), metal, METAL)
	k:box(V(5, 2, 3.6), CFrame.new(0, 10.6, -0.1), metalDark, METAL)
	-- "IOI" chest marking and "16" on the right shoulder
	for i, x in { -1.1, 0, 1.1 } do
		k:box(if i == 2 then V(1, 1.4, 0.2) else V(0.25, 1.4, 0.2), CFrame.new(x, 13.2, -2.25), metalDark)
	end
	k:box(V(0.25, 1.2, 0.2), CFrame.new(-5.1, 15.2, -2.05), green, NEON)
	k:box(V(0.7, 1.2, 0.2), CFrame.new(-4.4, 15.2, -2.05), green, NEON)
	-- helmet
	k:ball(V(3, 3, 3.2), V(0, 16.7, -0.2), metal, METAL)
	k:box(V(2.4, 0.9, 0.4), CFrame.new(0, 16.8, -1.6), visor)
	k:box(V(1.6, 0.2, 0.2), CFrame.new(0, 16.9, -1.85), C(120, 200, 120), NEON)
	-- rust patches
	for _, p in { V(-2.4, 13.6, -2.25), V(2.2, 11.6, -2.25), V(-1.6, 7.4, -1.45), V(2.8, 2.2, -1.65) } do
		k:box(V(1.2, 0.9, 0.15), CFrame.new(p) * CFrame.Angles(0, 0, 0.4), rust)
	end
	-- sword in the right hand, pointing down and forward
	local hand = V(5.2, 5.9, -1.6)
	k:group("arm1", V(4.8, 13.6, 0), "arm", nil, function()
		k:box(V(0.5, 0.5, 2.6), CFrame.lookAt(hand, hand + V(0, -0.3, -1)), metalDark)
		k:box(V(3, 0.5, 0.6), CFrame.new(hand + V(0, -0.2, -1.5)), rust)
		k:blade({ hand + V(0, -0.3, -1.6), V(6.6, 3, -7), V(7.6, 0.6, -11.6) }, 1.5, 0.5, V(1, 0, 0), C(180, 184, 192), 0.3, METAL)
	end)
	-- infecting vines with yellow bulbs, mostly over the left shoulder and arm
	local vines = {
		{ V(-4.6, 15.6, 0), V(-3.4, 18, -0.6), V(-5.8, 19.6, 0.4), V(-4.2, 21.4, 0) },
		{ V(-2.6, 15, -1.4), V(-1.2, 17.4, -1.8), V(-2.6, 19.2, -1), V(-0.8, 20.6, -1.2) },
		{ V(-5, 13.6, -1.4), V(-7.6, 14.4, -1.6), V(-8.2, 12.2, -1.4), V(-9.6, 13, -1.2) },
		{ V(-5.2, 9.6, -1.6), V(-7.4, 8.6, -1.8), V(-6.8, 6.6, -1.6), V(-8.4, 5.4, -1.4) },
		{ V(2.8, 15.8, -0.4), V(3.6, 18, 0), V(2.2, 19.4, 0.2), V(3.8, 20.8, 0) },
		{ V(-2.2, 11.8, -2.3), V(-3.8, 10.4, -2.4), V(-2.4, 8.6, -2.2), V(-3.6, 7.4, -2) },
	}
	for _, v in vines do
		local pts = bez(v[1], v[2], v[3], v[4], 5)
		k:tube(pts, 0.24, 0.16, vine)
		k:ball(V(1.1, 1.1, 1.1), pts[#pts], bulb, NEON)
	end
end

-- ───────────────────────────── KL 4 ─────────────────────────────

-- Green chameleon-beast: crouched, horned frill, bulging eye, purple maw, spiral-curled tail.
Designs.leazorn = function(k)
	k:saddle(V(0, 7.5, 1.6))
	local green, light, horn, maw, claw, scar = C(58, 160, 104), C(110, 206, 150), C(170, 220, 180), C(96, 40, 96), C(220, 214, 180), C(170, 24, 30)
	local drop = 1.8 -- crouch: everything sits lower than a standing pose
	k:ball(V(5.2, 5, 9.6), V(0, 6.2 - drop, 0.4), green)
	k:ball(V(3.6, 1.2, 8), V(0, 8.5 - drop, 0.6), light)
	for i = 0, 6 do
		k:tri(V(-0.2, 8.6 - drop, -3.6 + i * 1.3), V(0.2, 8.6 - drop, -2.6 + i * 1.3), V(0, 9.8 - drop - i * 0.1, -2.8 + i * 1.3), light, 0.3)
	end
	k:ball(V(3.8, 3.4, 4.2), V(0, 7.8 - drop, -5.6), green)
	k:ball(V(3, 1.6, 3), V(0, 6.4 - drop, -6.6), maw)
	k:teeth(V(-1.2, 7.1 - drop, -7.7), V(1.2, 7.1 - drop, -7.7), 6, 0.6, V(0, -1, 0), claw)
	k:tube(bez(V(0, 6.3 - drop, -7.4), V(0.4, 5.4 - drop, -9.4), V(-0.6, 4.4 - drop, -9.8), V(0, 4.8 - drop, -8.6), 5), 0.32, 0.2, C(150, 60, 140))
	k:spike(V(0, 9.2 - drop, -5.2), V(0, 12.4 - drop, -3.6), 0.55, horn)
	mirror(function(s)
		k:eye(V(s * 1.7, 8.4 - drop, -6.4), 1.4, C(150, 230, 60), { dir = V(s, 0.1, -0.6) })
		k:spike(V(s * 1.5, 9 - drop, -5), V(s * 3.4, 11.2 - drop, -4), 0.45, horn)
		k:spike(V(s * 1.8, 8.4 - drop, -4.4), V(s * 3.8, 9.4 - drop, -2.2), 0.4, horn)
		-- sprawled chameleon legs: elbows/knees pushed out and up
		for j, z in { -2.6, 3.8 } do
			local top = V(s * 2.3, 4.2, z)
			local knee = V(s * 5.2, 5.4, z + (if j == 1 then -0.8 else 1))
			local foot = V(s * 5, 0.3, z + (if j == 1 then -2.2 else 1.8))
			k:group("leg" .. j .. s, top, "leg", { phase = diagonal(j == 1, s), side = s }, function()
				k:tube({ top, knee, foot }, 0.95, 0.55, green)
				for c = -1, 1 do
					k:spike(foot, foot + V(c * 0.6, -0.1, -0.9), 0.15, claw)
				end
			end)
		end
		k:box(V(0.15, 1.8, 0.4), CFrame.new(s * 2.55, 6 - drop, -0.6 + s) * CFrame.Angles(0.3, 0, 0), scar)
	end)
	-- tail curling into a spiral
	local tail = bez(V(0, 4.6, 5), V(0, 5.8, 8.4), V(0, 8.6, 10.6), V(0, 9.8, 13.2), 6)
	local center = V(0, 8.4, 14)
	for i = 1, 14 do
		local a = math.pi * 0.6 + i / 14 * math.pi * 3
		local r = 2.2 - i * 0.12
		table.insert(tail, center + V(0, math.sin(a) * r, math.cos(a) * r))
	end
	k:group("tail", tail[1], "tail", nil, function()
		k:tube(tail, 1.1, 0.28, green)
	end)
end

-- Dark armoured blade-dragon: white scythe blades on head, arms and back, glowing blue eye, bladed tail.
Designs.hornet = function(k)
	k:saddle(V(0, 9.1, 1.2))
	local navy, navyDark, blade, eye, red, mouth = C(26, 26, 54), C(14, 14, 30), C(226, 226, 234), C(80, 140, 255), C(200, 30, 60), C(150, 110, 120)
	k:ball(V(5.2, 4.6, 10.4), V(0, 6.2, 0.6), navy)
	k:ball(V(4, 1.4, 8), V(0, 8.4, 0.8), navyDark)
	k:tube({ V(0, 6.8, -4.4), V(0, 6, -6.4) }, 1.6, 1.3, navy)
	k:ball(V(3, 2.6, 4.4), V(0, 5.8, -7.8), navy)
	k:ball(V(2.4, 1.2, 3.2), V(0, 4.6, -8.2), mouth)
	k:teeth(V(-0.9, 5.2, -9.6), V(0.9, 5.2, -9.6), 5, 0.6, V(0, -1, 0))
	k:box(V(0.3, 0.3, 4), CFrame.new(0, 7.2, -7.4), red, NEON)
	mirror(function(s)
		k:ball(V(0.8, 0.6, 0.8), V(s * 1.2, 6.4, -9.2), eye, NEON)
		-- forelegs and hind legs
		k:group("legF" .. s, V(s * 2.4, 6, -2.6), "leg", { phase = diagonal(true, s), side = s, amp = 0.7 }, function()
			k:tube({ V(s * 2.4, 6, -2.6), V(s * 3.4, 3.6, -3.6), V(s * 3, 0.3, -4.4) }, 1, 0.6, navy)
			-- huge scythe blade from the elbow
			k:blade(bez(V(s * 3.4, 4, -3.6), V(s * 7, 4.6, -6), V(s * 9.4, 8.6, -4), V(s * 9, 12, 1), 7), 2.6, 0.3, V(0, 0.4, 1), blade, 0.35)
		end)
		k:group("legB" .. s, V(s * 2.2, 6, 4), "leg", { phase = diagonal(false, s), side = s }, function()
			k:tube({ V(s * 2.2, 6, 4), V(s * 3.4, 4, 5.4), V(s * 3, 0.3, 4.4) }, 1.1, 0.6, navy)
		end)
		-- shoulder scythes, held like wings
		k:group("wing" .. s, V(s * 2, 8, 0.6), "wing", { side = s, amp = 0.35 }, function()
			k:blade(bez(V(s * 2, 8, 0.6), V(s * 8, 12, 2), V(s * 11.4, 9, 9), V(s * 9, 4, 14), 8), 3, 0.3, V(0, 0.3, 1), blade, 0.35)
		end)
		k:blade(bez(V(s * 0.8, 7.2, -8), V(s * 2.6, 9.6, -10.4), V(s * 3, 12.6, -9.4), V(s * 2, 14.6, -6.6), 5), 1.8, 0.2, V(1, 0, 0), blade, 0.3)
	end)
	for i = 0, 6 do
		k:spike(V(0, 8.6, -3 + i * 1.3), V(0, 10.2 - i * 0.1, -2 + i * 1.3), 0.3, blade)
	end
	local tail = bez(V(0, 6, 5.6), V(0, 3.6, 10), V(0, 7, 15), V(0, 13, 14.6), 8)
	k:group("tail", tail[1], "tail", nil, function()
		k:tube(tail, 1.2, 0.4, navy)
		local tip = { tail[#tail - 2], tail[#tail - 1], tail[#tail], tail[#tail] + V(0, 2.4, -1.6) }
		k:blade(tip, 1.4, 0.3, V(1, 0, 0), blade, 0.3)
	end)
end

-- Winged wolf-sphinx sitting on a rock: skull mask, huge dark feathered wings with orange eye-spots.
Designs.night_angel = function(k)
	k:saddle(V(0, 11.2, 0.6))
	local fur, furDark, rock, mask, wing, feather, orange, tail = C(30, 30, 36), C(18, 18, 22), C(104, 104, 112), C(206, 206, 210), C(40, 38, 48), C(26, 24, 32), C(240, 120, 30), C(52, 36, 86)
	k:ball(V(8, 4.4, 7.4), V(0, 2.2, 0.6), rock, SLATE)
	k:ball(V(5, 3, 5), V(2.6, 1.6, 2.4), rock, SLATE)
	k:ball(V(4.2, 4, 4.8), V(0, 6, 1.2), fur)
	k:ball(V(3.4, 5.2, 3.4), V(0, 8.6, -0.4), fur)
	k:ball(V(2.2, 2.6, 0.6), V(0, 9, -2), furDark)
	k:ball(V(2.8, 2.6, 2.8), V(0, 11.8, -0.8), fur)
	k:ball(V(1.5, 1.2, 2), V(0, 11.3, -2.3), fur)
	k:ball(V(2.3, 2, 0.6), V(0, 11.7, -2.1), mask)
	mirror(function(s)
		k:ball(V(0.6, 0.55, 0.3), V(s * 0.55, 11.9, -2.4), C(10, 10, 10))
		k:tri(V(s * 0.5, 12.8, -0.8), V(s * 1.4, 12.6, -0.4), V(s * 1.2, 14.6, -0.4), fur, 0.3)
		k:tube({ V(s * 0.9, 7.4, -1.4), V(s * 1, 4.6, -1.8) }, 0.6, 0.45, fur)
		k:ball(V(1, 0.6, 1.4), V(s * 1, 4.4, -2.2), furDark)
		-- wing: arm bone, feathers fanning outward, membrane behind, orange eye-spot
		local shoulder, elbow, wrist = V(s * 1.4, 10, 0.6), V(s * 6, 13.4, 1.2), V(s * 12, 14.6, 1.6)
		k:group("wing" .. s, shoulder, "wing", { side = s, amp = 0.6 }, function()
		k:tube({ shoulder, elbow, wrist }, 0.5, 0.3, furDark)
		k:tri(shoulder, elbow, V(s * 5, 7, 1.2), wing, 0.2)
		k:tri(elbow, wrist, V(s * 10, 8, 1.6), wing, 0.2)
		k:tri(elbow, V(s * 10, 8, 1.6), V(s * 5, 7, 1.2), wing, 0.2)
		k:tri(shoulder, V(s * 5, 7, 1.2), V(s * 2.4, 6.4, 1), wing, 0.2)
		for f = 0, 11 do
			local root = shoulder:Lerp(elbow, math.min(1, f / 5)):Lerp(wrist, math.max(0, (f - 5) / 6)) + V(0, -0.3, 0.1)
			local length = 5.5 + f * 0.35
			local tip = root + (V(s * (0.25 + f * 0.09), -1, 0)).Unit * length
			k:blade({ root, root:Lerp(tip, 0.5), tip }, 1.5, 0.6, V(0, 0, 1), if f % 2 == 0 then feather else wing, 0.15)
		end
		k:ball(V(3, 3, 0.3), V(s * 7.4, 11, 1.05), orange, NEON)
		k:ball(V(2, 2, 0.4), V(s * 7.4, 11, 1.0), C(16, 16, 18))
		for d = 1, 3 do
			k:ball(V(0.7, 0.7, 0.3), V(s * (9.8 + d * 0.8), 13.2 - d * 0.6, 1.2), orange, NEON)
		end
		end)
	end)
	local tailPts = bez(V(0, 5, 3.2), V(2.6, 3.2, 5.8), V(5.2, 5, 3.6), V(4.6, 3.6, -0.6), 7)
	k:group("tail", tailPts[1], "tail", nil, function()
		k:tube(tailPts, 1, 0.75, tail, nil, { tail, furDark })
	end)
end

-- Boulder caterpillar: grey rock segments, big ringed eyes, crystals on the back, a forest on its flanks.
Designs.cataboulder = function(k)
	k:saddle(V(0, 9.8, -3.3))
	local rock, rockDark, ringGreen, ringPink, toothC, trunk, pine, pineDark, leg =
		C(140, 150, 168), C(96, 104, 120), C(70, 200, 120), C(226, 70, 210), C(214, 190, 150), C(120, 80, 50), C(40, 140, 50), C(26, 96, 36), C(206, 150, 110)
	local segments = { { -6, 8, 8.4 }, { -0.6, 9, 9 }, { 4.8, 9.4, 9.2 }, { 10, 8.8, 8.6 }, { 14.6, 7.4, 7.4 } }
	for i, seg in segments do
		k:ball(V(seg[3], seg[2], 6.6), V(0, seg[2] / 2 + 1.4, seg[1]), if i % 2 == 0 then rockDark else rock, SLATE)
	end
	-- head
	k:group("head", V(0, 5.6, -8), "head", { amp = 1.5 }, function()
		k:ball(V(9, 8.2, 7.4), V(0, 5.6, -11), rock, SLATE)
		k:ball(V(5.6, 1.8, 1.4), V(0, 3.8, -14.4), C(40, 20, 24))
		k:teeth(V(-2.2, 4.6, -14.8), V(2.2, 4.6, -14.8), 7, 0.9, V(0, -1, -0.1), toothC)
		mirror(function(s)
			local eye = V(s * 2.3, 7.2, -14.4)
			k:ball(V(2.6, 2.6, 0.6), eye, ringGreen)
			k:ball(V(2, 2, 0.7), eye + V(0, 0, -0.08), ringPink)
			k:ball(V(1, 1, 0.8), eye + V(0, 0, -0.15), C(12, 12, 14))
		end)
	end)
	mirror(function(s)
		-- forest growing on the flanks
		for t = 0, 5 do
			local z = -7 + t * 4
			local base = V(s * 4.4, 1.6, z)
			k:cylinder(base, base + V(s * 0.3, 1.6, 0), 0.3, trunk)
			for layer = 0, 2 do
				local y = 2.4 + layer * 1.2
				k:ball(V(2.6 - layer * 0.7, 1.4, 2.6 - layer * 0.7), base + V(s * 0.4, y - 1.6, 0), if layer % 2 == 0 then pine else pineDark)
			end
			k:group("leg" .. t .. s, V(s * 2.6, 1.6, z + 1.6), "leg", { phase = t / 6 + (if s > 0 then 0.5 else 0), side = s, amp = 1.2 }, function()
				k:cylinder(V(s * 2.6, 1.2, z + 1.6), V(s * 2.8, 0, z + 1.4), 0.5, leg)
			end)
		end
	end)
	-- crystal clusters along the back
	local crystalColors = { C(70, 210, 240), C(230, 40, 40), C(244, 140, 40), C(70, 210, 240), C(240, 60, 220) }
	for i, seg in segments do
		local top = V(0, seg[2] + 1.2, seg[1])
		for c = -1, 1 do
			local tilt = CFrame.Angles(math.rad(c * 18), 0, math.rad(c * 22))
			k:box(V(0.9, 3.4 - math.abs(c) * 0.8, 0.9), CFrame.new(top + V(c * 1.1, 1.2, c * 0.5)) * tilt, crystalColors[i], GLASS)
		end
	end
end

-- Bright green fish-titan: stooped, shark-like head with open magenta maw, yellow antennae, webbed fins.
Designs.korand = function(k)
	k:saddle(V(0, 14.2, 1.4))
	local green, pale, fin, maw, yellow = C(64, 228, 96), C(200, 250, 210), C(160, 236, 186), C(206, 40, 120), C(250, 236, 60)
	mirror(function(s)
		k:group("leg" .. s, V(s * 2.4, 7, 1), "leg", { phase = if s < 0 then 0 else 0.5, side = s, amp = 0.7 }, function()
			k:tube({ V(s * 2.4, 7, 1), V(s * 2.9, 3.6, -0.6), V(s * 2.6, 1, 0.6) }, 1.7, 1.2, green)
			k:tri(V(s * 1.6, 0.2, 0.4), V(s * 3.6, 0.2, 0.4), V(s * 2.6, 0.2, -3.4), pale, 0.6)
			for t = -1, 1 do
				k:spike(V(s * 2.6, 0.4, -1.2), V(s * (2.6 + t * 1.2), 0.2, -3.6), 0.2, pale)
			end
		end)
		-- arms with elbow fins
		k:group("arm" .. s, V(s * 3.6, 11.8, -1), "arm", { phase = if s < 0 then 0.5 else 0, side = s }, function()
			k:tube({ V(s * 3.6, 11.8, -1), V(s * 4.8, 9, -2.6), V(s * 4.4, 7, -4) }, 1.1, 0.8, green)
			for c = -1, 1 do
				k:spike(V(s * 4.4, 7, -4), V(s * (4.4 + c * 0.5), 6, -5.2), 0.22, pale)
			end
			k:tri(V(s * 4.8, 9, -2.6), V(s * 5.2, 11, -1.4), V(s * 7.4, 9.4, 0.4), fin, 0.25)
		end)
		k:eye(V(s * 2.3, 14.8, -5.4), 1, yellow, { dir = V(s, 0, -0.5) })
		k:tube(bez(V(s * 0.8, 16.2, -3.6), V(s * 1, 18.2, -4.6), V(s * 1.6, 18.6, -6.6), V(s * 1.8, 17.8, -8), 5), 0.22, 0.16, C(60, 180, 70))
		k:ball(V(0.8, 0.8, 1.6), V(s * 1.8, 17.8, -8.2), yellow, NEON)
	end)
	k:ball(V(6.6, 7.6, 5.6), V(0, 10.2, 0.2), green, nil, CFrame.Angles(math.rad(18), 0, 0))
	k:ball(V(4.6, 6, 1.4), V(0, 9.6, -2.4), pale, nil, CFrame.Angles(math.rad(18), 0, 0))
	-- head and open maw
	k:ball(V(5.4, 4.4, 6.6), V(0, 14.4, -3.8), green)
	k:ball(V(4.2, 1.8, 5), V(0, 11.8, -4.6), pale)
	k:ball(V(3.6, 2.2, 3.2), V(0, 12.8, -5.8), maw)
	k:teeth(V(-1.6, 13.6, -7), V(1.6, 13.6, -7), 6, 0.6, V(0, -1, 0))
	-- back fins and fish tail
	for i, z in { -0.4, 1.6, 3.4 } do
		k:tri(V(0, 13.4 - i * 1.6, z), V(0, 11.8 - i * 1.6, z + 1.6), V(0, 15.6 - i * 1.4, z + 3.6), fin, 0.3)
	end
	local tail = { V(0, 7.4, 2.8), V(0, 5.4, 6), V(0, 3.4, 8.6) }
	k:group("tail", tail[1], "tail", nil, function()
		k:tube(tail, 1.8, 0.8, green)
		k:tri(V(0, 3.6, 8.4), V(0, 7.6, 12.4), V(0, 4.2, 12.6), fin, 0.35)
		k:tri(V(0, 3.2, 8.4), V(0, 0.6, 12.2), V(0, 4.2, 12.6), fin, 0.35)
	end)
end

-- ───────────────────────────── KL 5 ─────────────────────────────

-- Hulking turtle-dragon on its knuckles: spiked blue shell, glowing green patches, boar tusks, long tail.
Designs.cagn = function(k)
	k:saddle(V(0, 13.1, 1.2))
	local body, bodyDark, shell, shellLight, glow, tusk = C(38, 74, 92), C(24, 44, 56), C(56, 124, 186), C(96, 170, 222), C(90, 230, 170), C(232, 226, 204)
	k:ball(V(7.2, 6.6, 10.4), V(0, 8, 0.6), body)
	k:ball(V(8.4, 5.4, 10.6), V(0, 10.6, 1.4), shell)
	for i, dir in ModelKit.sphereDirections(26) do
		if dir.Y > 0.05 then
			local base = V(0, 10.6, 1.4) + V(dir.X * 4, dir.Y * 2.6, dir.Z * 5.2)
			k:tri(base + V(-0.7, 0, 0), base + V(0.7, 0, 0), base + (dir + V(0, 0.4, 0.3)).Unit * 2.6, if i % 2 == 0 then shell else shellLight, 0.45)
		end
	end
	-- head
	k:tube({ V(0, 8.4, -4.4), V(0, 8, -6) }, 1.8, 1.5, body)
	k:ball(V(3.8, 3, 4.6), V(0, 7.8, -7.2), body)
	k:ball(V(3, 1.6, 2.6), V(0, 7, -9), bodyDark)
	mirror(function(s)
		k:ball(V(0.5, 0.45, 0.45), V(s * 1.4, 8.7, -8.6), C(250, 210, 40), NEON)
		k:tube(bez(V(s * 1.2, 7, -9.2), V(s * 1.8, 7, -10), V(s * 2, 8, -10.4), V(s * 1.7, 8.8, -10.2), 4), 0.35, 0.12, tusk)
		-- glowing patches on shoulders and hips
		for _, c in { V(s * 3.5, 8.8, -2.6), V(s * 3.5, 7.8, 4.2) } do
			for g = 0, 2 do
				k:ball(V(0.3, 1.2 - g * 0.2, 1.2 - g * 0.2), c + V(s * 0.1, g * 0.6 - 0.6, (g - 1) * 0.8), glow, NEON)
			end
		end
		-- knuckle-walking forelimbs and heavy hind legs
		k:group("legF" .. s, V(s * 3.2, 9, -3), "leg", { phase = diagonal(true, s), side = s, amp = 0.7 }, function()
			k:tube({ V(s * 3.2, 9, -3), V(s * 4.4, 5.4, -4.2), V(s * 3.8, 0.6, -5) }, 1.6, 1.2, body)
			for c = -1, 1 do
				k:spike(V(s * 3.8, 0.6, -5), V(s * (3.8 + c * 0.6), 0.1, -6.4), 0.25, bodyDark)
			end
		end)
		k:group("legB" .. s, V(s * 3, 7.4, 4), "leg", { phase = diagonal(false, s), side = s, amp = 0.7 }, function()
			k:tube({ V(s * 3, 7.4, 4), V(s * 3.8, 4.2, 3), V(s * 3.4, 0.6, 4.6) }, 1.7, 1.2, body)
			for c = -1, 1 do
				k:spike(V(s * 3.4, 0.6, 4.6), V(s * (3.4 + c * 0.6), 0.1, 3.2), 0.25, bodyDark)
			end
		end)
	end)
	local tail = bez(V(0, 7, 5.6), V(0, 3.6, 10), V(0, 1.6, 15), V(0, 0.8, 19.6), 8)
	k:group("tail", tail[1], "tail", nil, function()
		k:tube(tail, 1.6, 0.35, body, nil, { body, bodyDark })
		for i = 2, #tail - 1 do
			local p = tail[i]
			k:tri(p + V(0, 0.6, -0.5), p + V(0, 0.6, 0.5), p + V(0, 2 - i * 0.15, 0.9), shellLight, 0.3)
		end
	end)
end

-- Teal golem with a ram skull: pink muscle, grey fur collar, huge arms reaching the ground.
Designs.doubt = function(k)
	k:saddle(V(4.4, 17.6, 0.6))
	local teal, tealDark, pink, fur, skull, horn = C(40, 150, 144), C(26, 108, 104), C(236, 120, 128), C(168, 168, 174), C(232, 230, 222), C(186, 180, 168)
	mirror(function(s)
		k:group("leg" .. s, V(s * 2.8, 8.4, 0.4), "leg", { phase = if s < 0 then 0 else 0.5, side = s, amp = 0.6 }, function()
			k:tube({ V(s * 2.8, 8, 0.4), V(s * 3.2, 4, -0.2), V(s * 3, 1.2, 0) }, 2.3, 2, teal)
			k:ball(V(4, 1.6, 4.8), V(s * 3, 0.8, -0.6), tealDark)
			for j = 0, 2 do
				k:tri(V(s * 4.6, 6 - j * 1.8, -1), V(s * 4.6, 6 - j * 1.8, 1), V(s * 6, 7.4 - j * 1.8, 0.4), tealDark, 0.4)
			end
		end)
		-- long arms: pink upper arm, armoured forearm, huge fist near the ground
		k:group("arm" .. s, V(s * 5, 15, 0), "arm", { phase = if s < 0 then 0.5 else 0, side = s, amp = 0.7 }, function()
			k:tube({ V(s * 5, 15, 0), V(s * 6.6, 10.4, -0.8) }, 2, 1.8, pink)
			k:tube({ V(s * 6.6, 10.4, -0.8), V(s * 6.6, 4.4, -1.4) }, 2.2, 2.2, teal)
			k:ball(V(3.4, 3.4, 3.4), V(s * 6.6, 2.6, -1.6), tealDark)
			for j = 0, 3 do
				local p = V(s * 8.4, 9.6 - j * 1.4, -0.8)
				k:tri(p + V(0, 0, -0.8), p + V(0, 0, 0.8), p + V(s * 1.8, 1.4, 0.2), teal, 0.4)
			end
		end)
		-- muscles and fur
		k:ball(V(3.2, 3.6, 1.2), V(s * 1.8, 13.4, -2.6), pink)
		k:ball(V(3.4, 2.4, 3.4), V(s * 4.4, 16.4, 0.6), fur)
		k:tri(V(s * 3, 17.6, 0), V(s * 5, 17.4, 1), V(s * 5.6, 19.4, 1.4), fur, 0.5)
		-- ram horns spiralling beside the skull
		local spiral = {}
		for i = 0, 14 do
			local a = math.pi * 0.55 + i / 14 * math.pi * 1.8
			local r = 1.9 - i * 0.07
			spiral[#spiral + 1] = V(s * (1.9 + i * 0.05), 18.6 + math.sin(a) * r, -0.6 + math.cos(a) * r)
		end
		k:tube(spiral, 0.75, 0.25, horn)
		k:ball(V(0.7, 0.6, 0.3), V(s * 0.65, 18.6, -2.5), C(30, 20, 20))
		k:ball(V(0.3, 0.3, 0.2), V(s * 0.65, 18.6, -2.62), C(250, 200, 40), NEON)
	end)
	k:ball(V(8.4, 8.4, 5.6), V(0, 12, 0), teal)
	for row = 0, 1 do
		mirror(function(s)
			k:box(V(1.6, 1.4, 0.6), CFrame.new(s * 0.9, 10.6 - row * 1.6, -2.6), tealDark)
		end)
	end
	k:ball(V(6, 2.6, 4.4), V(0, 16.4, 0.4), fur)
	-- ram skull
	k:ball(V(2.8, 2.8, 3), V(0, 18.6, -1), skull)
	k:ball(V(1.7, 1.8, 2.4), V(0, 17.6, -2.4), skull)
	k:box(V(0.25, 1.4, 0.2), CFrame.new(0, 17.6, -3.62), C(170, 30, 40))
end

-- Starry crystal titan: dark body flecked with cyan stars, golden beetle horns, giant crab-claw arms.
Designs.yumir = function(k)
	k:saddle(V(4.2, 17.1, 0))
	local dark, darker, chest, gold, cyan = C(40, 50, 62), C(26, 32, 42), C(214, 196, 150), C(214, 176, 90), C(80, 226, 236)
	mirror(function(s)
		k:group("leg" .. s, V(s * 2, 8.4, 0.4), "leg", { phase = if s < 0 then 0 else 0.5, side = s, amp = 0.6 }, function()
			k:tube({ V(s * 2, 8.4, 0.4), V(s * 2.4, 4.2, -0.4), V(s * 2.2, 0.8, 0) }, 1.6, 1.2, dark)
			for c = -1, 1 do
				k:spike(V(s * 2.2, 0.8, 0), V(s * (2.2 + c * 0.7), 0.1, -1.6), 0.3, darker)
			end
		end)
		k:ball(V(3.6, 3, 3.6), V(s * 4.2, 15.6, 0), dark)
		for g = 0, 2 do
			k:spike(V(s * 4.2, 16.6, -0.8 + g * 0.8), V(s * (5.4 + g * 0.2), 18.4 - g * 0.3, -0.6 + g * 0.9), 0.35, gold)
		end
		-- crab-claw arms
		k:group("arm" .. s, V(s * 4.6, 14.6, 0), "arm", { phase = if s < 0 then 0.5 else 0, side = s, amp = 0.5 }, function()
			k:tube({ V(s * 4.6, 14.6, 0), V(s * 6.4, 11, -0.6) }, 1.3, 1.2, dark)
			k:ball(V(4.6, 10.4, 3.2), V(s * 7.4, 6.8, -0.8), dark, nil, CFrame.Angles(0, 0, math.rad(s * 6)))
			k:ball(V(2.4, 7, 2.4), V(s * 5.4, 5.6, -1.6), darker, nil, CFrame.Angles(0, 0, math.rad(-s * 10)))
			-- glowing glyph on each claw
			local g = V(s * 9.65, 7.4, -0.8)
			k:box(V(0.15, 0.25, 2.4), CFrame.new(g), cyan, NEON)
			k:box(V(0.15, 1.8, 0.25), CFrame.new(g + V(0, 0, -0.6)) * CFrame.Angles(0.5, 0, 0), cyan, NEON)
			k:box(V(0.15, 1.8, 0.25), CFrame.new(g + V(0, 0, 0.6)) * CFrame.Angles(-0.5, 0, 0), cyan, NEON)
		end)
		-- golden beetle horns
		k:tube(bez(V(s * 0.9, 19.2, -0.4), V(s * 2.8, 21, -0.4), V(s * 2.6, 23.4, -0.2), V(s * 1.2, 24.4, -0.2), 6), 0.7, 0.18, gold)
		k:ball(V(0.4, 0.3, 0.3), V(s * 0.55, 18.3, -1.5), cyan, NEON)
	end)
	k:ball(V(3.4, 3, 3), V(0, 9.4, 0), darker)
	k:ball(V(6.4, 7, 4.4), V(0, 13.2, 0), dark)
	k:ball(V(4.2, 5, 1.2), V(0, 13.6, -1.8), chest)
	k:ball(V(1.4, 1.4, 0.6), V(0, 14.6, -2.5), gold, NEON)
	k:ball(V(0.7, 0.9, 0.5), V(0, 11.4, -2.2), cyan, NEON)
	k:ball(V(2.4, 2.6, 2.6), V(0, 18, -0.4), dark)
	-- starry flecks
	local rng = Random.new(55)
	local surfaces = { -- ellipsoid centre and radii; flecks sit on their front-facing surface
		{ V(-7.4, 6.8, -0.8), V(2.3, 5.2, 1.6) },
		{ V(7.4, 6.8, -0.8), V(2.3, 5.2, 1.6) },
		{ V(0, 13.2, 0), V(3.2, 3.5, 2.2) },
		{ V(-4.2, 15.6, 0), V(1.8, 1.5, 1.8) },
		{ V(4.2, 15.6, 0), V(1.8, 1.5, 1.8) },
	}
	for i = 1, 40 do
		local index = (i % #surfaces) + 1
		local surf = surfaces[index]
		local a, b = rng:NextNumber(-1.3, 1.3), rng:NextNumber(-1.2, 1.2)
		local dir = V(math.sin(a) * math.cos(b), math.sin(b), -math.cos(a) * math.cos(b))
		local function fleck()
			k:ball(Vector3.one * 0.24, surf[1] + dir * surf[2] * 1.02, C(190, 240, 255), NEON)
		end
		if index <= 2 then
			local s = if index == 1 then -1 else 1
			k:group("arm" .. s, V(s * 4.6, 14.6, 0), "arm", nil, fleck)
		else
			fleck()
		end
	end
end

-- Golden eastern-western dragon: red-scaled coiling body, orange bat wings, flame mane and tail tuft.
Designs.emperor = function(k)
	k:saddle(V(0, 11.1, -0.8))
	local gold, goldDark, red, redDark, wingC, bone, claw, eye = C(244, 196, 40), C(196, 146, 30), C(204, 30, 30), C(120, 14, 20), C(242, 152, 40), C(200, 110, 20), C(240, 240, 240), C(70, 220, 240)
	local body = bez(V(0, 9, -2), V(3, 4, 1), V(-4, 3, 5), V(-1, 1.8, 8), 7)
	for _, p in bez(V(-1, 1.8, 8), V(3, 1.2, 11), V(4, 5, 12.6), V(1, 6.4, 12.6), 6) do
		table.insert(body, p)
	end
	k:tube(body, 2, 0.6, red, nil, { red, redDark })
	for i = 1, #body - 1, 2 do
		k:ball(V(1.2, 1, 1.6), body[i] + V(0, -0.9, -0.6), gold)
	end
	local tip = body[#body]
	for i, dir in { V(0, 1, 0.2), V(0.7, 0.8, 0.4), V(-0.7, 0.8, 0.4), V(0.3, 0.4, 1), V(-0.3, 0.4, 1) } do
		k:spike(tip, tip + dir.Unit * (2.4 - i * 0.15), 0.32, gold)
	end
	-- neck and head
	k:tube(bez(V(0, 9, -2), V(0, 12, -2.6), V(0, 13.2, -4.6), V(0, 13.6, -6), 4), 1.6, 1.3, gold)
	k:ball(V(3, 2.6, 4), V(0, 14, -7.4), gold)
	k:ball(V(2.2, 1.4, 2.8), V(0, 13.6, -9.4), gold)
	k:ball(V(1.8, 0.9, 2.6), V(0, 12.5, -9), red)
	k:teeth(V(-0.8, 13, -10.4), V(0.8, 13, -10.4), 5, 0.5, V(0, -1, 0))
	mirror(function(s)
		k:ball(V(0.55, 0.45, 0.5), V(s * 1.1, 14.5, -8.6), eye, NEON)
		k:spike(V(s * 0.8, 15, -6.6), V(s * 1.8, 16.6, -3.6), 0.35, goldDark)
		k:tube(bez(V(s * 0.8, 13.2, -10.4), V(s * 2.4, 12.6, -11.6), V(s * 3.6, 13.4, -10.8), V(s * 4.6, 12.6, -11.8), 5), 0.12, 0.06, gold)
		for m = 0, 2 do
			k:spike(V(s * 1.2, 14.2 - m * 0.8, -6.4 + m * 0.6), V(s * (2.8 + m * 0.3), 15.4 - m * 1.2, -4.6 + m * 0.8), 0.3, gold)
		end
		-- clawed limbs
		k:group("arm" .. s, V(s * 1.6, 8.2, -2.6), "arm", { phase = diagonal(true, s), side = s }, function()
			k:tube({ V(s * 1.6, 8.2, -2.6), V(s * 2.8, 6, -4), V(s * 2.4, 4.4, -5) }, 0.7, 0.45, gold)
			for c = -1, 1 do
				k:spike(V(s * 2.4, 4.4, -5), V(s * (2.4 + c * 0.4), 3.6, -5.8), 0.15, claw)
			end
		end)
		k:group("leg" .. s, V(s * 1.8, 2.6, 6), "leg", { phase = diagonal(false, s), side = s }, function()
			k:tube({ V(s * 1.8, 2.6, 6), V(s * 2.8, 1.6, 5), V(s * 2.6, 0.3, 6.2) }, 0.8, 0.5, gold)
			for c = -1, 1 do
				k:spike(V(s * 2.6, 0.3, 6.2), V(s * (2.6 + c * 0.5), 0.1, 5), 0.18, claw)
			end
		end)
		-- bat wings
		local shoulder, elbow, wrist = V(s * 1.4, 10.6, 0), V(s * 5, 14.2, 1), V(s * 9, 17.2, 1.5)
		k:group("wing" .. s, shoulder, "wing", { side = s, amp = 0.8 }, function()
		k:tube({ shoulder, elbow, wrist }, 0.5, 0.32, bone)
		local tips = { V(s * 16, 16.4, 2), V(s * 15.4, 11.4, 2.4), V(s * 12.4, 7.6, 2), V(s * 8, 6.6, 1.4) }
		for _, t in tips do
			k:tube({ wrist, t }, 0.26, 0.1, bone)
		end
		for i = 1, #tips - 1 do
			k:tri(wrist, tips[i], tips[i + 1], wingC, 0.15)
		end
		k:tri(elbow, wrist, tips[#tips], wingC, 0.15)
		k:tri(shoulder, elbow, tips[#tips], wingC, 0.15)
		end)
	end)
end

return Designs
