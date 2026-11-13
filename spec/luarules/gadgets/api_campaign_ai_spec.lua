local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local GADGET_PATH = "luarules/gadgets/api_campaign_ai.lua"
local TEAM_ID = 3
local AI_HOST_PLAYER_ID = 0
local OTHER_PLAYER_ID = 1

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
			SendLuaRulesMsg = function(message)
				world.luaRulesMessages[#world.luaRulesMessages + 1] = message
			end,
			GetAIInfo = function(teamID)
				return 0, "Campaign AI", world.aiHostPlayerIDs[teamID]
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
		world = {
			rulesParams = { inMission = true },
			gameFrame = 0,
			syncActions = {},
			sent = {},
			removed = {},
			luaRulesMessages = {},
			aiHostPlayerIDs = { [TEAM_ID] = AI_HOST_PLAYER_ID },
		}
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

		it("defines a squad: its ID, where it gathers, then its units in unit def order", function()
			campaignAI.DefineSquad(5, { [9] = 2, [7] = 3 }, 4300, 1600, 600, 400, TEAM_ID)
			assert.same(
				{ { teamID = TEAM_ID, message = "1|201:5|204:1=4300,1600;2=600;3=400|202:7=3;9=2" } },
				world.sent
			)
		end)

		it("leaves a squad's attack range to the AI when none is given", function()
			campaignAI.DefineSquad(5, { [7] = 3 }, 4300, 1600, 600, nil, TEAM_ID)
			assert.same({ { teamID = TEAM_ID, message = "1|201:5|204:1=4300,1600;2=600|202:7=3" } }, world.sent)
		end)

		it("runs a squad: its ID, its task, then where it goes", function()
			campaignAI.RunSquad(5, 1, 4300, 1600, 400, TEAM_ID)
			assert.same({ { teamID = TEAM_ID, message = "1|211:5|213:1|214:1=4300,1600;3=400" } }, world.sent)
		end)

		it("leaves a running squad's attack range as it was defined when none is given", function()
			campaignAI.RunSquad(5, 4, 4300, 1600, nil, TEAM_ID)
			assert.same({ { teamID = TEAM_ID, message = "1|211:5|213:4|214:1=4300,1600" } }, world.sent)
		end)

		it("uses one sync action for messages and one for signals", function()
			local names = table.keys(world.syncActions)
			table.sort(names)
			assert.same({ "CampaignAI", "CampaignAISignal" }, names)
		end)
	end)

	describe("a signal from the AI", function()
		local syncedHalf ---@type table
		local campaignAI ---@type table

		before_each(function()
			loadHalf(false, world)
			local env
			syncedHalf, env = loadHalf(true, world)
			campaignAI = env.GG.CampaignAI
		end)

		it("goes out through the net with its team", function()
			syncedHalf:RecvSkirmishAIMessage(TEAM_ID, "ai_201:5")
			assert.same({ "CampaignAISignal:3:201:5" }, world.luaRulesMessages)
		end)

		it("gets no answer, which the AI would take as its own", function()
			assert.is_nil(syncedHalf:RecvSkirmishAIMessage(TEAM_ID, "ai_201:5"))
		end)

		it("is the only kind of AI message that goes out", function()
			syncedHalf:RecvSkirmishAIMessage(TEAM_ID, "ai_super_fire:12/100/200")
			assert.same({}, world.luaRulesMessages)
		end)

		it("is read back as its team, code and ID when the AI's host sent it", function()
			assert.same({ TEAM_ID, 201, 5 }, { campaignAI.ReadSignal("CampaignAISignal:3:201:5", AI_HOST_PLAYER_ID) })
		end)

		it("is read back with its second ID", function()
			assert.same(
				{ TEAM_ID, 301, 2, 5 },
				{ campaignAI.ReadSignal("CampaignAISignal:3:301:2;5", AI_HOST_PLAYER_ID) }
			)
		end)

		it("is not read when another player sent it", function()
			assert.is_nil(campaignAI.ReadSignal("CampaignAISignal:3:201:5", OTHER_PLAYER_ID))
		end)

		it("is not read from any other message", function()
			assert.is_nil(campaignAI.ReadSignal("VideoPlaybackFinished:1", AI_HOST_PLAYER_ID))
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
