require("spec_helper")

GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

local actions = VFS.Include("luarules/mission_api/actions/media/start_cutscene.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.start_cutscene", function()

	local startedCutscenes

	before_each(function()
		startedCutscenes = {}
		GG["MissionAPI"].Modules.Cutscenes = {
			StartCutscene = function(cutsceneID, skippable)
				startedCutscenes[#startedCutscenes + 1] = { cutsceneID, skippable }
			end,
		}
	end)

	after_each(function()
		GG["MissionAPI"].Modules.Cutscenes = nil
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "StartCutscene",
			cutsceneID = "CutsceneID!",
			skippable = "Boolean",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("calls Cutscenes.StartCutscene with the given cutsceneID and skippable", function()
			action.actionFunction("intro", true)
			assert.are.same({ { "intro", true } }, startedCutscenes)
		end)
	end)

end)
