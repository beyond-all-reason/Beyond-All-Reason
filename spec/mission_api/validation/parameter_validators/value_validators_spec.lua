---
--- Lua type, string, number and enum parameter validators.
---

local V = require("mission_api.validation.validation_spec_helper")

describe("mission_api.validation.value_validators", function()
	before_each(V.mockEngineGlobals)

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
end)
