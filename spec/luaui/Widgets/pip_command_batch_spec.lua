-- Run the actual PiP command handlers with mocked world/UI state.
local path = "luaui/Widgets/gui_pip.lua"
local f = assert(io.open(path))
local src = f:read("*a")
f:close()
local handlers = assert(src:match("(function widget:UnitCommand%(.-)\n%-%- Track newly finished units"))
local history = assert(src:match("(function miscState.hist.LogCommand%(.-)\n%-%- Effect builders"))
local function setup()
	local records = {}
	local env = setmetatable(
		{
			widget = {},
			CMD = { ATTACK = 20, OPT_SHIFT = 32, SELFD = 65, STOP = 0 },
			Game = { maxUnits = 32000 },
			config = { historyCommands = true, commandFXIgnoreNewUnits = true, drawCommandFX = true },
			wallClockTime = 10,
			gameTime = 10,
			gaiaTeamID = 9,
			uiState = {},
			cameraState = { mySpecState = false },
			interactionState = {},
			state = {},
			teamAllyTeamCache = {},
			selfDUnits = {},
			cmdQueueCache = { waypoints = {} },
			commandFX = { newUnits = {}, lastTarget = {}, count = 0, MAX = 3, list = {} },
			cmdColors = { [20] = { 1, 0, 0 } },
			miscState = { hist = { cmdKind = { [20] = 2 }, frame = 100 } },
			Spring = {
				GetTeamAllyTeamID = function(team)
					return team
				end,
				GetGameFrame = function()
					return 100
				end,
				GetLocalAllyTeamID = function()
					return 0
				end,
			},
			spFunc = {
				GetTeamAllyTeamID = function(team)
					return team
				end,
				GetTeamInfo = function(team)
					return nil, nil, nil, nil, nil, team
				end,
				GetUnitPosition = function(id)
					if id ~= 404 then
						return id * 10, 20, id * 5
					end
				end,
				GetFeaturePosition = function(id)
					return id * 20, 0, id * 30
				end,
			},
		},
		{ __index = _G }
	)
	env.miscState.hist.Feeds = function()
		return {
			OnCommand = function(_, ...)
				records[#records + 1] = { ... }
			end,
		}
	end
	local chunk
	if setfenv then
		chunk = assert(loadstring(history .. "\n" .. handlers))
		setfenv(chunk, env)
	else
		chunk = assert(load(history .. "\n" .. handlers, "pip handlers", "t", env))
	end
	chunk()
	return env, records
end
local function equal(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in pairs(a) do
		if not equal(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end
describe("PiP batch command notifications", function()
	for _, mode in ipairs({ "normal", "hidden", "minimized", "enemy", "new", "gaia", "no-history" }) do
		it("preserves legacy history and FX in " .. mode .. " mode", function()
			local a, ar = setup()
			local b, br = setup()
			local team = mode == "enemy" and 1 or mode == "gaia" and 9 or 0
			for _, env in ipairs({ a, b }) do
				if mode == "hidden" then
					env.config.drawCommandFX = false
				end
				if mode == "minimized" then
					env.uiState.inMinMode = true
				end
				if mode == "new" then
					env.commandFX.newUnits[1] = 9.9
				end
				if mode == "no-history" then
					env.config.historyCommands = false
				end
			end
			local targets = { 10, 20, 404, 32001, 30, 40 }
			local reads = 0
			local commands = {
				GetTarget = function(_, i)
					reads = reads + 1
					return targets[i]
				end,
				GetOptions = function(_, i)
					return i == 1 and 0 or 32
				end,
			}
			-- Gaps and a rejected first input; duplicate targets across notifications;
			-- chaining after the FX cap and invalid target positions must stay identical.
			for _, ranges in ipairs({ { 1, 2, 4, 2 }, { 2, 2, 6, 1 } }) do
				for unit = 1, 3 do
					for r = 1, #ranges, 2 do
						for i = ranges[r], ranges[r] + ranges[r + 1] - 1 do
							a.widget:UnitCommand(unit, 1, team, 20, { targets[i] }, { shift = i ~= 1 })
						end
					end
					b.widget:UnitCommandBatch(unit, 1, team, commands, -1, true, true, ranges)
				end
			end
			assert(equal(ar, br), mode .. ": history mismatch")
			assert(equal(a.commandFX, b.commandFX), mode .. ": live FX mismatch")
			assert(reads == 6, mode .. ": input was decoded per unit")
			local batch = dofile("common/command_batch.lua")
			local wants, notify = batch.NotificationDispatcher(function()
				return { b.widget }
			end)
			assert(wants(1, 1, team, commands, -1, true, true))
			notify(1, 1, team, commands, -1, true, true, { 1, 1 })
			assert(batch.GetStats().notifyFallback == 0)
		end)
	end
end)
