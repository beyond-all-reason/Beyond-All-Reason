-- Various helpers for bridging the gap in unit data between defs and scripts.

local function removeCobComments(content)
	local n = #content
	local i = 1
	local output = {}

	local escape = "\\"
	local line_feed = "\n"
	local line_return = "\r"
	local line_ends = { [line_feed] = true, [line_return] = true }
	local quotes = { ['"'] = true, ["'"] = true }

	local insert = table.insert
	local string_start = string.startsWith
	local string_sub = string.sub

	local function current()
		return string_sub(content, i, i)
	end
	local function matchFromCurrent(s)
		return string_start(content, s, i)
	end

	while i <= n do
		local ch = current()

		if quotes[ch] then
			-- Literals
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

		elseif matchFromCurrent("//") then
			-- Single-line comment
			i = i + 2
			while i <= n do
				local c = current()
				i = i + 1
				if c == line_return then
					insert(output, line_return)
					if current() == line_feed then
						insert(output, line_feed)
						i = i + 1
					end
					break
				elseif c == line_feed then
					insert(output, line_feed)
					break
				end
			end

		elseif matchFromCurrent("/*") then
			-- Multi-line comment
			i = i + 2
			while i <= n do
				if matchFromCurrent("*/") then
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

local function removeLusComments(content)
	local n = #content
	local i = 1
	local output = {}

	local escape = "%"
	local line_feed = "\n"
	local line_return = "\r"
	local line_ends = { [line_feed] = true, [line_return] = true }
	local quotes = { ['"'] = true, ["'"] = true }

	local insert = table.insert
	local string_charat = string.charAt
	local string_start = string.startsWith
	local string_sub = string.sub

	local function current()
		return string_sub(content, i, i)
	end
	local function charAt(j)
		return string_charat(content, j)
	end
	local function matchFromCurrent(s)
		return string_start(content, s, i)
	end

	-- Check for multiline opening "long bracket" [=*[
	local function multilineOpenLength(j)
		j = j + 1 -- skip initial '['
		local count = 0
		while charAt(j) == "=" do
			count = count + 1
			j = j + 1
		end
		if charAt(j) == "[" then
			return count
		end
	end

	-- Find next closing ]=*] of given size
	local function seekMultilineClose(length, j)
		while j <= n do
			if charAt(j) == "]" then
				local k = j + 1
				local count = 0
				while charAt(k) == "=" do
					count = count + 1
					k = k + 1
				end
				if charAt(k) == "]" and count == length then
					return k + 1
				end
			end
			j = j + 1
		end
		return n + 1 -- ! file is malformed
	end

	local function skipMultilineComment(length)
		i = i + 1 + length + 1
		local next_pos = seekMultilineClose(length, i)

		while i < (next_pos or n) do
			local c = current()
			if line_ends[c] then insert(output, c) end
			i = i + 1
		end
	end

	local function skipLineComment()
		while i <= n do
			local c = current()
			i = i + 1
			if c == line_return then
				insert(output, line_return)
				if current() == line_feed then
					insert(output, line_feed)
					i = i + 1
				end
				break
			elseif c == line_feed then
				insert(output, line_feed)
				break
			end
		end
	end

	local function outputStringLiteral(quote)
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
	end

	while i <= n do
		local ch = current()
		if quotes[ch] then
			outputStringLiteral(ch)
		elseif matchFromCurrent("--") then
			i = i + 2
			if current() == "[" then
				local length = multilineOpenLength(i)
				if length then
					skipMultilineComment(length)
				else
					skipLineComment()
				end
			else
				skipLineComment()
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

	local isScriptCob = isUnitScriptCOB(unitDef)
	local includePattern = isScriptCob and [[^#include "([^"]+])"]] or [[%s*include%s*(%(?%s*["']([^"']+)["']%s*%)?)]]
	local removeComments = isScriptCob and removeCobComments or removeLusComments

	if isScriptCob then
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
	repeat
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

					local _, _, include = line:find(includePattern)
					if include then
						-- Normalize path and .cob; though, COB includes use .h extensions:
						include = include:lower():gsub("^%.%./", ""):gsub(".cob$", ".bos")
						if not table.getKeyOf(files, include:lower()) then
							files[#files + 1] = include
						end
					end
				end
			end
		end
		index = index + 1
		file = files[index]
	until file == nil

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
	if isUnitScriptCOB(unitDef) and hasScriptMethod(unitDef, "repairShield") then
		local scriptName = getUnitScriptFile(unitDef)
		local content = removeCobComments(VFS.LoadFile(scriptName))

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
