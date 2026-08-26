---
--- The parameter validators, one per parameter type.
---

local V = require("mission_api.validation.validation_spec_helper")

describe("mission_api.validation.parameter_validators", function()
	before_each(V.mockEngineGlobals)

	--- Without a validator, the schema walker calls a nil value
	it("has a validator for every parameter type the definitions use", function()
		local parameterTypes = V.definitions.ParameterTypes
		local parameterValidators = VFS.Include('luarules/mission_api/validation/parameter_validators.lua')
			.CreateParameterValidators({
				Stages   = {},
				Objectives = {},
				Triggers = {},
				Actions  = {},
				Types    = parameterTypes.Types,
				Enums    = parameterTypes.Enums,
				EnumSets = parameterTypes.EnumSets,
			})

		local missing = {}
		for _, definitions in ipairs({ V.definitions.ActionDefinitions, V.definitions.TriggerDefinitions }) do
			for entityType, parameters in pairs(definitions.Parameters) do
				for _, parameter in ipairs(parameters) do
					if parameterValidators[parameter.type] == nil then
						missing[#missing + 1] = entityType .. "." .. parameter.name .. " (" .. tostring(parameter.type) .. ")"
					end
				end
			end
		end
		table.sort(missing)

		assert.are.same({}, missing)
	end)

	describe("String", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({ type = V.actionTypes.SendMessage, parameters = { message = 123 } })

			V.assertMessage(result, "Unexpected parameter type, expected string, got number. Action: a, Parameter: message")
		end)
	end)

	describe("Number", function()
		it("rejects the wrong type", function()
			local result = V.validateTrigger(V.trigger(V.triggerTypes.TimeElapsed, { seconds = 'bad' }))

			V.assertMessage(result, "Unexpected parameter type, expected number, got string. Trigger: t, Parameter: seconds")
		end)
	end)

	describe("Boolean", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({
				type       = V.actionTypes.PlaySound,
				parameters = { soundfile = "x", enqueue = 'bad' },
			})

			V.assertMessage(result, "Unexpected parameter type, expected boolean, got string. Action: a, Parameter: enqueue")
		end)
	end)

	describe("Function", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({ type = V.actionTypes.Custom, parameters = { ['function'] = 'bad' } })

			V.assertMessage(result, "Unexpected parameter type, expected function, got string. Action: a, Parameter: function")
		end)
	end)

	describe("Quantity", function()
		it("rejects a negative number", function()
			local result = V.validateTrigger(V.trigger(V.triggerTypes.UnitsOwned, {
				teamID      = 0,
				quantity    = -1,
				unitDefName = 'armwar',
			}))

			V.assertMessage(result, "Quantity must be >= 0, got -1. Trigger: t, Parameter: quantity")
		end)
	end)

	describe("Fraction", function()
		local function validateProgress(progress)
			return V.validateTrigger(V.trigger(V.triggerTypes.ConstructionProgress, {
				teamID      = 0,
				unitDefName = 'armwar',
				progress    = progress,
			}))
		end

		it("rejects the wrong type", function()
			V.assertMessage(validateProgress('bad'),
				"Unexpected parameter type, expected number, got string. Trigger: t, Parameter: progress")
		end)

		it("rejects a value greater than one", function()
			V.assertMessage(validateProgress(5.0), "Fraction must be between 0 and 1, got 5. Trigger: t, Parameter: progress")
		end)

		it("rejects a negative value", function()
			V.assertMessage(validateProgress(-0.5), "Fraction must be between 0 and 1, got -0.5. Trigger: t, Parameter: progress")
		end)

		it("accepts the bounds", function()
			V.assertNoMessageContaining(validateProgress(0), "Fraction")
			V.assertNoMessageContaining(validateProgress(1), "Fraction")
		end)
	end)

	describe("TriggerID", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({ type = V.actionTypes.EnableTrigger, parameters = { triggerID = 123 } })

			V.assertMessage(result, "Unexpected parameter type, expected string, got number. Action: a, Parameter: triggerID")
		end)

		it("rejects a trigger the mission does not declare", function()
			local result = V.validateAction({ type = V.actionTypes.EnableTrigger, parameters = { triggerID = 'noSuch' } })

			V.assertMessage(result, "Invalid triggerID: noSuch. Action: a, Parameter: triggerID")
		end)

		it("accepts a trigger the mission declares", function()
			local result = V.validateAction({ type = V.actionTypes.EnableTrigger, parameters = { triggerID = 't' } })

			V.assertNoMessage(result, "Invalid triggerID: t. Action: a, Parameter: triggerID")
		end)
	end)

	describe("StageID", function()
		it("rejects a stage the mission does not declare", function()
			local result = V.validateAction({ type = V.actionTypes.ChangeStage, parameters = { stageID = 'noSuch' } })

			V.assertMessage(result, "Invalid stageID: noSuch. Action: a, Parameter: stageID")
		end)
	end)

	describe("ObjectiveID", function()
		it("rejects an objective the mission does not declare", function()
			local result = V.validateAction({
				type       = V.actionTypes.UpdateObjective,
				parameters = { objectiveID = 'noSuch', completed = true },
			})

			V.assertMessage(result, "Invalid objectiveID: noSuch. Action: a, Parameter: objectiveID")
		end)
	end)

	describe("UnitDefName", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({
				type       = V.actionTypes.SpawnUnits,
				parameters = { unitLoadout = { { unitDefName = 123, team = 0, x = 0, z = 0 } } },
			})

			V.assertMessage(result, "Unexpected parameter type, expected string, got number. Action: a, Parameter: unitLoadout[1].unitDefName")
		end)

		it("rejects a unit def that does not exist", function()
			local result = V.validateAction({
				type       = V.actionTypes.SpawnUnits,
				parameters = { unitLoadout = { { unitDefName = 'noSuch', team = 0, x = 0, z = 0 } } },
			})

			V.assertMessage(result, "Invalid unitDefName: noSuch. Action: a, Parameter: unitLoadout[1].unitDefName")
		end)
	end)

	describe("FeatureDefName", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({
				type       = V.actionTypes.CreateFeatures,
				parameters = { featureLoadout = { { featureDefName = 123, x = 0, z = 0 } } },
			})

			V.assertMessage(result, "Unexpected parameter type, expected string, got number. Action: a, Parameter: featureLoadout[1].featureDefName")
		end)

		it("rejects a feature def that does not exist", function()
			local result = V.validateAction({
				type       = V.actionTypes.CreateFeatures,
				parameters = { featureLoadout = { { featureDefName = 'noSuch', x = 0, z = 0 } } },
			})

			V.assertMessage(result, "Invalid featureDefName: noSuch. Action: a, Parameter: featureLoadout[1].featureDefName")
		end)
	end)

	describe("WeaponDefName", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({
				type       = V.actionTypes.SpawnExplosion,
				parameters = { weaponDefName = 123, position = { x = 0, z = 0 } },
			})

			V.assertMessage(result, "Unexpected parameter type, expected string, got number. Action: a, Parameter: weaponDefName")
		end)

		it("rejects a weapon def that does not exist", function()
			local result = V.validateAction({
				type       = V.actionTypes.SpawnExplosion,
				parameters = { weaponDefName = 'noSuch', position = { x = 0, z = 0 } },
			})

			V.assertMessage(result, "Invalid weaponDefName: noSuch. Action: a, Parameter: weaponDefName")
		end)
	end)

	describe("Facing", function()
		it("rejects a type that is neither string nor number", function()
			local result = V.validateAction({
				type       = V.actionTypes.SpawnUnits,
				parameters = { unitLoadout = { { unitDefName = 'armwar', team = 0, x = 0, z = 0, facing = {} } } },
			})

			V.assertMessage(result, "Unexpected parameter type, expected string or number, got table. Action: a, Parameter: unitLoadout[1].facing")
		end)

		it("rejects a facing that is not a compass direction", function()
			local result = V.validateAction({
				type       = V.actionTypes.SpawnUnits,
				parameters = { unitLoadout = { { unitDefName = 'armwar', team = 0, x = 0, z = 0, facing = 'diagonal' } } },
			})

			V.assertMessage(result, "Invalid facing: diagonal. Must be one of 'n', 's', 'e', 'w', 'north', 'south', 'east', 'west'. Action: a, Parameter: unitLoadout[1].facing")
		end)
	end)

	describe("SoundFile", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({ type = V.actionTypes.PlaySound, parameters = { soundfile = 123 } })

			V.assertMessage(result, "Unexpected parameter type, expected string, got number. Action: a, Parameter: soundfile")
		end)

		it("rejects a file that does not exist", function()
			local result = V.validateAction({
				type       = V.actionTypes.PlaySound,
				parameters = { soundfile = 'nonexistent/file.wav' },
			})

			V.assertMessage(result, "Invalid soundfile: nonexistent/file.wav. File does not exist. Action: a, Parameter: soundfile")
		end)

		it("rejects a file that is not a RIFF .wav", function()
			local originalFileExists = VFS.FileExists
			local originalReadWAV    = _G.ReadWAV
			VFS.FileExists = function(path) return path == 'dummy.wav' end
			_G.ReadWAV     = function() return nil end

			local result = V.validateAction({ type = V.actionTypes.PlaySound, parameters = { soundfile = 'dummy.wav' } })

			VFS.FileExists = originalFileExists
			_G.ReadWAV     = originalReadWAV

			V.assertMessage(result, "Invalid soundfile: dummy.wav. File is not a RIFF .wav file. Action: a, Parameter: soundfile")
		end)
	end)

	--- Validates the area parameter of the trigger under test.
	local function validateArea(area)
		return V.validateTrigger(V.trigger(V.triggerTypes.UnitEnteredLocation, { area = area, unitName = 'x' }))
	end

	describe("Position", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({ type = V.actionTypes.AddMarker, parameters = { position = 'bad' } })

			V.assertMessage(result, "Unexpected parameter type, expected table, got string. Action: a, Parameter: position")
		end)

		it("rejects a missing coordinate", function()
			local result = V.validateAction({ type = V.actionTypes.AddMarker, parameters = { position = { z = 0 } } })

			V.assertMessage(result, "Missing required parameter. Action: a, Parameter: position.x")
		end)

		it("rejects a coordinate that is not a number", function()
			local result = V.validateAction({
				type       = V.actionTypes.AddMarker,
				parameters = { position = { x = 'bad', z = 0 } },
			})

			V.assertMessage(result, "Unexpected parameter type, expected number, got string. Action: a, Parameter: position.x")
		end)

		it("rejects a false coordinate as the wrong type, not as missing", function()
			local result = V.validateAction({
				type       = V.actionTypes.AddMarker,
				parameters = { position = { x = false, z = 0 } },
			})

			V.assertMessage(result, "Unexpected parameter type, expected number, got boolean. Action: a, Parameter: position.x")
			V.assertNoMessage(result, "Missing required parameter. Action: a, Parameter: position.x")
		end)

		it("accepts zero coordinates", function()
			local result = V.validateAction({
				type       = V.actionTypes.AddMarker,
				parameters = { position = { x = 0, y = 0, z = 0 }, name = 'flag' },
			})

			V.assertNoMessageContaining(result, "Parameter: position")
		end)
	end)

	describe("Positions", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({ type = V.actionTypes.DrawLines, parameters = { positions = 'bad' } })

			V.assertMessage(result, "Unexpected parameter type, expected table, got string. Action: a, Parameter: positions")
		end)

		it("rejects fewer than two positions", function()
			local result = V.validateAction({
				type       = V.actionTypes.DrawLines,
				parameters = { positions = { { x = 0, z = 0 } } },
			})

			V.assertMessage(result, "Positions table needs at least two positions. Action: a, Parameter: positions")
		end)

		it("rejects an entry that is not a table", function()
			local result = V.validateAction({
				type       = V.actionTypes.DrawLines,
				parameters = { positions = { 'bad', { x = 0, z = 0 } } },
			})

			V.assertMessage(result, "Unexpected parameter type, expected table, got string. Action: a, Parameter: positions[1]")
		end)

		it("rejects an entry with a missing coordinate", function()
			local result = V.validateAction({
				type       = V.actionTypes.DrawLines,
				parameters = { positions = { { z = 0 }, { x = 0, z = 0 } } },
			})

			V.assertMessage(result, "Missing required parameter. Action: a, Parameter: positions[1].x")
		end)
	end)

	describe("Area", function()
		it("rejects the wrong type", function()
			V.assertMessage(validateArea('bad'),
				"Unexpected parameter type, expected table, got string. Trigger: t, Parameter: area")
		end)

		it("rejects a table that is neither a rectangle nor a circle", function()
			V.assertMessage(validateArea({}),
				"Invalid area parameter, must be either rectangle { x1, z1, x2, z2 } with x1 < x2 and z1 < z2, or circle { x, z, radius }. Trigger: t, Parameter: area")
		end)

		it("rejects a field that is not a number", function()
			V.assertMessage(validateArea({ x1 = 'bad', z1 = 0, x2 = 1, z2 = 1 }),
				"Unexpected parameter type, expected number, got string. Trigger: t, Parameter: area.x1")
		end)

		it("rejects a rectangle whose x1 is not less than x2", function()
			V.assertMessage(validateArea({ x1 = 1, z1 = 0, x2 = 0, z2 = 1 }),
				"Invalid area rectangle parameter, x1 must be less than x2. Trigger: t, Parameter: area")
		end)

		it("rejects a rectangle whose z1 is not less than z2", function()
			V.assertMessage(validateArea({ x1 = 0, z1 = 1, x2 = 1, z2 = 0 }),
				"Invalid area rectangle parameter, z1 must be less than z2. Trigger: t, Parameter: area")
		end)

		it("accepts a circle", function()
			V.assertNoMessageContaining(validateArea({ x = 0, z = 0, radius = 10 }), "area")
		end)
	end)

	describe("Direction", function()
		local function validateDirection(direction)
			return V.validateAction({
				type       = V.actionTypes.RotateUnits,
				parameters = { unitName = 'x', direction = direction },
			})
		end

		it("rejects the wrong type", function()
			V.assertMessage(validateDirection('bad'),
				"Unexpected parameter type, expected table, got string. Action: a, Parameter: direction")
		end)

		it("rejects a table that is neither an angle nor a vector", function()
			V.assertMessage(validateDirection({}),
				"Invalid direction parameter, must be either angle { angle }, or direction { x, z, optional y }. Action: a, Parameter: direction")
		end)

		it("rejects a table that is both an angle and a vector", function()
			V.assertMessage(validateDirection({ angle = 1, x = 0, z = 0 }),
				"Invalid direction parameter, must be either angle { angle }, or direction { x, z, optional y }, not both. Action: a, Parameter: direction")
		end)

		it("validates a vector as a position", function()
			V.assertMessage(validateDirection({ x = 'bad', z = 0 }),
				"Unexpected parameter type, expected number, got string. Action: a, Parameter: direction.x")
		end)

		it("rejects an angle that is not a number", function()
			V.assertMessage(validateDirection({ angle = 'north' }),
				"Unexpected parameter type, expected number, got string. Action: a, Parameter: direction.angle")
		end)

		it("accepts an angle", function()
			V.assertNoMessageContaining(validateDirection({ angle = 90 }), "direction")
		end)

		it("accepts a vector", function()
			V.assertNoMessageContaining(validateDirection({ x = 1, z = 1 }), "direction")
		end)
	end)

	--- Validates the allyTeamIDs parameter of the action under test.
	local function validateAllyTeamIDs(allyTeamIDs)
		return V.validateAction({ type = V.actionTypes.Victory, parameters = { allyTeamIDs = allyTeamIDs } })
	end

	describe("TeamID", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({ type = V.actionTypes.AddResources, parameters = { teamID = 'bad' } })

			V.assertMessage(result, "Unexpected parameter type, expected number, got string. Action: a, Parameter: teamID")
		end)

		it("rejects a team that does not exist", function()
			Spring.GetTeamAllyTeamID = function() return nil end

			local result = V.validateAction({ type = V.actionTypes.AddResources, parameters = { teamID = 99 } })

			V.assertMessage(result, "Invalid teamID: 99. Action: a, Parameter: teamID")
		end)
	end)

	describe("AllyTeamID", function()
		it("rejects the wrong type", function()
			local result = V.validateTrigger(V.trigger(V.triggerTypes.UnitDetected, {
				unitName       = 'x',
				sensorAllyTeam = 'bad',
			}))

			V.assertMessage(result, "Unexpected parameter type, expected number, got string. Trigger: t, Parameter: sensorAllyTeam")
		end)

		it("rejects an ally team that does not exist", function()
			local result = V.validateTrigger(V.trigger(V.triggerTypes.UnitDetected, {
				unitName       = 'x',
				sensorAllyTeam = 99,
			}))

			V.assertMessage(result, "Invalid allyTeamID: 99. Trigger: t, Parameter: sensorAllyTeam")
		end)
	end)

	describe("AllyTeamIDs", function()
		it("rejects the wrong type", function()
			V.assertMessage(validateAllyTeamIDs('bad'),
				"Unexpected parameter type, expected table, got string. Action: a, Parameter: allyTeamIDs")
		end)

		it("rejects an empty table", function()
			V.assertMessage(validateAllyTeamIDs({}), "allyTeamIDs table is empty. Action: a, Parameter: allyTeamIDs")
		end)

		it("rejects an entry that is not a number", function()
			V.assertMessage(validateAllyTeamIDs({ 'bad' }),
				"Unexpected parameter type, expected number, got string. Action: a, Parameter: allyTeamIDs[1]")
		end)

		it("rejects an entry that does not exist", function()
			V.assertMessage(validateAllyTeamIDs({ 99 }),
				"Invalid allyTeamID: 99. Action: a, Parameter: allyTeamIDs[1]")
		end)

		-- Entries are validated by the AllyTeamID validator, so every bad one is reported.
		it("reports each entry that does not exist", function()
			local result = validateAllyTeamIDs({ 0, 98, 99 })

			V.assertMessage(result, "Invalid allyTeamID: 98. Action: a, Parameter: allyTeamIDs[2]")
			V.assertMessage(result, "Invalid allyTeamID: 99. Action: a, Parameter: allyTeamIDs[3]")
		end)

		it("accepts existing ally teams", function()
			V.assertNoMessageContaining(validateAllyTeamIDs({ 0 }), "allyTeamID")
		end)
	end)

	--- Validates the orders parameter of the action under test.
	local function validateOrders(orders)
		return V.validateAction({
			type       = V.actionTypes.IssueOrders,
			parameters = { unitName = 'x', orders = orders },
		})
	end

	before_each(function()
		V.mockEngineGlobals()

		-- The engine's CMD table maps both ways (name -> id and id -> name),
		-- which is what the known-command lookup relies on.
		_G.CMD = {}
		for i, name in ipairs({
			'STOP', 'SELFD', 'GUARD', 'DGUN', 'MOVE', 'FIGHT', 'PATROL',
			'UNLOAD_UNITS', 'AREA_ATTACK', 'RESTORE', 'ATTACK', 'CAPTURE',
			'REPAIR', 'LOAD_UNITS', 'RESURRECT', 'RECLAIM', 'CLOAK', 'ONOFF',
			'FIRE_STATE', 'MOVE_STATE',
		}) do
			CMD[name] = i
			CMD[i] = name
		end
		_G.GameCMD = { AREA_ATTACK_GROUND = 21, [21] = 'AREA_ATTACK_GROUND' }
	end)

	after_each(function()
		_G.CMD     = {}
		_G.GameCMD = {}
	end)

	it("rejects the wrong type", function()
		V.assertMessage(validateOrders('bad'),
			"Unexpected parameter type, expected table, got string. Action: a, Parameter: orders")
	end)

	it("rejects an empty orders table", function()
		V.assertMessage(validateOrders({}), "Orders table is empty. Action: a, Parameter: orders")
	end)

	it("rejects an order that is not a table", function()
		V.assertMessage(validateOrders({ 'notanorder' }),
			"Unexpected parameter type, expected table, got string. Action: a, Parameter: orders[1]")
	end)

	it("rejects a build order for a unit that does not exist", function()
		V.assertMessage(validateOrders({ { 'notAUnit', { 0, 0, 0 } } }),
			"Invalid build order unitDefName: notAUnit. Action: a, Parameter: orders[1][1]")
	end)

	it("rejects an unknown order option", function()
		V.assertMessage(validateOrders({ { CMD.STOP, nil, { 'diagonal' } } }),
			"Invalid order option: diagonal. Action: a, Parameter: orders[1][3]")
	end)

	it("rejects the wrong number of parameters for a move command", function()
		V.assertMessage(validateOrders({ { CMD.MOVE, {} } }),
			"Parameter must be an array of 3 numbers {x, y, z}. Action: a, Parameter: orders[1][2]")
	end)

	it("accepts a unit name instead of coordinates, for commands that allow it", function()
		V.assertNoMessageContaining(validateOrders({ { CMD.ATTACK, { unitName = 'x' } } }), "Parameter must be")
	end)

	it("rejects coordinates for a command that only takes a unit name", function()
		V.assertMessage(validateOrders({ { CMD.GUARD, { 0, 0, 0 } } }),
			"Parameter must be { unitName = 'aUnitName' }. Action: a, Parameter: orders[1][2]")
	end)

	it("accepts a unit name for a command that only takes a unit name", function()
		V.assertNoMessageContaining(validateOrders({ { CMD.GUARD, { unitName = 'x' } } }), "Parameter must be")
	end)

	it("reports every invalid order, named after its position in the list", function()
		local result = validateOrders({ { CMD.MOVE, { 0, 0, 0 } }, { CMD.MOVE, {} }, { 99999 } })

		V.assertMessage(result, "Parameter must be an array of 3 numbers {x, y, z}. Action: a, Parameter: orders[2][2]")
		V.assertMessage(result, "Unknown command ID: 99999. Action: a, Parameter: orders[3][1]")
	end)

	-- Commands that take no parameters are known, they just have nothing to validate.
	it("accepts a command that takes no parameters", function()
		V.assertNoMessage(validateOrders({ { CMD.STOP } }),
			"No validator implemented for orders with command ID: " .. CMD.STOP)
	end)

	it("rejects an unknown command ID", function()
		V.assertMessage(validateOrders({ { 99999, { 0, 0, 0 } } }),
			"Unknown command ID: 99999. Action: a, Parameter: orders[1][1]")
	end)

	--- Validates the command parameter of a Command-typed trigger.
	local function validateCommand(command)
		return V.validateTrigger(V.trigger(V.triggerTypes.UnitOrdered, { command = command, unitName = 'x' }))
	end

	describe("Command", function()
		before_each(function()
			_G.CMD = { MOVE = 1, [1] = 'MOVE', CLOAK = 17, [17] = 'CLOAK', ANY = 'a', BUILD = 'b' }
			_G.GameCMD = {}
		end)

		after_each(function()
			_G.CMD     = {}
			_G.GameCMD = {}
		end)

		it("accepts a known command id", function()
			V.assertNoMessageContaining(validateCommand(CMD.MOVE), "command")
		end)

		it("accepts a build order authored as a unitDefName", function()
			V.assertNoMessageContaining(validateCommand('armwar'), "command")
		end)

		it("accepts the ANY qualifier", function()
			V.assertNoMessageContaining(validateCommand(CMD.ANY), "command")
		end)

		it("accepts the BUILD qualifier", function()
			V.assertNoMessageContaining(validateCommand(CMD.BUILD), "command")
		end)

		it("warns, but does not error, for a command consumed in AllowCommand", function()
			local result = validateCommand(CMD.CLOAK)

			V.assertMessage(result, "Command CLOAK may fail to trigger in UnitOrdered. Trigger: t, Parameter: command")
			assert.is_true(result.ok)
		end)

		it("rejects an unknown command id", function()
			V.assertMessage(validateCommand(4242), "Unknown command ID: 4242. Trigger: t, Parameter: command")
		end)

		it("rejects a command that is not a known unitDefName", function()
			V.assertMessage(validateCommand('notAUnit'), "Invalid unitDefName: notAUnit. Trigger: t, Parameter: command")
		end)

		it("rejects a command that is neither a number nor a string", function()
			V.assertMessage(validateCommand(true),
				"Unexpected parameter type, expected number or string, got boolean. Trigger: t, Parameter: command")
		end)
	end)

	--- Validates the unitLoadout parameter of the action under test.
	local function validateUnitLoadout(unitLoadout)
		return V.validateAction({ type = V.actionTypes.SpawnUnits, parameters = { unitLoadout = unitLoadout } })
	end

	--- Validates the featureLoadout parameter of the action under test.
	local function validateFeatureLoadout(featureLoadout)
		return V.validateAction({ type = V.actionTypes.CreateFeatures, parameters = { featureLoadout = featureLoadout } })
	end

	describe("UnitLoadout", function()
		it("passes for a well-formed entry", function()
			local result = validateUnitLoadout({ { unitDefName = 'armwar', team = 0, x = 0, z = 0 } })

			V.assertNoMessageContaining(result, "unitLoadout entry")
		end)

		it("rejects the wrong type", function()
			V.assertMessage(validateUnitLoadout('notATable'),
				"Unexpected parameter type, expected table, got string. Action: a, Parameter: unitLoadout")
		end)

		it("reports a missing required field", function()
			local result = validateUnitLoadout({ { unitDefName = 'armwar', x = 0, z = 0 } })

			V.assertMessage(result, "Missing required parameter. Action: a, Parameter: unitLoadout[1].team")
		end)

		it("reports a missing position coordinate", function()
			local result = validateUnitLoadout({ { unitDefName = 'armwar', team = 0, x = 0 } })

			V.assertMessage(result, "Missing required parameter. Action: a, Parameter: unitLoadout[1].z")
		end)

		it("reports a field of the wrong type", function()
			local result = validateUnitLoadout({ { unitDefName = 'armwar', team = 'notANumber', x = 0, z = 0 } })

			V.assertMessage(result, "Unexpected parameter type, expected number, got string. Action: a, Parameter: unitLoadout[1].team")
		end)
	end)

	describe("FeatureLoadout", function()
		it("passes for a well-formed entry", function()
			local result = validateFeatureLoadout({ { featureDefName = 'rockdef', x = 0, z = 0 } })

			V.assertNoMessageContaining(result, "featureLoadout entry")
		end)

		it("rejects the wrong type", function()
			V.assertMessage(validateFeatureLoadout('notATable'),
				"Unexpected parameter type, expected table, got string. Action: a, Parameter: featureLoadout")
		end)

		it("reports a missing position coordinate", function()
			local result = validateFeatureLoadout({ { featureDefName = 'rockdef', z = 0 } })

			V.assertMessage(result, "Missing required parameter. Action: a, Parameter: featureLoadout[1].x")
		end)
	end)
end)
