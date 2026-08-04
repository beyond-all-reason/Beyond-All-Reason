--- Mission roster DSL: units.lua's authoring surface. Pure Lua — no Spring —
--- so it specs under busted; Named/Grouped are the only definition sites for names trigger files validate against.

local Roster = {}

local VALID_ROLES = { player = true, enemy = true, gaia = true }

---Build one roster file's authoring surface: the Spawn and Claim chain
---entries the loader injects, and the Finalize the loader calls after the
---include.
---@param filename string mission-relative path, e.g. "cm8_ashfall/units.lua"
---@return { Spawn: fun(unitDef: MissionUnitDefRef, team: MissionTeamRole): MissionSpawnChain, Claim: fun(unitDef: MissionUnitDefRef, team: MissionTeamRole): MissionClaimChain, Finalize: fun(): MissionRosterEntry[] }
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
		assert(type(unitDef) == "table" and type(unitDef.name) == "string",
			filename .. ": Spawn expects a UnitDef(...) reference")
		assert(type(team) == "string" and VALID_ROLES[team],
			filename .. ': Spawn expects a team role: "player", "enemy" or "gaia"')

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
			assert(type(fx) == "number" and type(fz) == "number"
					and fx >= 0 and fx <= 1 and fz >= 0 and fz <= 1,
				filename .. ": At expects map fractions in 0..1")
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

		---Standing there, not taking part. A derelict the player is meant to
		---walk up to and inherit must not shoot them on the way in, and an
		---abandoned base on Gaia does exactly that by default — Gaia is hostile
		---to everyone, so its towers open fire on the discovery the mission was
		---built around.
		---
		---Only a starting state, and one the mission does not have to undo:
		---the engine drops the flag when a unit changes hands, so an inherited
		---base defends its new owner without being told to.
		---@return MissionSpawnChain
		chain.Neutral = function()
			checkOpen("Neutral")
			build.neutral = true
			return chain
		end

		return chain
	end

	---Take a unit the team already has, rather than adding another. A mission
	---dropped into a skirmish finds the enemy seat already occupied — spawning
	---its own commander there leaves that team with two, and the mission's
	---story with one too many. Claim binds the mission's name to whatever is
	---already standing, and only builds one when the seat really is empty.
	---
	---Ownership follows the outcome, which is the whole reason this is a
	---separate verb rather than a flag: a claimed unit belongs to the team that
	---already had it and must survive a reload, while one spawned to fill a gap
	---is the mission's to clean up.
	---@param unitDef MissionUnitDefRef
	---@param team MissionTeamRole
	---@return MissionClaimChain
	local Claim = function(unitDef, team)
		checkOpen("Claim")
		assert(type(unitDef) == "table" and type(unitDef.name) == "string",
			filename .. ": Claim expects a UnitDef(...) reference")
		assert(type(team) == "string" and VALID_ROLES[team],
			filename .. ': Claim expects a team role: "player", "enemy" or "gaia"')

		local build = { def = unitDef.name, team = team, claim = true }
		builds[#builds + 1] = build

		local chain = {}

		---@param name string
		---@return MissionClaimChain
		chain.Named = function(name)
			checkOpen("Named")
			assert(type(name) == "string", filename .. ": Named expects a unit name string")
			build.name = name
			return chain
		end

		---@param group string
		---@return MissionClaimChain
		chain.Grouped = function(group)
			checkOpen("Grouped")
			assert(type(group) == "string", filename .. ": Grouped expects a group name string")
			build.group = group
			return chain
		end

		---Where to build one if the team has none. Required: a mission that
		---cannot say what to do with an empty seat cannot arm in its own
		---single-player game, which is the game it was written for.
		---@param fx number
		---@param fz number
		---@return MissionClaimChain
		chain.OrSpawnAt = function(fx, fz)
			checkOpen("OrSpawnAt")
			assert(type(fx) == "number" and type(fz) == "number"
					and fx >= 0 and fx <= 1 and fz >= 0 and fz <= 1,
				filename .. ": OrSpawnAt expects map fractions in 0..1")
			build.fx, build.fz = fx, fz
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
			local where = filename .. ": " .. (build.claim and "Claim " or "Spawn ") .. order
			if build.fx == nil then
				if build.claim then
					error(where .. " has no OrSpawnAt — say where to build one when the team has none")
				end
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

	return { Spawn = Spawn, Claim = Claim, Finalize = Finalize }
end

return Roster
