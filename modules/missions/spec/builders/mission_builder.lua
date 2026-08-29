
local realVFS = VFS
local realModuleHandler = VFS.Include("modules/module_handler.lua")

local LOADER = "modules/missions/gadgets/mission_loader.lua"
local MISSIONS = "modules/missions/"
local EVALUATE_PERIOD = 15
local PLAYER, ENEMY, GAIA = 0, 1, 2

---@class MissionBuilder
---@field params table<string, any> game rules params, the runtime's save pile
---@field calls { module: string, method: string, args: any[] }[] every module api call, in order
---@field echo string[]
---@field log string[]
local MissionBuilder = {}
MissionBuilder.__index = MissionBuilder

function MissionBuilder.new()
	local self = setmetatable({
		sources = {},
		missionName = nil,
		params = {},
		echo = {},
		log = {},
		calls = {},
		stubs = {},
		counts = {},
		defNames = {},
		nextDefId = 100,
		frame = 0,
		engines = {},
		objectiveDecls = {},
		includes = {},
		rosters = {},
		units = {},
		nextUnitId = 1,
		actions = {},
		modules = {},
		gadgets = {},
		apis = {},
		loaded = false,
	}, MissionBuilder)
	return self
end

---@param name string
---@param gadgetPath string
---@return MissionBuilder
function MissionBuilder:WithModule(name, gadgetPath)
	self.modules[#self.modules + 1] = { name = name, gadgetPath = gadgetPath }
	return self
end

---@param name string
function MissionBuilder:callin(name, ...)
	if self.gadget and self.gadget[name] then
		self.gadget[name](self.gadget, ...)
	end
	for _, gadget in ipairs(self.gadgets) do
		if gadget[name] then
			gadget[name](gadget, ...)
		end
	end
end

---@param name string
---@param files table<string, fun()|string>
---@return MissionBuilder
function MissionBuilder:WithSources(name, files)
	self.missionName = name
	for path, source in pairs(files) do
		self.sources[MISSIONS .. name .. "/" .. path] = source
	end
	return self
end

---@param name string
---@return MissionBuilder
function MissionBuilder:WithMission(name)
	self.missionName = name
	return self
end

---@param teamID integer
---@param defName string
---@param count integer
---@return MissionBuilder
function MissionBuilder:WithUnits(teamID, defName, count)
	self.counts[teamID] = self.counts[teamID] or {}
	self.counts[teamID][defName] = count
	-- Has is event-driven: the engine only re-asks after a UnitFinished.
	if self.gadget then
		self:callin("UnitFinished", -count, self:defId(defName), teamID)
	end
	return self
end

---@param moduleName string
---@param method string
---@param fn function
---@return MissionBuilder
function MissionBuilder:WithStub(moduleName, method, fn)
	self.stubs[moduleName] = self.stubs[moduleName] or {}
	self.stubs[moduleName][method] = fn
	return self
end

---@param moduleName string
---@return { method: string, args: any[] }[]
function MissionBuilder:Calls(moduleName)
	local out = {}
	for _, call in ipairs(self.calls) do
		if call.module == moduleName then
			out[#out + 1] = call
		end
	end
	return out
end

---@return TriggerDescriptor[]
function MissionBuilder:Triggers()
	local engine = self.engines[#self.engines]
	return engine and engine.Triggers() or {}
end

---@return MissionObjectiveDeclarationEntry[]
function MissionBuilder:Objectives()
	return self.objectiveDecls[#self.objectiveDecls] or {}
end

---@return string[]
function MissionBuilder:ObjectiveOrder()
	local order = {}
	for id in tostring(self.params.objective_display_order or ""):gmatch("[^,]+") do
		order[#order + 1] = id
	end
	return order
end

---@param name string
function MissionBuilder:Param(name)
	return self.params[name]
end

---@return table Units
---@return table Objectives
---@return table Variables
function MissionBuilder:Includes()
	return self.includes.units or {}, self.includes.objectives or {}, self.includes.variables or {}
end

---@param objective MissionObjectiveDeclaration|string a handle, or the id
---@return string
local function objectiveId(objective)
	if type(objective) == "table" then
		return assert(objective.id, "not an objective handle")
	end
	return objective
end

---@param objective MissionObjectiveDeclaration|string
---@return boolean
function MissionBuilder:IsComplete(objective)
	return self.params["objective_" .. objectiveId(objective)] == 1
end

---@param objective MissionObjectiveDeclaration|string
---@return boolean
function MissionBuilder:IsRevealed(objective)
	return self.params["objective_revealed_" .. objectiveId(objective)] == 1
end

---@param objective MissionObjectiveDeclaration|string
---@return string|nil
function MissionBuilder:TitleOf(objective)
	return self.params["objective_title_" .. objectiveId(objective)]
end

---@param needle string
---@return integer
function MissionBuilder:Echoed(needle)
	local seen = 0
	for _, line in ipairs(self.echo) do
		if line:find(needle, 1, true) then
			seen = seen + 1
		end
	end
	return seen
end

---@param needle string
---@return boolean
function MissionBuilder:Logged(needle)
	for _, line in ipairs(self.log) do
		if line:find(needle, 1, true) then
			return true
		end
	end
	return false
end

---@return MissionBuilder
function MissionBuilder:ClearOutput()
	self.echo, self.log = {}, {}
	return self
end

---@param frame integer
---@return MissionBuilder
function MissionBuilder:Frame(frame)
	self.frame = frame
	self:callin("GameFrame", frame)
	return self
end

---@return MissionBuilder
function MissionBuilder:Step()
	return self:Frame(self.frame + EVALUATE_PERIOD)
end

---@param ... string
---@return MissionBuilder
function MissionBuilder:Command(...)
	self:Load()
	local words = { ... }
	self.actions.mission("mission", table.concat(words, " "), words, 0)
	return self
end

---@return MissionBuilder
function MissionBuilder:Arm()
	assert(self.missionName, "WithMission or WithSources first")
	self:Command("load", self.missionName)
	return self
end

function MissionBuilder:Reload()
	self:Command("reload")
	return self
end

function MissionBuilder:Restart()
	self:Command("restart")
	return self
end

---@param teamID integer
---@param defName string
---@return integer unitID
function MissionBuilder:WithExistingUnit(teamID, defName)
	return self:createUnit(defName, teamID)
end

---@return MissionRosterEntry[]
function MissionBuilder:Roster()
	return self.rosters[#self.rosters] or {}
end

---@param unit table|string a roster handle, or the roster name
---@return string
local function unitName(unit)
	if type(unit) == "table" then
		return assert(unit.name, "not a roster handle")
	end
	return unit
end

---@param unit table|string a roster handle, or the roster name
---@return integer|nil
function MissionBuilder:UnitOf(unit)
	return self.params["mission_unit_" .. unitName(unit)]
end

---@return table<integer, { def: string, team: integer, neutral: boolean }>
function MissionBuilder:Units()
	return self.units
end

---@param unit table|string a roster handle, or the roster name
---@return MissionRosterEntry|nil what the roster declared for it
function MissionBuilder:Entry(unit)
	local name = unitName(unit)
	for _, entry in ipairs(self:Roster()) do
		if entry.name == name then
			return entry
		end
	end
	return nil
end

local TEAMS = { player = PLAYER, enemy = ENEMY, gaia = GAIA }

---@param role "player"|"enemy"|"gaia"
---@return { def: string, team: integer, neutral: boolean, holdsFire: boolean }[]
function MissionBuilder:TeamUnits(role)
	local teamID = assert(TEAMS[role], "team role: player, enemy or gaia")
	local out = {}
	for unitID, unit in pairs(self.units) do
		if unit.team == teamID then
			out[#out + 1] = {
				id = unitID,
				def = unit.def,
				team = unit.team,
				neutral = unit.neutral,
				holdsFire = self:HoldsFire(unitID),
			}
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

---@param unit table|string|integer a roster handle, a roster name or a unit id
---@return boolean
function MissionBuilder:HoldsFire(unit)
	local unitID = type(unit) == "number" and unit or self:UnitOf(unit)
	local entry = unitID and self.units[unitID]
	if not entry then
		return false
	end
	for _, order in ipairs(entry.orders) do
		if order.cmd == self.env.CMD.FIRE_STATE and order.params[1] == 0 then
			return true
		end
	end
	return false
end

---@param unit table|string a roster handle, or the roster name
---@return MissionBuilder
function MissionBuilder:Spot(unit)
	local unitID = assert(self:UnitOf(unit), "no roster unit named " .. unitName(unit))
	self:callin("UnitEnteredLos", unitID, self.units[unitID].team, PLAYER, self:defId(self.units[unitID].def))
	return self
end

---@param unit table|string a roster handle, or the roster name
---@param attackerTeam integer|nil
---@return MissionBuilder
function MissionBuilder:Kill(unit, attackerTeam)
	local unitID = assert(self:UnitOf(unit), "no roster unit named " .. unitName(unit))
	local unit = self.units[unitID]
	self.units[unitID] = nil
	self:callin("UnitDestroyed", unitID, self:defId(unit.def), unit.team, nil, nil, attackerTeam)
	return self
end

function MissionBuilder:createUnit(defName, teamID, x, y, z)
	local unitID = self.nextUnitId
	self.nextUnitId = unitID + 1
	self.units[unitID] =
		{ def = defName, team = teamID, neutral = false, orders = {}, x = x or 0, y = y or 0, z = z or 0 }
	return unitID
end

---@param cargo table|string
---@param carrier table|string
---@return MissionBuilder
function MissionBuilder:Board(cargo, carrier)
	local cargoID = assert(self:UnitOf(cargo), "no roster unit named " .. unitName(cargo))
	local carrierID = assert(self:UnitOf(carrier), "no roster unit named " .. unitName(carrier))
	self.units[cargoID].carrier = carrierID
	self:callin("UnitLoaded", cargoID, self:defId(self.units[cargoID].def), self.units[cargoID].team, carrierID)
	return self
end

---@param cargo table|string
---@return MissionBuilder
function MissionBuilder:SetDown(cargo)
	local cargoID = assert(self:UnitOf(cargo), "no roster unit named " .. unitName(cargo))
	local carrierID = assert(self.units[cargoID].carrier, unitName(cargo) .. " is not aboard anything")
	self.units[cargoID].carrier = nil
	self:callin("UnitUnloaded", cargoID, self:defId(self.units[cargoID].def), self.units[cargoID].team, carrierID)
	return self
end

function MissionBuilder:defId(defName)
	return self.env.UnitDefNames[defName].id
end

function MissionBuilder:recorderFor(moduleName)
	local self_ = self
	return setmetatable({}, {
		__index = function(_, method)
			return function(...)
				self_.calls[#self_.calls + 1] = { module = moduleName, method = method, args = { ... } }
				local stub = self_.stubs[moduleName] and self_.stubs[moduleName][method]
				if stub then
					return stub(...)
				end
			end
		end,
	})
end

function MissionBuilder:Load()
	if self.loaded then
		return self
	end
	self.loaded = true
	local self_ = self
	local env

	local recorders = {}
	local moduleHandler = {
		Discover = function(...)
			return realModuleHandler.Discover(...)
		end,
		ResetCaches = realModuleHandler.ResetCaches,
		Get = function(name)
			if self_.apis[name] then
				return self_.apis[name]
			end
			recorders[name] = recorders[name] or self_:recorderFor(name)
			return recorders[name]
		end,
		LoadPolicies = realModuleHandler.LoadPolicies,
		Evaluate = realModuleHandler.Evaluate,
		-- Over this builder's VFS so an inline mission is visible to the action files.
		LoadActions = function()
			local registry = { byName = {}, list = {} }
			for _, name in ipairs({ "load", "reload", "restart" }) do
				local entry = { name = name }
				local registrar = {
					RegisterValidate = function(fn)
						entry.validate = fn
					end,
					RegisterExecute = function(fn)
						entry.execute = fn
					end,
				}
				local path = MISSIONS .. "actions/" .. name .. ".lua"
				local handle = assert(io.open(path, "rb"), path)
				local source = handle:read("*a")
				handle:close()
				local chunk = assert(loadstring(source, "@" .. path))
				setfenv(chunk, setmetatable({ Actions = registrar, VFS = env.VFS }, { __index = _G }))
				chunk()
				registry.byName[name] = entry
				registry.list[#registry.list + 1] = entry
			end
			return registry
		end,
	}

	local wrapped = {
		["modules/missions/lib/trigger_engine.lua"] = function(lib)
			return setmetatable({
				New = function()
					local engine = lib.New()
					self_.engines[#self_.engines + 1] = engine
					return engine
				end,
			}, { __index = lib })
		end,
		["modules/missions/lib/objectives.lua"] = function(lib)
			return setmetatable({
				ForFile = function(...)
					local file = lib.ForFile(...)
					local finalize = file.Finalize
					file.Finalize = function(exports, ...)
						local decls = finalize(exports, ...)
						self_.objectiveDecls[#self_.objectiveDecls + 1] = decls
						self_.includes.objectives = exports
						return decls
					end
					return file
				end,
			}, { __index = lib })
		end,
		["modules/missions/lib/roster.lua"] = function(lib)
			return setmetatable({
				ForFile = function(...)
					local file = lib.ForFile(...)
					local finalize = file.Finalize
					file.Finalize = function(exports, ...)
						local entries, exportNames, declaredGroups = finalize(exports, ...)
						self_.rosters[#self_.rosters + 1] = entries
						self_.includes.units = exports
						return entries, exportNames, declaredGroups
					end
					return file
				end,
			}, { __index = lib })
		end,
		["modules/missions/lib/variables.lua"] = function(lib)
			return setmetatable({
				ForFile = function(...)
					local file = lib.ForFile(...)
					local finalize = file.Finalize
					file.Finalize = function(exports, ...)
						self_.includes.variables = exports
						return finalize(exports, ...)
					end
					return file
				end,
			}, { __index = lib })
		end,
		["modules/placement/api.lua"] = function()
			return {
				NearestValid = function(x, z)
					return x, 0, z
				end,
			}
		end,
	}

	local vfs = {}
	vfs.Include = function(path, fileEnv)
		local source = self_.sources[path]
		if source ~= nil then
			local chunk = source
			if type(source) == "string" then
				chunk = assert(loadstring(source, "@" .. path))
			end
			setfenv(chunk, fileEnv or env)
			return chunk()
		end
		if path == "modules/module_handler.lua" then
			return moduleHandler
		end
		-- So a contribution's own VFS.Include reaches this shim, not the globals.
		if wrapped[path] then
			return wrapped[path](realVFS.Include(path, fileEnv or env))
		end
		return realVFS.Include(path, fileEnv or env)
	end
	vfs.FileExists = function(path)
		if self_.sources[path] ~= nil then
			return true
		end
		if next(self_.sources) ~= nil and path:sub(1, #MISSIONS) == MISSIONS then
			return false
		end
		return realVFS.FileExists(path)
	end
	vfs.DirList = function(dir, pattern)
		if next(self_.sources) ~= nil then
			local found = {}
			for path in pairs(self_.sources) do
				if path:sub(1, #dir) == dir and not path:sub(#dir + 1):find("/") then
					found[#found + 1] = path
				end
			end
			return found
		end
		return realVFS.DirList(dir, pattern)
	end
	vfs.SubDirs = realVFS.SubDirs

	local unitDefNames = setmetatable({}, {
		__index = function(t, name)
			local id = self_.nextDefId
			self_.nextDefId = id + 1
			local def = { id = id, name = name, xsize = 8, zsize = 8, customParams = {} }
			rawset(t, name, def)
			self_.defNames[id] = name
			return def
		end,
	})
	-- Defs come to exist as the roster names them, so a load-time scan sees none.
	local unitDefs = setmetatable({}, {
		__index = function(_, id)
			local name = self_.defNames[id]
			return name and unitDefNames[name] or nil
		end,
	})

	local spring = {
		Echo = function(message)
			self_.echo[#self_.echo + 1] = tostring(message)
		end,
		Log = function(_, level, message)
			self_.log[#self_.log + 1] = tostring(level) .. " " .. tostring(message)
		end,
		GetGameFrame = function()
			return self_.frame
		end,
		GetGameRulesParam = function(name)
			return self_.params[name]
		end,
		GetGameRulesParams = function()
			local all = {}
			for name, value in pairs(self_.params) do
				all[name] = value
			end
			return all
		end,
		SetGameRulesParam = function(name, value)
			self_.params[name] = value
		end,
		GetGaiaTeamID = function()
			return GAIA
		end,
		GetTeamList = function()
			return { PLAYER, ENEMY, GAIA }
		end,
		GetTeamInfo = function(teamID)
			return teamID, 0, false, teamID == ENEMY, "", teamID
		end,
		GetTeamLuaAI = function()
			return ""
		end,
		GetAllyTeamList = function()
			return { PLAYER, ENEMY }
		end,
		GetTeamUnitsByDefs = function(teamID, defID)
			local units = {}
			local defName = self_.defNames[defID]
			for i = 1, ((self_.counts[teamID] or {})[defName] or 0) do
				units[#units + 1] = -i
			end
			for unitID, unit in pairs(self_.units) do
				if unit.team == teamID and unit.def == defName then
					units[#units + 1] = unitID
				end
			end
			return units
		end,
		GetUnitIsBeingBuilt = function()
			return false
		end,
		IsCheatingEnabled = function()
			return false
		end,
		CreateUnit = function(defName, x, y, z, _, teamID)
			return self_:createUnit(defName, teamID, x, y, z)
		end,
		GetUnitPosition = function(unitID)
			local unit = self_.units[unitID]
			if unit == nil then
				return nil
			end
			return unit.x, unit.y, unit.z
		end,
		GetUnitTransporter = function(unitID)
			local unit = self_.units[unitID]
			return unit and unit.carrier or nil
		end,
		GetUnitIsTransporting = function(carrierID)
			local cargo = {}
			for unitID, unit in pairs(self_.units) do
				if unit.carrier == carrierID then
					cargo[#cargo + 1] = unitID
				end
			end
			table.sort(cargo)
			return cargo
		end,
		GetAllUnits = function()
			local ids = {}
			for unitID in pairs(self_.units) do
				ids[#ids + 1] = unitID
			end
			table.sort(ids)
			return ids
		end,
		GetModOptions = function()
			return {}
		end,
		AreTeamsAllied = function(a, b)
			return a == b
		end,
		GetUnitHeight = function()
			return 10
		end,
		GetUnitVelocity = function()
			return 0, 0, 0, 0
		end,
		SetUnitVelocity = function() end,
		GetUnitDirection = function()
			return 0, 0, 1, 0, 0, 0
		end,
		SetUnitPhysics = function() end,
		SetUnitDirection = function() end,
		SetUnitStealth = function() end,
		SetUnitLeavesGhost = function() end,
		GetUnitRulesParam = function()
			return nil
		end,
		GetUnitIsDead = function(unitID)
			return self_.units[unitID] == nil
		end,
		GetUnitMoveTypeData = function()
			return {}
		end,
		GetUnitCommandCount = function()
			return 0
		end,
		GetGroundNormal = function()
			return 0, 1, 0
		end,
		UnitDetach = function() end,
		AddUnitDamage = function() end,
		DestroyUnit = function(unitID)
			self_.units[unitID] = nil
		end,
		ValidUnitID = function(unitID)
			return self_.units[unitID] ~= nil
		end,
		GetTeamUnits = function(teamID)
			local ids = {}
			for unitID, unit in pairs(self_.units) do
				if unit.team == teamID then
					ids[#ids + 1] = unitID
				end
			end
			table.sort(ids)
			return ids
		end,
		GetUnitDefID = function(unitID)
			local unit = self_.units[unitID]
			return unit and unitDefNames[unit.def].id or nil
		end,
		GetUnitTeam = function(unitID)
			local unit = self_.units[unitID]
			return unit and unit.team or nil
		end,
		SetUnitNeutral = function(unitID, neutral)
			self_.units[unitID].neutral = neutral
		end,
		GetUnitNeutral = function(unitID)
			local unit = self_.units[unitID]
			return unit ~= nil and unit.neutral
		end,
		GiveOrderToUnit = function(unitID, cmd, params)
			local unit = self_.units[unitID]
			if unit then
				unit.orders[#unit.orders + 1] = { cmd = cmd, params = params }
			end
		end,
		GetGroundHeight = function()
			return 0
		end,
		IsUnitInLos = function()
			return false
		end,
	}

	env = setmetatable({
		VFS = vfs,
		Spring = spring,
		BAR = { Utilities = { Gametype = {
			IsSinglePlayer = function()
				return true
			end,
		} } },
		UnitDefNames = unitDefNames,
		UnitDefs = unitDefs,
		GG = {},
		Game = { mapSizeX = 8192, mapSizeZ = 8192, gameSpeed = 30, envDamageTypes = {} },
		CMD = { FIRE_STATE = 45, STOP = 0, MOVE = 10, LOAD_UNITS = 75, UNLOAD_UNITS = 80, UNLOAD_UNIT = 81 },
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
			RegisterAllowCommand = function() end,
			RegisterCMDID = function() end,
			AddChatAction = function(_, name, fn)
				self_.actions[name] = fn
			end,
			RemoveChatAction = function(_, name)
				self_.actions[name] = nil
			end,
			UpdateCallIn = function() end,
		},
	}, { __index = _G })
	self.env = env

	realModuleHandler.ResetCaches()

	-- Wired gadgets first: they publish the GG surface their apis read.
	for _, module in ipairs(self.modules) do
		local gadgetEnv = setmetatable({ gadget = {} }, { __index = env })
		realVFS.Include(module.gadgetPath, gadgetEnv)
		assert(type(gadgetEnv.gadget.Initialize) == "function", module.gadgetPath .. " did not load")
		gadgetEnv.gadget:Initialize()
		self.gadgets[#self.gadgets + 1] = gadgetEnv.gadget
		self.apis[module.name] = realVFS.Include("modules/" .. module.name .. "/api.lua", env)
	end

	realVFS.Include(LOADER, env)
	assert(type(env.gadget.Initialize) == "function", "the mission loader did not load")
	self.gadget = env.gadget
	self.gadget:Initialize()
	return self
end

return MissionBuilder
