require("spec_helper")

GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}

local stages = VFS.Include("luarules/mission_api/stages.lua")
local stagesLoader = VFS.Include("luarules/mission_api/stages_loader.lua")

describe("mission_api.stages", function()

	before_each(function()
		GG["MissionAPI"].Stages = {
			first = { objectives = { "a", "b" } },
			second = { objectives = { "c" } },
			third = { objectives = {} },
		}
		GG["MissionAPI"].CurrentStageID = "first"
	end)

	describe("ChangeStage", function()
		it("sets the current stage", function()
			stages.ChangeStage("second")
			assert.are.equal("second", GG["MissionAPI"].CurrentStageID)
		end)

		it("is reflected by GetCurrentStageID", function()
			stages.ChangeStage("third")
			assert.are.equal("third", stages.GetCurrentStageID())
		end)
	end)

	describe("SetInitialStage", function()
		it("sets the current stage without announcing", function()
			stages.SetInitialStage("second")
			assert.are.equal("second", stages.GetCurrentStageID())
		end)
	end)

	describe("GetStage", function()
		it("returns the stage data", function()
			assert.are.same({ objectives = { "a", "b" } }, stages.GetStage("first"))
		end)

		it("returns nil for an unknown stage", function()
			assert.is_nil(stages.GetStage("nope"))
		end)
	end)

	describe("GetObjectiveIDs", function()
		it("defaults to the current stage", function()
			assert.are.same({ "a", "b" }, stages.GetObjectiveIDs())
		end)

		it("accepts an explicit stage", function()
			assert.are.same({ "c" }, stages.GetObjectiveIDs("second"))
		end)

		it("returns an empty list for an unknown stage", function()
			assert.are.same({}, stages.GetObjectiveIDs("nope"))
		end)
	end)
end)

describe("mission_api.stages_loader", function()

	describe("ProcessRawStages", function()
		it("returns the stages unchanged", function()
			local raw = { first = { objectives = { "a" } } }
			assert.are.same(raw, stagesLoader.ProcessRawStages(raw))
		end)

		it("returns an empty table when there are no stages", function()
			assert.are.same({}, stagesLoader.ProcessRawStages(nil))
		end)
	end)

	describe("IndexStagesByObjective", function()
		it("inverts the stage to objective mapping", function()
			local index = stagesLoader.IndexStagesByObjective({
				first = { objectives = { "a", "b" } },
				second = { objectives = { "b" } },
			})
			assert.are.same({ "first" }, index.a)
			table.sort(index.b)
			assert.are.same({ "first", "second" }, index.b)
		end)

		it("omits objectives that appear in no stage", function()
			local index = stagesLoader.IndexStagesByObjective({ first = { objectives = { "a" } } })
			assert.is_nil(index.unused)
		end)

		it("handles missing or malformed stages", function()
			assert.are.same({}, stagesLoader.IndexStagesByObjective(nil))
			assert.are.same({}, stagesLoader.IndexStagesByObjective({ bad = "notATable" }))
		end)
	end)
end)
