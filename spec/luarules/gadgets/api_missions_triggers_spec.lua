---@diagnostic disable: undefined-field

local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local GADGET_PATH = "luarules/gadgets/api_missions_triggers.lua"
local UNITS_OWNED = 7
local OUTPOST = 1
local TURRET = 2

local unitDefs = {
	[OUTPOST] = { id = OUTPOST, name = "outpost", xsize = 2, zsize = 2 },
	[TURRET] = { id = TURRET, name = "turret" },
}
local unitDefNames = { outpost = unitDefs[OUTPOST], turret = unitDefs[TURRET] } ---@type table<string, table>
-- Unit types that create another unit in their own UnitCreated, as pve_attachments.lua does.
local attachments = { [OUTPOST] = TURRET } ---@type table<UnitDefID, UnitDefID?>

local gadget ---@type Gadget
local lastUnitID = 0

-- gadgetHandler:UnitCreated, which runs MetaUnitAdded first.
local function createUnit(unitDefName, x, y, z, facing, teamID)
	lastUnitID = lastUnitID + 1
	local unitID = lastUnitID
	local unitDefID = unitDefNames[unitDefName].id
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
		GetUnitIsBeingBuilt = function()
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

	-- The gadget's own activateTrigger counts each firing on the trigger.
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
