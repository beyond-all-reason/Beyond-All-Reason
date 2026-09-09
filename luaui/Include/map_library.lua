-- Unsynced file-queue client. No Git, shell commands, network or credentials in LuaUI.
local M = {}
local Spring = Spring
local Json = Json
local io = io
local ROOT = "Terraform Brush/Map Library/"
local MAX_JSON = 2 * 1024 * 1024
local POLL_SECONDS = 1
local HEARTBEAT_SECONDS = 10
local RANDOM_WORD_MAX = 0xffff

local function readJson(name)
	local file = io.open(ROOT .. name .. ".json", "rb")
	if not file then
		return nil
	end
	local raw = file:read(MAX_JSON + 1)
	file:close()
	if not raw or #raw > MAX_JSON or raw:sub(-1) ~= "\n" then
		return nil
	end
	local ok, value = pcall(Json.decode, raw)
	return ok and type(value) == "table" and value or nil
end

local function writeJson(name, value)
	Spring.CreateDir(ROOT)
	local file = io.open(ROOT .. name .. ".json", "wb")
	if not file then
		return false
	end
	-- Helper accepts only complete, newline-terminated JSON. This file stays in
	-- place until acknowledged; a reload must not enqueue a duplicate upload.
	local written = file:write(Json.encode(value) .. "\n")
	local closed = file:close()
	return written ~= nil and closed ~= nil
end

function M.new(options)
	local read = options.readJson or readJson
	local write = options.writeJson or writeJson
	local now = options.now or os.time
	local client = { state = {}, catalog = { projects = {}, stages = {} }, generation = 0 }
	local elapsed, lastResult, lastRevision, catalogStatus = POLL_SECONDS, nil, nil, nil

	function client.update(dt)
		elapsed = elapsed + (dt or POLL_SECONDS)
		if elapsed < POLL_SECONDS then
			return
		end
		elapsed = 0
		local state = read("status") or {}
		local age = now() - (tonumber(state.heartbeat) or 0)
		state.online = state.version == 1 and type(state.session) == "string" and age >= -5 and age <= HEARTBEAT_SECONDS
		state.pending = read("request") ~= nil
		client.state = state
		local statusKey = tostring(state.session) .. ":" .. tostring(state.request_id)
		if not state.busy and catalogStatus ~= statusKey then
			local catalog = read("catalog")
			if
				catalog
				and catalog.version == 1
				and catalog.remote == state.remote
				and catalog.branch == state.branch
			then
				client.catalog = catalog
				if catalog.revision ~= lastRevision then
					lastRevision = catalog.revision
					client.generation = client.generation + 1
				end
			elseif catalog then
				client.catalog = { projects = {}, stages = {} }
				lastRevision = nil
				client.generation = client.generation + 1
			end
			catalogStatus = statusKey
		end
		if state.request_id and state.request_id ~= lastResult and not state.busy then
			lastResult = state.request_id
			if state.code == "downloaded" and options.validateSlug(state.local_slug) then
				options.downloaded(state.local_slug)
				client.generation = client.generation + 1
			end
		end
	end

	function client.isBusy()
		return client.state.online and (client.state.busy or client.state.pending) or false
	end

	-- Optional confirmed destination is checked AFTER refreshing the heartbeat.
	function client.request(operation, source, stage, expected)
		elapsed = POLL_SECONDS
		client.update(0)
		local state = client.state
		if not state.online then
			return false, "offline"
		end
		if
			expected
			and (
				state.session ~= expected.session
				or state.remote ~= expected.remote
				or state.branch ~= expected.branch
			)
		then
			return false, "destination_changed"
		end
		if state.busy or state.pending or options.isProjectBusy() then
			return false, "busy"
		end
		if operation ~= "pull" and operation ~= "publish" and operation ~= "download" then
			return false, "invalid_request"
		end
		if operation ~= "pull" and not options.validateSlug(source) then
			return false, "invalid_path"
		end
		if operation == "publish" then
			if not state.allow_push then
				return false, "read_only"
			end
			local found = false
			local stages = client.catalog.stages
			if not stages or #stages == 0 then
				stages = state.stages or {}
			end
			for _, value in ipairs(stages) do
				if value == stage then
					found = true
				end
			end
			if not found then
				return false, "invalid_stage"
			end
		end
		local request = {
			version = 1,
			-- Recoil's float32 numbers round near-INT_MAX bounds out of range.
			-- Format four exact 16-bit draws separately to retain the random bits.
			id = string.format(
				"%04x%04x%04x%04x%08x",
				math.random(0, RANDOM_WORD_MAX),
				math.random(0, RANDOM_WORD_MAX),
				math.random(0, RANDOM_WORD_MAX),
				math.random(0, RANDOM_WORD_MAX),
				now()
			),
			session = state.session,
			operation = operation,
			source = source or "",
			stage = stage or "",
			revision = client.catalog.revision or "",
		}
		if not write("request", request) then
			return false, "write_failed"
		end
		state.pending = true
		return true, request.id
	end

	client.update(0)
	return client
end

return M
