local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local GADGET_PATH = "luarules/gadgets/api_campaign_ai.lua"
local TEAM_ID = 3

-- One half of the gadget. What the synced half sends reaches the unsynced half's sync actions through world.
local function loadHalf(synced, world)
	local half = synced and "synced" or "unsynced"
	local env = SpecEnv.new({
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return synced
			end,
			RemoveGadget = function()
				world.removed[half] = true
			end,
			AddSyncAction = function(_, name, action)
				world.syncActions[name] = action
			end,
			RemoveSyncAction = function(_, name)
				world.syncActions[name] = nil
			end,
		},
		SendToUnsynced = function(name, ...)
			world.syncActions[name](name, ...)
		end,
		Spring = {
			GetGameRulesParam = function(name)
				return world.rulesParams[name]
			end,
			GetGameFrame = function()
				return world.gameFrame, 0
			end,
			SendSkirmishAIMessage = function(teamID, message)
				world.sent[#world.sent + 1] = { teamID = teamID, message = message }
			end,
		},
	})
	SpecEnv.include(env, GADGET_PATH)
	env.gadget:Initialize()
	return env.gadget, env
end

describe("api_campaign_ai", function()
	local world ---@type table

	before_each(function()
		world = { rulesParams = { inMission = true }, gameFrame = 0, syncActions = {}, sent = {}, removed = {} }
	end)

	describe("before the game starts", function()
		local campaignAI ---@type table
		local unsyncedHalf ---@type table

		before_each(function()
			unsyncedHalf = loadHalf(false, world)
			local _, env = loadHalf(true, world)
			campaignAI = env.GG.CampaignAI
		end)

		it("holds a message, because the AI does not exist yet", function()
			campaignAI.SetAiState(1, TEAM_ID)
			assert.same({}, world.sent)
		end)

		it("sends the held messages in their order when the game starts", function()
			campaignAI.SetAiState(1, TEAM_ID)
			campaignAI.SetAiActive(false, TEAM_ID)

			unsyncedHalf:GameStart()

			assert.same({
				{ teamID = TEAM_ID, message = "1|6:1" },
				{ teamID = TEAM_ID, message = "1|1:0" },
			}, world.sent)
		end)
	end)

	it("sends at once when it loads into a running game", function()
		world.gameFrame = 90
		loadHalf(false, world)
		local _, env = loadHalf(true, world)

		env.GG.CampaignAI.SetAiState(1, TEAM_ID)

		assert.same({ { teamID = TEAM_ID, message = "1|6:1" } }, world.sent)
	end)

	describe("once the game has started", function()
		local campaignAI ---@type table

		before_each(function()
			local unsyncedHalf = loadHalf(false, world)
			unsyncedHalf:GameStart()
			local _, env = loadHalf(true, world)
			campaignAI = env.GG.CampaignAI
		end)

		it("enables unit defs for the team's AI", function()
			campaignAI.SetUnitDefsEnabled({ 7, 8 }, true, TEAM_ID)
			assert.same({ { teamID = TEAM_ID, message = "1|2:7;8" } }, world.sent)
		end)

		it("disables unit defs for the team's AI", function()
			campaignAI.SetUnitDefsEnabled({ 7 }, false, TEAM_ID)
			assert.same({ { teamID = TEAM_ID, message = "1|3:7" } }, world.sent)
		end)

		it("gives units back to the AI's control", function()
			campaignAI.SetUnitsCtrlEnabled({ 101, 102 }, true, TEAM_ID)
			assert.same({ { teamID = TEAM_ID, message = "1|4:101;102" } }, world.sent)
		end)

		it("takes units out of the AI's control", function()
			campaignAI.SetUnitsCtrlEnabled({ 101 }, false, TEAM_ID)
			assert.same({ { teamID = TEAM_ID, message = "1|5:101" } }, world.sent)
		end)

		it("activates the AI", function()
			campaignAI.SetAiActive(true, TEAM_ID)
			assert.same({ { teamID = TEAM_ID, message = "1|1:1" } }, world.sent)
		end)

		it("deactivates the AI", function()
			campaignAI.SetAiActive(false, TEAM_ID)
			assert.same({ { teamID = TEAM_ID, message = "1|1:0" } }, world.sent)
		end)

		it("sets the AI's state", function()
			campaignAI.SetAiState(4, TEAM_ID)
			assert.same({ { teamID = TEAM_ID, message = "1|6:4" } }, world.sent)
		end)

		it("sends every message through one sync action", function()
			assert.same({ "CampaignAI" }, table.keys(world.syncActions))
		end)
	end)

	describe("outside a mission", function()
		before_each(function()
			world.rulesParams.inMission = nil
		end)

		it("removes the synced half", function()
			loadHalf(true, world)
			assert.is_true(world.removed.synced)
		end)

		it("removes the unsynced half before it listens for messages", function()
			loadHalf(false, world)
			assert.is_true(world.removed.unsynced)
			assert.same({}, world.syncActions)
		end)
	end)

	describe("on shutdown", function()
		it("takes its API away", function()
			local gadget, env = loadHalf(true, world)
			gadget:Shutdown()
			assert.is_nil(env.GG.CampaignAI)
		end)

		it("stops listening for messages", function()
			local gadget = loadHalf(false, world)
			gadget:Shutdown()
			assert.same({}, world.syncActions)
		end)
	end)
end)
