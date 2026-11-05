---@diagnostic disable: undefined-field

local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local GADGET_PATH = "luarules/gadgets/api_dynamic_build_options.lua"

local CMD_MOVE = 10

local SOLAR = 42
local WIND = 43
local PAWN = 44
local CON_BOT = 7
local BOT_LAB = 9

local UNIT_DEFS = {
	[SOLAR] = { name = "armsolar", maxThisUnit = 1000 },
	[WIND] = { name = "armwin", maxThisUnit = 1000 },
	[PAWN] = { name = "armpw", maxThisUnit = 1000 },
	[CON_BOT] = { name = "armck", isBuilder = true, buildOptions = { SOLAR, WIND } },
	[BOT_LAB] = { name = "armlab", isBuilder = true, isFactory = true, buildOptions = { PAWN } },
}

-- A world of two teams: a construction bot on team 0, a construction bot and a bot lab on team 1.
local function newWorld()
	local world = { units = {}, sent = {}, gameRulesParams = {}, teamRulesParams = { [0] = {}, [1] = {} } }

	function world.addUnit(unitID, unitDefID, teamID)
		local cmdDescs = { { id = CMD_MOVE } }
		for _, builtUnitDefID in ipairs(UNIT_DEFS[unitDefID].buildOptions or {}) do
			cmdDescs[#cmdDescs + 1] = { id = -builtUnitDefID }
		end
		world.units[unitID] = { unitDefID = unitDefID, teamID = teamID, cmdDescs = cmdDescs }
	end

	world.addUnit(100, CON_BOT, 0)
	world.addUnit(101, CON_BOT, 1)
	world.addUnit(102, BOT_LAB, 1)
	return world
end

local function teamUnitsOfDef(world, teamID, unitDefID)
	local unitIDs = {}
	for unitID, unit in pairs(world.units) do
		if unit.teamID == teamID and unit.unitDefID == unitDefID then
			unitIDs[#unitIDs + 1] = unitID
		end
	end
	table.sort(unitIDs)
	return unitIDs
end

local function newSpring(world)
	local function findCmdDesc(unitID, cmdID)
		for index, cmdDesc in ipairs(world.units[unitID].cmdDescs) do
			if cmdDesc.id == cmdID then
				return index
			end
		end
	end

	return {
		FindUnitCmdDesc = findCmdDesc,
		InsertUnitCmdDesc = function(unitID, index, cmdDesc)
			local cmdDescs = world.units[unitID].cmdDescs
			if cmdDesc == nil then
				cmdDescs[#cmdDescs + 1] = index
			else
				table.insert(cmdDescs, index, cmdDesc)
			end
		end,
		RemoveUnitCmdDesc = function(unitID, index)
			table.remove(world.units[unitID].cmdDescs, index)
		end,
		GetUnitCmdDescs = function(unitID)
			return world.units[unitID].cmdDescs
		end,
		GetTeamList = function()
			return { 0, 1 }
		end,
		GetTeamUnitDefCount = function(teamID, unitDefID)
			return #teamUnitsOfDef(world, teamID, unitDefID)
		end,
		GetTeamUnitsByDefs = function(teamID, unitDefID)
			return teamUnitsOfDef(world, teamID, unitDefID)
		end,
		SetGameRulesParam = function(name, value)
			world.gameRulesParams[name] = value
		end,
		GetGameRulesParam = function(name)
			return world.gameRulesParams[name]
		end,
		SetTeamRulesParam = function(teamID, name, value)
			world.teamRulesParams[teamID][name] = value
		end,
		GetTeamRulesParam = function(teamID, name)
			return world.teamRulesParams[teamID][name]
		end,
		Log = function() end,
	}
end

local function loadGadget(world)
	local env = SpecEnv.new({
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
		},
		SendToUnsynced = function(...)
			world.sent[#world.sent + 1] = { ... }
		end,
		CMDTYPE = { ICON = 0, ICON_BUILDING = 1 },
		LOG = { WARNING = "warning" },
		UnitDefs = UNIT_DEFS,
		Spring = newSpring(world),
	})
	SpecEnv.include(env, GADGET_PATH)
	env.gadget:Initialize()
	return env.gadget, env.GG.DynamicBuildOptions, env
end

local function hasOption(world, unitID, builtUnitDefID)
	for _, cmdDesc in ipairs(world.units[unitID].cmdDescs) do
		if cmdDesc.id == -builtUnitDefID then
			return true
		end
	end
	return false
end

describe("api_dynamic_build_options", function()
	local world, gadget, buildOptions, env

	before_each(function()
		world = newWorld()
		gadget, buildOptions, env = loadGadget(world)
	end)

	describe("for one team", function()
		it("takes the option off that team's units only", function()
			buildOptions.Remove(SOLAR, CON_BOT, 1)

			assert.is_false(hasOption(world, 101, SOLAR))
			assert.is_true(hasOption(world, 100, SOLAR))
			assert.is_false(buildOptions.HasBuildOption(SOLAR, CON_BOT, 1))
			assert.is_true(buildOptions.HasBuildOption(SOLAR, CON_BOT, 0))
			assert.is_true(buildOptions.HasBuildOption(SOLAR, CON_BOT))
		end)

		it("adds the option to that team's units only", function()
			buildOptions.Add(SOLAR, BOT_LAB, 1, 1)

			assert.is_true(hasOption(world, 102, SOLAR))
			assert.are.same({ CMD_MOVE, -SOLAR, -PAWN }, {
				world.units[102].cmdDescs[1].id,
				world.units[102].cmdDescs[2].id,
				world.units[102].cmdDescs[3].id,
			})
			assert.is_true(buildOptions.HasBuildOption(SOLAR, BOT_LAB, 1))
			assert.is_false(buildOptions.HasBuildOption(SOLAR, BOT_LAB, 0))
		end)

		it("is undone by adding the option back for the team", function()
			buildOptions.Remove(SOLAR, CON_BOT, 1)
			buildOptions.Add(SOLAR, CON_BOT, nil, 1)

			assert.is_true(hasOption(world, 101, SOLAR))
			assert.is_true(buildOptions.HasBuildOption(SOLAR, CON_BOT, 1))
			assert.is_nil(world.teamRulesParams[1].dynamic_build_options)
		end)

		it("takes the option off every builder type of the team at once", function()
			buildOptions.Remove(SOLAR, nil, 1)

			assert.is_false(hasOption(world, 101, SOLAR))
			assert.is_true(hasOption(world, 100, SOLAR))
			assert.is_false(buildOptions.HasBuildOption(SOLAR, CON_BOT, 1))
			assert.are.equal(1, #world.sent)
			assert.are.equal("7:42:0", world.teamRulesParams[1].dynamic_build_options)
		end)

		it("gives every builder type of the team back what it has for all teams", function()
			buildOptions.Remove(SOLAR, nil, 1)
			buildOptions.Add(SOLAR, nil, nil, 1)

			assert.is_true(hasOption(world, 101, SOLAR))
			assert.is_false(hasOption(world, 102, SOLAR))
			assert.is_nil(world.teamRulesParams[1].dynamic_build_options)
		end)

		it("applies to the team's new units", function()
			buildOptions.Remove(SOLAR, CON_BOT, 1)
			world.addUnit(103, CON_BOT, 1)
			world.addUnit(104, CON_BOT, 0)
			gadget:UnitCreated(103, CON_BOT, 1)
			gadget:UnitCreated(104, CON_BOT, 0)

			assert.is_false(hasOption(world, 103, SOLAR))
			assert.is_true(hasOption(world, 104, SOLAR))
		end)

		it("follows a unit given to another team", function()
			buildOptions.Remove(SOLAR, CON_BOT, 1)
			world.units[101].teamID = 0
			gadget:UnitGiven(101, CON_BOT, 0, 1)
			world.units[100].teamID = 1
			gadget:UnitGiven(100, CON_BOT, 1, 0)

			assert.is_true(hasOption(world, 101, SOLAR))
			assert.is_false(hasOption(world, 100, SOLAR))
		end)

		it("clears the team's rules param when a change for all teams replaces its own", function()
			buildOptions.Remove(SOLAR, CON_BOT, 1)
			buildOptions.Add(SOLAR, CON_BOT)

			assert.is_nil(world.teamRulesParams[1].dynamic_build_options)
		end)

		it("is replaced by a later change for every team", function()
			buildOptions.Remove(SOLAR, CON_BOT, 1)
			buildOptions.Add(SOLAR, CON_BOT)

			assert.is_true(hasOption(world, 101, SOLAR))
			assert.is_true(buildOptions.HasBuildOption(SOLAR, CON_BOT, 1))
		end)
	end)

	describe("publishing", function()
		it("keeps a team's own changes in its team rules param", function()
			buildOptions.Remove(SOLAR, CON_BOT, 1)
			buildOptions.Remove(WIND, CON_BOT)

			assert.are.equal("7:42:0", world.teamRulesParams[1].dynamic_build_options)
			assert.is_nil(world.teamRulesParams[0].dynamic_build_options)
			assert.are.equal("7:43:0", world.gameRulesParams.dynamic_build_options)
		end)

		it("reads a team's changes over the ones for every team", function()
			buildOptions.Remove(SOLAR, CON_BOT, 1)
			buildOptions.Remove(WIND, CON_BOT)
			buildOptions.Add(WIND, CON_BOT, nil, 1)
			local changes = SpecEnv.include(env, "common/dynamicBuildOptions.lua")

			assert.are.same({ [CON_BOT] = { [WIND] = false } }, changes.getChanges())
			assert.are.same({ [CON_BOT] = { [SOLAR] = false, [WIND] = true } }, changes.getChanges(1))
		end)

		it("tells LuaUI which team a change is for", function()
			buildOptions.Remove(SOLAR, CON_BOT, 1)
			buildOptions.Remove(WIND, CON_BOT)

			assert.are.same({ "DynamicBuildOptionsChanged", CON_BOT, SOLAR, false, 1 }, world.sent[1])
			assert.are.same({ "DynamicBuildOptionsChanged", CON_BOT, WIND, false }, world.sent[2])
		end)
	end)
end)
