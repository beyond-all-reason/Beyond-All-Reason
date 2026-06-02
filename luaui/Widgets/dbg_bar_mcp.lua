if not Spring.Utilities.IsDevMode() then
	return
end

--------------------------------------------------------------------------------
-- BAR MCP Server — Developer Tool
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
-- ┌─────────────────────────────┐   TCP/JSON-RPC    ┌────────────────────────┐
-- │  AI client (Claude / Copilot│ ◄────────────────► │  dbg_bar_mcp.lua       │
-- │  VS Code MCP extension …)   │                   │  (LuaUI widget,        │
-- └─────────────────────────────┘                   │   unsynced context)    │
--                                                   └──────────┬─────────────┘
--                                  Spring.SendLuaRulesMsg ▼   │ ▲ Spring.SendLuaUIMsg
--                                                   ┌──────────┴─────────────┐
--                                                   │  dbg_gadget_auto_      │
--                                                   │  reloader.lua          │
--                                                   │  (LuaRules gadget,     │
--                                                   │   synced context)      │
--                                                   └────────────────────────┘
--
-- Exposed MCP tools
--   lua_eval          – run Lua in the unsynced widget environment, return value(s)
--   lua_eval_synced   – run Lua in the synced gadget environment (async; needs cheats)
--   widget_list       – list all known LuaUI widgets and their active state
--   widget_enable     – load a widget by name
--   widget_disable    – unload a widget by name
--   widget_reload     – disable then re-enable a widget by name
--   spring_command    – send a Spring/Recoil console command (e.g. "reloadshaders")
--   vfs_read          – read a VFS file (capped at 512 KB)
--   vfs_list          – list VFS directory contents with a glob pattern
--   game_info         – current frame, map/mod name, player, cheat/dev flags
--   gadget_list       – list all known LuaRules gadgets (async via gadget companion)
--   gadget_enable     – load a gadget by name (async)
--   gadget_disable    – unload a gadget by name (async)
--   gadget_reload     – disable then re-enable a gadget (async)
--
-- Async tools forward a message to the synced gadget companion via
-- Spring.SendLuaRulesMsg("mcp_<op>:<reqId>:<args>").  The gadget executes the
-- operation inside the synced VM and replies with
-- Spring.SendLuaUIMsg("mcp_result:<reqId>:<json>"), which widget:RecvLuaMsg
-- picks up and delivers back to the waiting TCP client.
--
-- MCP client setup (Claude Desktop — claude_desktop_config.json):
--   {
--     "mcpServers": {
--       "BAR": {
--         "command": "npx",
--         "args": ["-y", "mcp-remote", "http://localhost:23452"]
--       }
--     }
--   }
-- Note: MCP-over-raw-TCP is not yet part of the official MCP spec; use an
-- intermediary proxy (mcp-remote, socat, or a thin stdio↔TCP bridge) if your
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

local Json   = Json or VFS.Include("common/luaUtilities/json.lua")
local spEcho = Spring.Echo

--------------------------------------------------------------------------------
-- Socket state
--------------------------------------------------------------------------------
local server    = nil
local clients   = {}  -- array of {sock, buffer}
local selectSet = {}  -- all sockets for socket.select

-- pending async tool calls awaiting gadget response: reqId -> {client, jsonId}
local pending   = {}
local nextReqId = 0

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
local function sendRaw(client, tbl)
	local ok, line = pcall(Json.encode, tbl)
	if not ok then
		line = '{"jsonrpc":"2.0","error":{"code":-32603,"message":"encode error"}}'
	end
	client.sock:send(line .. "\n")
end

local function sendResult(client, id, result)
	sendRaw(client, {jsonrpc = "2.0", id = id, result = result})
end

local function sendRpcError(client, id, code, msg)
	sendRaw(client, {jsonrpc = "2.0", id = id, error = {code = code, message = msg}})
end

-- MCP tool result wrappers
local function mcpOk(text)
	return {content = {{type = "text", text = tostring(text)}}, isError = false}
end

local function mcpErr(text)
	return {content = {{type = "text", text = tostring(text)}}, isError = true}
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

--------------------------------------------------------------------------------
-- Tool registry
--------------------------------------------------------------------------------
local TOOLS = {
	{
		name        = "lua_eval",
		description = "Execute Lua code in the unsynced LuaUI widget environment. Returns the serialized return value(s).",
		inputSchema = {type="object", properties={code={type="string", description="Lua code to execute"}}, required={"code"}},
		handler     = tool_lua_eval,
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
		name        = "widget_enable",
		description = "Enable (load) a LuaUI widget by name.",
		inputSchema = {type="object", properties={name={type="string", description="Widget name"}}, required={"name"}},
		handler     = tool_widget_enable,
	},
	{
		name        = "widget_disable",
		description = "Disable (unload) a LuaUI widget by name.",
		inputSchema = {type="object", properties={name={type="string", description="Widget name"}}, required={"name"}},
		handler     = tool_widget_disable,
	},
	{
		name        = "widget_reload",
		description = "Reload (disable then re-enable) a LuaUI widget by name.",
		inputSchema = {type="object", properties={name={type="string", description="Widget name"}}, required={"name"}},
		handler     = tool_widget_reload,
	},
	{
		name        = "spring_command",
		description = "Send a Spring/Recoil engine console command, e.g. 'pause', 'setspeed 4', 'globallos', 'reloadshaders'.",
		inputSchema = {type="object", properties={command={type="string", description="Command string without leading /"}}, required={"command"}},
		handler     = tool_spring_command,
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
		name        = "gadget_enable",
		description = "Enable (load) a LuaRules gadget by name. Async.",
		inputSchema = {type="object", properties={name={type="string", description="Gadget name"}}, required={"name"}},
		async       = true,
	},
	{
		name        = "gadget_disable",
		description = "Disable (unload) a LuaRules gadget by name. Async.",
		inputSchema = {type="object", properties={name={type="string", description="Gadget name"}}, required={"name"}},
		async       = true,
	},
	{
		name        = "gadget_reload",
		description = "Reload (disable then re-enable) a LuaRules gadget by name. Async.",
		inputSchema = {type="object", properties={name={type="string", description="Gadget name"}}, required={"name"}},
		async       = true,
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
end

local function onToolsList(client, msg)
	local list = {}
	for _, t in ipairs(TOOLS) do
		list[#list + 1] = {name = t.name, description = t.description, inputSchema = t.inputSchema}
	end
	sendResult(client, msg.id, {tools = list})
end

local function onToolsCall(client, msg)
	local params   = msg.params or {}
	local toolName = params.name
	local args     = params.arguments or {}

	local tool = TOOL_MAP[toolName]
	if not tool then
		sendRpcError(client, msg.id, -32601, "Unknown tool: " .. tostring(toolName))
		return
	end

	-- Async tools: forwarded to the synced gadget companion via LuaRulesMsg
	if tool.async then
		local reqId = newReqId()
		pending[reqId] = {client = client, jsonId = msg.id}
		local fwd
		if     toolName == "lua_eval_synced" then fwd = "mcp_exec:"           .. reqId .. ":" .. tostring(args.code or "")
		elseif toolName == "gadget_list"     then fwd = "mcp_gadget_list:"    .. reqId
		elseif toolName == "gadget_enable"   then fwd = "mcp_gadget_enable:"  .. reqId .. ":" .. tostring(args.name or "")
		elseif toolName == "gadget_disable"  then fwd = "mcp_gadget_disable:" .. reqId .. ":" .. tostring(args.name or "")
		elseif toolName == "gadget_reload"   then fwd = "mcp_gadget_reload:"  .. reqId .. ":" .. tostring(args.name or "")
		end
		Spring.SendLuaRulesMsg(fwd)
		return
	end

	-- Sync tools: call handler directly
	local ok, result = pcall(tool.handler, args)
	if not ok then
		sendResult(client, msg.id, mcpErr(tostring(result)))
		return
	end
	sendResult(client, msg.id, mcpOk(result))
end

local HANDLERS = {
	["initialize"]                = onInitialize,
	["notifications/initialized"] = function() end, -- no-op
	["tools/list"]                = onToolsList,
	["tools/call"]                = onToolsCall,
}

local function dispatchLine(client, line)
	if line == "" then return end
	local ok, msg = pcall(Json.decode, line)
	if not ok or type(msg) ~= "table" then
		sendRpcError(client, Json.null, -32700, "Parse error")
		return
	end
	local h = HANDLERS[msg.method]
	if h then
		local ok2, err = pcall(h, client, msg)
		if not ok2 then
			sendRpcError(client, msg.id, -32603, "Internal error: " .. tostring(err))
		end
	elseif msg.id ~= nil then
		sendRpcError(client, msg.id, -32601, "Method not found: " .. tostring(msg.method))
	end
	-- notifications with unknown method: silently ignore
end

--------------------------------------------------------------------------------
-- Widget callins
--------------------------------------------------------------------------------
function widget:Initialize()
	server = socket.tcp()
	server:setoption("reuseaddr", true)
	local ok, err = server:bind(MCP_HOST, MCP_PORT)
	if not ok then
		spEcho("[BARMCP] bind failed on " .. MCP_HOST .. ":" .. MCP_PORT .. " — " .. tostring(err))
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
	spEcho("[BARMCP] Stopped.")
end

function widget:Update(dt)
	if not server then return end

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
						while true do
							local nl = c.buffer:find("\n", 1, true)
							if not nl then break end
							local line = c.buffer:sub(1, nl - 1)
							c.buffer   = c.buffer:sub(nl + 1)
							dispatchLine(c, line)
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
	sendResult(p.client, p.jsonId, mcpOk(resultStr))
end
