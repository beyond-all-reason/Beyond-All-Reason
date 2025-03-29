local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Synced Proxy",
		desc = "Proxy that allows running arbitrary code in the synced LuaRules environment",
		license = "GNU GPL, v2 or later",
		layer = 9999,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

if not Spring.Utilities.IsDevMode() or not Spring.Utilities.Gametype.IsSinglePlayer() then
	Spring.SetGameRulesParam('isSyncedProxyEnabled', false)
	return
end

Spring.SetGameRulesParam('isSyncedProxyEnabled', true)

local LOG_LEVEL = LOG.INFO

local Proxy = VFS.Include('common/testing/synced_proxy.lua')

local rpc = VFS.Include('common/testing/rpc.lua'):new()

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

local function processFunctionCall(fn, returnID)
	local pcallOk, pcallResult = fn()

	log(LOG.DEBUG, "[processFunctionCall] " .. table.toString({
		pcall = { pcallOk, pcallResult },
		returnID = returnID,
	}))

	local serializedReturn = rpc:serializeFunctionReturn(pcallOk, pcallResult, returnID)

	log(LOG.DEBUG, "[processFunctionCall.SendLuaUIMsg] " .. Proxy.PREFIX.RETURN .. serializedReturn)
	Spring.SendLuaUIMsg(Proxy.PREFIX.RETURN .. serializedReturn)
end

local RECEIVE_MODES = {
	[Proxy.PREFIX.CALL] = function(msg)
		log(LOG.DEBUG, "[ProxyCall] " .. msg)

		processFunctionCall(rpc:deserializeFunctionCall(msg, _G))
	end,
	[Proxy.PREFIX.RUN] = function(msg)
		log(LOG.DEBUG, "[ProxyRun]")

		processFunctionCall(rpc:deserializeFunctionRun(msg))
	end,
}

function gadget:RecvLuaMsg(msg, playerID)
	-- check cheating here because cheats might not be enabled when the game starts
	if not Spring.IsCheatingEnabled() then
		return
	end
	for prefix, fn in pairs(RECEIVE_MODES) do
		if msg:sub(1, #prefix) == prefix then
			fn(msg:sub(#prefix + 1))
			return
		end
	end
end

function gadget:Shutdown()
	Spring.SetGameRulesParam('isSyncedProxyEnabled', false)
end
