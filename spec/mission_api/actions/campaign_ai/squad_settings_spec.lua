local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/campaign_ai/squad_settings.lua")
local setSquadRetreatThreshold, setSquadTarget, setSquadEscort = actions[1], actions[2], actions[3]
local summarizeSchema = require("mission_api.schema_spec_helper")

local TEAM_ID = 3

describe("mission_api.actions.squad_settings", function()
	local squads ---@type table
	local sent ---@type table[]

	local function assembledSquad(squadName)
		local squadID = squads.Define(squadName, TEAM_ID)
		squads.Assemble(TEAM_ID, squadID)
		return squadID
	end

	before_each(function()
		squads = MissionSpecEnv.include(env, "luarules/mission_api/squads.lua")
		MissionApiBuilder.new()
			:WithModule("Squads", squads)
			:WithTrackedUnit("convoy", 202)
			:WithTrackedUnit("convoy", 201)
			:Install()

		sent = {}
		GG.CampaignAI = {
			SetSquadRetreat = function(...)
				sent[#sent + 1] = { "retreat", ... }
			end,
			SetSquadTarget = function(...)
				sent[#sent + 1] = { "target", ... }
			end,
			SetSquadEscort = function(...)
				sent[#sent + 1] = { "escort", ... }
			end,
		}
	end)

	after_each(function()
		GG.CampaignAI = nil
	end)

	describe("SetSquadRetreatThreshold", function()
		it("declares its type and parameters", function()
			assert.are.same(
				{ type = "SetSquadRetreatThreshold", squadName = "SquadName!", threshold = "Fraction" },
				summarizeSchema(setSquadRetreatThreshold)
			)
		end)

		it("sets the threshold of a squad that is still gathering", function()
			local squadID = squads.Define("raiders", TEAM_ID)
			setSquadRetreatThreshold.actionFunction("raiders", 0.3)
			assert.are.same({ { "retreat", squadID, 0.3, false, TEAM_ID } }, sent)
		end)

		it("tells the AI when the squad has its units, which then take the threshold at once", function()
			local squadID = assembledSquad("raiders")
			setSquadRetreatThreshold.actionFunction("raiders", 0)
			assert.are.same({ { "retreat", squadID, 0, true, TEAM_ID } }, sent)
		end)

		it("goes back to the AI's own setting when no threshold is given", function()
			local squadID = squads.Define("raiders", TEAM_ID)
			setSquadRetreatThreshold.actionFunction("raiders")
			assert.are.same({ { "retreat", squadID, -1, false, TEAM_ID } }, sent)
		end)

		it("sends nothing for a squad that is not live", function()
			setSquadRetreatThreshold.actionFunction("raiders", 0.3)
			assert.are.same({}, sent)
		end)
	end)

	describe("SetSquadTarget", function()
		it("declares its type and parameters", function()
			assert.are.same(
				{ type = "SetSquadTarget", squadName = "SquadName!", unitName = "UnitName!" },
				summarizeSchema(setSquadTarget)
			)
		end)

		it("gives an assembled squad the named unit with the lowest ID as its target", function()
			local squadID = assembledSquad("raiders")
			setSquadTarget.actionFunction("raiders", "convoy")
			assert.are.same({ { "target", squadID, 201, TEAM_ID } }, sent)
		end)

		it("sends nothing to a squad that is still gathering", function()
			squads.Define("raiders", TEAM_ID)
			setSquadTarget.actionFunction("raiders", "convoy")
			assert.are.same({}, sent)
		end)

		it("sends nothing for a name no unit has", function()
			assembledSquad("raiders")
			setSquadTarget.actionFunction("raiders", "ghost")
			assert.are.same({}, sent)
		end)
	end)

	describe("SetSquadEscort", function()
		it("declares its type and parameters", function()
			assert.are.same(
				{ type = "SetSquadEscort", squadName = "SquadName!", unitName = "UnitName!" },
				summarizeSchema(setSquadEscort)
			)
		end)

		it("has an assembled squad escort the named unit with the lowest ID", function()
			local squadID = assembledSquad("raiders")
			setSquadEscort.actionFunction("raiders", "convoy")
			assert.are.same({ { "escort", squadID, 201, TEAM_ID } }, sent)
		end)

		it("sends nothing to a squad that is still gathering", function()
			squads.Define("raiders", TEAM_ID)
			setSquadEscort.actionFunction("raiders", "convoy")
			assert.are.same({}, sent)
		end)

		it("sends nothing for a name no unit has", function()
			assembledSquad("raiders")
			setSquadEscort.actionFunction("raiders", "ghost")
			assert.are.same({}, sent)
		end)
	end)
end)
