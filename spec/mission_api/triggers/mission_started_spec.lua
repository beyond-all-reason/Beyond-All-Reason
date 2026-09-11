require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

local missionStarted = VFS.Include("luarules/mission_api/triggers/mission_started.lua")
local onGameStart = missionStarted.callins.GameStart
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.triggers.mission_started", function()
	it("declares its type and takes no parameters", function()
		assert.are.same({ type = "MissionStarted" }, summarizeSchema(missionStarted))
	end)

	it("fires when the game starts", function()
		local context = Builders.TriggerContext.new():Build()
		onGameStart(Builders.Trigger.new():Build(), "t", context)
		assert.are.equal(1, context.timesFired())
	end)

	-- Attempt to check that we never restart. I don't think we can test this here.
	it("can be fired by nothing but GameStart", function()
		local callinNames = {}
		for callinName in pairs(missionStarted.callins) do
			callinNames[#callinNames + 1] = callinName
		end
		assert.are.same({ "GameStart" }, callinNames)
	end)
end)
