--- Mission roster DSL: units.lua's authoring surface. Pure Lua — no Spring —
--- so it specs under busted; Named/Grouped are the only definition sites for names trigger files validate against.

local Roster = {}

local VALID_ROLES = { player = true, enemy = true, gaia = true }

---Build one roster file's authoring surface: the Spawn chain entry the
---loader injects, and the Finalize the loader calls after the include.
---@param filename string mission-relative path, e.g. "cm8_ashfall/units.lua"
---@return { Spawn: fun(unitDef: MissionUnitDefRef, team: MissionTeamRole): MissionSpawnChain, Finalize: fun(): MissionRosterEntry[] }
function Roster.ForFile(filename)
	local builds = {} ---@type MissionRosterEntry[]
	local finalized = false

	local function checkOpen(step)
		assert(not finalized, filename .. ": " .. step .. " after Finalize — the file already loaded")
	end

	---@param unitDef MissionUnitDefRef
	---@param team MissionTeamRole
	---@return MissionSpawnChain
	local Spawn = function(unitDef, team)
		checkOpen("Spawn")
		assert(
			type(unitDef) == "table" and type(unitDef.name) == "string",
			filename .. ": Spawn expects a UnitDef(...) reference"
		)
		assert(
			type(team) == "string" and VALID_ROLES[team],
			filename .. ': Spawn expects a team role: "player", "enemy" or "gaia"'
		)

		local build = { def = unitDef.name, team = team }
		builds[#builds + 1] = build

		local chain = {}

		---Position as map fractions, so rosters play on any map until real
		---maps pin real coordinates.
		---@param fx number
		---@param fz number
		---@return MissionSpawnChain
		chain.At = function(fx, fz)
			checkOpen("At")
			assert(
				type(fx) == "number" and type(fz) == "number" and fx >= 0 and fx <= 1 and fz >= 0 and fz <= 1,
				filename .. ": At expects map fractions in 0..1"
			)
			build.fx, build.fz = fx, fz
			return chain
		end

		---@param name string
		---@return MissionSpawnChain
		chain.Named = function(name)
			checkOpen("Named")
			assert(type(name) == "string", filename .. ": Named expects a unit name string")
			build.name = name
			return chain
		end

		---@param group string
		---@return MissionSpawnChain
		chain.Grouped = function(group)
			checkOpen("Grouped")
			assert(type(group) == "string", filename .. ": Grouped expects a group name string")
			build.group = group
			return chain
		end

		return chain
	end

	---The commit point: validates every chain, in declaration order — a
	---failed load spawns nothing.
	---@return MissionRosterEntry[]
	local Finalize = function()
		assert(not finalized, filename .. ": Finalize called twice")
		finalized = true
		local seenNames = {}
		for order, build in ipairs(builds) do
			local where = filename .. ": Spawn " .. order
			if build.fx == nil then
				error(where .. " has no At — every spawn needs a position")
			end
			if build.name ~= nil then
				if seenNames[build.name] then
					error(where .. ": duplicate unit name " .. build.name)
				end
				seenNames[build.name] = true
			end
		end
		return builds
	end

	return { Spawn = Spawn, Finalize = Finalize }
end

return Roster
