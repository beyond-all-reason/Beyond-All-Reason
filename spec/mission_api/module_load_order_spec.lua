require("spec_helper")

--- Several mission_api modules capture GG['MissionAPI'] state into upvalues when
--- they load, which constrains the order api_missions may include them in.
--- Getting it wrong fails in two ways: indexing a missing table errors
--- immediately, while capturing a missing table silently yields nil and only
--- breaks on first use. This spec covers both.

local MODULE_PATHS = {
	parameterTypes    = 'luarules/mission_api/parameter_types.lua',
	tracking          = 'luarules/mission_api/tracking.lua',
	loadout           = 'luarules/mission_api/loadout.lua',
	sounds            = 'luarules/mission_api/sounds.lua',
	stages            = 'luarules/mission_api/stages.lua',
	objectives        = 'luarules/mission_api/objectives.lua',
	actionsDispatcher = 'luarules/mission_api/actions_dispatcher.lua',
}

-- The spec_helper's VFS.Include swallows load errors (it pcalls and returns an
-- empty table), which would hide exactly the failures this spec looks for. Run
-- the chunk directly so a missing dependency propagates.
local function loadFresh(path)
	local chunk = assert(loadfile(path), 'could not load ' .. path)
	return chunk()
end

--- The shared state api_missions sets up before including any module.
local function baseState()
	return {
		Difficulty          = 0,
		trackedUnitIDs      = {},
		trackedUnitNames    = {},
		trackedFeatureIDs   = {},
		trackedFeatureNames = {},
		markerNames         = {},
		soundFiles          = {},
		soundQueue          = {},
		Modules             = {},
	}
end

describe("mission_api module load order", function()

	before_each(function()
		GG['MissionAPI'] = baseState()
		-- Engine globals loadout reads while loading.
		Spring.GetGaiaTeamID = function() return 99 end
		_G.UnitDefs = {}
		_G.FeatureDefs = {}
	end)

	it("loads the gadget's Initialize sequence without error", function()
		local modules = GG['MissionAPI'].Modules

		assert.has_no.errors(function()
			modules.ParameterTypes = loadFresh(MODULE_PATHS.parameterTypes)
			modules.Tracking       = loadFresh(MODULE_PATHS.tracking)
			modules.Loadout        = loadFresh(MODULE_PATHS.loadout)
			modules.Sounds         = loadFresh(MODULE_PATHS.sounds)
			modules.Stages         = loadFresh(MODULE_PATHS.stages)
			modules.Objectives     = loadFresh(MODULE_PATHS.objectives)
		end)
	end)

	describe("modules that capture state silently", function()
		-- Capturing a missing table binds nil rather than erroring, so the module
		-- loads happily and only breaks later. api_missions therefore has to set
		-- the tracked tables up before including tracking.

		it("leaves tracking non-functional if the tracked tables are missing", function()
			GG['MissionAPI'].trackedUnitIDs = nil
			GG['MissionAPI'].trackedUnitNames = nil

			local tracking = loadFresh(MODULE_PATHS.tracking)

			assert.has_error(function()
				tracking.TrackUnit('someUnit', 1)
			end)
		end)

		it("works when the tracked tables exist first, as in the real sequence", function()
			local tracking = loadFresh(MODULE_PATHS.tracking)

			assert.has_no.errors(function()
				tracking.TrackUnit('someUnit', 1)
			end)
			assert.is_true(GG['MissionAPI'].trackedUnitIDs.someUnit[1])
		end)
	end)

	describe("actions_dispatcher", function()
		-- It indexes ActionDefinitions directly, so loading it too early errors
		-- outright. Actions only exists once a mission has been loaded, which is
		-- why api_missions includes it at the end of loadMission rather than
		-- alongside the other modules in Initialize.

		it("errors when loaded before ActionDefinitions exists", function()
			assert.has_error(function()
				loadFresh(MODULE_PATHS.actionsDispatcher)
			end)
		end)

		it("loads once ActionDefinitions and Actions are populated", function()
			GG['MissionAPI'].ActionDefinitions = { Functions = {}, Parameters = {} }
			GG['MissionAPI'].Actions = {}

			assert.has_no.errors(function()
				loadFresh(MODULE_PATHS.actionsDispatcher)
			end)
		end)
	end)

	it("leaves stages and objectives free of load-time state capture", function()
		-- They read GG only inside functions, so they impose no ordering at all.
		GG['MissionAPI'] = {}

		assert.has_no.errors(function()
			loadFresh(MODULE_PATHS.stages)
			loadFresh(MODULE_PATHS.objectives)
		end)
	end)

end)
