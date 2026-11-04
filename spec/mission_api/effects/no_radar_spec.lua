local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}

local unitsInArea = {}
env.Spring.GetUnitsInCylinder = function()
	return unitsInArea
end
local areaTracking = MissionSpecEnv.include(env, "luarules/mission_api/area_tracking.lua")
GG["MissionAPI"].Modules.AreaTracking = areaTracking

local effect = MissionSpecEnv.include(env, "luarules/mission_api/effects/no_radar.lua")

describe("mission_api.effects.no_radar", function()
	local AREA = { x = 100, z = 100, radius = 50 }
	local multipliers, createdIDs

	local function create()
		local id = effect.Create(AREA, 1)
		createdIDs[#createdIDs + 1] = id
		return id
	end

	local function hasRadarRemoved(unitID)
		return next(multipliers[unitID] or {}) ~= nil
	end

	before_each(function()
		unitsInArea = {}
		multipliers = {}
		createdIDs = {}
		GG.UnitAttributes.SetUnitModifier = function(unitID, attribute, multiplier, source)
			assert.are.equal("radarRadius", attribute)
			multipliers[unitID] = multipliers[unitID] or {}
			multipliers[unitID][source] = multiplier
		end
	end)

	after_each(function()
		for _, id in ipairs(createdIDs) do
			effect.Remove(id)
		end
	end)

	it("removes the radar of units already inside its area", function()
		unitsInArea = { 100, 101 }
		create()
		assert.is_true(hasRadarRemoved(100))
		assert.is_true(hasRadarRemoved(101))
	end)

	it("scales radar to zero, so that a value set on the unit cannot restore it", function()
		unitsInArea = { 100 }
		create()
		local _, multiplier = next(multipliers[100])
		assert.are.equal(0, multiplier)
	end)

	it("follows units as they enter and leave", function()
		create()
		unitsInArea = { 100 }
		areaTracking.UpdateTrackedAreas()
		assert.is_true(hasRadarRemoved(100))

		unitsInArea = {}
		areaTracking.UpdateTrackedAreas()
		assert.is_false(hasRadarRemoved(100))
	end)

	it("restores every unit inside when it is removed", function()
		unitsInArea = { 100, 101 }
		effect.Remove(create())
		assert.is_false(hasRadarRemoved(100))
		assert.is_false(hasRadarRemoved(101))
	end)

	it("keeps a unit's radar removed until every overlapping effect is gone", function()
		unitsInArea = { 100 }
		local first = create()
		local second = create()
		effect.Remove(first)
		assert.is_true(hasRadarRemoved(100))
		effect.Remove(second)
		assert.is_false(hasRadarRemoved(100))
	end)
end)
