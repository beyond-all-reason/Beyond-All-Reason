if not Spring.Utilities.IsDevMode() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Gadget Auto Reloader",
		desc = "Reloads all gadgets that have changed after the mouse returned to the game window",
		author = "Beherith, Floris",
		date = "2026.04.01",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
		handler = true,
	}
end

local SELF_NAME = "Gadget Auto Reloader"

local spEcho = Spring.Echo

local gadgetContents = {}
local gadgetFileNames = {}
local failedGadgets = {}
local gadgetDependents = {}  -- gadgetName -> {dependentName1, dependentName2, ...}

local function CacheGadgets()
	for _, g in pairs(gadgetHandler.gadgets) do
		local ghInfo = g.ghInfo
		local name = ghInfo.name
		if name ~= SELF_NAME then
			gadgetFileNames[name] = ghInfo.filename
			if not gadgetContents[name] then
				gadgetContents[name] = VFS.LoadFile(ghInfo.filename)
			end
			if g.GetInfo then
				local info = g:GetInfo()
				if info.dependents then
					gadgetDependents[name] = info.dependents
				end
			end
		end
	end
end

local pendingReHook = {}

local function ReHookProfiler(gadgetName)
	local g = gadgetHandler:FindGadget(gadgetName)
	if not g then return end
	for key, value in pairs(gadgetHandler) do
		if type(value) == "table" then
			local i = string.find(key, "List", 1, true)
			if i then
				local callinName = string.sub(key, 1, i - 1)
				if type(g[callinName]) == "function" then
					gadgetHandler:UpdateGadgetCallIn(callinName, g)
				end
			end
		end
	end
end

local function ReloadGadget(gadgetName, label)
	spEcho("Reloading gadget (" .. label .. "): " .. gadgetName)
	gadgetHandler:DisableGadget(gadgetName)
	gadgetHandler:EnableGadget(gadgetName)
	pendingReHook[gadgetName] = true
end

local function CheckForChanges(gadgetName, fileName, label)
	local newContents = VFS.LoadFile(fileName)
	if newContents ~= gadgetContents[gadgetName] then
		gadgetContents[gadgetName] = newContents
		local chunk, err = loadstring(newContents, fileName)
		if chunk == nil then
			spEcho('Failed to load: ' .. fileName .. '  (' .. err .. ')')
			failedGadgets[gadgetName] = fileName
			return
		end
		failedGadgets[gadgetName] = nil
		ReloadGadget(gadgetName, label)
		-- Reload dependents
		local deps = gadgetDependents[gadgetName]
		if deps then
			for i = 1, #deps do
				local depName = deps[i]
				if gadgetHandler:FindGadget(depName) then
					ReloadGadget(depName, label .. ", dependent of " .. gadgetName)
				end
			end
		end
	end
end

if gadgetHandler:IsSyncedCode() then

	local updateQueue = {}

	function gadget:Initialize()
		CacheGadgets()
	end

	local lastCheckFrame = 0
	local lastFullScanFrame = 0
	function gadget:GameFrame(frame)
		if next(pendingReHook) then
			for name in pairs(pendingReHook) do
				ReHookProfiler(name)
			end
			pendingReHook = {}
		end

		local numGadgets = 15
		while numGadgets > 0 and next(updateQueue) do
			local gadgetName, fileName = next(updateQueue)
			CheckForChanges(gadgetName, fileName, "synced")
			updateQueue[gadgetName] = nil
			numGadgets = numGadgets - 1
		end

		if frame - lastCheckFrame < 30 then
			return
		end
		lastCheckFrame = frame
		for name, fileName in pairs(failedGadgets) do
			CheckForChanges(name, fileName, "synced")
		end
		-- Full scan every ~3 seconds to catch synced-side changes
		if frame - lastFullScanFrame >= 90 then
			lastFullScanFrame = frame
			CacheGadgets()
			updateQueue = {}
			for gadgetName, fileName in pairs(gadgetFileNames) do
				updateQueue[gadgetName] = fileName
			end
		end
	end

	--------------------------------------------------------------------------------
	-- MCP companion: handle requests forwarded from dbg_bar_mcp.lua widget
	--------------------------------------------------------------------------------
	local JsonMcp = VFS.Include("common/luaUtilities/json.lua")

	local function mcpReply(reqId, resultStr)
		-- resultStr must be valid JSON (no bare newlines); Json.encode guarantees this
		Spring.SendLuaUIMsg("mcp_result:" .. reqId .. ":" .. resultStr)
	end

	local function mcpEncodeValue(v)
		if v == nil then return "null" end
		local t = type(v)
		if t == "boolean" or t == "number" then return tostring(v) end
		local ok, enc = pcall(JsonMcp.encode, v)
		return ok and enc or ('"' .. tostring(v):gsub('"', '\\"'):gsub("\n", "\\n") .. '"')
	end

	local function mcpSerialize(ok, ...)
		if not ok then
			local e = (...)
			local _, enc = pcall(JsonMcp.encode, {error = tostring(e)})
			return enc or '{"error":"unknown"}'
		end
		local n = select("#", ...)
		if n == 0 then return "null" end
		if n == 1 then return mcpEncodeValue((...)) end
		local arr = {}
		for i = 1, n do arr[i] = select(i, ...) end
		local ok2, enc = pcall(JsonMcp.encode, arr)
		return ok2 and enc or "[]"
	end

	local function splitIdRest(msg, prefix)
		local rest = msg:sub(#prefix + 1)
		local sep  = rest:find(":", 1, true)
		if not sep then return nil, nil end
		return rest:sub(1, sep - 1), rest:sub(sep + 1)
	end

	local MCP_exec    = "mcp_exec:"
	local MCP_glist   = "mcp_gadget_list:"
	local MCP_genable = "mcp_gadget_enable:"
	local MCP_gdis    = "mcp_gadget_disable:"
	local MCP_greload = "mcp_gadget_reload:"

	function gadget:RecvLuaMsg(msg, playerID)
		-- lua_eval_synced: mcp_exec:<reqId>:<code>
		if msg:sub(1, #MCP_exec) == MCP_exec then
			local reqId, code = splitIdRest(msg, MCP_exec)
			if not reqId then return end
			local fn, cerr = loadstring(code)
			if not fn then
				mcpReply(reqId, JsonMcp.encode({error = "compile: " .. tostring(cerr)}))
				return
			end
			mcpReply(reqId, mcpSerialize(pcall(fn)))
			return
		end

		-- gadget_list: mcp_gadget_list:<reqId>
		if msg:sub(1, #MCP_glist) == MCP_glist then
			local reqId = msg:sub(#MCP_glist + 1)
			local list = {}
			for name, ki in pairs(gadgetHandler.knownGadgets) do
				list[#list + 1] = {name = name, active = ki.active == true, filename = ki.filename or ""}
			end
			table.sort(list, function(a, b) return a.name < b.name end)
			local ok, enc = pcall(JsonMcp.encode, list)
			mcpReply(reqId, ok and enc or "[]")
			return
		end

		-- gadget_enable: mcp_gadget_enable:<reqId>:<name>
		if msg:sub(1, #MCP_genable) == MCP_genable then
			local reqId, name = splitIdRest(msg, MCP_genable)
			if not reqId then return end
			gadgetHandler:EnableGadget(name)
			mcpReply(reqId, JsonMcp.encode({success = true, name = name, action = "enabled"}))
			return
		end

		-- gadget_disable: mcp_gadget_disable:<reqId>:<name>
		if msg:sub(1, #MCP_gdis) == MCP_gdis then
			local reqId, name = splitIdRest(msg, MCP_gdis)
			if not reqId then return end
			gadgetHandler:DisableGadget(name)
			mcpReply(reqId, JsonMcp.encode({success = true, name = name, action = "disabled"}))
			return
		end

		-- gadget_reload: mcp_gadget_reload:<reqId>:<name>
		if msg:sub(1, #MCP_greload) == MCP_greload then
			local reqId, name = splitIdRest(msg, MCP_greload)
			if not reqId then return end
			gadgetHandler:DisableGadget(name)
			gadgetHandler:EnableGadget(name)
			pendingReHook[name] = true
			mcpReply(reqId, JsonMcp.encode({success = true, name = name, action = "reloaded"}))
			return
		end
	end

else

	local spGetMouseState = Spring.GetMouseState
	local mouseOffscreen = select(6, spGetMouseState())

	function gadget:Initialize()
		CacheGadgets()
	end

	local timeSinceCheck = 0
	local updateQueue = {}
	function gadget:Update(dt)
		if next(pendingReHook) then
			for name in pairs(pendingReHook) do
				ReHookProfiler(name)
			end
			pendingReHook = {}
		end

		if next(updateQueue) then
			local startTime = Spring.GetTimer()
			-- 3 ms budget per frame
			while next(updateQueue) and (Spring.DiffTimers(Spring.GetTimer(), startTime, true) < 3.0) do
				local gadgetName, fileName = next(updateQueue)
				CheckForChanges(gadgetName, fileName, "unsynced")
				updateQueue[gadgetName] = nil
			end
		end

		timeSinceCheck = timeSinceCheck + dt
		if timeSinceCheck < 1 then
			return
		end
		timeSinceCheck = 0

		local prevMouseOffscreen = mouseOffscreen
		mouseOffscreen = select(6, spGetMouseState())

		if not mouseOffscreen and prevMouseOffscreen then
			CacheGadgets()
			updateQueue = {}
			for gadgetName, fileName in pairs(gadgetFileNames) do
				updateQueue[gadgetName] = fileName
			end
		else
			for name, fileName in pairs(failedGadgets) do
				CheckForChanges(name, fileName, "unsynced")
			end
		end
	end

end
