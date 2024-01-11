local serpent = serpent or VFS.Include('common/luaUtilities/serpent.lua')

TEST_RESULT = {
	PASS = 1,
	FAIL = 2,
	SKIPPED = 3,
	ERROR = 4,
}

TEST_RESULT_ID_TO_STRING = {}
for k, v in pairs(TEST_RESULT) do
	TEST_RESULT_ID_TO_STRING[v] = k
end

function pack(...)
	return { ... }
end

function splitFirstElement(tbl)
	if type(tbl) ~= "table" then
		error("Input must be a table")
	end

	if #tbl < 1 then
		return nil, {}
	end

	local firstElement = table.remove(tbl, 1)
	return firstElement, tbl
end

function clamp(min, max, num)
	if (num < min) then
		return min
	elseif (num > max) then
		return max
	end
	return num
end

function rgbToColorCode(r, g, b)
	local rs = clamp(1, 255, math.round(255 * r))
	local gs = clamp(1, 255, math.round(255 * g))
	local bs = clamp(1, 255, math.round(255 * b))
	return "\255" .. string.char(rs) .. string.char(gs) .. string.char(bs)
end

function rgbReset()
	return rgbToColorCode(0.85, 0.85, 0.85)
end

function formatTestResult(testResult)
	local resultColor
	if testResult.result == TEST_RESULT.PASS then
		resultColor = rgbToColorCode(0, 1, 0)
	elseif testResult.result == TEST_RESULT.FAIL then
		resultColor = rgbToColorCode(1, 0, 0)
	elseif testResult.result == TEST_RESULT.SKIP then
		resultColor = rgbToColorCode(0.8, 0.8, 0)
	elseif testResult.result == TEST_RESULT.ERROR then
		resultColor = rgbToColorCode(0.8, 0, 0.8)
	end
	local resultStr = resultColor .. TEST_RESULT_ID_TO_STRING[testResult.result] .. rgbReset()
	local s = string.format("%s: %s", resultStr, testResult.label)
	if testResult.frames ~= nil then
		s = s .. " [" .. testResult.frames .. " frames]"
	end
	if testResult.milliseconds ~= nil then
		s = s .. " [" .. testResult.milliseconds .. " ms]"
	end
	if testResult.error ~= nil then
		s = s .. " | " .. testResult.error
	end
	return s
end

function evaluateStringPath(str, initialEnv)
	local parts = {}
	for part in str:gmatch("[^.]+") do
		table.insert(parts, part)
	end

	local obj = initialEnv or _G

	for _, part in ipairs(parts) do
		obj = obj[part]
		if obj == nil then
			return nil
		end
	end

	return obj
end

PROXY_SEPARATOR = "||||"

PROXY_PREFIX = "testframeworkproxy" .. PROXY_SEPARATOR
PROXY_EXTRA_PREFIX = "testframeworkproxyextra" .. PROXY_SEPARATOR
PROXY_RUN_PREFIX = "testframeworkproxyrun" .. PROXY_SEPARATOR

PROXY_RETURN_PREFIX = "testframeworkproxyreturn" .. PROXY_SEPARATOR

function registerCallins(target, callback, callins)
	local callinNames = {
		'UnitCreated',
		'UnitFinished',
		'UnitFromFactory',
		'UnitReverseBuilt',
		'UnitDestroyed',
		'RenderUnitDestroyed',
		'UnitTaken',
		'UnitGiven',
		'UnitIdle',
		'UnitCommand',
		'UnitCmdDone',
		'UnitDamaged',
		--'UnitStunned',
		'UnitEnteredRadar',
		'UnitEnteredLos',
		'UnitLeftRadar',
		'UnitLeftLos',
		'UnitEnteredUnderwater',
		'UnitEnteredWater',
		'UnitEnteredAir',
		'UnitLeftUnderwater',
		'UnitLeftWater',
		'UnitLeftAir',
		'UnitSeismicPing',
		'UnitLoaded',
		'UnitUnloaded',
		'UnitCloaked',
		'UnitDecloaked',
		'UnitMoveFailed',
		'UnitHarvestStorageFull',
	}

	for _, callinName in ipairs(callinNames) do
		if callins == nil or table.contains(callins, callinName) then
			target[callinName] = function(...)
				local args = { ... }
				table.remove(args, 1)
				callback(callinName, args)
			end
		end
	end
end

local function getLocals(i)
	local result = {}
	local j = 1
	while true do
		local n, v = debug.getlocal(i, j)
		if n == nil then
			break
		end
		result[n] = v
		j = j + 1
	end
	return result
end

local function getUpvalues(fn)
	local result = {}
	local j = 1
	while true do
		local n, v = debug.getupvalue(fn, j)
		if n == nil then
			break
		end
		result[n] = v
		j = j + 1
	end
	return result
end

local currentReturnId = 0

function serializeFunctionCall(path, args)
	currentReturnId = currentReturnId + 1

	local data = {
		path = path,
		args = args,
		returnId = currentReturnId,
	}

	return serpent.dump(data), currentReturnId
end

function deserializeFunctionCall(serializedCall)
	local dataOk, data = serpent.load(serializedCall, { safe = false })

	if not dataOk then
		-- error parsing data
		error(data)
	end

	return data, data.returnId
end

function serializeFunctionRun(fn, stackDistance)
	local fnLocals = getLocals(stackDistance + 1)
	--local fnUpvalues = getUpvalues(fn)

	currentReturnId = currentReturnId + 1

	local data = {
		fn = fn,
		locals = fnLocals,
		--upvalues = fnUpvalues,
		returnId = currentReturnId,
	}

	return serpent.dump(data), currentReturnId
end

function deserializeFunctionRun(serializedFn)
	local dataOk, data = serpent.load(serializedFn, { safe = false })

	if not dataOk then
		-- error parsing data
		error(data)
	end

	local callableFunction = function()
		local pcallOk, pcallResult = splitFirstElement(pack(pcall(data.fn, data.locals)))
		return pcallOk, pcallResult
	end

	return callableFunction, data.returnId
end

function serializeFunctionReturn(pcallOk, pcallResult, returnId)
	local data = nil
	if pcallOk then
		data = {
			success = true,
			result = pcallResult,
			returnId = returnId,
		}
	else
		data = {
			success = false,
			error = pcallResult,
			returnId = returnId,
		}
	end

	return serpent.dump(data)
end

function deserializeFunctionReturn(serializedReturn)
	local dataOk, data = serpent.load(serializedReturn)

	if not dataOk then
		-- error parsing data
		error(data)
	end

	if data.success then
		return data.success, data.result, data.returnId
	else
		return data.success, data.error, data.returnId
	end
end

function spy(parent, target)
	local original = parent[target]
	local calls = {}
	local wrapper = function(...)
		local args = { ... }
		calls[#calls + 1] = table.copy(args)
		return original(unpack(args))
	end
	parent[target] = wrapper
	return {
		calls = calls,
		remove = function()
			parent[target] = original
		end
	}
end

function matchesPatterns(str, patterns)
	for _, p in ipairs(patterns) do
		if string.match(str, p) then
			return true
		end
	end
	return false
end

function splitPhrases(input)
	local result = {}
	local currentPhrase = ""

	local function appendPhrase(phrase)
		table.insert(result, phrase:match("^%s*(.-)%s*$"))  -- Trim whitespace
		currentPhrase = ""
	end

	local i = 1
	local len = string.len(input)

	while i <= len do
		local char = string.sub(input, i, i)

		if char == " " and currentPhrase ~= "" then
			appendPhrase(currentPhrase)
		elseif char == "\"" then
			local quoteStart = i
			repeat
				i = i + 1
				char = string.sub(input, i, i)
				if char == "\\" then
					i = i + 1 -- Skip escaped character
				end
			until char == "\"" or i > len

			local quoteEnd = i
			appendPhrase(string.sub(input, quoteStart + 1, quoteEnd - 1))
		else
			currentPhrase = currentPhrase .. char
		end

		i = i + 1
	end

	if currentPhrase ~= "" then
		appendPhrase(currentPhrase)
	end

	return result
end

function removeFileExtension(filename)
	local lastDotIndex = filename:match(".+()%.%w+$")
	if lastDotIndex then
		return filename:sub(1, lastDotIndex - 1)
	else
		return filename
	end
end

function yieldable_pcall(func, ...)
	-- this works just like pcall, but while pcall fails on yield, this handles yield transparently
	local function helper(co, ok, ...)
		if ok then
			if coroutine.status(co) == "dead" then
				return true, (...)
			end
			return helper(co, coroutine.resume(co, coroutine.yield(...)))
		else
			return false, (...)
		end
	end

	local co = coroutine.create(function(...)
		return func(...)
	end)

	return helper(co, coroutine.resume(co, ...))
end
