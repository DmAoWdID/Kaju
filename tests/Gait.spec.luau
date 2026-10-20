--!strict
local T = require("./TestLib")
local KaijuGait = require("../src/shared/Visual/KaijuGait")

local describe, it, eq, truthy, near = T.describe, T.it, T.eq, T.truthy, T.near

describe("KaijuGait", function()
	it("legs and arms don't swing when the kaiju stands still", function()
		for _, cycle in { 0, 0.25, 0.6 } do
			local x = KaijuGait.angles("leg", 0, 1, 1, cycle, 0, 3)
			eq(x, 0, "leg at cycle " .. cycle)
		end
		local armX = KaijuGait.angles("arm", 0, 1, 1, 0.25, 0, 3)
		truthy(math.abs(armX) <= 0.04 + 1e-9, "arm only idles slightly")
	end)

	it("opposite-phase legs swing in opposite directions while walking", function()
		local a = KaijuGait.angles("leg", 0, -1, 1, 0.25, 1, 0)
		local b = KaijuGait.angles("leg", 0.5, 1, 1, 0.25, 1, 0)
		near(a, KaijuGait.AMPLITUDE.leg, 1e-6, "front leg forward")
		near(b, -KaijuGait.AMPLITUDE.leg, 1e-6, "other leg back")
	end)

	it("wings flap mirrored left/right", function()
		local _, _, left = KaijuGait.angles("wing", 0, -1, 1, 0, 0.5, 0.3)
		local _, _, right = KaijuGait.angles("wing", 0, 1, 1, 0, 0.5, 0.3)
		near(left, -right, 1e-9)
	end)

	it("every kind stays within its amplitude", function()
		for kind, amplitude in KaijuGait.AMPLITUDE do
			for i = 0, 40 do
				local x, y, z = KaijuGait.angles(kind, i / 7, if i % 2 == 0 then 1 else -1, 1, i / 13, (i % 5) / 4, i * 0.37)
				for _, v in { x, y, z } do
					truthy(v == v, kind .. " produced NaN")
					truthy(math.abs(v) <= amplitude * 1.3 + 0.05, ("%s angle %.3f exceeds amplitude"):format(kind, v))
				end
			end
		end
	end)

	it("unknown kinds stay still", function()
		local x, y, z = KaijuGait.angles("mystery", 0, 1, 1, 0.3, 1, 2)
		eq(x + y + z, 0)
	end)
end)

return nil
