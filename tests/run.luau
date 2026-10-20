--!strict
-- Run from the repository root:  luau tests/run.luau
local TestLib = require("./TestLib")

local specs = {
	"./KaijuData.spec",
	"./Progression.spec",
	"./Combat.spec",
	"./PlayerData.spec",
}

for _, path in specs do
	(require :: any)(path)
end

local r = TestLib.results()
for _, failure in r.failures do
	print("FAIL " .. failure)
end
print(("\n%d passed, %d failed"):format(r.passed, r.failed))
if r.failed > 0 then
	error("test failures", 0)
end
