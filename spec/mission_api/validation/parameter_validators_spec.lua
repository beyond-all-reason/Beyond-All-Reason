---
--- The parameter validators, one per parameter type.
---

local V = require("mission_api.validation.validation_spec_helper")

describe("mission_api.validation.parameter_validators", function()
	before_each(V.mockEngineGlobals)

	--- Without a validator, the schema walker calls a nil value
	it("has a validator for every parameter type the definitions use", function()
		local parameterTypes = V.definitions.ParameterTypes
		local parameterValidators =
			V.env.VFS.Include("luarules/mission_api/validation/parameter_validators.lua").CreateParameterValidators({
				Stages = {},
				Objectives = {},
				Triggers = {},
				Actions = {},
				Types = parameterTypes.Types,
				Enums = parameterTypes.Enums,
				EnumSets = parameterTypes.EnumSets,
			})

		local missing = {}
		for _, definitions in ipairs({ V.definitions.ActionDefinitions, V.definitions.TriggerDefinitions }) do
			for entityType, parameters in pairs(definitions.Parameters) do
				for _, parameter in ipairs(parameters) do
					if parameterValidators[parameter.type] == nil then
						missing[#missing + 1] = entityType
							.. "."
							.. parameter.name
							.. " ("
							.. tostring(parameter.type)
							.. ")"
					end
				end
			end
		end
		table.sort(missing)

		assert.are.same({}, missing)
	end)

	describe("String", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({ type = V.actionTypes.SendMessage, parameters = { messageKey = 123 } })

			V.assertMessage(
				result,
				"Unexpected parameter type, expected string, got number. Action: a, Parameter: messageKey"
			)
		end)
	end)

	describe("Number", function()
		it("rejects the wrong type", function()
			local result = V.validateTrigger(V.trigger(V.triggerTypes.TimeElapsed, { seconds = "bad" }))

			V.assertMessage(
				result,
				"Unexpected parameter type, expected number, got string. Trigger: t, Parameter: seconds"
			)
		end)
	end)

	describe("Boolean", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({
				type = V.actionTypes.PlaySound,
				parameters = { soundfile = "x", enqueue = "bad" },
			})

			V.assertMessage(
				result,
				"Unexpected parameter type, expected boolean, got string. Action: a, Parameter: enqueue"
			)
		end)
	end)

	describe("Function", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({ type = V.actionTypes.Custom, parameters = { ["function"] = "bad" } })

			V.assertMessage(
				result,
				"Unexpected parameter type, expected function, got string. Action: a, Parameter: function"
			)
		end)
	end)

	describe("Quantity", function()
		it("rejects a negative number", function()
			local result = V.validateTrigger(V.trigger(V.triggerTypes.UnitsOwned, {
				teamName = "player",
				quantity = -1,
				unitDefName = "armwar",
			}))

			V.assertMessage(result, "Quantity must be >= 0, got -1. Trigger: t, Parameter: quantity")
		end)
	end)

	describe("Fraction", function()
		local function validateProgress(progress)
			return V.validateTrigger(V.trigger(V.triggerTypes.ConstructionProgress, {
				teamName = "player",
				unitDefName = "armwar",
				progress = progress,
			}))
		end

		it("rejects the wrong type", function()
			V.assertMessage(
				validateProgress("bad"),
				"Unexpected parameter type, expected number, got string. Trigger: t, Parameter: progress"
			)
		end)

		it("rejects a value greater than one", function()
			V.assertMessage(
				validateProgress(5.0),
				"Fraction must be between 0 and 1, got 5. Trigger: t, Parameter: progress"
			)
		end)

		it("rejects a negative value", function()
			V.assertMessage(
				validateProgress(-0.5),
				"Fraction must be between 0 and 1, got -0.5. Trigger: t, Parameter: progress"
			)
		end)

		it("accepts the bounds", function()
			V.assertNoMessageContaining(validateProgress(0), "Fraction")
			V.assertNoMessageContaining(validateProgress(1), "Fraction")
		end)
	end)

	describe("TimeOfDay", function()
		local function validateHour(hour)
			return V.validateAction({ type = V.actionTypes.SetMapTimeOfDay, parameters = { hour = hour } })
		end

		it("rejects the wrong type", function()
			V.assertMessage(
				validateHour("noon"),
				"Unexpected parameter type, expected number, got string. Action: a, Parameter: hour"
			)
		end)

		it("rejects an hour outside 0 to 24", function()
			V.assertMessage(
				validateHour(25),
				"TimeOfDay must be an hour from 0 to 24, got 25. Action: a, Parameter: hour"
			)
		end)

		it("accepts midnight as 0 and as 24", function()
			V.assertNoMessageContaining(validateHour(0), "Parameter: hour")
			V.assertNoMessageContaining(validateHour(24), "Parameter: hour")
		end)
	end)

	describe("CompassAngle", function()
		local function validateAzimuth(degrees)
			return V.validateAction({ type = V.actionTypes.SetMapLighting, parameters = { sunAzimuth = degrees } })
		end

		it("rejects the wrong type", function()
			V.assertMessage(
				validateAzimuth("east"),
				"Unexpected parameter type, expected number, got string. Action: a, Parameter: sunAzimuth"
			)
		end)

		it("accepts any number of degrees", function()
			V.assertNoMessageContaining(validateAzimuth(-90), "Parameter: sunAzimuth")
			V.assertNoMessageContaining(validateAzimuth(450), "Parameter: sunAzimuth")
		end)
	end)

	describe("Elevation", function()
		local function validateElevation(degrees)
			return V.validateAction({ type = V.actionTypes.SetMapLighting, parameters = { sunElevation = degrees } })
		end

		it("rejects the wrong type", function()
			V.assertMessage(
				validateElevation("high"),
				"Unexpected parameter type, expected number, got string. Action: a, Parameter: sunElevation"
			)
		end)

		it("rejects an elevation past straight up or down", function()
			V.assertMessage(
				validateElevation(91),
				"Elevation must be between -90 and 90 degrees, got 91. Action: a, Parameter: sunElevation"
			)
			V.assertMessage(
				validateElevation(-91),
				"Elevation must be between -90 and 90 degrees, got -91. Action: a, Parameter: sunElevation"
			)
		end)

		it("accepts straight up and straight down", function()
			V.assertNoMessageContaining(validateElevation(90), "Parameter: sunElevation")
			V.assertNoMessageContaining(validateElevation(-90), "Parameter: sunElevation")
		end)
	end)

	describe("CountdownID", function()
		it("rejects an ID starting with __, which the Mission API keeps for its own countdowns", function()
			V.assertMessage(
				V.validateAction({
					type = V.actionTypes.AddCountdown,
					parameters = { countdownID = "__timeElapsed_t", seconds = 5 },
				}),
				"Invalid countdownID: __timeElapsed_t. Action: a, Parameter: countdownID"
			)
		end)
	end)

	describe("PositiveInteger", function()
		local function validateTimeRemaining(timeRemaining)
			return V.validateTrigger(
				V.trigger(V.triggerTypes.CountdownReached, { countdownID = "bomb", timeRemaining = timeRemaining })
			)
		end

		it("rejects zero, which CountdownFinished covers", function()
			V.assertMessage(
				validateTimeRemaining(0),
				"PositiveInteger must be a whole number > 0, got 0. Trigger: t, Parameter: timeRemaining"
			)
		end)

		it("rejects a negative value", function()
			V.assertMessage(
				validateTimeRemaining(-5),
				"PositiveInteger must be a whole number > 0, got -5. Trigger: t, Parameter: timeRemaining"
			)
		end)

		it("rejects a fractional value", function()
			V.assertMessage(
				validateTimeRemaining(2.5),
				"PositiveInteger must be a whole number > 0, got 2.5. Trigger: t, Parameter: timeRemaining"
			)
		end)

		it("accepts a whole number of seconds", function()
			V.assertNoMessageContaining(validateTimeRemaining(1), "PositiveInteger")
		end)
	end)

	describe("TriggerID", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({ type = V.actionTypes.EnableTrigger, parameters = { triggerID = 123 } })

			V.assertMessage(
				result,
				"Unexpected parameter type, expected string, got number. Action: a, Parameter: triggerID"
			)
		end)

		it("rejects a trigger the mission does not declare", function()
			local result =
				V.validateAction({ type = V.actionTypes.EnableTrigger, parameters = { triggerID = "noSuch" } })

			V.assertMessage(result, "Invalid triggerID: noSuch. Action: a, Parameter: triggerID")
		end)

		it("accepts a trigger the mission declares", function()
			local result = V.validateAction({ type = V.actionTypes.EnableTrigger, parameters = { triggerID = "t" } })

			V.assertNoMessage(result, "Invalid triggerID: t. Action: a, Parameter: triggerID")
		end)
	end)

	describe("StageID", function()
		it("rejects a stage the mission does not declare", function()
			local result = V.validateAction({ type = V.actionTypes.ChangeStage, parameters = { stageID = "noSuch" } })

			V.assertMessage(result, "Invalid stageID: noSuch. Action: a, Parameter: stageID")
		end)
	end)

	describe("ObjectiveID", function()
		it("rejects an objective the mission does not declare", function()
			local result = V.validateAction({
				type = V.actionTypes.UpdateObjective,
				parameters = { objectiveID = "noSuch", completed = true },
			})

			V.assertMessage(result, "Invalid objectiveID: noSuch. Action: a, Parameter: objectiveID")
		end)
	end)

	describe("UnitDefName", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({
				type = V.actionTypes.SpawnUnits,
				parameters = {
					unitLoadout = { { unitDefName = 123, teamName = "player", position = { x = 0, z = 0 } } },
				},
			})

			V.assertMessage(
				result,
				"Unexpected parameter type, expected string, got number. Action: a, Parameter: unitLoadout[1].unitDefName"
			)
		end)

		it("rejects a unit def that does not exist", function()
			local result = V.validateAction({
				type = V.actionTypes.SpawnUnits,
				parameters = {
					unitLoadout = { { unitDefName = "noSuch", teamName = "player", position = { x = 0, z = 0 } } },
				},
			})

			V.assertMessage(result, "Invalid unitDefName: noSuch. Action: a, Parameter: unitLoadout[1].unitDefName")
		end)
	end)

	describe("UnitDefCounts", function()
		local function validateComposition(composition)
			return V.validateAction({
				type = V.actionTypes.DefineSquad,
				parameters = {
					squadName = "raiders",
					teamName = "player",
					position = { x = 0, z = 0 },
					gatherRange = 600,
					composition = composition,
				},
			})
		end

		it("rejects an empty table", function()
			V.assertMessage(validateComposition({}), "unitDefCounts table is empty. Action: a, Parameter: composition")
		end)

		it("rejects a unit def that does not exist", function()
			V.assertMessage(
				validateComposition({ noSuch = 2 }),
				"Invalid unitDefName: noSuch. Action: a, Parameter: composition[noSuch]"
			)
		end)

		it("rejects a count that is not a whole number above zero", function()
			V.assertMessage(
				validateComposition({ armwar = 0 }),
				"PositiveInteger must be a whole number > 0, got 0. Action: a, Parameter: composition[armwar]"
			)
		end)

		it("accepts unit def names with their counts", function()
			V.assertValid(validateComposition({ armwar = 3 }))
		end)
	end)

	describe("FeatureDefName", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({
				type = V.actionTypes.CreateFeatures,
				parameters = { featureLoadout = { { featureDefName = 123, position = { x = 0, z = 0 } } } },
			})

			V.assertMessage(
				result,
				"Unexpected parameter type, expected string, got number. Action: a, Parameter: featureLoadout[1].featureDefName"
			)
		end)

		it("rejects a feature def that does not exist", function()
			local result = V.validateAction({
				type = V.actionTypes.CreateFeatures,
				parameters = { featureLoadout = { { featureDefName = "noSuch", position = { x = 0, z = 0 } } } },
			})

			V.assertMessage(
				result,
				"Invalid featureDefName: noSuch. Action: a, Parameter: featureLoadout[1].featureDefName"
			)
		end)
	end)

	describe("WeaponDefName", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({
				type = V.actionTypes.SpawnExplosion,
				parameters = { weaponDefName = 123, position = { x = 0, z = 0 } },
			})

			V.assertMessage(
				result,
				"Unexpected parameter type, expected string, got number. Action: a, Parameter: weaponDefName"
			)
		end)

		it("rejects a weapon def that does not exist", function()
			local result = V.validateAction({
				type = V.actionTypes.SpawnExplosion,
				parameters = { weaponDefName = "noSuch", position = { x = 0, z = 0 } },
			})

			V.assertMessage(result, "Invalid weaponDefName: noSuch. Action: a, Parameter: weaponDefName")
		end)
	end)

	describe("UnitAttribute", function()
		it("rejects an unknown attribute", function()
			local result = V.validateAction({
				type = V.actionTypes.SetUnitDefAttribute,
				parameters = { unitDefName = "armwar", attribute = "noSuchAttribute", value = 1 },
			})

			V.assertMessage(result, "Unit attribute 'noSuchAttribute' not found. Action: a, Parameter: attribute")
		end)

		it("rejects a weapon attribute", function()
			local result = V.validateAction({
				type = V.actionTypes.SetUnitDefAttribute,
				parameters = { unitDefName = "armwar", attribute = "damage", value = 1 },
			})

			V.assertMessage(result, "Unit attribute 'damage' is written per weapon. Action: a, Parameter: attribute")
		end)
	end)

	describe("WeaponAttribute", function()
		it("rejects a unit attribute", function()
			local result = V.validateAction({
				type = V.actionTypes.SetUnitDefWeaponAttribute,
				parameters = { unitDefName = "armwar", attribute = "losRadius", value = 1 },
			})

			V.assertMessage(
				result,
				"Weapon attribute 'losRadius' is not written per weapon. Action: a, Parameter: attribute"
			)
		end)
	end)

	describe("WeaponNumber", function()
		local function validateWeapon(weapon)
			return V.validateAction({
				type = V.actionTypes.SetUnitDefWeaponModifier,
				parameters = { unitDefName = "armwar", weapon = weapon, attribute = "damage", multiplier = 2 },
			})
		end

		it("rejects a name the engine does not use", function()
			V.assertMessage(
				validateWeapon("death"),
				"Expected a weapon number, 'explode' or 'selfDestruct', got death. Action: a, Parameter: weapon"
			)
		end)

		it("rejects a weapon number that is not a whole number above zero", function()
			V.assertMessage(
				validateWeapon(0),
				"Expected a weapon number, 'explode' or 'selfDestruct', got 0. Action: a, Parameter: weapon"
			)
		end)
	end)

	describe("AttributeValue", function()
		it("rejects a table", function()
			local result = V.validateAction({
				type = V.actionTypes.SetUnitDefAttribute,
				parameters = { unitDefName = "armwar", attribute = "losRadius", value = {} },
			})

			V.assertMessage(
				result,
				"Unexpected parameter type, expected number, string or boolean, got table. Action: a, Parameter: value"
			)
		end)
	end)

	describe("A unit entry's orientation", function()
		local function validateUnitOrientation(orientation)
			return V.validateAction({
				type = V.actionTypes.SpawnUnits,
				parameters = {
					unitLoadout = {
						{
							unitDefName = "armwar",
							teamName = "player",
							position = { x = 0, z = 0 },
							orientation = orientation,
						},
					},
				},
			})
		end

		it("passes for one of the four facings and for a direction", function()
			V.assertNoMessageContaining(validateUnitOrientation("e"), "unitLoadout")
			V.assertNoMessageContaining(validateUnitOrientation({ angle = 45 }), "unitLoadout")
			V.assertNoMessageContaining(validateUnitOrientation({ x = 10, z = 0 }), "unitLoadout")
		end)

		it("validates a table as a Direction", function()
			V.assertMessage(
				validateUnitOrientation({}),
				"Invalid direction parameter, must be either angle { angle }, or direction { x, z, optional y }. Action: a, Parameter: unitLoadout[1].orientation"
			)
		end)

		it("rejects a facing that is not a compass direction", function()
			V.assertMessage(
				validateUnitOrientation("diagonal"),
				"Invalid facing: diagonal. Must be one of 'n', 's', 'e', 'w', 'north', 'south', 'east', 'west'. Action: a, Parameter: unitLoadout[1].orientation"
			)
		end)
	end)

	describe("SoundFile", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({ type = V.actionTypes.PlaySound, parameters = { soundfile = 123 } })

			V.assertMessage(
				result,
				"Unexpected parameter type, expected string, got number. Action: a, Parameter: soundfile"
			)
		end)

		it("rejects a file that does not exist", function()
			local result = V.validateAction({
				type = V.actionTypes.PlaySound,
				parameters = { soundfile = "nonexistent/file.wav" },
			})

			V.assertMessage(
				result,
				"Invalid soundfile: nonexistent/file.wav. File does not exist. Action: a, Parameter: soundfile"
			)
		end)

		it("rejects a file that is not a RIFF .wav", function()
			local originalFileExists = V.env.VFS.FileExists
			local originalReadWAV = V.env.ReadWAV
			V.env.VFS.FileExists = function(path)
				return path == "dummy.wav"
			end
			V.env.ReadWAV = function()
				return nil
			end

			local result =
				V.validateAction({ type = V.actionTypes.PlaySound, parameters = { soundfile = "dummy.wav" } })

			V.env.VFS.FileExists = originalFileExists
			V.env.ReadWAV = originalReadWAV

			V.assertMessage(
				result,
				"Invalid soundfile: dummy.wav. File is not a RIFF .wav file. Action: a, Parameter: soundfile"
			)
		end)
	end)

	describe("SkyboxFile", function()
		local function validateTexture(texture)
			return V.validateAction({ type = V.actionTypes.SetMapSkybox, parameters = { texture = texture } })
		end

		it("rejects a file that is not a .dds", function()
			V.assertMessage(
				validateTexture("maps/sky.png"),
				"Invalid skyboxFile: maps/sky.png. Expected a .dds cubemap. Action: a, Parameter: texture"
			)
		end)

		it("rejects a file that does not exist", function()
			V.assertMessage(
				validateTexture("maps/missing.dds"),
				"Invalid skyboxFile: maps/missing.dds. File does not exist. Action: a, Parameter: texture"
			)
		end)

		it("accepts an existing .dds file", function()
			local originalFileExists = V.env.VFS.FileExists
			V.env.VFS.FileExists = function(path)
				return path == "maps/Sky.DDS"
			end

			local result = validateTexture("maps/Sky.DDS")

			V.env.VFS.FileExists = originalFileExists

			V.assertNoMessageContaining(result, "Parameter: texture")
		end)
	end)

	--- Validates the area parameter of the trigger under test.
	local function validateArea(area)
		return V.validateTrigger(V.trigger(V.triggerTypes.UnitEnteredLocation, { area = area, unitName = "x" }))
	end

	describe("Position", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({
				type = V.actionTypes.AddMapMarker,
				parameters = { markerName = "flag", position = "bad" },
			})

			V.assertMessage(
				result,
				"Unexpected parameter type, expected table, got string. Action: a, Parameter: position"
			)
		end)

		it("rejects a missing coordinate", function()
			local result = V.validateAction({
				type = V.actionTypes.AddMapMarker,
				parameters = { markerName = "flag", position = { z = 0 } },
			})

			V.assertMessage(result, "Missing required parameter. Action: a, Parameter: position.x")
		end)

		it("rejects a coordinate that is not a number", function()
			local result = V.validateAction({
				type = V.actionTypes.AddMapMarker,
				parameters = { markerName = "flag", position = { x = "bad", z = 0 } },
			})

			V.assertMessage(
				result,
				"Unexpected parameter type, expected number, got string. Action: a, Parameter: position.x"
			)
		end)

		it("rejects a false coordinate as the wrong type, not as missing", function()
			local result = V.validateAction({
				type = V.actionTypes.AddMapMarker,
				parameters = { markerName = "flag", position = { x = false, z = 0 } },
			})

			V.assertMessage(
				result,
				"Unexpected parameter type, expected number, got boolean. Action: a, Parameter: position.x"
			)
			V.assertNoMessage(result, "Missing required parameter. Action: a, Parameter: position.x")
		end)

		it("accepts zero coordinates", function()
			local result = V.validateAction({
				type = V.actionTypes.AddMapMarker,
				parameters = { markerName = "flag", position = { x = 0, y = 0, z = 0 } },
			})

			V.assertNoMessageContaining(result, "Parameter: position")
		end)
	end)

	describe("Positions", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({ type = V.actionTypes.DrawLines, parameters = { positions = "bad" } })

			V.assertMessage(
				result,
				"Unexpected parameter type, expected table, got string. Action: a, Parameter: positions"
			)
		end)

		it("rejects fewer than two positions", function()
			local result = V.validateAction({
				type = V.actionTypes.DrawLines,
				parameters = { positions = { { x = 0, z = 0 } } },
			})

			V.assertMessage(result, "Positions table needs at least two positions. Action: a, Parameter: positions")
		end)

		it("rejects an entry that is not a table", function()
			local result = V.validateAction({
				type = V.actionTypes.DrawLines,
				parameters = { positions = { "bad", { x = 0, z = 0 } } },
			})

			V.assertMessage(
				result,
				"Unexpected parameter type, expected table, got string. Action: a, Parameter: positions[1]"
			)
		end)

		it("rejects an entry with a missing coordinate", function()
			local result = V.validateAction({
				type = V.actionTypes.DrawLines,
				parameters = { positions = { { z = 0 }, { x = 0, z = 0 } } },
			})

			V.assertMessage(result, "Missing required parameter. Action: a, Parameter: positions[1].x")
		end)
	end)

	describe("Area", function()
		it("rejects the wrong type", function()
			V.assertMessage(
				validateArea("bad"),
				"Unexpected parameter type, expected table, got string. Trigger: t, Parameter: area"
			)
		end)

		it("rejects a table that is neither a rectangle nor a circle", function()
			V.assertMessage(
				validateArea({}),
				"Invalid area parameter, must be either rectangle { x1, z1, x2, z2 } with x1 < x2 and z1 < z2, or circle { x, z, radius }. Trigger: t, Parameter: area"
			)
		end)

		it("rejects a field that is not a number", function()
			V.assertMessage(
				validateArea({ x1 = "bad", z1 = 0, x2 = 1, z2 = 1 }),
				"Unexpected parameter type, expected number, got string. Trigger: t, Parameter: area.x1"
			)
		end)

		it("rejects a rectangle whose x1 is not less than x2", function()
			V.assertMessage(
				validateArea({ x1 = 1, z1 = 0, x2 = 0, z2 = 1 }),
				"Invalid area rectangle parameter, x1 must be less than x2. Trigger: t, Parameter: area"
			)
		end)

		it("rejects a rectangle whose z1 is not less than z2", function()
			V.assertMessage(
				validateArea({ x1 = 0, z1 = 1, x2 = 1, z2 = 0 }),
				"Invalid area rectangle parameter, z1 must be less than z2. Trigger: t, Parameter: area"
			)
		end)

		it("accepts a circle", function()
			V.assertNoMessageContaining(validateArea({ x = 0, z = 0, radius = 10 }), "area")
		end)
	end)

	describe("Direction", function()
		local function validateDirection(direction)
			return V.validateAction({
				type = V.actionTypes.RotateUnits,
				parameters = { unitName = "x", direction = direction },
			})
		end

		it("rejects the wrong type", function()
			V.assertMessage(
				validateDirection("bad"),
				"Unexpected parameter type, expected table, got string. Action: a, Parameter: direction"
			)
		end)

		it("rejects a table that is neither an angle nor a vector", function()
			V.assertMessage(
				validateDirection({}),
				"Invalid direction parameter, must be either angle { angle }, or direction { x, z, optional y }. Action: a, Parameter: direction"
			)
		end)

		it("rejects a table that is both an angle and a vector", function()
			V.assertMessage(
				validateDirection({ angle = 1, x = 0, z = 0 }),
				"Invalid direction parameter, must be either angle { angle }, or direction { x, z, optional y }, not both. Action: a, Parameter: direction"
			)
		end)

		it("validates a vector as a position", function()
			V.assertMessage(
				validateDirection({ x = "bad", z = 0 }),
				"Unexpected parameter type, expected number, got string. Action: a, Parameter: direction.x"
			)
		end)

		it("rejects an angle that is not a number", function()
			V.assertMessage(
				validateDirection({ angle = "north" }),
				"Unexpected parameter type, expected number, got string. Action: a, Parameter: direction.angle"
			)
		end)

		it("accepts an angle", function()
			V.assertNoMessageContaining(validateDirection({ angle = 90 }), "direction")
		end)

		it("accepts a vector", function()
			V.assertNoMessageContaining(validateDirection({ x = 1, z = 1 }), "direction")
		end)
	end)

	describe("Color", function()
		local function validateLighting(parameters)
			return V.validateAction({ type = V.actionTypes.SetMapLighting, parameters = parameters })
		end

		it("rejects the wrong type", function()
			V.assertMessage(
				validateLighting({ tint = "red" }),
				"Unexpected parameter type, expected table, got string. Action: a, Parameter: tint"
			)
		end)

		it("rejects a missing channel", function()
			V.assertMessage(
				validateLighting({ tint = { r = 1, g = 1 } }),
				"Missing required parameter. Action: a, Parameter: tint.b"
			)
		end)

		it("rejects a negative channel", function()
			V.assertMessage(
				validateLighting({ tint = { r = -1, g = 1, b = 1 } }),
				"Color channel must be >= 0, got -1. Action: a, Parameter: tint.r"
			)
		end)

		it("accepts channels above 1", function()
			V.assertNoMessageContaining(
				validateLighting({ groundDiffuseColor = { r = 1.2, g = 1, b = 0 } }),
				"groundDiffuseColor"
			)
		end)
	end)

	--- Validates the allianceNames parameter of the action under test.
	local function validateAllianceNames(allianceNames)
		return V.validateAction({ type = V.actionTypes.Victory, parameters = { allianceNames = allianceNames } })
	end

	describe("TeamName", function()
		before_each(function()
			V.missionAPI().Teams = { rebels = 0, [0] = "rebels" }
		end)

		it("accepts a named team", function()
			V.assertNoMessageContaining(
				V.validateAction({
					type = V.actionTypes.ChangeTeam,
					parameters = { oldTeamName = "rebels", newTeamName = "rebels" },
				}),
				"Parameter:"
			)
		end)

		it("rejects the wrong type", function()
			V.assertMessage(
				V.validateAction({
					type = V.actionTypes.ChangeTeam,
					parameters = { oldTeamName = 0, newTeamName = "rebels" },
				}),
				"Unexpected parameter type, expected string, got number. Action: a, Parameter: oldTeamName"
			)
		end)

		it("rejects an unknown team name", function()
			V.assertMessage(
				V.validateAction({
					type = V.actionTypes.ChangeTeam,
					parameters = { oldTeamName = "rebels", newTeamName = "nobody" },
				}),
				"Invalid teamName: nobody. Action: a, Parameter: newTeamName"
			)
		end)
	end)

	describe("Gaia's team", function()
		it("is a team name a loadout entry can use", function()
			V.missionAPI().Teams = { rebels = 0, [0] = "rebels", gaia = 1, [1] = "gaia" }

			V.assertValid(V.validateAction({
				type = V.actionTypes.SpawnUnits,
				parameters = {
					unitLoadout = { { unitDefName = "armwar", teamName = "gaia", position = { x = 0, z = 0 } } },
				},
			}))
		end)
	end)

	describe("VariableValue", function()
		local function validateValue(value)
			return V.validateAction({ type = V.actionTypes.WriteVariable, parameters = { key = "k", value = value } })
		end

		it("accepts numbers, strings, booleans and nested tables of them", function()
			for _, value in ipairs({ 1, "text", false, { 1, 2 }, { a = { b = "c" }, [3] = true } }) do
				V.assertValid(validateValue(value))
			end
		end)

		it("rejects a function", function()
			V.assertMessage(
				validateValue(function() end),
				"Unexpected parameter type, expected number, string, boolean or table, got function. Action: a, Parameter: value"
			)
		end)

		it("rejects a function nested in a table", function()
			V.assertMessage(
				validateValue({ a = { 1, function() end } }),
				"Unexpected parameter type, expected number, string, boolean or table, got function. Action: a, Parameter: value.a.2"
			)
		end)

		it("rejects a table key that is not a number or string", function()
			V.assertMessage(
				validateValue({ [true] = 1 }),
				"Unexpected table key type, expected number or string, got boolean. Action: a, Parameter: value.true"
			)
		end)
	end)

	describe("AllianceName", function()
		it("rejects the wrong type", function()
			local result = V.validateTrigger(V.trigger(V.triggerTypes.UnitDetected, {
				unitName = "x",
				sensorAllianceName = 0,
			}))

			V.assertMessage(
				result,
				"Unexpected parameter type, expected string, got number. Trigger: t, Parameter: sensorAllianceName"
			)
		end)

		it("rejects an unknown alliance name", function()
			local result = V.validateTrigger(V.trigger(V.triggerTypes.UnitDetected, {
				unitName = "x",
				sensorAllianceName = "nobody",
			}))

			V.assertMessage(result, "Invalid allianceName: nobody. Trigger: t, Parameter: sensorAllianceName")
		end)
	end)

	describe("AllianceNames", function()
		it("rejects the wrong type", function()
			V.assertMessage(
				validateAllianceNames("bad"),
				"Unexpected parameter type, expected table, got string. Action: a, Parameter: allianceNames"
			)
		end)

		it("rejects an empty table", function()
			V.assertMessage(
				validateAllianceNames({}),
				"allianceNames table is empty. Action: a, Parameter: allianceNames"
			)
		end)

		it("rejects an entry that is not a string", function()
			V.assertMessage(
				validateAllianceNames({ 0 }),
				"Unexpected parameter type, expected string, got number. Action: a, Parameter: allianceNames[1]"
			)
		end)

		it("rejects an unknown alliance name", function()
			V.assertMessage(
				validateAllianceNames({ "nobody" }),
				"Invalid allianceName: nobody. Action: a, Parameter: allianceNames[1]"
			)
		end)

		-- Entries are validated by the AllianceName validator, so every bad one is reported.
		it("reports each unknown alliance name", function()
			local result = validateAllianceNames({ "players", "nobody", "noone" })

			V.assertMessage(result, "Invalid allianceName: nobody. Action: a, Parameter: allianceNames[2]")
			V.assertMessage(result, "Invalid allianceName: noone. Action: a, Parameter: allianceNames[3]")
		end)

		it("accepts named alliances", function()
			V.assertNoMessageContaining(validateAllianceNames({ "players" }), "allianceName")
		end)
	end)

	--- Validates the orders parameter of the action under test.
	local function validateOrders(orders)
		return V.validateAction({
			type = V.actionTypes.IssueOrders,
			parameters = { unitName = "x", orders = orders },
		})
	end

	before_each(function()
		V.mockEngineGlobals()

		-- The engine's CMD table maps both ways (name -> id and id -> name),
		-- which is what the known-command lookup relies on.
		V.env.CMD = {}
		for i, name in ipairs({
			"STOP",
			"SELFD",
			"GUARD",
			"DGUN",
			"MOVE",
			"FIGHT",
			"PATROL",
			"UNLOAD_UNITS",
			"AREA_ATTACK",
			"RESTORE",
			"ATTACK",
			"CAPTURE",
			"REPAIR",
			"LOAD_UNITS",
			"RESURRECT",
			"RECLAIM",
			"CLOAK",
			"ONOFF",
			"FIRE_STATE",
			"MOVE_STATE",
			"WAIT",
			"TIMEWAIT",
			"DEATHWAIT",
			"SQUADWAIT",
			"GATHERWAIT",
			"REPEAT",
		}) do
			V.env.CMD[name] = i
			V.env.CMD[i] = name
		end
		V.env.GameCMD = { AREA_ATTACK_GROUND = 100, [100] = "AREA_ATTACK_GROUND" }
	end)

	after_each(function()
		V.env.CMD = {}
		V.env.GameCMD = {}
	end)

	it("rejects the wrong type", function()
		V.assertMessage(
			validateOrders("bad"),
			"Unexpected parameter type, expected table, got string. Action: a, Parameter: orders"
		)
	end)

	it("rejects an empty orders table", function()
		V.assertMessage(validateOrders({}), "Orders table is empty. Action: a, Parameter: orders")
	end)

	it("rejects an order that is not a table", function()
		V.assertMessage(
			validateOrders({ "notanorder" }),
			"Unexpected parameter type, expected table, got string. Action: a, Parameter: orders[1]"
		)
	end)

	it("rejects a build order for a unit that does not exist", function()
		V.assertMessage(
			validateOrders({ { "notAUnit", { 0, 0, 0 } } }),
			"Invalid build order unitDefName: notAUnit. Action: a, Parameter: orders[1][1]"
		)
	end)

	it("rejects an unknown order option", function()
		V.assertMessage(
			validateOrders({ { V.env.CMD.STOP, nil, { "diagonal" } } }),
			"Invalid order option: diagonal. Action: a, Parameter: orders[1][3]"
		)
	end)

	it("rejects the wrong number of parameters for a move command", function()
		V.assertMessage(
			validateOrders({ { V.env.CMD.MOVE, {} } }),
			"Parameter must be an array of 3 numbers {x, y, z}. Action: a, Parameter: orders[1][2]"
		)
	end)

	it("accepts a unit name instead of coordinates, for commands that allow it", function()
		V.assertNoMessageContaining(validateOrders({ { V.env.CMD.ATTACK, { unitName = "x" } } }), "Parameter must be")
	end)

	it("rejects coordinates for a command that only takes a unit name", function()
		V.assertMessage(
			validateOrders({ { V.env.CMD.GUARD, { 0, 0, 0 } } }),
			"Parameter must be { unitName = 'aUnitName' }. Action: a, Parameter: orders[1][2]"
		)
	end)

	it("accepts a unit name for a command that only takes a unit name", function()
		V.assertNoMessageContaining(validateOrders({ { V.env.CMD.GUARD, { unitName = "x" } } }), "Parameter must be")
	end)

	it("rejects an order that names both a unit and a feature", function()
		V.assertMessage(
			validateOrders({ { V.env.CMD.RECLAIM, { unitName = "x", featureName = "y" } } }),
			"Give a unitName or a featureName, not both. Action: a, Parameter: orders[1][2]"
		)
	end)

	it("warns about an order past a gap, which is never given", function()
		local result = validateOrders({ [1] = { V.env.CMD.STOP }, [3] = { V.env.CMD.STOP } })

		V.assertMessage(result, "Order is never given: orders stop at the first gap. Action: a, Parameter: orders[3]")
		assert.is_true(result.ok)
	end)

	it("warns about a queued wait right after another wait, which can cancel both", function()
		local result = validateOrders({
			{ V.env.CMD.GATHERWAIT },
			{ V.env.CMD.TIMEWAIT, { 5 }, { "shift" } },
		})

		V.assertMessage(
			result,
			"A queued wait right after another wait can cancel both, so neither is kept. Action: a, Parameter: orders[2]"
		)
		assert.is_true(result.ok)
	end)

	it("keeps a third queued wait, after the first two cancel", function()
		local result = validateOrders({
			{ V.env.CMD.GATHERWAIT },
			{ V.env.CMD.TIMEWAIT, { 5 }, { "shift" } },
			{ V.env.CMD.TIMEWAIT, { 5 }, { "shift" } },
		})

		V.assertMessage(
			result,
			"A queued wait right after another wait can cancel both, so neither is kept. Action: a, Parameter: orders[2]"
		)
		V.assertNoMessageContaining(result, "Parameter: orders[3]")
	end)

	it("keeps a queued wait after a wait that went to the front of the queue", function()
		local result = validateOrders({
			{ V.env.CMD.MOVE, { 0, 0, 0 } },
			{ V.env.CMD.GATHERWAIT },
			{ V.env.CMD.TIMEWAIT, { 5 }, { "shift" } },
		})

		V.assertNoMessageContaining(result, "can cancel both")
	end)

	it("reports every invalid order, named after its position in the list", function()
		local result = validateOrders({ { V.env.CMD.MOVE, { 0, 0, 0 } }, { V.env.CMD.MOVE, {} }, { 99999 } })

		V.assertMessage(result, "Parameter must be an array of 3 numbers {x, y, z}. Action: a, Parameter: orders[2][2]")
		V.assertMessage(result, "Unknown command ID: 99999. Action: a, Parameter: orders[3][1]")
	end)

	it("rejects an unknown command ID", function()
		V.assertMessage(
			validateOrders({ { 99999, { 0, 0, 0 } } }),
			"Unknown command ID: 99999. Action: a, Parameter: orders[1][1]"
		)
	end)

	it("accepts commands that take no parameters, given none or an empty table", function()
		local result = validateOrders({
			{ V.env.CMD.STOP },
			{ V.env.CMD.SELFD, {} },
			{ V.env.CMD.WAIT, nil, { "shift" } },
		})

		V.assertNoMessageContaining(result, "Parameter: orders")
	end)

	it("rejects parameters for a command that takes none", function()
		V.assertMessage(
			validateOrders({ { V.env.CMD.STOP, { 1, 2 } } }),
			"Command takes no parameters. Action: a, Parameter: orders[1][2]"
		)
	end)

	it("accepts the coded wait commands with their parameters", function()
		V.assertNoMessageContaining(
			validateOrders({
				{ V.env.CMD.TIMEWAIT, { 5 } },
				{ V.env.CMD.DEATHWAIT, { x1 = 0, z1 = 0, x2 = 100, z2 = 100 } },
				{ V.env.CMD.DEATHWAIT, { unitName = "bosses" } },
				{ V.env.CMD.SQUADWAIT, { 2 } },
				{ V.env.CMD.GATHERWAIT },
			}),
			"Parameter: orders"
		)
	end)

	for _, commandName in ipairs({ "CLOAK", "ONOFF", "REPEAT" }) do
		it("accepts " .. commandName .. " 0 or 1, bare or in a table", function()
			local commandID = V.env.CMD[commandName]

			V.assertNoMessageContaining(
				validateOrders({
					{ commandID, 0 },
					{ commandID, 1 },
					{ commandID, { 0 } },
					{ commandID, { 1 } },
				}),
				"Parameter: orders"
			)
		end)

		it("rejects " .. commandName .. " without a parameter, or with one other than 0 or 1", function()
			local commandID = V.env.CMD[commandName]
			local result = validateOrders({
				{ commandID },
				{ commandID, {} },
				{ commandID, 2 },
				{ commandID, { 2 } },
				{ commandID, { 1, 1 } },
				{ commandID, "1" },
			})

			for index = 1, 6 do
				V.assertMessage(
					result,
					"Parameter must be 0 (off) or 1 (on), as a number or {0} / {1}. Action: a, Parameter: orders["
						.. index
						.. "][2]"
				)
			end
		end)
	end

	it("rejects AREA_ATTACK without a radius", function()
		V.assertMessage(
			validateOrders({ { V.env.CMD.AREA_ATTACK, { 0, 0, 0 } } }),
			"Parameter must be an array of 4 numbers {x, y, z, radius}. Action: a, Parameter: orders[1][2]"
		)
	end)

	--- Validates the command parameter of a Command-typed trigger.
	local function validateCommand(command)
		return V.validateTrigger(V.trigger(V.triggerTypes.UnitOrdered, { command = command, unitName = "x" }))
	end

	describe("Command", function()
		before_each(function()
			V.env.CMD = { MOVE = 1, [1] = "MOVE", CLOAK = 17, [17] = "CLOAK", ANY = "a", BUILD = "b" }
			V.env.GameCMD = {}
		end)

		after_each(function()
			V.env.CMD = {}
			V.env.GameCMD = {}
		end)

		it("accepts a known command id", function()
			V.assertNoMessageContaining(validateCommand(V.env.CMD.MOVE), "command")
		end)

		it("accepts a build order authored as a unitDefName", function()
			V.assertNoMessageContaining(validateCommand("armwar"), "command")
		end)

		it("accepts the ANY qualifier", function()
			V.assertNoMessageContaining(validateCommand(V.env.CMD.ANY), "command")
		end)

		it("accepts the BUILD qualifier", function()
			V.assertNoMessageContaining(validateCommand(V.env.CMD.BUILD), "command")
		end)

		it("warns, but does not error, for a command consumed in AllowCommand", function()
			local result = validateCommand(V.env.CMD.CLOAK)

			V.assertMessage(result, "Command CLOAK may fail to trigger in UnitOrdered. Trigger: t, Parameter: command")
			assert.is_true(result.ok)
		end)

		it("rejects an unknown command id", function()
			V.assertMessage(validateCommand(4242), "Unknown command ID: 4242. Trigger: t, Parameter: command")
		end)

		it("rejects a command that is not a known unitDefName", function()
			V.assertMessage(
				validateCommand("notAUnit"),
				"Invalid unitDefName: notAUnit. Trigger: t, Parameter: command"
			)
		end)

		it("rejects a command that is neither a number nor a string", function()
			V.assertMessage(
				validateCommand(true),
				"Unexpected parameter type, expected number or string, got boolean. Trigger: t, Parameter: command"
			)
		end)
	end)

	--- Validates the unitLoadout parameter of the action under test.
	local function validateUnitLoadout(unitLoadout)
		return V.validateAction({ type = V.actionTypes.SpawnUnits, parameters = { unitLoadout = unitLoadout } })
	end

	--- Validates the featureLoadout parameter of the action under test.
	local function validateFeatureLoadout(featureLoadout)
		return V.validateAction({
			type = V.actionTypes.CreateFeatures,
			parameters = { featureLoadout = featureLoadout },
		})
	end

	describe("UnitLoadout", function()
		it("passes for a well-formed entry", function()
			local result =
				validateUnitLoadout({ { unitDefName = "armwar", teamName = "player", position = { x = 0, z = 0 } } })

			V.assertNoMessageContaining(result, "unitLoadout entry")
		end)

		it("rejects the wrong type", function()
			V.assertMessage(
				validateUnitLoadout("notATable"),
				"Unexpected parameter type, expected table, got string. Action: a, Parameter: unitLoadout"
			)
		end)

		it("reports a missing required field", function()
			local result = validateUnitLoadout({ { unitDefName = "armwar", position = { x = 0, z = 0 } } })

			V.assertMessage(result, "Missing required parameter. Action: a, Parameter: unitLoadout[1].teamName")
		end)

		it("reports a missing position coordinate", function()
			local result =
				validateUnitLoadout({ { unitDefName = "armwar", teamName = "player", position = { x = 0 } } })

			V.assertMessage(result, "Missing required parameter. Action: a, Parameter: unitLoadout[1].position.z")
		end)

		it("reports a field of the wrong type", function()
			local result =
				validateUnitLoadout({ { unitDefName = "armwar", teamName = 0, position = { x = 0, z = 0 } } })

			V.assertMessage(
				result,
				"Unexpected parameter type, expected string, got number. Action: a, Parameter: unitLoadout[1].teamName"
			)
		end)
	end)

	describe("FeatureLoadout", function()
		it("passes for a well-formed entry", function()
			local result = validateFeatureLoadout({ { featureDefName = "rockdef", position = { x = 0, z = 0 } } })

			V.assertNoMessageContaining(result, "featureLoadout entry")
		end)

		it("rejects the wrong type", function()
			V.assertMessage(
				validateFeatureLoadout("notATable"),
				"Unexpected parameter type, expected table, got string. Action: a, Parameter: featureLoadout"
			)
		end)

		it("reports a missing position coordinate", function()
			local result = validateFeatureLoadout({ { featureDefName = "rockdef", position = { z = 0 } } })

			V.assertMessage(result, "Missing required parameter. Action: a, Parameter: featureLoadout[1].position.x")
		end)

		it("passes for an orientation that is a direction", function()
			local result = validateFeatureLoadout({
				{ featureDefName = "rockdef", position = { x = 0, z = 0 }, orientation = { angle = 45 } },
				{ featureDefName = "rockdef", position = { x = 0, z = 0 }, orientation = { x = 10, z = 0 } },
			})

			V.assertNoMessageContaining(result, "featureLoadout")
		end)

		it("validates an orientation table as a Direction", function()
			local result = validateFeatureLoadout({
				{ featureDefName = "rockdef", position = { x = 0, z = 0 }, orientation = {} },
			})

			V.assertMessage(
				result,
				"Invalid direction parameter, must be either angle { angle }, or direction { x, z, optional y }. Action: a, Parameter: featureLoadout[1].orientation"
			)
		end)

		it("validates any other orientation as a Facing", function()
			local result = validateFeatureLoadout({
				{ featureDefName = "rockdef", position = { x = 0, z = 0 }, orientation = "diagonal" },
			})

			V.assertMessage(
				result,
				"Invalid facing: diagonal. Must be one of 'n', 's', 'e', 'w', 'north', 'south', 'east', 'west'. Action: a, Parameter: featureLoadout[1].orientation"
			)
		end)

		it("rejects an orientation that is neither a facing nor a direction", function()
			local result = validateFeatureLoadout({
				{ featureDefName = "rockdef", position = { x = 0, z = 0 }, orientation = true },
			})

			V.assertMessage(
				result,
				"Unexpected parameter type, expected string, number or table, got boolean. Action: a, Parameter: featureLoadout[1].orientation"
			)
		end)
	end)

	local EASINGS = "'cut', 'inCubic', 'inOutCubic', 'inOutQuad', 'inOutSine', 'inQuad', 'inSine', 'linear', "
		.. "'outCubic', 'outQuad', 'outSine', 'smoothstep'"

	describe("camera enums", function()
		local function validateFollowCamera(parameters)
			parameters.position = { x = 0, z = 0 }
			return V.validateAction({ type = V.actionTypes.FollowCamera, parameters = parameters })
		end

		it("accepts a known easing", function()
			V.assertNoMessageContaining(validateFollowCamera({ easing = "inOutSine" }), "easing")
		end)

		it("lists the choices for an unknown easing", function()
			V.assertMessage(
				validateFollowCamera({ easing = "bouncy" }),
				"Invalid easing: 'bouncy'. Must be one of: " .. EASINGS .. ". Action: a, Parameter: easing"
			)
		end)

		it("rejects an easing that is not a string", function()
			V.assertMessage(
				validateFollowCamera({ easing = 3 }),
				"Unexpected parameter type, expected string, got number. Action: a, Parameter: easing"
			)
		end)

		it("rejects an unknown sequence end", function()
			V.assertMessage(
				validateFollowCamera({ ending = "stay" }),
				"Invalid camera sequence end: 'stay'. Must be one of: 'hold', 'release', 'restore'. Action: a, Parameter: ending"
			)
		end)

		it("accepts the game clock and rejects an unknown one", function()
			V.assertNoMessageContaining(validateFollowCamera({ clock = "game" }), "clock")
			V.assertMessage(
				validateFollowCamera({ clock = "sim" }),
				"Invalid camera clock: 'sim'. Must be one of: 'game', 'real'. Action: a, Parameter: clock"
			)
		end)
	end)

	describe("CameraKeyframes", function()
		local function validateKeyframes(keyframes)
			return V.validateAction({ type = V.actionTypes.PlayCameraSequence, parameters = { keyframes = keyframes } })
		end

		it("passes well-formed keyframes", function()
			local hero = { unitDefName = "armwar", position = { x = 0, z = 0 }, teamName = "player", unitName = "hero" }
			local trigger = { type = V.triggerTypes.TimeElapsed, parameters = { seconds = 1 }, actions = { "a" } }
			local keyframes = {
				{ position = { x = 0, z = 0 }, lookAtUnitName = "hero", duration = 0 },
				{ unitName = "hero", offsetZ = -200, offsetY = 100, relativeToHeading = true, path = "spline" },
				{ position = { x = 100, y = 50, z = 100 }, pitch = 45, yaw = 90, roll = 5, fov = 60, hold = 2 },
			}
			local mission = V.mission():WithUnitLoadout({ hero }):WithTrigger("t", trigger):WithAction(
				"a",
				{ type = V.actionTypes.PlayCameraSequence, parameters = { keyframes = keyframes } }
			)

			V.assertValid(V.validate(mission))
		end)

		it("rejects the wrong type and an empty list", function()
			V.assertMessage(
				validateKeyframes("bad"),
				"Unexpected parameter type, expected table, got string. Action: a, Parameter: keyframes"
			)
			V.assertMessage(validateKeyframes({}), "Keyframes table is empty. Action: a, Parameter: keyframes")
		end)

		it("rejects a keyframe that is not a table", function()
			V.assertMessage(
				validateKeyframes({ "bad" }),
				"Unexpected parameter type, expected table, got string. Action: a, Parameter: keyframes[1]"
			)
		end)

		it("requires a position or a unit to ride along with", function()
			V.assertMessage(
				validateKeyframes({ { duration = 1 } }),
				"Keyframe needs one of: 'position', 'unitName'. Action: a, Parameter: keyframes[1]"
			)
		end)

		it("rejects unknown fields", function()
			V.assertMessage(
				validateKeyframes({ { position = { x = 0, z = 0 }, speed = 3 } }),
				"Unknown keyframe field 'speed'. Action: a, Parameter: keyframes[1]"
			)
		end)

		it("checks each field against its type, naming the keyframe and field", function()
			local result = validateKeyframes({
				{ position = { z = 0 }, path = "curve", lookAtUnitName = 7 },
				{ position = { x = 0, z = 0 }, easing = "nope", duration = -1 },
			})

			V.assertMessage(result, "Missing required parameter. Action: a, Parameter: keyframes[1].position.x")
			V.assertMessage(
				result,
				"Invalid camera path: 'curve'. Must be one of: 'linear', 'spline'. Action: a, Parameter: keyframes[1].path"
			)
			V.assertMessage(
				result,
				"Unexpected parameter type, expected string, got number. Action: a, Parameter: keyframes[1].lookAtUnitName"
			)
			V.assertMessage(
				result,
				"Invalid easing: 'nope'. Must be one of: " .. EASINGS .. ". Action: a, Parameter: keyframes[2].easing"
			)
			V.assertMessage(result, "Quantity must be >= 0, got -1. Action: a, Parameter: keyframes[2].duration")
		end)

		it("places the eye once per keyframe", function()
			V.assertMessage(
				validateKeyframes({ { position = { x = 0, z = 0 }, unitName = "hero" } }),
				"Keyframe places the eye twice, use one of: 'position', 'unitName'. Action: a, Parameter: keyframes[1]"
			)
		end)

		it("warns when relativeToHeading has no unit to follow", function()
			local result =
				validateKeyframes({ { position = { x = 0, z = 0 }, offsetX = 10, relativeToHeading = true } })

			V.assertMessage(
				result,
				"Keyframe relativeToHeading needs a unitName to take the heading from. Action: a, Parameter: keyframes[1]"
			)
			assert.is_true(result.ok) -- a warning, not an error
		end)

		it("allows one look-at target per keyframe", function()
			V.assertMessage(
				validateKeyframes({
					{ position = { x = 0, z = 0 }, lookAtUnitName = "hero", lookAtPosition = { x = 1, z = 1 } },
				}),
				"Keyframe has more than one look-at target, use one of: 'lookAtPosition', 'lookAtUnitName'. Action: a, Parameter: keyframes[1]"
			)
		end)

		it("warns when pitch or yaw accompany a look-at target", function()
			local result =
				validateKeyframes({ { position = { x = 0, z = 0 }, lookAtPosition = { x = 1, z = 1 }, pitch = 30 } })

			V.assertMessage(
				result,
				"Keyframe pitch and yaw are ignored while it looks at a target. Action: a, Parameter: keyframes[1]"
			)
			assert.is_true(result.ok)
		end)
	end)
end)
