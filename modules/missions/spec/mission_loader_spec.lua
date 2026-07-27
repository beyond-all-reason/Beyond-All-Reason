--- The mission loader's reload transaction. Reload is the authoring
--- workflow, and every step of it is a pure state transition: the gadget is
--- loaded into a mocked environment and driven through its own chat action.
---
--- CreateUnit's contract is the engine's, not a convenience: a bad def name
--- RAISES (LuaSyncedCtrl.cpp), nil means the unit limit.

local realVFS = VFS

local LOADER = "modules/missions/gadgets/mission_loader.lua"
local MISSIONS = "modules/missions/"

local UNIT_DEFS = { armpw = { id = 11 }, armcom = { id = 12 } }
local DEF_NAMES = { [11] = "armpw", [12] = "armcom" }

---@param name string
---@param files table<string, string> mission-relative path -> chunk source
---@return table<string, string>
local function mission(name, files)
	local sources = {}
	for path, source in pairs(files) do
		sources[MISSIONS .. name .. "/" .. path] = source
	end
	return sources
end

---Load the gadget over a mock VFS/Spring. `sources` is the mission tree;
---anything else falls through to the real spec VFS.
---@param sources table<string, string>
---@param requires string[]? modules the missions manifest pulls DSL from
local function newLoader(sources, requires)
	local h = {
		sources = sources,
		params = {},
		echo = {},
		log = {},
		counts = {}, -- teamID -> defName -> finished count
		actions = {},
	}
	local env

	local moduleHandler = {
		Discover = function()
			return { missions = { name = "missions", dir = MISSIONS, requires = requires or {} } }
		end,
		Get = function()
			return { Protect = function() end, Unprotect = function() end }
		end,
	}

	local vfs = {}
	vfs.Include = function(path, fileEnv)
		local source = h.sources[path]
		if source ~= nil then
			local chunk = assert(loadstring(source, "@" .. path))
			-- No env means the handler's own globals, as in the engine.
			setfenv(chunk, fileEnv or env)
			return chunk()
		end
		if path == "modules/module_handler.lua" then
			return moduleHandler
		end
		return realVFS.Include(path, fileEnv)
	end
	vfs.FileExists = function(path)
		if h.sources[path] ~= nil then
			return true
		end
		if path:sub(1, #MISSIONS) == MISSIONS or path:find("/mission_dsl%.lua$") then
			return false
		end
		return realVFS.FileExists(path)
	end
	vfs.DirList = function(dir)
		local found = {}
		for path in pairs(h.sources) do
			if path:sub(1, #dir) == dir and not path:sub(#dir + 1):find("/") then
				found[#found + 1] = path
			end
		end
		return found
	end

	local spring = {
		Echo = function(message)
			h.echo[#h.echo + 1] = tostring(message)
		end,
		Log = function(_, level, message)
			h.log[#h.log + 1] = tostring(level) .. " " .. tostring(message)
		end,
		GetGameRulesParam = function(name)
			return h.params[name]
		end,
		GetGameRulesParams = function()
			local all = {}
			for name, value in pairs(h.params) do
				all[name] = value
			end
			return all
		end,
		-- A nil value ERASES the param (LuaSyncedCtrl.cpp SetRulesParam).
		SetGameRulesParam = function(name, value)
			h.params[name] = value
		end,
		GetGaiaTeamID = function()
			return 2
		end,
		GetTeamList = function()
			return { 0, 1, 2 }
		end,
		GetTeamInfo = function(teamID)
			return teamID, 0, false, teamID == 1, "", teamID
		end,
		GetTeamLuaAI = function()
			return ""
		end,
		GetAllyTeamList = function()
			return { 0, 1 }
		end,
		GetTeamUnitsByDefs = function(teamID, defID)
			local units = {}
			for i = 1, ((h.counts[teamID] or {})[DEF_NAMES[defID]] or 0) do
				units[i] = -i
			end
			return units
		end,
		GetUnitIsBeingBuilt = function()
			return false
		end,
		IsCheatingEnabled = function()
			return false
		end,
		Utilities = { Gametype = { IsSinglePlayer = function()
			return true
		end } },
	}

	env = setmetatable({
		VFS = vfs,
		Spring = spring,
		UnitDefNames = UNIT_DEFS,
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
			AddChatAction = function(_, name, fn)
				h.actions[name] = fn
			end,
			RemoveChatAction = function(_, name)
				h.actions[name] = nil
			end,
			UpdateCallIn = function() end,
		},
	}, { __index = _G })

	realVFS._cache[LOADER] = nil
	realVFS.Include(LOADER, env)
	assert(type(env.gadget.Initialize) == "function", "the mission loader did not load")
	h.gadget = env.gadget
	h.gadget:Initialize()

	h.mission = function(name)
		return h.actions.mission("mission", name, { name }, 0)
	end
	h.frame = function(frame)
		h.gadget:GameFrame(frame)
	end
	h.clear = function()
		h.echo, h.log = {}, {}
	end
	h.echoed = function(needle)
		local seen = 0
		for _, line in ipairs(h.echo) do
			if line:find(needle, 1, true) then
				seen = seen + 1
			end
		end
		return seen
	end
	h.logged = function(needle)
		for _, line in ipairs(h.log) do
			if line:find(needle, 1, true) then
				return true
			end
		end
		return false
	end
	---@return integer|nil count from the last "mission armed" echo, nil if none
	h.armed = function()
		local count
		for _, line in ipairs(h.echo) do
			local n = line:match("mission armed: .* %((%d+) trigger")
			if n ~= nil then
				count = tonumber(n)
			end
		end
		return count
	end

	return h
end

local BUILD = [[
When(Team.Player.Has(UnitDef("armpw"), 3))
	.Do(Objective("build_pawns").Complete())
]]

local VICTORY = [[
When(Objective("build_pawns").IsComplete())
	.Do(Objective("win").Complete())
]]

local ROSTER = [[
Spawn(UnitDef("armcom"), "player").At(0.5, 0.5).Named("hero")
]]

-- A module DSL contribution: registers one trigger per Mark at Finalize.
local CONTRIBUTION = [[
return {
	ForFile = function(file)
		local marks = {}
		return {
			env = {
				Mark = function(name)
					marks[#marks + 1] = name
				end,
			},
			Finalize = function()
				for order, name in ipairs(marks) do
					file.Register({
						id = file.filename .. ":mark:" .. order,
						filename = file.filename,
						order = order,
						condition = { inputs = { "UnitFinished" }, evaluate = function() return true end },
						effects = { { execute = function() Spring.Echo("mark: " .. name) end } },
						once = true,
					})
				end
			end,
		}
	end,
}
]]

describe("mission loader reload", function()
	describe("stale triggers", function()
		it("arms a renamed trigger file once, not twice", function()
			local h = newLoader(mission("t", { ["triggers/win.lua"] = BUILD }))
			h.counts[0] = { armpw = 3 }
			h.mission("t")
			h.frame(15)
			assert.are.equal(1, h.armed())

			h.sources[MISSIONS .. "t/triggers/victory.lua"] = h.sources[MISSIONS .. "t/triggers/win.lua"]
			h.sources[MISSIONS .. "t/triggers/win.lua"] = nil
			h.clear()
			h.mission("t")
			assert.are.equal(1, h.armed())
			h.frame(30)
			assert.are.equal(1, h.echoed("objective complete: build_pawns"))
		end)

		it("drops the previous mission's triggers on a switch", function()
			local sources = mission("t", { ["triggers/win.lua"] = BUILD })
			for path, source in pairs(mission("u", { ["triggers/other.lua"] = [[
When(Team.Player.Has(UnitDef("armpw"), 3))
	.Do(Objective("scout").Complete())
]] })) do
				sources[path] = source
			end
			local h = newLoader(sources)
			h.mission("t")
			h.clear()
			h.mission("u")
			assert.are.equal(1, h.armed())
			h.counts[0] = { armpw = 3 }
			h.frame(15)
			assert.are.equal(1, h.params.objective_scout)
			assert.is_nil(h.params.objective_build_pawns)
		end)
	end)

	describe("objective progress", function()
		it("clears completed objectives so a reload is a fresh run", function()
			local h = newLoader(mission("t", {
				["triggers/a_build.lua"] = BUILD,
				["triggers/z_win.lua"] = VICTORY,
			}))
			h.counts[0] = { armpw = 3 }
			h.mission("t")
			h.frame(15)
			assert.are.equal(1, h.params.objective_build_pawns)
			assert.are.equal(1, h.params.objective_win)

			-- The author reloads to test from the top; the pawns are gone.
			h.counts[0] = { armpw = 0 }
			h.clear()
			h.mission("t")
			assert.is_nil(h.params.objective_build_pawns)
			assert.is_nil(h.params.objective_win)
			h.frame(30)
			assert.is_nil(h.params.objective_win)
		end)

		it("clears the objective prefix and nothing else", function()
			local h = newLoader(mission("t", { ["triggers/a_build.lua"] = BUILD }))
			h.mission("t")
			h.params.some_other_gadget = 7
			h.params.mission_unit_dead_ghost = 1
			h.mission("t")
			assert.are.equal(7, h.params.some_other_gadget)
			assert.are.equal(1, h.params.mission_unit_dead_ghost)
		end)
	end)

	describe("a failed load", function()
		it("leaves the running mission armed when a trigger file fails", function()
			local h = newLoader(mission("t", {
				["triggers/a_build.lua"] = BUILD,
				["triggers/z_win.lua"] = VICTORY,
			}))
			h.counts[0] = { armpw = 3 }
			h.mission("t")
			assert.are.equal(2, h.armed())
			h.frame(15)
			assert.are.equal(1, h.params.objective_build_pawns)

			h.sources[MISSIONS .. "t/triggers/z_win.lua"] = "NoSuchVerb()"
			h.clear()
			local ok, err = pcall(h.mission, "t")
			assert.is_true(ok, tostring(err))
			assert.is_nil(h.armed())
			assert.is_true(h.logged("z_win.lua"))
			-- Progress belongs to the mission that is still running.
			assert.are.equal(1, h.params.objective_build_pawns)

			-- And that mission is still whole: the second trigger fires too.
			h.frame(30)
			assert.are.equal(1, h.params.objective_win)
		end)

		it("keeps a half-parsed mission's triggers out of the armed set", function()
			local h = newLoader(mission("t", {
				["triggers/a_build.lua"] = BUILD,
				["triggers/z_win.lua"] = "NoSuchVerb()",
			}))
			local ok = pcall(h.mission, "t")
			assert.is_true(ok)
			assert.is_nil(h.armed())
			h.counts[0] = { armpw = 3 }
			h.frame(15)
			assert.is_nil(h.params.objective_build_pawns)
			assert.is_nil(h.params.mission_active)
		end)
	end)
end)
