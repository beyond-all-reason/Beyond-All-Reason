---@diagnostic disable: undefined-field

local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local GADGET_PATH = "luarules/gadgets/api_missions_triggers.lua"
local UNITS_OWNED = 7
local OUTPOST = 1
local TURRET = 2
local PAWN = 3
local COMMANDER = 4

local unitDefs = {
	[OUTPOST] = { id = OUTPOST, name = "outpost", xsize = 2, zsize = 2 },
	[TURRET] = { id = TURRET, name = "turret" },
	[PAWN] = { id = PAWN, name = "armpw" },
	[COMMANDER] = { id = COMMANDER, name = "armcom" },
}
---@type table<string, table>
local unitDefNames = {
	outpost = unitDefs[OUTPOST],
	turret = unitDefs[TURRET],
	armpw = unitDefs[PAWN],
	armcom = unitDefs[COMMANDER],
}
-- Unit types that create another unit in their own UnitCreated, as pve_attachments.lua does.
local attachments = { [OUTPOST] = TURRET } ---@type table<UnitDefID, UnitDefID?>

-- The modules keep the engine calls they make at load, so the stubs read this table.
---@type table<integer, { unitDefID: integer, teamID: integer }>
local units = {}

local gadget ---@type Gadget
local lastUnitID = 0

-- gadgetHandler:UnitCreated, which runs MetaUnitAdded first.
local function createUnit(unitDefName, x, y, z, facing, teamID)
	lastUnitID = lastUnitID + 1
	local unitID = lastUnitID
	local unitDefID = unitDefNames[unitDefName].id
	units[unitID] = { unitDefID = unitDefID, teamID = teamID }
	gadget:MetaUnitAdded(unitID, unitDefID, teamID)
	gadget:UnitCreated(unitID, unitDefID, teamID)
	if attachments[unitDefID] then
		createUnit(unitDefs[attachments[unitDefID]].name, x, y, z, facing, teamID)
	end
	return unitID
end

local env = MissionSpecEnv.new({
	gadget = {},
	gadgetHandler = {
		IsSyncedCode = function()
			return true
		end,
		RemoveCallIn = function() end,
		RemoveGadget = function() end,
	},
	Game = { squareSize = 8, footprintScale = 2 },
	Spring = {
		GetGameRulesParam = function(name)
			return name == "inMission"
		end,
		GetGameFrame = function()
			return 0
		end,
		GetGroundHeight = function()
			return 0
		end,
		GetHeadingFromFacing = function(facing)
			return facing * 16384
		end,
		GetAllUnits = function()
			local unitIDs = {}
			for unitID in pairs(units) do
				unitIDs[#unitIDs + 1] = unitID
			end
			table.sort(unitIDs)
			return unitIDs
		end,
		GetTeamUnits = function(teamID)
			local unitIDs = {}
			for unitID, unit in pairs(units) do
				if unit.teamID == teamID then
					unitIDs[#unitIDs + 1] = unitID
				end
			end
			table.sort(unitIDs)
			return unitIDs
		end,
		GetUnitDefID = function(unitID)
			return units[unitID].unitDefID
		end,
		GetUnitTeam = function(unitID)
			return units[unitID].teamID
		end,
		GetUnitIsBeingBuilt = function()
			return false
		end,
		GetUnitIsDead = function()
			return false
		end,
		CreateUnit = createUnit,
	},
})
env.UnitDefs = unitDefs
env.UnitDefNames = unitDefNames
env.BAR = { Utilities = MissionSpecEnv.include(env, "common/springUtilities/facingFunctions.lua") }

describe("api_missions_triggers loadout names", function()
	local missionApi, loadout ---@type table, table

	local function unitsOwned(unitName, atLeast)
		return {
			type = UNITS_OWNED,
			parameters = { teamName = 0, unitName = unitName },
			atLeast = atLeast,
			settings = { active = true, prerequisites = {}, stages = {}, repeating = true },
			actions = {},
			triggered = false,
			repeatCount = 0,
			occurrences = 0,
			metricSatisfied = false,
		}
	end

	-- The gadget's activateTrigger counts each firing on the trigger.
	local function firedTriggerIDs()
		local triggerIDs = {}
		for triggerID, trigger in pairs(missionApi.Triggers) do
			if trigger.repeatCount > 0 then
				triggerIDs[#triggerIDs + 1] = triggerID
			end
		end
		table.sort(triggerIDs)
		return triggerIDs
	end

	before_each(function()
		missionApi = MissionApiBuilder.new()
			:WithConditionDefinitions({
				Types = { UnitsOwned = UNITS_OWNED },
				Kinds = { [UNITS_OWNED] = "metric" },
				Callins = {},
			})
			:WithActionDefinitions({ Functions = {}, Parameters = {} })
			:WithTrigger("oneOutpost", unitsOwned("outpost", 1))
			:WithTrigger("twoOutposts", unitsOwned("outpost", 2))
			:WithModule("SeismicContacts", { UpdateInterval = 15 })
			:Install(env)
		missionApi.Modules.DerivedNames = MissionSpecEnv.include(env, "luarules/mission_api/derived_names.lua")

		---@diagnostic disable -- return_overload doesn't work here, emmylua has no idea what our lua builtins are
		local chunk = assert(loadfile(GADGET_PATH))
		setfenv(chunk, env)
		chunk()
		---@diagnostic enable

		gadget = env.gadget ---@as Gadget
		gadget:Initialize()

		loadout = MissionSpecEnv.include(env, "luarules/mission_api/loadout.lua")
	end)

	it("counts a spawned unit under its loadout name, and not a unit created in its call-ins", function()
		loadout.SpawnUnitLoadout({
			{ unitDefName = "outpost", unitName = "outpost", position = { x = 0, z = 0 }, teamName = 0 },
		})

		assert.are.same({ "oneOutpost" }, firedTriggerIDs())
	end)
end)

-- Drives the gadget's MetaUnit, transfer, and finish call-ins in the order gadgets.lua calls them.
describe("api_missions_triggers derived name wiring", function()
	local missionApi, derivedNames ---@type table, table

	local function unitsOwned(teamID, atLeast, atMost)
		return {
			type = UNITS_OWNED,
			parameters = { teamName = teamID, unitName = "army" },
			atLeast = atLeast,
			atMost = atMost,
			settings = { active = true, prerequisites = {}, stages = {}, repeating = true },
			actions = {},
			triggered = false,
			repeatCount = 0,
		}
	end

	local function members()
		local unitIDs = missionApi.Modules.UnitQuery.MatchingUnits("army")
		table.sort(unitIDs)
		return unitIDs
	end

	-- gadgetHandler:UnitTaken and :UnitGiven, with the engine's team change between them.
	local function transfer(unitID, newTeamID)
		local unit = units[unitID]
		local oldTeamID = unit.teamID
		gadget:MetaUnitRemoved(unitID, unit.unitDefID, oldTeamID)
		gadget:UnitTaken(unitID, unit.unitDefID, oldTeamID, newTeamID)
		unit.teamID = newTeamID
		gadget:MetaUnitAdded(unitID, unit.unitDefID, newTeamID)
		gadget:UnitGiven(unitID, unit.unitDefID, newTeamID, oldTeamID)
	end

	-- gadgetHandler:UnitCreated and :UnitFinished for a unit spawned finished, inside spawnUnit's CreateUnit.
	local function spawn(unitID, unitDefID, unitName)
		units[unitID] = { unitDefID = unitDefID, teamID = 0 }
		missionApi.nameOfUnitBeingSpawned = unitName
		missionApi.unitIDBeingSpawned = nil
		gadget:MetaUnitAdded(unitID, unitDefID, 0)
		gadget:UnitCreated(unitID, unitDefID, 0)
		gadget:UnitFinished(unitID, unitDefID, 0)
		missionApi.nameOfUnitBeingSpawned = nil
		missionApi.unitIDBeingSpawned = nil
		missionApi.Modules.Tracking.TrackUnit(unitName, unitID)
	end

	before_each(function()
		for unitID in pairs(units) do
			units[unitID] = nil
		end
		units[100] = { unitDefID = COMMANDER, teamID = 0 }
		units[102] = { unitDefID = PAWN, teamID = 0 }

		missionApi = MissionApiBuilder.new()
			:WithTrackedUnit("commander", 100)
			:WithConditionDefinitions({
				Types = { UnitsOwned = UNITS_OWNED },
				Kinds = { [UNITS_OWNED] = "metric" },
				Callins = {},
			})
			:WithActionDefinitions({ Functions = {}, Parameters = {} })
			:WithTrigger("playerArmyGone", unitsOwned(0, nil, 0))
			:WithTrigger("playerArmyOfTwo", unitsOwned(0, 2))
			:WithTrigger("enemyArmy", unitsOwned(1, 1))
			:WithModule("SeismicContacts", { UpdateInterval = 15 })
			:Install(env)
		missionApi.Modules.DerivedNames = MissionSpecEnv.include(env, "luarules/mission_api/derived_names.lua")
		derivedNames = missionApi.Modules.DerivedNames

		---@diagnostic disable -- return_overload doesn't work here, emmylua has no idea what our lua builtins are
		local chunk = assert(loadfile(GADGET_PATH))
		setfenv(chunk, env)
		chunk()
		---@diagnostic enable

		gadget = env.gadget ---@as Gadget
		gadget:Initialize()

		derivedNames.AddDerivedUnitName("army", { teamName = 0 }, { { unitName = "commander" } })
	end)

	-- The gadget's activateTrigger counts each firing on the trigger.
	local function firedTriggerIDs()
		local triggerIDs = {}
		for triggerID, trigger in pairs(missionApi.Triggers) do
			if trigger.repeatCount > 0 then
				triggerIDs[#triggerIDs + 1] = triggerID
			end
		end
		table.sort(triggerIDs)
		return triggerIDs
	end

	it("counts a member given away once, on the team it left", function()
		transfer(102, 1)

		assert.are.same({}, members())
		assert.are.same({ "playerArmyGone" }, firedTriggerIDs())
	end)

	it("counts a unit given to the filter's team once, on the team it joined", function()
		units[103] = { unitDefID = PAWN, teamID = 1 }

		transfer(103, 0)

		assert.are.same({ 102, 103 }, members())
		assert.are.same({ "playerArmyOfTwo" }, firedTriggerIDs())
	end)

	it("counts a spawned unit once, and never one spawned with an excepted name", function()
		spawn(104, COMMANDER, "commander")
		assert.are.same({ 102 }, members())
		assert.are.same({}, firedTriggerIDs())

		spawn(105, PAWN, nil)
		assert.are.same({ 102, 105 }, members())
		assert.are.same({ "playerArmyOfTwo" }, firedTriggerIDs())
	end)
end)
