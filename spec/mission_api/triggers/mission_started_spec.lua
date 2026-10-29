local TriggerBuilder = VFS.Include("spec/builders/trigger_builder.lua")
local TriggerContextBuilder = VFS.Include("spec/builders/trigger_context_builder.lua")

local missionStarted = VFS.Include("luarules/mission_api/triggers/mission_started.lua")
local onGameStart = missionStarted.callins.GameStart
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.triggers.mission_started", function()
	it("declares its type and takes no parameters", function()
		assert.are.same({ type = "MissionStarted" }, summarizeSchema(missionStarted))
	end)

	it("fires when the game starts", function()
		local context = TriggerContextBuilder.new():Build()
		onGameStart(TriggerBuilder.new():Build(), "t", context)
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
