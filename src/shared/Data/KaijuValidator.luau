--!strict
-- Validates species definitions. It only REPORTS problems; it never modifies source values.

local KaijuValidator = {}

export type Issue = {
	severity: string, -- "error" | "warning"
	speciesId: string,
	message: string,
}

local STAT_KEYS = { "durability", "damage", "mobility", "stamina", "intelligence" }
local KNOWN_ARCHETYPES = {
	crawler = true,
	blob = true,
	flyer = true,
	fish = true,
	jelly = true,
	quadruped = true,
	serpent = true,
	biped = true,
}
local MIN_KL, MAX_KL = 1, 5
local TRAIT_COUNT = 3

local function isInteger(n: any): boolean
	return type(n) == "number" and n == math.floor(n)
end

local function isNonEmptyString(s: any): boolean
	return type(s) == "string" and #s > 0
end

local function isRGB(c: any): boolean
	if type(c) ~= "table" or #c ~= 3 then
		return false
	end
	for i = 1, 3 do
		local v = c[i]
		if type(v) ~= "number" or v < 0 or v > 255 then
			return false
		end
	end
	return true
end

-- Validates one entry. `index` is used to label entries that lack a usable id.
function KaijuValidator.validateSpecies(species: any, index: number): { Issue }
	local issues: { Issue } = {}
	local label = if type(species) == "table" and isNonEmptyString(species.id)
		then species.id
		else ("<entry #" .. index .. ">")

	local function err(msg: string)
		table.insert(issues, { severity = "error", speciesId = label, message = msg })
	end
	local function warn(msg: string)
		table.insert(issues, { severity = "warning", speciesId = label, message = msg })
	end

	if type(species) ~= "table" then
		err("definition is not a table")
		return issues
	end

	if not isNonEmptyString(species.id) then
		err("missing or empty 'id'")
	elseif not string.match(species.id, "^[a-z][a-z0-9_]*$") then
		err("id '" .. species.id .. "' must be lowercase snake_case")
	end

	if not isNonEmptyString(species.displayName) then
		err("missing or empty 'displayName'")
	end

	if not isInteger(species.kl) then
		err("'kl' must be an integer")
	elseif species.kl < MIN_KL or species.kl > MAX_KL then
		err(("'kl' %d out of range %d..%d"):format(species.kl :: number, MIN_KL, MAX_KL))
	end

	if type(species.threatRating) ~= "number" then
		err("'threatRating' must be a number")
	elseif species.threatRating < 0 then
		err("'threatRating' must not be negative")
	end

	if type(species.traits) ~= "table" then
		err("'traits' must be a list")
	else
		if #species.traits ~= TRAIT_COUNT then
			err(("expected %d traits, found %d"):format(TRAIT_COUNT, #(species.traits :: { any })))
		end
		for i, trait in species.traits do
			if not isNonEmptyString(trait) then
				err("trait #" .. tostring(i) .. " is not a non-empty string")
			end
		end
	end

	if type(species.stats) ~= "table" then
		err("'stats' must be a table")
	else
		local sum = 0
		local allValid = true
		for _, key in STAT_KEYS do
			local v = species.stats[key]
			if type(v) ~= "number" then
				err("stat '" .. key .. "' missing or not a number")
				allValid = false
			elseif v < 0 then
				err("stat '" .. key .. "' is negative")
				allValid = false
			else
				sum += v
			end
		end
		for key in species.stats do
			if not table.find(STAT_KEYS, key) then
				err("unknown stat '" .. tostring(key) .. "'")
			end
		end
		if type(species.documentedTotal) ~= "number" then
			err("'documentedTotal' must be a number")
		elseif allValid and sum ~= species.documentedTotal then
			-- Reported, never corrected: the document is the source of truth.
			warn(("stat sum %d does not match documented Total %d"):format(sum, species.documentedTotal :: number))
		end
	end

	if species.statAnnotations ~= nil then
		if type(species.statAnnotations) ~= "table" then
			err("'statAnnotations' must be a table")
		else
			for key, text in species.statAnnotations do
				if not table.find(STAT_KEYS, key) then
					err("statAnnotations has unknown stat '" .. tostring(key) .. "'")
				elseif not isNonEmptyString(text) then
					err("statAnnotations['" .. key .. "'] must be a non-empty string")
				end
			end
		end
	end

	if type(species.dimensions) ~= "table" then
		err("'dimensions' must be a list (may be empty)")
	else
		for i, dim in species.dimensions do
			if type(dim) ~= "table" or not isNonEmptyString(dim.kind) or not isNonEmptyString(dim.text) then
				err("dimension #" .. tostring(i) .. " needs 'kind' and 'text'")
			elseif dim.meters ~= nil and type(dim.meters) ~= "number" then
				err("dimension #" .. tostring(i) .. " 'meters' must be a number if present")
			end
		end
	end

	if species.nameVariants ~= nil and type(species.nameVariants) ~= "table" then
		err("'nameVariants' must be a list if present")
	end
	if species.notes ~= nil and type(species.notes) ~= "table" then
		err("'notes' must be a list if present")
	end

	local visual = species.visual
	if type(visual) ~= "table" then
		err("'visual' must be a table")
	else
		if not KNOWN_ARCHETYPES[visual.archetype] then
			err("unknown visual archetype '" .. tostring(visual.archetype) .. "'")
		end
		for _, key in { "primary", "secondary", "accent" } do
			if not isRGB(visual[key]) then
				err("visual." .. key .. " must be an {r,g,b} list of 0..255")
			end
		end
		if type(visual.scale) ~= "number" or visual.scale <= 0 then
			err("visual.scale must be a positive number")
		end
	end

	return issues
end

-- Validates a whole roster: per-entry checks plus duplicate ids / names.
function KaijuValidator.validateRoster(list: any): { Issue }
	local issues: { Issue } = {}
	if type(list) ~= "table" then
		table.insert(issues, { severity = "error", speciesId = "<roster>", message = "roster is not a list" })
		return issues
	end

	local seenIds: { [string]: boolean } = {}
	local seenNames: { [string]: boolean } = {}
	for index, species in list do
		for _, issue in KaijuValidator.validateSpecies(species, index) do
			table.insert(issues, issue)
		end
		if type(species) == "table" then
			if isNonEmptyString(species.id) then
				if seenIds[species.id] then
					table.insert(issues, { severity = "error", speciesId = species.id, message = "duplicate id" })
				end
				seenIds[species.id] = true
			end
			if isNonEmptyString(species.displayName) then
				local key = string.lower(species.displayName)
				if seenNames[key] then
					table.insert(
						issues,
						{ severity = "error", speciesId = tostring(species.id), message = "duplicate displayName" }
					)
				end
				seenNames[key] = true
			end
		end
	end
	return issues
end

function KaijuValidator.hasErrors(issues: { Issue }): boolean
	for _, issue in issues do
		if issue.severity == "error" then
			return true
		end
	end
	return false
end

function KaijuValidator.format(issue: Issue): string
	return ("[%s] %s: %s"):format(string.upper(issue.severity), issue.speciesId, issue.message)
end

return KaijuValidator
