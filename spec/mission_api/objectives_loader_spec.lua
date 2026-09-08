require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")
local RegisterMissionApiModules = require("mission_api.spec_helper")

-- The real trigger definitions, for the managed-or-synthesized split.
-- (Trigger files read GG['MissionAPI'].Modules at include time.)
Builders.MissionApi.new():Install()
RegisterMissionApiModules()
local triggerDefinitions = VFS.Include("luarules/mission_api/triggers_loader.lua").LoadTriggerDefinitions()

local ObjectivesLoader = VFS.Include("luarules/mission_api/objectives_loader.lua")

describe("mission_api.objectives_loader", function()
	describe("ProcessRawObjectives", function()
		local ACTION_TYPES = { UpdateObjective = 1 }

		local function process(rawObjectives, stages)
			local missionApi = Builders.MissionApi
				.new()
				:WithActionDefinitions({ Types = ACTION_TYPES })
				:WithTriggerDefinitions(triggerDefinitions)
				:Install()
			local rawTriggers = {}
			local objectives = ObjectivesLoader.ProcessRawObjectives(rawObjectives, rawTriggers, {}, stages or {})
			return objectives, rawTriggers, missionApi
		end

		local function timed(seconds)
			return {
				textKey = "t",
				trigger = { type = triggerDefinitions.Types.TimeElapsed, parameters = { seconds = seconds } },
			}
		end

		it("creates every objective inactive", function()
			local objectives = process({ timed = timed(1), bare = { textKey = "b" } })
			assert.is_false(objectives.timed.active)
			assert.is_false(objectives.bare.active)
		end)

		it("synthesizes a disabled trigger for a non-managed objective and records it", function()
			local _, rawTriggers, missionApi = process({ timed = timed(1) })
			assert.is_false(rawTriggers.__objective_timed.settings.active)
			assert.are.equal("__objective_timed", missionApi.ObjectiveTriggers.timed)
		end)

		it("records the stages that list each objective", function()
			local _, _, missionApi = process({ a = { textKey = "a" }, b = { textKey = "b" }, c = { textKey = "c" } }, {
				s1 = { objectives = { "a" } },
				s2 = { objectives = { "b" } },
			})
			assert.are.same({ "s1" }, missionApi.ObjectiveStages.a)
			assert.are.same({ "s2" }, missionApi.ObjectiveStages.b)
			assert.is_nil(missionApi.ObjectiveStages.c)
		end)

		it("records no trigger for a managed objective", function()
			local kills = {
				textKey = "k",
				amount = 2,
				trigger = { type = triggerDefinitions.Types.TotalUnitsKilled, parameters = { teamID = 0 } },
			}
			local _, rawTriggers, missionApi = process({ kills = kills })
			assert.is_nil(rawTriggers.__objective_kills)
			assert.is_nil(missionApi.ObjectiveTriggers.kills)
		end)
	end)
end)
