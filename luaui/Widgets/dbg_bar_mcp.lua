if not Spring.Utilities.IsDevMode() then
	return
end

--------------------------------------------------------------------------------
-- BAR MCP Server - Developer Tool
--
-- Implements a Model Context Protocol (MCP) server over a local TCP socket so
-- that AI coding assistants (e.g. Claude Desktop, VS Code GitHub Copilot) can
-- interact with a live BAR/Recoil game session.
--
-- Transport: JSON-RPC 2.0, newline-delimited, on 127.0.0.1:23452 (loopback only).
-- Protocol:  MCP 2025-11-25.  Non-blocking I/O via LuaSocket + socket.select.
-- Guard:     Only loads in dev mode (Spring.Utilities.IsDevMode() == true).
--
-- Architecture
--   AI MCP client <-> dbg_bar_mcp.lua (LuaUI widget, unsynced)
--   dbg_bar_mcp.lua -> Spring.SendLuaRulesMsg -> dbg_gadget_auto_reloader.lua
--   dbg_gadget_auto_reloader.lua -> Spring.SendLuaUIMsg -> dbg_bar_mcp.lua
--
-- Exposed MCP tools
--   lua_eval          - run Lua in the unsynced widget environment, return value(s)
--   lua_eval_synced   - run Lua in the synced gadget environment (async; needs cheats)
--   widget_list       - list all known LuaUI widgets and their active state
--   widget_reload     - disable then re-enable a widget by name
--   spring_command    - send a Spring/Recoil console command (e.g. "reloadshaders")
--   vfs_read          - read a VFS file (capped at 512 KB)
--   vfs_list          - list VFS directory contents with a glob pattern
--   game_info         - current frame, map/mod name, player, cheat/dev flags
--   gadget_list       - list all known LuaRules gadgets (async via gadget companion)
--   gadget_reload     - disable then re-enable a gadget (async)
--
-- Async tools forward a message to the synced gadget companion via
-- Spring.SendLuaRulesMsg("mcp_<op>:<reqId>:<args>").  The gadget executes the
-- operation inside the synced VM and replies with
-- Spring.SendLuaUIMsg("mcp_result:<reqId>:<json>"), which widget:RecvLuaMsg
-- picks up and delivers back to the waiting TCP client.
--
-- MCP client setup (Claude Desktop - claude_desktop_config.json):
--   {
--     "mcpServers": {
--       "BAR": {
--         "command": "npx",
--         "args": ["-y", "mcp-remote", "http://localhost:23452"]
--       }
--     }
--   }
-- Note: MCP-over-raw-TCP is not yet part of the official MCP spec; use an
-- intermediary proxy (mcp-remote, socat, or a thin stdio<->TCP bridge) if your
-- client only supports stdio or SSE transports.
--------------------------------------------------------------------------------
--
-- [ ] As MCP-over-raw-TCP is not yet part of the official MCP spec, we need to write a companion python app. 
-- [ ] 
--------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "BAR MCP Server",
		desc    = "MCP (Model Context Protocol) server over TCP for AI-assisted development. Port 23452.",
		author  = "Beherith",
		date    = "2026.05.29",
		license = "GNU GPL v2",
		layer   = 0,
		enabled = true,
		handler = true,
	}
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------
local MCP_PORT    = 23452
local MCP_HOST    = "127.0.0.1"
local MCP_VERSION = "2025-11-25"
local VFS_CAP     = 512 * 1024 -- 512 KB read cap
local MAX_CLIENT_BUFFER = 1024 * 1024 -- Drop clients that send >1 MB without a newline
local MAX_CONSOLE_CACHE_LINES = 4096
local INFOLOG_DELAY_UPDATES = 2
local INFOLOG_MARKER_PREFIX = "[BARMCP_INFOLOG_MARKER]"
local INFOLOG_ERROR_PATTERN = "^%[t=[%d%.:]*%]%[f=[%-%d]*%] Error.*"

local Json   = Json or VFS.Include("common/luaUtilities/json.lua")
local spEcho = Spring.Echo
local debugMode = true
--------------------------------------------------------------------------------
-- Socket state
--------------------------------------------------------------------------------
local server    = nil
local clients   = {}  -- array of {sock, buffer}
local selectSet = {}  -- all sockets for socket.select

-- pending async tool calls awaiting gadget response: reqId -> {client, jsonId}
local pending   = {}
local nextReqId = 0
local consoleLineCache = {}
local delayedToolResponses = {}
local requestQueue = {}
local activeRequest = nil
local updateSerial = 0

local function newReqId()
	nextReqId = nextReqId + 1
	return tostring(nextReqId)
end

local function buildSelectSet()
	selectSet = {}
	if server then selectSet[1] = server end
	for _, c in ipairs(clients) do
		selectSet[#selectSet + 1] = c.sock
	end
end

local function removeClient(sock)
	for i = #clients, 1, -1 do
		if clients[i].sock == sock then
			table.remove(clients, i)
		end
	end
	buildSelectSet()
end

--------------------------------------------------------------------------------
-- JSON-RPC helpers
--------------------------------------------------------------------------------
local pendingSends = {}  -- array of {sock, data}

local function sendAll(sock, data)
	-- Queue data for non-blocking send.
	-- widget:Update() will drain the queue each frame.
	pendingSends[#pendingSends + 1] = {sock = sock, data = data}
end

local function drainPendingSends()
	while #pendingSends > 0 do
		local ps = pendingSends[1]
		local sent, err, partial = ps.sock:send(ps.data)
		if sent then
			if sent < #ps.data then
				-- Partial send: keep the remaining data for the next frame
				ps.data = ps.data:sub(sent + 1)
				return
			else
				-- Full send succeeded
				table.remove(pendingSends, 1)
			end
		elseif err == "timeout" or err == "wantwrite" or err == "wantread" then
			if type(partial) == "number" and partial > 0 then
				ps.data = ps.data:sub(partial + 1)
				if ps.data == "" then
					table.remove(pendingSends, 1)
				end
			end
			return
		else
			-- Real error (closed, reset, etc.)
			table.remove(pendingSends, 1)
			spEcho("[BARMCP] send error: " .. tostring(err))
			pcall(function() ps.sock:close() end)
			removeClient(ps.sock)
		end
	end
end

local function sendRaw(client, tbl)
	local ok, line = pcall(Json.encode, tbl)
	if not ok then
		line = '{"jsonrpc":"2.0","error":{"code":-32603,"message":"encode error"}}'
	end
	sendAll(client.sock, line .. "\n")
end

local function sendResult(client, id, result)
	sendRaw(client, {jsonrpc = "2.0", id = id, result = result})
end

local function sendRpcError(client, id, code, msg)
	sendRaw(client, {jsonrpc = "2.0", id = id, error = {code = code, message = msg}})
end

local function completeActiveRequest()
	activeRequest = nil
end

-- MCP tool result wrappers
local function mcpOk(text)
	return {content = {{type = "text", text = tostring(text)}}, isError = false}
end

local function mcpErr(text)
	return {content = {{type = "text", text = tostring(text)}}, isError = true}
end

local function debugPreview(value)
	local s = tostring(value)
	if #s > 1024 then
		return s:sub(1, 1024) .. "\n[BARMCP: debug log truncated, bytes=" .. tostring(#s) .. "]"
	end
	return s
end

local QUIET_TOOL_NAMES = {
	ping = true,
}

local function jsonEncodeOrFallback(value, fallback)
	local ok, enc = pcall(Json.encode, value)
	return ok and enc or fallback
end

local function splitLines(text)
	local lines = {}
	if type(text) ~= "string" or text == "" then
		return lines
	end
	text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
	for line in (text .. "\n"):gmatch("(.-)\n") do
		if line ~= "" then
			lines[#lines + 1] = line
		end
	end
	return lines
end

local function findLastPlain(text, needle)
	local found = nil
	local from = 1
	while true do
		local idx = text:find(needle, from, true)
		if not idx then
			return found
		end
		found = idx
		from = idx + 1
	end
end

local function cacheConsoleLine(line, priority)
	consoleLineCache[#consoleLineCache + 1] = {
		frame = Spring.GetGameFrame(),
		line = tostring(line),
		priority = priority,
	}
	while #consoleLineCache > MAX_CONSOLE_CACHE_LINES do
		table.remove(consoleLineCache, 1)
	end
end

local function lineIsInfologError(line)
	return line:match(INFOLOG_ERROR_PATTERN) ~= nil
		or line:match("^Error[:%s].*") ~= nil
		or line:match("^%[t=[%d%.:]*%]%[f=[%-%d]*%] Failed to load:.*") ~= nil
		or line:match("^Failed to load:.*") ~= nil
end

local function fillInfologReportFromLines(report, lines, source)
	local errorLines = {}
	for _, line in ipairs(lines) do
		if lineIsInfologError(line) then
			errorLines[#errorLines + 1] = line
		end
	end
	report.checked = true
	report.source = source
	report.lines = lines
	report.errorLines = errorLines
	report.lineCount = #lines
	report.errorCount = #errorLines
	return report
end

local function collectConsoleDelta(probe, report)
	local markerIndex = nil
	for i = #consoleLineCache, 1, -1 do
		if consoleLineCache[i].line:find(probe.marker, 1, true) then
			markerIndex = i
			break
		end
	end
	if not markerIndex then
		return nil, "marker was not found in cached console lines"
	end
	local lines = {}
	for i = markerIndex + 1, #consoleLineCache do
		lines[#lines + 1] = consoleLineCache[i].line
	end
	return fillInfologReportFromLines(report, lines, "console")
end

local function readInfologSnapshot()
	local ok, content = pcall(function()
		return VFS.LoadFile("infolog.txt")
	end)
	if not ok then
		return nil, "VFS.LoadFile('infolog.txt') failed"
	end
	if type(content) ~= "string" or content == "" then
		return nil, "infolog.txt is unavailable from VFS"
	end
	return content
end

local function beginInfologProbe(toolName, requestId)
	local probe = {
		tool = toolName,
		requestId = requestId,
		checked = false,
		path = "infolog.txt",
	}
	local marker = string.format(
		"%s tool=%s request=%s frame=%s clock=%.6f",
		INFOLOG_MARKER_PREFIX,
		tostring(toolName),
		tostring(requestId),
		tostring(Spring.GetGameFrame()),
		(os and os.clock and os.clock()) or 0
	)
	probe.marker = marker
	cacheConsoleLine(marker, "marker")
	spEcho(marker)
	return probe
end

local function collectInfologDelta(probe)
	local report = {
		path = probe and probe.path or "infolog.txt",
		marker = probe and probe.marker or nil,
		checked = false,
		lineCount = 0,
		errorCount = 0,
		lines = {},
		errorLines = {},
	}
	if not probe then
		report.reason = "no infolog probe was created"
		return report
	end
	if not probe.marker then
		report.reason = probe.reason or "infolog marker is unavailable"
		return report
	end
	local consoleReport, consoleMiss = collectConsoleDelta(probe, report)
	if consoleReport then
		return consoleReport
	end
	local snapshot, readErr = readInfologSnapshot()
	if not snapshot then
		report.reason = tostring(consoleMiss) .. "; VFS fallback failed: " .. tostring(readErr)
		return report
	end
	local markerIdx = findLastPlain(snapshot, probe.marker)
	if not markerIdx then
		report.reason = tostring(consoleMiss) .. "; marker was not found in VFS infolog"
		return report
	end
	local after = snapshot:sub(markerIdx + #probe.marker)
	if after:sub(1, 2) == "\r\n" then
		after = after:sub(3)
	elseif after:sub(1, 1) == "\n" or after:sub(1, 1) == "\r" then
		after = after:sub(2)
	end
	local lines = splitLines(after)
	return fillInfologReportFromLines(report, lines, "vfs")
end

local function buildInfologToolPayload(toolName, commandResult, infolog)
	local success = infolog.checked and infolog.errorCount == 0
	local hasErrors = infolog.checked and infolog.errorCount > 0
	local payload = {
		tool = toolName,
		success = success,
		commandResult = tostring(commandResult),
		infolog = infolog,
	}
	local fallback = tostring(commandResult)
	if infolog.reason then
		fallback = fallback .. "\n[BARMCP] infolog check unavailable: " .. tostring(infolog.reason)
	end
	return success, hasErrors, jsonEncodeOrFallback(payload, fallback)
end

local function sendInfologToolResult(client, id, toolName, commandResult, infologProbe)
	local success, hasErrors, payload = buildInfologToolPayload(toolName, commandResult, collectInfologDelta(infologProbe))
	if debugMode and not QUIET_TOOL_NAMES[toolName] then
		spEcho("[BARMCP] <<< tool '" .. toolName .. "' result=" .. debugPreview(payload))
	end
	if hasErrors then
		sendResult(client, id, mcpErr(payload))
	else
		sendResult(client, id, mcpOk(payload))
	end
	return success, hasErrors, payload
end

local function queueDelayedInfologToolResult(client, id, toolName, commandResult, infologProbe, delayUpdates)
	delayedToolResponses[#delayedToolResponses + 1] = {
		client = client,
		jsonId = id,
		toolName = toolName,
		commandResult = commandResult,
		infologProbe = infologProbe,
		dueUpdate = updateSerial + (delayUpdates or INFOLOG_DELAY_UPDATES),
	}
end

local function drainDelayedToolResponses()
	for i = #delayedToolResponses, 1, -1 do
		local p = delayedToolResponses[i]
		if updateSerial >= p.dueUpdate then
			table.remove(delayedToolResponses, i)
			sendInfologToolResult(p.client, p.jsonId, p.toolName, p.commandResult, p.infologProbe)
			completeActiveRequest()
		end
	end
end

--------------------------------------------------------------------------------
-- Value serializer (used by lua_eval return values)
--------------------------------------------------------------------------------
local function serializeValue(v)
	if v == nil then return "null" end
	local t = type(v)
	if t == "boolean" or t == "number" then return tostring(v) end
	if t == "string" or t == "table" then
		local ok, enc = pcall(Json.encode, v)
		return ok and enc or tostring(v)
	end
	return tostring(v)
end

--------------------------------------------------------------------------------
-- Tool implementations  (raise error() on failure, return string on success)
--------------------------------------------------------------------------------

local function tool_lua_eval(args)
	if type(args.code) ~= "string" then error("'code' must be a string") end
	local fn, cerr = loadstring(args.code)
	if not fn then error("compile: " .. tostring(cerr)) end
	local rets = {pcall(fn)}
	if not rets[1] then error("runtime: " .. tostring(rets[2])) end
	if #rets == 1 then return "null" end
	if #rets == 2 then return serializeValue(rets[2]) end
	local parts = {}
	for i = 2, #rets do parts[#parts + 1] = serializeValue(rets[i]) end
	return table.concat(parts, "\t")
end

local function tool_widget_list(args)
	local list = {}
	for name, ki in pairs(widgetHandler.knownWidgets) do
		list[#list + 1] = {name = name, active = ki.active == true, filename = ki.filename or ""}
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	local ok, enc = pcall(Json.encode, list)
	return ok and enc or "[]"
end

local function tool_widget_enable(args)
	if type(args.name) ~= "string" then error("'name' must be a string") end
	widgetHandler:EnableWidget(args.name)
	return args.name .. " enabled"
end

local function tool_widget_disable(args)
	if type(args.name) ~= "string" then error("'name' must be a string") end
	widgetHandler:DisableWidget(args.name)
	return args.name .. " disabled"
end

local function tool_widget_reload(args)
	if type(args.name) ~= "string" then error("'name' must be a string") end
	widgetHandler:DisableWidget(args.name)
	widgetHandler:EnableWidget(args.name)
	return args.name .. " reloaded"
end

local function tool_spring_command(args)
	if type(args.command) ~= "string" then error("'command' must be a string") end
	Spring.SendCommands(args.command)
	return "sent: " .. args.command
end

local function tool_vfs_read(args)
	if type(args.path) ~= "string" then error("'path' must be a string") end
	local content = VFS.LoadFile(args.path, VFS.RAW_FIRST)
	if content == nil then error("not found: " .. args.path) end
	local truncated = #content > VFS_CAP
	if truncated then
		content = content:sub(1, VFS_CAP) .. "\n-- [BARMCP: truncated at 512 KB]"
	end
	return content
end

local function tool_vfs_list(args)
	if type(args.path) ~= "string" then error("'path' must be a string") end
	local pattern = type(args.pattern) == "string" and args.pattern or "*"
	local files = VFS.DirList(args.path, pattern, VFS.RAW_FIRST) or {}
	table.sort(files)
	local ok, enc = pcall(Json.encode, files)
	return ok and enc or "[]"
end

local function tool_game_info(args)
	local pid   = Spring.GetMyPlayerID()
	local pname = Spring.GetPlayerInfo(pid, false) or "unknown"
	local info  = {
		gameFrame  = Spring.GetGameFrame(),
		mapName    = Game.mapName    or "unknown",
		modName    = Game.gameName   or "unknown",
		isReplay   = Spring.IsReplay() == true,
		isSpec     = Spring.GetSpectatingState() == true,
		playerID   = pid,
		playerName = pname,
		isCheating = Spring.IsCheatingEnabled() == true,
		mcpPort    = MCP_PORT,
	}
	local ok, enc = pcall(Json.encode, info)
	return ok and enc or "{}"
end

local function tool_ping(args)
	return "pong"
end

--------------------------------------------------------------------------------
-- Tool registry
--------------------------------------------------------------------------------
local TOOLS = {
	{
		name        = "ping",
		description = "Heartbeat check for the BAR MCP TCP connection.",
		inputSchema = {type="object", properties={}},
		handler     = tool_ping,
	},
	{
		name        = "lua_eval",
		description = "Execute Lua code in the unsynced LuaUI widget environment. Returns the serialized return value(s).",
		inputSchema = {type="object", properties={code={type="string", description="Lua code to execute"}}, required={"code"}},
		handler     = tool_lua_eval,
		infologCheck = true,
	},
	{
		name        = "lua_eval_synced",
		description = "Execute Lua code in the synced LuaRules gadget environment. Requires devmode + cheats enabled. Response is async.",
		inputSchema = {type="object", properties={code={type="string", description="Lua code for synced context"}}, required={"code"}},
		async       = true,
	},
	{
		name        = "widget_list",
		description = "List all known LuaUI widgets and whether they are currently active.",
		inputSchema = {type="object", properties={}},
		handler     = tool_widget_list,
	},
	{
		name        = "widget_reload",
		description = "Reload (disable then re-enable) a LuaUI widget by name.",
		inputSchema = {type="object", properties={name={type="string", description="Widget name"}}, required={"name"}},
		handler     = tool_widget_reload,
		infologCheck = true,
		infologDelayUpdates = INFOLOG_DELAY_UPDATES,
	},
	{
		name        = "spring_command",
		description = "Send a Spring/Recoil engine console command, e.g. 'pause', 'setspeed 4', 'globallos', 'reloadshaders'.",
		inputSchema = {type="object", properties={command={type="string", description="Command string without leading /"}}, required={"command"}},
		handler     = tool_spring_command,
		infologCheck = true,
	},
	{
		name        = "vfs_read",
		description = "Read a file from the game's virtual file system (VFS). Content is capped at 512 KB.",
		inputSchema = {type="object", properties={path={type="string", description="VFS path, e.g. luaui/Widgets/gui_startpoint_placer.lua"}}, required={"path"}},
		handler     = tool_vfs_read,
	},
	{
		name        = "vfs_list",
		description = "List files in a VFS directory matching a glob pattern.",
		inputSchema = {type="object", properties={path={type="string", description="Directory path"}, pattern={type="string", description="Glob, default *"}}, required={"path"}},
		handler     = tool_vfs_list,
	},
	{
		name        = "game_info",
		description = "Return current game state: frame number, map, mod, player, cheat/dev flags.",
		inputSchema = {type="object", properties={}},
		handler     = tool_game_info,
	},
	{
		name        = "gadget_list",
		description = "List all known LuaRules gadgets and whether they are active. Requires Gadget Auto Reloader. Async.",
		inputSchema = {type="object", properties={}},
		async       = true,
	},
	{
		name        = "gadget_reload",
		description = "Reload (disable then re-enable) a LuaRules gadget by name. Async.",
		inputSchema = {type="object", properties={name={type="string", description="Gadget name"}}, required={"name"}},
		async       = true,
		infologCheck = true,
	},
}

local TOOL_MAP = {}
for _, t in ipairs(TOOLS) do TOOL_MAP[t.name] = t end

--------------------------------------------------------------------------------
-- MCP method dispatch
--------------------------------------------------------------------------------
local function onInitialize(client, msg)
	sendResult(client, msg.id, {
		protocolVersion = MCP_VERSION,
		capabilities    = {tools = {}},
		serverInfo      = {name = "BARMCP", version = "1.0.0"},
	})
	return false
end

local function onToolsList(client, msg)
	local list = {}
	for _, t in ipairs(TOOLS) do
		list[#list + 1] = {name = t.name, description = t.description, inputSchema = t.inputSchema}
	end
	sendResult(client, msg.id, {tools = list})
	return false
end

local function onToolsCall(client, msg)
	local params   = msg.params or {}
	local toolName = params.name
	local args     = params.arguments or {}

	local tool = TOOL_MAP[toolName]
	if not tool then
		sendRpcError(client, msg.id, -32601, "Unknown tool: " .. tostring(toolName))
		return false
	end

	-- Debug: log tool call with params
	if debugMode and not QUIET_TOOL_NAMES[toolName] then
		local okArgs, argsStr = pcall(Json.encode, args)
		spEcho("[BARMCP] >>> tool '" .. toolName .. "' args=" .. tostring(okArgs and argsStr or args))
	end

	-- Async tools: forwarded to the synced gadget companion via LuaRulesMsg
	if tool.async then
		local reqId = newReqId()
		local infologProbe = nil
		if tool.infologCheck then
			infologProbe = beginInfologProbe(toolName, msg.id)
		end
		pending[reqId] = {
			client = client,
			jsonId = msg.id,
			toolName = toolName,
			infologProbe = infologProbe,
		}
		local fwd
		if     toolName == "lua_eval_synced" then fwd = "mcp_exec:"           .. reqId .. ":" .. tostring(args.code or "")
		elseif toolName == "gadget_list"     then fwd = "mcp_gadget_list:"    .. reqId
		elseif toolName == "gadget_reload"   then fwd = "mcp_gadget_reload:"  .. reqId .. ":" .. tostring(args.name or "")
		end
		if debugMode and not QUIET_TOOL_NAMES[toolName] then
			spEcho("[BARMCP] >>> async forward: " .. fwd)
		end
		Spring.SendLuaRulesMsg(fwd)
		return true
	end

	-- Sync tools: call handler directly
	local infologProbe = nil
	if tool.infologCheck then
		infologProbe = beginInfologProbe(toolName, msg.id)
	end
	local ok, result = pcall(tool.handler, args)
	if not ok then
		if debugMode and not QUIET_TOOL_NAMES[toolName] then
			spEcho("[BARMCP] <<< tool '" .. toolName .. "' ERROR: " .. tostring(result))
		end
		sendResult(client, msg.id, mcpErr(tostring(result)))
		return false
	end
	if infologProbe then
		if tool.infologDelayUpdates then
			queueDelayedInfologToolResult(client, msg.id, toolName, result, infologProbe, tool.infologDelayUpdates)
			return true
		else
			sendInfologToolResult(client, msg.id, toolName, result, infologProbe)
		end
		return false
	end
	if debugMode and not QUIET_TOOL_NAMES[toolName] then
		spEcho("[BARMCP] <<< tool '" .. toolName .. "' result=" .. debugPreview(result))
	end
	sendResult(client, msg.id, mcpOk(result))
	return false
end

local HANDLERS = {
	["initialize"]                = onInitialize,
	["notifications/initialized"] = function() return false end, -- no-op
	["tools/list"]                = onToolsList,
	["tools/call"]                = onToolsCall,
}

local function enqueueLine(client, line)
	if line == "" then return end
	local ok, msg = pcall(Json.decode, line)
	if not ok or type(msg) ~= "table" then
		sendRpcError(client, Json.null, -32700, "Parse error")
		return
	end
	requestQueue[#requestQueue + 1] = {client = client, msg = msg}
end

local function processNextRequest()
	if activeRequest or #requestQueue == 0 then
		return
	end
	local request = table.remove(requestQueue, 1)
	activeRequest = request
	local client = request.client
	local msg = request.msg
	local h = HANDLERS[msg.method]
	if h then
		local ok2, pendingOrErr = pcall(h, client, msg)
		if not ok2 then
			sendRpcError(client, msg.id, -32603, "Internal error: " .. tostring(pendingOrErr))
			completeActiveRequest()
		elseif not pendingOrErr then
			completeActiveRequest()
		end
	elseif msg.id ~= nil then
		sendRpcError(client, msg.id, -32601, "Method not found: " .. tostring(msg.method))
		completeActiveRequest()
	else
		-- notifications with unknown method: silently ignore
		completeActiveRequest()
	end
end

--------------------------------------------------------------------------------
-- Widget callins
--------------------------------------------------------------------------------
function widget:Initialize()
	server = socket.tcp()
	server:setoption("reuseaddr", true)
	local ok, err = server:bind(MCP_HOST, MCP_PORT)
	if not ok then
		spEcho("[BARMCP] bind failed on " .. MCP_HOST .. ":" .. MCP_PORT .. " - " .. tostring(err))
		widgetHandler:RemoveWidget()
		return
	end
	server:listen(5)
	server:settimeout(0)
	buildSelectSet()
	spEcho("[BARMCP] Listening on " .. MCP_HOST .. ":" .. MCP_PORT)
end

function widget:Shutdown()
	for _, c in ipairs(clients) do pcall(function() c.sock:close() end) end
	if server then pcall(function() server:close() end) end
	clients, server, selectSet = {}, nil, {}
	requestQueue, activeRequest = {}, nil
	delayedToolResponses = {}
	spEcho("[BARMCP] Stopped.")
end

function widget:Update(dt)
	if not server then return end
	updateSerial = updateSerial + 1

	-- Drain any pending sends from the previous frame
	drainDelayedToolResponses()
	drainPendingSends()

	local readable, _, err = socket.select(selectSet, nil, 0)
	if err and err ~= "timeout" then
		spEcho("[BARMCP] select error: " .. tostring(err))
		return
	end

	for _, sock in ipairs(readable) do
		if sock == server then
			-- accept new connection
			local csock = server:accept()
			if csock then
				csock:settimeout(0)
				clients[#clients + 1] = {sock = csock, buffer = ""}
				buildSelectSet()
				spEcho("[BARMCP] New client. Total: " .. #clients)
			end
		else
			-- data from existing client
			local data, status, partial = sock:receive("*a")
			local chunk = data or partial or ""

			if chunk ~= "" then
				for _, c in ipairs(clients) do
					if c.sock == sock then
						c.buffer = c.buffer .. chunk
						if #c.buffer > MAX_CLIENT_BUFFER then
							spEcho("[BARMCP] client buffer exceeded " .. tostring(MAX_CLIENT_BUFFER) .. " bytes without newline; disconnecting")
							pcall(function() sock:close() end)
							removeClient(sock)
							break
						end
						while true do
							local nl = c.buffer:find("\n", 1, true)
							if not nl then break end
							local line = c.buffer:sub(1, nl - 1)
							c.buffer   = c.buffer:sub(nl + 1)
							enqueueLine(c, line)
						end
						break
					end
				end
			end

			if status == "closed" then
				sock:close()
				removeClient(sock)
				spEcho("[BARMCP] Client disconnected. Remaining: " .. #clients)
			end
		end
	end

	processNextRequest()
end

function widget:AddConsoleLine(lines, priority)
	for _, line in ipairs(splitLines(lines)) do
		if not line:find(INFOLOG_MARKER_PREFIX, 1, true) then
			cacheConsoleLine(line, priority)
		end
	end
end

-- Receive async results from the synced gadget companion
function widget:RecvLuaMsg(msg, playerID)
	local PREFIX = "mcp_result:"
	if msg:sub(1, #PREFIX) ~= PREFIX then return end
	local rest = msg:sub(#PREFIX + 1)
	local sep  = rest:find(":", 1, true)
	if not sep then return end
	local reqId     = rest:sub(1, sep - 1)
	local resultStr = rest:sub(sep + 1)
	local p = pending[reqId]
	if not p then return end
	pending[reqId] = nil
	if p.infologProbe then
		local _success, hasErrors, payload = buildInfologToolPayload(
			p.toolName or "async_tool",
			resultStr,
			collectInfologDelta(p.infologProbe)
		)
		if debugMode and not QUIET_TOOL_NAMES[p.toolName] then
			spEcho("[BARMCP] <<< async tool '" .. tostring(p.toolName) .. "' result=" .. debugPreview(payload))
		end
		if hasErrors then
			sendResult(p.client, p.jsonId, mcpErr(payload))
		else
			sendResult(p.client, p.jsonId, mcpOk(payload))
		end
		completeActiveRequest()
		return
	end
	sendResult(p.client, p.jsonId, mcpOk(resultStr))
	completeActiveRequest()
end
