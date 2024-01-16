function gadget:GetInfo()
	return {
		name = "Test Framework Synced Proxy",
		desc = "Proxy for synced commands and code",
		date = "2023",
		license = "GNU GPL, v2 or later",
		version = 0,
		layer = 9999,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

if not Spring.Utilities.IsDevMode() then
	return
end

local LOG_LEVEL = LOG.INFO

VFS.Include('luarules/testing/util.lua')

local function log(level, str, ...)
	if level < LOG_LEVEL then
		return
	end

	Spring.Log(
		gadget:GetInfo().name,
		LOG.NOTICE,
		str
	)
end

local Extra = {
	clearMap = function()
		for _, unitID in ipairs(Spring.GetAllUnits()) do
			Spring.DestroyUnit(unitID, false, true, nil, true)
		end
		for _, featureID in ipairs(Spring.GetAllFeatures()) do
			Spring.DestroyFeature(featureID)
		end
	end,
}

local function processCall(msg, env)
	log(LOG.DEBUG, "[processCall] " .. msg)
	local data, returnId = deserializeFunctionCall(msg)

	local fn = evaluateStringPath(data.path, env)

	if not fn then
		error("[processCall] could not find function: " .. data.path)
	end

	local pcallOk, pcallResult = splitFirstElement(pack(pcall(fn, unpack(data.args))))

	log(LOG.DEBUG, "[processCall.pcall] " .. table.toString({
		pcall = { pcallOk, pcallResult },
		returnId = returnId,
	}))

	local serializedReturn = serializeFunctionReturn(pcallOk, pcallResult, returnId)

	log(LOG.DEBUG, "[processCall.SendLuaUIMsg] " .. PROXY_RETURN_PREFIX .. serializedReturn)
	Spring.SendLuaUIMsg(PROXY_RETURN_PREFIX .. serializedReturn)

end

local function processCode(msg)
	log(LOG.DEBUG, "[processCode] " .. table.toString({
		msg = msg,
	}))

	local fn, returnId = deserializeFunctionRun(msg)

	local pcallOk, pcallResult = fn()

	log(LOG.DEBUG, "[processCode.pcall] " .. table.toString({
		pcall = { pcallOk, pcallResult },
		returnId = returnId,
	}))

	local serializedReturn = serializeFunctionReturn(pcallOk, pcallResult, returnId)

	log(LOG.DEBUG, "[processCode.SendLuaUIMsg] " .. PROXY_RETURN_PREFIX .. serializedReturn)
	Spring.SendLuaUIMsg(PROXY_RETURN_PREFIX .. serializedReturn)
end

local RECEIVE_MODES = {
	[PROXY_PREFIX] = function(msg)
		processCall(msg, _G)
	end,
	[PROXY_EXTRA_PREFIX] = function(msg)
		processCall(msg, Extra)
	end,
	[PROXY_RUN_PREFIX] = function(msg)
		processCode(msg)
	end,
}

function gadget:RecvLuaMsg(msg, playerID)
	for prefix, fn in pairs(RECEIVE_MODES) do
		if msg:sub(1, #prefix) == prefix then
			fn(msg:sub(#prefix + 1))
			return
		end
	end
end
