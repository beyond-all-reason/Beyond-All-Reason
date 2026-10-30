---@diagnostic disable: undefined-field

-- Boots the triggers gadget, as the code under test is its own MetaUnitAdded: it reads the
-- names spawnUnit publishes, and a trigger it runs first can spawn units of its own.

local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local TriggerBuilder = VFS.Include("spec/builders/trigger_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local GADGET_PATH = "luarules/gadgets/api_missions_triggers.lua"
local BOT_DEF_ID = 1

local gadget = {}
local lastUnitID = 0
-- The actions the triggers fired.
---@type table<integer, string>
local invoked = {}
-- What an action does when it fires, by action ID.
---@type table<string, function|nil>
local actionFunctions = {}

local env = MissionSpecEnv.new({
	Game = { squareSize = 8 },
	UnitDefNames = { bot = { xsize = 4, zsize = 4 } },
	UnitDefs = { [BOT_DEF_ID] = { name = "bot" } },
	Spring = {
		GetGroundHeight = function()
			return 0
		end,
		-- The engine calls MetaUnitAdded inside CreateUnit.
		CreateUnit = function(_, _, _, _, _, teamID)
			lastUnitID = lastUnitID + 1
			gadget:MetaUnitAdded(lastUnitID, BOT_DEF_ID, teamID)
			return lastUnitID
		end,
		GiveOrderArrayToUnit = function() end,
	},
	gadgetHandler = {
		IsSyncedCode = function()
			return true
		end,
		RemoveGadget = function() end,
		RemoveCallIn = function() end,
	},
	includes = {
		["luarules/mission_api/actions_dispatcher.lua"] = {
			Invoke = function(actionID)
				invoked[#invoked + 1] = actionID
				if actionFunctions[actionID] then
					actionFunctions[actionID]()
				end
			end,
		},
	},
})
env.BAR = { Utilities = MissionSpecEnv.include(env, "common/springUtilities/facingFunctions.lua") }

MissionApiBuilder.new():Install()
local loadout = MissionSpecEnv.include(env, "luarules/mission_api/loadout.lua")
local unitExists = MissionSpecEnv.include(env, "luarules/mission_api/triggers/unit_exists.lua")

local function trigger(triggerType, parameters, actionID, repeating)
	local built = TriggerBuilder.new():WithParameters(parameters):WithSettings({ repeating = repeating }):Build()
	built.type = triggerType
	built.actions = { actionID }
	return built
end

local function unitsOwned(unitName, quantity, actionID)
	return trigger("UnitsOwned", { teamID = 0, unitName = unitName, quantity = quantity }, actionID, true)
end

-- A fresh gadget, so the counts of the statistics module start at zero.
local function startMission(triggers)
	local builder = MissionApiBuilder.new()
		:WithTriggerDefinitions({
			Types = { UnitsOwned = "UnitsOwned", UnitExists = "UnitExists" },
			Callins = { MetaUnitAdded = { UnitExists = unitExists.callins.MetaUnitAdded } },
		})
		:WithModule("SeismicContacts", { UpdateInterval = 1 })
	for triggerID, definition in pairs(triggers) do
		builder:WithTrigger(triggerID, definition)
	end
	builder:Install()

	gadget = {}
	env.gadget = gadget
	MissionSpecEnv.include(env, GADGET_PATH)
	gadget:Initialize()
end

local function spawnSquadMember()
	loadout.SpawnUnitLoadout({
		{ unitDefName = "bot", x = 0, z = 0, team = 0, unitName = "squad", alsoNamed = { "Lab1" } },
	})
end

describe("api_missions_triggers MetaUnitAdded", function()
	before_each(function()
		invoked = {}
		actionFunctions = {}
	end)

	it("counts a spawned unit under the names in its alsoNamed", function()
		startMission({ labOwned = unitsOwned("Lab1", 1, "labOwned") })

		spawnSquadMember()

		assert.are.same({ "labOwned" }, invoked)
	end)

	it("fires a UnitsOwned of 0 on such a name when the unit is removed", function()
		startMission({ labLost = unitsOwned("Lab1", 0, "labLost") })

		spawnSquadMember()
		assert.are.same({}, invoked)

		gadget:MetaUnitRemoved(lastUnitID, BOT_DEF_ID, 0)

		assert.are.same({ "labLost" }, invoked)
	end)

	it("does not count a unit added later under the names of the one spawned before", function()
		startMission({ labOwned = unitsOwned("Lab1", 1, "labOwned") })
		spawnSquadMember()

		-- A second count would reach the next milestone (2) and fire again.
		gadget:MetaUnitAdded(lastUnitID + 1, BOT_DEF_ID, 0)

		assert.are.same({ "labOwned" }, invoked)
	end)

	it("keeps the names when a trigger spawns units inside the unit's CreateUnit", function()
		actionFunctions.spawnWave = function()
			loadout.SpawnUnitLoadout({ { unitDefName = "bot", x = 0, z = 0, team = 0, unitName = "wave" } })
		end
		startMission({
			botSeen = trigger("UnitExists", { unitDefName = "bot" }, "spawnWave", false),
			labOwned = unitsOwned("Lab1", 1, "labOwned"),
			squadOwned = unitsOwned("squad", 1, "squadOwned"),
		})

		spawnSquadMember()

		table.sort(invoked)
		assert.are.same({ "labOwned", "spawnWave", "squadOwned" }, invoked)
	end)
end)
