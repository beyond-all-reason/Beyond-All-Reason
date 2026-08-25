require("spec_helper")
local registerMissionApiModules = require("mission_api.spec_helper")

-- Definition files and parameter_processing itself read from GG when they are included.
local parameterTypes = registerMissionApiModules().ParameterTypes
local actionDefinitions  = VFS.Include('luarules/mission_api/actions_loader.lua').LoadActionDefinitions()
local triggerDefinitions = VFS.Include('luarules/mission_api/triggers_loader.lua').LoadTriggerDefinitions()
GG['MissionAPI'].ActionDefinitions  = actionDefinitions
GG['MissionAPI'].TriggerDefinitions = triggerDefinitions
local parameterProcessing = VFS.Include('luarules/mission_api/parameter_processing.lua')
GG['MissionAPI'] = nil

local actionTypes  = actionDefinitions.Types
local triggerTypes = triggerDefinitions.Types

local GROUND_HEIGHT = 42

--- Processing runs on validated data, so these mirror what validation guarantees.
describe("mission_api.parameter_processing", function()
	local originalReadWAV, originalUnitDefNames

	--- Processes action 'a', and returns its parameters afterwards.
	local function processAction(action)
		local actions = { a = action }
		parameterProcessing.ProcessActionParameters(actions)
		return actions.a.parameters
	end

	--- Processes trigger 't', and returns its parameters afterwards.
	local function processTrigger(trigger)
		local triggers = { t = trigger }
		parameterProcessing.ProcessTriggerParameters(triggers)
		return triggers.t.parameters
	end

	before_each(function()
		GG['MissionAPI'] = { soundFiles = {} }
		Spring.GetGroundHeight = function() return GROUND_HEIGHT end

		originalUnitDefNames = _G.UnitDefNames
		originalReadWAV      = _G.ReadWAV
		_G.UnitDefNames      = { armwar = { id = 7 } }
		_G.ReadWAV           = function() return { Length = 1.5 } end
	end)

	after_each(function()
		GG['MissionAPI'] = nil
		_G.UnitDefNames  = originalUnitDefNames
		_G.ReadWAV       = originalReadWAV
	end)

	describe("Position", function()
		it("fills in the ground height when a position has no y", function()
			local parameters = processAction({
				type       = actionTypes.AddMarker,
				parameters = { position = { x = 1, z = 2 }, name = 'flag' },
			})

			assert.are.equal(GROUND_HEIGHT, parameters.position.y)
		end)

		it("keeps a y that the mission specified", function()
			local parameters = processAction({
				type       = actionTypes.AddMarker,
				parameters = { position = { x = 1, y = 5, z = 2 }, name = 'flag' },
			})

			assert.are.equal(5, parameters.position.y)
		end)
	end)

	describe("Positions", function()
		it("fills in the ground height for every position", function()
			local parameters = processAction({
				type       = actionTypes.DrawLines,
				parameters = { positions = { { x = 1, z = 2 }, { x = 3, y = 9, z = 4 } } },
			})

			assert.are.equal(GROUND_HEIGHT, parameters.positions[1].y)
			assert.are.equal(9, parameters.positions[2].y)
		end)
	end)

	describe("Orders", function()
		it("turns a build order unitDefName into its negative unit def ID", function()
			local parameters = processAction({
				type       = actionTypes.IssueOrders,
				parameters = { unitName = 'bot', orders = { { 'armwar', { 0, 0, 0 } } } },
			})

			assert.are.same({ -7, { 0, 0, 0 } }, parameters.orders[1])
		end)

		it("leaves an order with a numeric command ID alone", function()
			local parameters = processAction({
				type       = actionTypes.IssueOrders,
				parameters = { unitName = 'bot', orders = { { 40, { 0, 0, 0 } } } },
			})

			assert.are.same({ 40, { 0, 0, 0 } }, parameters.orders[1])
		end)
	end)

	describe("SoundFile", function()
		it("records the length of the sound file", function()
			processAction({
				type       = actionTypes.PlaySound,
				parameters = { soundfile = 'sounds/beep.wav' },
			})

			assert.are.equal(1.5, GG['MissionAPI'].soundFiles['sounds/beep.wav'])
		end)
	end)

	describe("enum sets", function()
		it("turns the list of values into a set", function()
			local parameters = processTrigger({
				type       = triggerTypes.ResourceIncome,
				parameters = { teamID = 0, resource = 'metal', quantity = 1, sources = { 'extractor', 'reclaim' } },
			})

			assert.are.same({ extractor = true, reclaim = true }, parameters.sources)
		end)
	end)

	it("leaves parameters the mission did not set alone", function()
		local parameters = processAction({
			type       = actionTypes.PlaySound,
			parameters = { soundfile = 'sounds/beep.wav' },
		})

		assert.is_nil(parameters.enqueue)
	end)

	it("processes an action without parameters", function()
		assert.has_no.errors(function()
			processAction({ type = actionTypes.Victory })
		end)
	end)
end)
