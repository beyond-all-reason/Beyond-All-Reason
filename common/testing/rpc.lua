local serpent = VFS.Include('common/luaUtilities/serpent.lua')
local Util = VFS.Include('common/testing/util.lua')

local function generateRandomString(length)
	local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local random_string = ""
	local charset_length = string.len(charset)

	for i = 1, length do
		local random_index = math.random(1, charset_length)
		random_string = random_string .. string.sub(charset, random_index, random_index)
	end

	return random_string
end

local function evaluateStringPath(str, env)
	local parts = {}
	for part in str:gmatch("[^.]+") do
		table.insert(parts, part)
	end

	local obj = env or _G

	for _, part in ipairs(parts) do
		obj = obj[part]
		if obj == nil then
			return nil
		end
	end

	return obj
end

local function getLocals(i)
	local result = {}
	local j = 1
	while true do
		local n, v = debug.getlocal(i, j)
		if n == nil then
			break
		end
		result[#result + 1] = { n, v }
		j = j + 1
	end
	return result
end

local RPC = {}

function RPC:new(key)
	local obj = {
		key = key or generateRandomString(16),
		currentReturnID = 0,
	}
	setmetatable(obj, self)
	self.__index = self
	return obj
end

function RPC:getNextReturnID()
	self.currentReturnID = self.currentReturnID + 1
	return self.key .. tostring(self.currentReturnID)
end

function RPC:serializeFunctionCall(path, args)
	local returnID = self:getNextReturnID()

	local data = {
		path = path,
		args = args,
		returnID = returnID,
	}

	return serpent.dump(data), returnID
end

function RPC:deserializeFunctionCall(serializedCall, env)
	local dataOk, data = serpent.load(serializedCall, { safe = false })

	if not dataOk then
		-- error parsing data
		error(data)
	end

	local fn = evaluateStringPath(data.path, env)

	if not fn then
		error("could not find function: " .. data.path)
	end

	local callableFunction = function()
		local pcallOk, pcallResult = Util.splitFirstElement(Util.pack(pcall(fn, unpack(data.args))))
		if not pcallOk then
			pcallResult = pcallResult[1]
		end
		return pcallOk, pcallResult
	end

	return callableFunction, data.returnID
end

function RPC:serializeFunctionRun(fn, stackDistance)
	local fnLocals = getLocals(stackDistance + 1)
	--local fnUpvalues = getUpvalues(fn)

	local returnID = self:getNextReturnID()

	local data = {
		fn = fn,
		locals = fnLocals,
		--upvalues = fnUpvalues,
		returnID = returnID,
	}

	return serpent.dump(data), returnID
end

function RPC:deserializeFunctionRun(serializedFn)
	local dataOk, data = serpent.load(serializedFn, { safe = false })

	if not dataOk then
		-- error parsing data
		error(data)
	end

	local localsDictionary = {}

	for i = 1, #data.locals do
		local key = data.locals[i][1]
		local value = data.locals[i][2]

		if key ~= nil and value ~= nil then
			localsDictionary[key] = value
		end
	end

	local callableFunction = function()
		local pcallOk, pcallResult = Util.splitFirstElement(Util.pack(pcall(data.fn, localsDictionary)))
		if not pcallOk then
			pcallResult = pcallResult[1]
		end
		return pcallOk, pcallResult
	end

	return callableFunction, data.returnID
end

function RPC:serializeFunctionReturn(pcallOk, pcallResult, returnID)
	local data = nil
	if pcallOk then
		data = {
			success = true,
			result = pcallResult,
			returnID = returnID,
		}
	else
		data = {
			success = false,
			error = pcallResult,
			returnID = returnID,
		}
	end

	return serpent.dump(data)
end

function RPC:deserializeFunctionReturn(serializedReturn)
	local dataOk, data = serpent.load(serializedReturn)

	if not dataOk then
		-- error parsing data
		error(data)
	end

	if data.success then
		return data.success, data.result, data.returnID
	else
		return data.success, data.error, data.returnID
	end
end

return RPC
