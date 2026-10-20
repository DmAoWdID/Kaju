--!strict
-- Minimal test helpers for running pure-Luau specs with the standalone `luau` CLI.

local TestLib = {}

local results = { passed = 0, failed = 0, failures = {} :: { string } }
local currentSuite = ""

function TestLib.describe(name: string, fn: () -> ())
	local previous = currentSuite
	currentSuite = if previous == "" then name else previous .. " > " .. name
	fn()
	currentSuite = previous
end

function TestLib.it(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		results.passed += 1
	else
		results.failed += 1
		table.insert(results.failures, ("%s > %s\n    %s"):format(currentSuite, name, tostring(err)))
	end
end

local function fmt(v: any): string
	return if type(v) == "string" then ("%q"):format(v) else tostring(v)
end

function TestLib.eq(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(("%sexpected %s, got %s"):format(if label then label .. ": " else "", fmt(expected), fmt(actual)), 2)
	end
end

function TestLib.truthy(value: any, label: string?)
	if not value then
		error((label or "expected truthy value") .. ", got " .. fmt(value), 2)
	end
end

function TestLib.near(actual: number, expected: number, eps: number, label: string?)
	if math.abs(actual - expected) > eps then
		error(("%sexpected ~%s, got %s"):format(if label then label .. ": " else "", fmt(expected), fmt(actual)), 2)
	end
end

-- Deterministic RNG for tests (LCG); returns floats in [0, 1).
function TestLib.seededRng(seed: number): () -> number
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function()
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
end

function TestLib.results()
	return results
end

return TestLib
