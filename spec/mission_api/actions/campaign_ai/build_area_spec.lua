local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()
env.UnitDefNames = { cordrag = { id = 7, isImmobile = true }, corak = { id = 9, isImmobile = false } }
env.BAR = { Utilities = MissionSpecEnv.include(env, "common/springUtilities/facingFunctions.lua") }

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/campaign_ai/build_area.lua")
local defineBuildArea = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local TEAM_ID = 3
local AREA = { x1 = 0, z1 = 0, x2 = 128, z2 = 128 }
local POLYGON = { 0, 0, 128, 0, 128, 128, 0, 128 }

describe("mission_api.actions.build_area", function()
	local sent ---@type table[]

	before_each(function()
		MissionApiBuilder.new()
			:WithModule("AreaPolygons", MissionSpecEnv.include(env, "luarules/mission_api/area_polygons.lua"))
			:WithModule("BuildAreas", MissionSpecEnv.include(env, "luarules/mission_api/build_areas.lua"))
			:Install()

		sent = {}
		GG.CampaignAI = {
			DefineBuildArea = function(...)
				sent[#sent + 1] = { ... }
			end,
		}
	end)

	after_each(function()
		GG.CampaignAI = nil
	end)

	describe("DefineBuildArea", function()
		it("declares its type and parameters", function()
			assert.are.same({
				type = "DefineBuildArea",
				buildAreaName = "BuildAreaName!",
				teamName = "TeamName!",
				area = "Area!",
				unitDefName = "UnitDefName!",
				facing = "Facing",
				buildsAtOnce = "PositiveInteger",
			}, summarizeSchema(defineBuildArea))
		end)

		it("gives the team's AI the area as a polygon, with the structure by ID and the facing by number", function()
			defineBuildArea.actionFunction("wall", TEAM_ID, AREA, "cordrag", "n", 5)
			assert.are.same({ { 1, POLYGON, 7, 2, 5, TEAM_ID } }, sent)
		end)

		it("faces south and builds three at once unless told otherwise", function()
			defineBuildArea.actionFunction("wall", TEAM_ID, AREA, "cordrag")
			assert.are.same({ { 1, POLYGON, 7, 0, 3, TEAM_ID } }, sent)
		end)

		it("sends nothing for a unit that is not a structure", function()
			defineBuildArea.actionFunction("wall", TEAM_ID, AREA, "corak")
			assert.are.same({}, sent)
		end)

		it("sends nothing while a build area of that name is live", function()
			defineBuildArea.actionFunction("wall", TEAM_ID, AREA, "cordrag")
			defineBuildArea.actionFunction("wall", TEAM_ID, AREA, "cordrag")
			assert.are.equal(1, #sent)
		end)
	end)
end)
