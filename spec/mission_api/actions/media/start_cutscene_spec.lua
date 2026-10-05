require("spec_helper")

GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

local actions = VFS.Include("luarules/mission_api/actions/media/start_cutscene.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.start_cutscene", function()

	local startedCutsceneIDs

	before_each(function()
		startedCutsceneIDs = {}
		GG["MissionAPI"].Modules.Cutscenes = {
			StartCutscene = function(cutsceneID)
				startedCutsceneIDs[#startedCutsceneIDs + 1] = cutsceneID
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
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("calls Cutscenes.StartCutscene with the given cutsceneID", function()
			action.actionFunction("intro")
			assert.are.same({ "intro" }, startedCutsceneIDs)
		end)
	end)

end)
