local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

local gameFrame = 0
env.Spring.GetGameFrame = function()
	return gameFrame
end

GG["MissionAPI"] = GG["MissionAPI"] or {}

local effects = MissionSpecEnv.include(env, "luarules/mission_api/effects.lua")

describe("mission_api.effects", function()
	local AREA = { x = 100, z = 100, radius = 50 }
	local createCalls, removedIDs, nextInstanceID

	local function applyEffect(effectName, duration, strength)
		effects.ApplyEffect("Testing", effectName, AREA, duration, strength)
	end

	before_each(function()
		gameFrame = 100
		createCalls = {}
		removedIDs = {}
		nextInstanceID = 0
		GG["MissionAPI"].effectNames = {}
		GG["MissionAPI"].EffectDefinitions = {
			Effects = {
				Testing = {
					Create = function(area, strength)
						nextInstanceID = nextInstanceID + 1
						createCalls[#createCalls + 1] = { area = area, strength = strength }
						return nextInstanceID
					end,
					Remove = function(instanceID)
						removedIDs[#removedIDs + 1] = instanceID
					end,
				},
			},
		}
	end)

	describe("ApplyEffect", function()
		it("creates the effect with its area and strength", function()
			applyEffect("first", nil, 3)
			assert.are.same({ { area = AREA, strength = 3 } }, createCalls)
			assert.are.equal(1, GG["MissionAPI"].effectNames.first.instanceID)
		end)

		it("removes the effect that had the same name before creating the new one", function()
			applyEffect("first")
			applyEffect("first")
			assert.are.same({ 1 }, removedIDs)
			assert.are.equal(2, GG["MissionAPI"].effectNames.first.instanceID)
		end)

		it("keeps effects that have other names", function()
			applyEffect("first")
			applyEffect("second")
			assert.are.same({}, removedIDs)
		end)
	end)

	describe("ClearEffect", function()
		it("removes the effect and forgets its name", function()
			applyEffect("first")
			effects.ClearEffect("first")
			assert.are.same({ 1 }, removedIDs)
			assert.is_nil(GG["MissionAPI"].effectNames.first)
		end)

		it("does nothing for a name that is not applied", function()
			effects.ClearEffect("first")
			assert.are.same({}, removedIDs)
		end)
	end)

	describe("ClearExpiredEffects", function()
		it("keeps an effect until its duration ends, then removes it", function()
			applyEffect("first", 2)
			effects.ClearExpiredEffects(159)
			assert.are.same({}, removedIDs)

			effects.ClearExpiredEffects(160)
			assert.are.same({ 1 }, removedIDs)
			assert.is_nil(GG["MissionAPI"].effectNames.first)
		end)

		it("keeps an effect that has no duration", function()
			applyEffect("first")
			effects.ClearExpiredEffects(1000000)
			assert.are.same({}, removedIDs)
		end)

		it("keeps the effects that have not expired", function()
			applyEffect("first", 1)
			applyEffect("second", 2)
			effects.ClearExpiredEffects(130)
			assert.are.same({ 1 }, removedIDs)
			assert.is_not_nil(GG["MissionAPI"].effectNames.second)
		end)
	end)
end)
