require("spec_helper")

local RegisterMissionApiModules = require("mission_api.spec_helper")

local parameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')
local triggersLoader = VFS.Include('luarules/mission_api/triggers_loader.lua')

-- Load the real trigger definitions once for the integration section below.
-- (Real trigger files read GG['MissionAPI'].Modules.ParameterTypes at include time.)
GG['MissionAPI'] = { Modules = { ParameterTypes = parameterTypes } }
RegisterMissionApiModules()
local realDefinitions  = triggersLoader.LoadTriggerDefinitions()
local realTriggerFiles = VFS.DirList('luarules/mission_api/triggers/', '*.lua')

describe("mission_api.triggers_loader", function()
	before_each(function()
		-- Real trigger definition files read the parameter types from GG at include time.
		GG['MissionAPI'] = { Modules = { ParameterTypes = parameterTypes } }
		RegisterMissionApiModules()
	end)

	-- ── LoadTriggerDefinitions (isolated, mocked trigger files) ───────────────

	describe("LoadTriggerDefinitions", function()
		-- Runs the loader against a controlled, ordered list of fake trigger
		-- definitions by stubbing the VFS calls it makes, then restores them.
		local function loadWith(fakeFiles)
			local origDirList, origInclude = VFS.DirList, VFS.Include
			local paths, defsByPath = {}, {}
			for i, file in ipairs(fakeFiles) do
				paths[i]              = file.path
				defsByPath[file.path] = file.def
			end

			VFS.DirList = function() return paths end
			VFS.Include = function(path) return defsByPath[path] end

			local ok, result = pcall(triggersLoader.LoadTriggerDefinitions)

			VFS.DirList, VFS.Include = origDirList, origInclude
			assert(ok, result)
			return result
		end

		it("assigns sequential type IDs in directory-list order", function()
			local definitions = loadWith({
				{ path = 'a.lua', def = { type = 'Alpha' } },
				{ path = 'b.lua', def = { type = 'Beta' } },
				{ path = 'c.lua', def = { type = 'Gamma' } },
			})

			assert.are.same({ Alpha = 1, Beta = 2, Gamma = 3 }, definitions.Types)
		end)

		it("keeps a definition's parameters and defaults missing ones to an empty table", function()
			local alphaParameters = { { name = 'a' } }
			local definitions = loadWith({
				{ path = 'a.lua', def = { type = 'Alpha', parameters = alphaParameters } },
				{ path = 'b.lua', def = { type = 'Beta' } }, -- no parameters field
			})

			-- Kept as-is (same reference, not copied):
			assert.are.equal(alphaParameters, definitions.Parameters[1])
			-- Defaulted via `parameters or {}`:
			assert.are.same({}, definitions.Parameters[2])
		end)

		it("indexes callin handlers by callin name then type ID", function()
			local alphaGameFrame    = function() end
			local betaGameFrame     = function() end
			local betaUnitDestroyed = function() end

			local definitions = loadWith({
				{ path = 'a.lua', def = { type = 'Alpha', callins = { GameFrame = alphaGameFrame } } },
				{ path = 'b.lua', def = { type = 'Beta',  callins = { GameFrame = betaGameFrame, UnitDestroyed = betaUnitDestroyed } } },
				{ path = 'c.lua', def = { type = 'Gamma' } }, -- statistics-like: no callins
			})

			-- One callin shared by two types, keyed by type ID:
			assert.are.equal(alphaGameFrame, definitions.Callins.GameFrame[1])
			assert.are.equal(betaGameFrame,  definitions.Callins.GameFrame[2])
			-- A callin unique to a single type:
			assert.are.equal(betaUnitDestroyed, definitions.Callins.UnitDestroyed[2])
			assert.is_nil(definitions.Callins.UnitDestroyed[1])
			-- A definition without callins is absent from every callin map:
			for _, handlers in pairs(definitions.Callins) do
				assert.is_nil(handlers[3])
			end
		end)

		it("returns only Types, Parameters, and Callins", function()
			local definitions = loadWith({ { path = 'a.lua', def = { type = 'Alpha' } } })

			local keys = {}
			for key in pairs(definitions) do keys[key] = true end
			assert.are.same({ Types = true, Parameters = true, Callins = true }, keys)
		end)

		it("handles an empty triggers directory", function()
			local definitions = loadWith({})

			assert.are.same({}, definitions.Types)
			assert.are.same({}, definitions.Parameters)
			assert.are.same({}, definitions.Callins)
		end)
	end)

	-- ── LoadTriggerDefinitions (integration, real trigger files) ──────────────

	describe("LoadTriggerDefinitions with the real trigger files", function()
		it("registers every trigger file as a unique type", function()
			local typeCount = 0
			for _ in pairs(realDefinitions.Types) do typeCount = typeCount + 1 end

			assert.are.equal(#realTriggerFiles, typeCount)
		end)

		it("maps callins to the correct trigger types", function()
			local T = realDefinitions.Types
			local C = realDefinitions.Callins

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
			assert.is_function(C.BuildAssisted[T.ConstructionStarted])
			assert.is_function(C.UnitFinished[T.ConstructionFinished])
			assert.is_function(C.DetectionUpdate[T.UnitDetected])
			assert.is_function(C.DetectionUpdate[T.UnitUndetected])
			assert.is_function(C.UnitBuildStepPost[T.ConstructionProgress])
			assert.is_function(C.MetaUnitRemoved[T.ConstructionProgress])
			assert.is_function(C.MetaUnitRemoved[T.ConstructionCanceled])
			assert.is_function(C.UnitCreated[T.ProductionStarted])
			assert.is_function(C.UnitDestroyed[T.ProductionCanceled])
			assert.is_function(C.UnitTaken[T.ProductionCanceled])
			assert.is_function(C.TeamDied[T.TeamDestroyed])
			assert.is_function(C.FeatureCreated[T.FeatureCreated])
			assert.is_function(C.FeatureDestroyed[T.FeatureReclaimed])
			assert.is_function(C.FeatureDestroyed[T.FeatureDestroyed])
		end)

		it("registers no callins for statistics and mission-control triggers", function()
			local T = realDefinitions.Types
			local C = realDefinitions.Callins

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
	end)

	-- ── ProcessRawTriggers ────────────────────────────────────────────────────

	describe("ProcessRawTriggers", function()
		it("applies default settings when a trigger has none", function()
			local triggers = triggersLoader.ProcessRawTriggers({
				t = { type = 'Alpha' },
			})

			local settings = triggers.t.settings
			assert.are.same({}, settings.prerequisites)
			assert.is_false(settings.repeating)
			assert.is_false(settings.coop)
			assert.is_true(settings.active)
			assert.are.same({}, settings.stages)
			assert.is_nil(settings.maxRepeats)
			assert.is_nil(settings.difficulties)
		end)

		it("preserves settings that are already specified", function()
			local difficulties = { hard = true }
			local triggers = triggersLoader.ProcessRawTriggers({
				t = {
					type     = 'Alpha',
					settings = {
						prerequisites = { 'p1' },
						repeating     = true,
						maxRepeats    = 3,
						difficulties  = difficulties,
						coop          = true,
						stages        = { 'stage1' },
					},
				},
			})

			local settings = triggers.t.settings
			assert.are.same({ 'p1' }, settings.prerequisites)
			assert.is_true(settings.repeating)
			assert.are.equal(3, settings.maxRepeats)
			assert.are.same({ hard = true }, settings.difficulties)
			assert.is_true(settings.coop)
			assert.are.same({ 'stage1' }, settings.stages)
		end)

		it("(re)initializes triggered=false and repeatCount=0", function()
			local triggers = triggersLoader.ProcessRawTriggers({
				t = { type = 'Alpha', triggered = true, repeatCount = 7 },
			})

			assert.is_false(triggers.t.triggered)
			assert.are.equal(0, triggers.t.repeatCount)
		end)

		it("processes every trigger in the input map", function()
			local triggers = triggersLoader.ProcessRawTriggers({
				a = { type = 'Alpha' },
				b = { type = 'Beta' },
			})

			assert.is_table(triggers.a)
			assert.is_table(triggers.b)
		end)

		it("returns deep copies independent of the input tables", function()
			local raw = { t = { type = 'Alpha', parameters = { quantity = 1 } } }
			local triggers = triggersLoader.ProcessRawTriggers(raw)

			assert.are_not.equal(raw.t, triggers.t)                       -- top-level copy
			assert.are_not.equal(raw.t.parameters, triggers.t.parameters) -- nested deep copy
			assert.are.same({ quantity = 1 }, triggers.t.parameters)      -- but equal by value
		end)

		it("preserves an explicit active = false", function()
			local triggers = triggersLoader.ProcessRawTriggers({
				t = { type = 'Alpha', settings = { active = false } },
			})

			assert.is_false(triggers.t.settings.active)
		end)

		it("defaults active to true when settings omit it", function()
			local triggers = triggersLoader.ProcessRawTriggers({
				t = { type = 'Alpha', settings = { repeating = true } },
			})

			assert.is_true(triggers.t.settings.active)
		end)
	end)
end)
