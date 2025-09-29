-- Various helpers for bridging the gap in unit data between defs and scripts.

---Based on C-style comments, so maybe I am assuming wrong.
local function removeComments(content)
	local n = #content
	local i = 1
	local output = {}

	local escape = "\\"
	local line_feed = "\n"
	local line_return = "\r"
	local line_ends = { [line_feed] = true, [line_return] = true }
	local quotes = { ['"'] = true, ["'"] = true }

	local insert = table.insert
	local function current() return string.sub(content, i, i) end
	local function starts_with(s)
		return string.sub(content, i, i + #s - 1) == s
	end

	while i <= n do
		local ch = current()

		-- Literals
		if quotes[ch] then
			local quote = ch
			insert(output, quote)
			i = i + 1
			while i <= n do
				local c = current()
				insert(output, c)
				i = i + 1
				if c == escape then
					if i <= n then
						insert(output, current())
						i = i + 1
					end
				elseif c == quote then
					break
				end
			end

		elseif starts_with("//") then
			-- Single-line comment
			i = i + 2
			while i <= n do
				local c = current()
				i = i + 1
				if c == line_return then
					insert(output, line_return)
					if i <= n and current() == line_feed then
						insert(output, line_feed)
						i = i + 1
					end
					break
				elseif c == line_feed then
					insert(output, line_feed)
					break
				end
			end

		elseif starts_with("/*") then
			-- Multi-line comment
			i = i + 2
			while i <= n do
				if starts_with("*/") then
					i = i + 2
					break
				else
					local c = current()
					if line_ends[c] then
						insert(output, c)
					end
					i = i + 1
				end
			end
		else
			insert(output, ch)
			i = i + 1
		end
	end

	return table.concat(output)
end

---Test whether a unit's script is COB, as opposed to LUS.
---@param unitDef table
---@return boolean
local function isUnitScriptCOB(unitDef)
	local scriptName = unitDef.scriptName
	return scriptName and scriptName:lower():find(".cob$") and true or false
end

---Test whether a unit's script is LUS, as opposed to COB.
---@param unitDef table
---@return boolean
local function isUnitScriptLUS(unitDef)
	local scriptName = unitDef.scriptName
	return scriptName and scriptName:lower():find(".lua$") and true or false
end

local function getUnitScriptFile(unitDef)
	local scriptName
	if isUnitScriptCOB(unitDef) then
		scriptName = unitDef.scriptName:lower():gsub(".cob$", ".bos")
	else
		scriptName = unitDef.scriptName
	end
	if scriptName and VFS.FileExists(scriptName) then
		return scriptName
	end
end

---Test whether a unit's unit script contains a given method or methods.
--
-- Units can do this with `GetScriptEnv`, for example. It's harder with UnitDefs.
--
-- Returns a more detailed table showing what methods exist and which are called
-- within the unit's script to help with diagnosing scripts that never trigger.
---@param unitDef table
---@param ... string
---@return boolean allTrue
---@return table? report when methods are either not found or not called directly
local function hasScriptMethod(unitDef, ...)
	local scriptName = getUnitScriptFile(unitDef)

	if not scriptName then
		return false
	end

	-- We may need to load more files, e.g. any includes.
	local files = { scriptName }

	local methods = { ... }
	if not next(methods) then
		return false
	end
	local hasMethod = {}
	local useMethod = {}
	local hasMethodPattern = {}
	local useMethodPattern = {}

	-- Must not match lines like "//use call-script DeathAnim(); from Killed()"
	-- though such a comment pretty strongly implies these methods are present.
	local path = [[^#include "([^"]+])"]]

	if isUnitScriptCOB(unitDef) then
		for i, name in ipairs(methods) do
			hasMethod[i] = false
			useMethod[i] = false
			-- double-escape symbols that need to be escaped after formatting:
			hasMethodPattern[i] = ("^%%s*%s%%("):format(name)
			useMethodPattern[i] = ("^%%s*%%a+-script %s%%([^%%)]*%%);"):format(name)
		end
	elseif isUnitScriptLUS(unitDef) then
		for i, name in ipairs(methods) do
			hasMethod[i] = false
			useMethod[i] = false
			hasMethodPattern[i] = ("f[%%a]function %s%%s?%%("):format(name)
			useMethodPattern[i] = ("f[%%a]%s%%("):format(name)
		end
	else
		return false
	end

	local index = 1
	local file = files[index]
	while file ~= nil do
		index = index + 1
		local data = VFS.LoadFile(file)
		if data then
			data = removeComments(data)
			for _, line in ipairs(string.lines(data)) do
				for i = 1, #methods do
					if not hasMethod[i] and line:find(hasMethodPattern[i]) then
						hasMethod[i] = true
					end
					if not useMethod[i] and line:find(useMethodPattern[i]) then
						useMethod[i] = true
					end

					local _, _, include = line:find(path)
					if include and not table.getKeyOf(files, include:lower()) then
						files[#files + 1] = include:lower()
					end
				end
			end
		end
		file = files[index]
	end

	local function setTrue(value)
		return value == true
	end

	if table.all(hasMethod, setTrue) and table.all(useMethod, setTrue) then
		return true
	else
		local report = {}
		for i = 1, #methods do
			report[methods[i]] = {
				exists = hasMethod[i],
				called = useMethod[i],
			}
		end
		return false, report
	end
end

---Test whether a unit's unit script contains a death animation sequence.
---@param unitDef table
---@return boolean
local function hasDeathAnimation(unitDef)
	local _, methods = hasScriptMethod(unitDef, "Killed", "DeathAnim")
	-- We rely on the Killed method but do not need it to be called:
	if methods and methods.Killed.exists and methods.DeathAnim.called then
		return true
	else
		return false
	end
end

---Test whether a unit's unit script contains reactive armor variables.
---@param unitDef table
---@return boolean
---@return integer? armorHealth
---@return integer? armorRecoverTime
local function hasReactiveArmor(unitDef)
	if hasScriptMethod(unitDef, "repairShield") then
		local scriptName = getUnitScriptFile(unitDef)
		local content = removeComments(VFS.LoadFile(scriptName))

		local health = 0
		for _, var in ipairs { "tdamage", "ldamage", "rdamage" } do
			-- We do what we can just to find a matching variable:
			local _, _, capture = content:find(var .. " > (%d+)")
			if capture then
				health = tonumber(capture) / 100
			end
		end

		local recover = 0
		local inMethod = false
		for _, line in ipairs(string.lines(content)) do
			if not inMethod and line:find("^repairShield%(%)") then
				inMethod = true
			end
			if inMethod then
				if line == "}" then
					break
				end
				local _, _, duration = line:find("sleep (%d+)")
				if duration then
					recover = recover + tonumber(duration) / 1000 -- from ms
				end
			end
		end

		health = math.floor(health + 0.5)
		recover = math.floor(recover + 0.5)
		return true, health, recover
	end
	return false
end

return {
	IsUnitScriptCOB   = isUnitScriptCOB,
	IsUnitScriptLUS   = isUnitScriptLUS,
	GetUnitScriptFile = getUnitScriptFile,
	HasScriptMethod   = hasScriptMethod,
	HasDeathAnimation = hasDeathAnimation,
	HasReactiveArmor  = hasReactiveArmor,
}
