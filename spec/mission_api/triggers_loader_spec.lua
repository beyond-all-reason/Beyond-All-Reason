require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

local triggerDefinitions = VFS.Include('luarules/mission_api/triggers_loader.lua').LoadTriggerDefinitions()

describe("triggers_loader.LoadTriggerDefinitions (smoke)", function()
	it("registers all 27 trigger types", function()
		local count = 0
		for _ in pairs(triggerDefinitions.Types) do count = count + 1 end
		assert.are.equal(27, count)
	end)

	it("maps callins to the correct trigger types", function()
		local T = triggerDefinitions.Types
		local C = triggerDefinitions.Callins

		-- GameFrame drives time/location/resource triggers:
		assert.is_function(C.GameFrame[T.TimeElapsed])
		assert.is_function(C.GameFrame[T.ResourceStored])
		assert.is_function(C.GameFrame[T.ResourceIncome])
		assert.is_function(C.GameFrame[T.ResourcePull])
		assert.is_function(C.GameFrame[T.UnitEnteredLocation])
		assert.is_function(C.GameFrame[T.UnitLeftLocation])
		assert.is_function(C.GameFrame[T.UnitDwellLocation])

		-- Event-driven triggers:
		assert.is_function(C.MetaUnitAdded[T.UnitExists])
		assert.is_function(C.MetaUnitRemoved[T.UnitNotExists])
		assert.is_function(C.UnitDestroyed[T.UnitKilled])
		assert.is_function(C.UnitTaken[T.UnitCaptured])
		assert.is_function(C.UnitCreated[T.UnitResurrected])
		assert.is_function(C.UnitCreated[T.ConstructionStarted])
		assert.is_function(C.UnitFinished[T.ConstructionFinished])
		assert.is_function(C.UnitEnteredLos[T.UnitSpotted])
		assert.is_function(C.UnitLeftLos[T.UnitUnspotted])
		assert.is_function(C.TeamDied[T.TeamDestroyed])
		assert.is_function(C.FeatureCreated[T.FeatureCreated])
		assert.is_function(C.FeatureDestroyed[T.FeatureReclaimed])
		assert.is_function(C.FeatureDestroyed[T.FeatureDestroyed])
	end)

	it("registers no callins for statistics and mission-control triggers", function()
		local T = triggerDefinitions.Types
		local C = triggerDefinitions.Callins

		for callinName, handlers in pairs(C) do
			assert.is_nil(handlers[T.TotalUnitsLost],     callinName)
			assert.is_nil(handlers[T.TotalUnitsBuilt],    callinName)
			assert.is_nil(handlers[T.TotalUnitsKilled],   callinName)
			assert.is_nil(handlers[T.TotalUnitsCaptured], callinName)
			assert.is_nil(handlers[T.UnitsOwned],         callinName)
			assert.is_nil(handlers[T.Victory],            callinName)
			assert.is_nil(handlers[T.Defeat],             callinName)
		end
	end)

	it("exposes the shared settings schema", function()
		local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
		assert.are.equal(ParameterTypes.Boolean, triggerDefinitions.Settings.repeating)
		assert.are.equal(ParameterTypes.Table,   triggerDefinitions.Settings.stages)
	end)
end)
