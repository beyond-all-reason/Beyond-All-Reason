require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- Json.encode is not ours to test; passing the table straight through keeps the
-- assertions on the row building and ordering, which are.
_G.Json = {
	encode = function(value)
		return value
	end,
}

local paramWrites = {}
local playerParamWrites = {}
local unsyncedSends = {}

_G.Spring.SetGameRulesParam = function(name, value)
	paramWrites[#paramWrites + 1] = { name = name, value = value }
end
_G.Spring.SetPlayerRulesParam = function(playerID, name, value, access)
	playerParamWrites[#playerParamWrites + 1] = { playerID = playerID, name = name, value = value, access = access }
end
_G.SendToUnsynced = function(...)
	unsyncedSends[#unsyncedSends + 1] = { ... }
end

Builders.MissionApi.new():Install()

local Presentation = VFS.Include("luarules/mission_api/presentation.lua")

local function lastWrite(name)
	for i = #paramWrites, 1, -1 do
		if paramWrites[i].name == name then
			return paramWrites[i].value
		end
	end
end

describe("mission_api.presentation", function()
	before_each(function()
		paramWrites = {}
		playerParamWrites = {}
		unsyncedSends = {}
		Builders.MissionApi.new():Install()
	end)

	describe("PublishObjectives", function()
		it("publishes a row per objective", function()
			Builders.MissionApi.new():WithObjective("obj1", { textKey = "a", completed = false }):Install()
			Presentation.PublishObjectives()

			local rows = lastWrite("missionObjectives")
			assert.are.equal(1, #rows)
			assert.are.equal("obj1", rows[1].id)
			assert.are.equal("a", rows[1].textKey)
			assert.is_false(rows[1].completed)
			assert.is_false(rows[1].failed)
		end)

		it("omits hidden objectives, because a widget cannot be trusted to", function()
			Builders.MissionApi
				.new()
				:WithObjective("shown", { textKey = "a" })
				:WithObjective("secret", { textKey = "b", hidden = true })
				:Install()
			Presentation.PublishObjectives()

			local rows = lastWrite("missionObjectives")
			assert.are.equal(1, #rows)
			assert.are.equal("shown", rows[1].id)
		end)

		it("orders by the current stage's list, then the rest", function()
			Builders.MissionApi
				.new()
				:WithObjective("third", { textKey = "c" })
				:WithObjective("first", { textKey = "a" })
				:WithObjective("second", { textKey = "b" })
				:Install()
			GG["MissionAPI"].Stages = { only = { objectives = { "first", "second" } } }
			GG["MissionAPI"].CurrentStageID = "only"
			Presentation.PublishObjectives()

			local rows = lastWrite("missionObjectives")
			assert.are.same({ "first", "second", "third" }, { rows[1].id, rows[2].id, rows[3].id })
		end)

		it("bumps the version so a poller can tell something changed", function()
			Builders.MissionApi.new():WithObjective("obj1", { textKey = "a" }):Install()
			Presentation.PublishObjectives()
			local first = lastWrite("missionObjectivesVersion")
			Presentation.PublishObjectives()
			assert.are.equal(first + 1, lastWrite("missionObjectivesVersion"))
		end)

		it("writes a game param while the audience is everyone", function()
			Builders.MissionApi.new():WithObjective("obj1", { textKey = "a" }):Install()
			Presentation.PublishObjectives()
			assert.is_true(#paramWrites > 0)
			assert.are.equal(0, #playerParamWrites)
		end)
	end)

	describe("SendMessage", function()
		it("goes out on the broadcast channel", function()
			Presentation.SendMessage("hello")
			assert.are.equal(1, #unsyncedSends)
			assert.are.equal("MissionMessage", unsyncedSends[1][1])
			assert.are.equal("hello", unsyncedSends[1][2])
		end)
	end)

	describe("interactions", function()
		it("publishes the open interaction as state, not a message", function()
			Presentation.RaiseInteraction("prompt", "ask", nil, nil, nil)
			assert.is_table(lastWrite("missionInteraction"))
			assert.are.equal(0, #unsyncedSends)
		end)

		it("settles on a reply, clearing the param and running the callback", function()
			local answered
			local id = Presentation.RaiseInteraction("prompt", "ask", nil, nil, function(playerID, choice)
				answered = { playerID = playerID, choice = choice }
			end)

			assert.is_true(Presentation.EndInteraction(id, 7, 2))
			assert.are.same({ playerID = 7, choice = 2 }, answered)
			assert.are.equal("", lastWrite("missionInteraction"))
		end)

		it("rejects a reply to an interaction that is not open", function()
			assert.is_false(Presentation.EndInteraction(999, 7, nil))
		end)

		it("rejects a second reply to the same interaction", function()
			local id = Presentation.RaiseInteraction("prompt", "ask", nil, nil, nil)
			assert.is_true(Presentation.EndInteraction(id, 7, nil))
			assert.is_false(Presentation.EndInteraction(id, 7, nil))
		end)
	end)

	describe("IsInAudience", function()
		it("admits everyone while resolveAudience is stubbed", function()
			assert.is_true(Presentation.IsInAudience(0, nil))
			assert.is_true(Presentation.IsInAudience(42, { playerIDs = { 1 } }))
		end)
	end)
end)
