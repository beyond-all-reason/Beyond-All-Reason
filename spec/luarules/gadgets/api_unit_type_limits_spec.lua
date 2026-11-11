---@diagnostic disable: undefined-field

local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local GADGET_PATH = "luarules/gadgets/api_unit_type_limits.lua"
local TOWER, SOLAR = 50, 51

-- A world of units { id = { team, def, building, x, z } } and the engine calls the gadget reads.
local function loadGadget(units, outsideMission)
	local blocked, destroyed, removed = {}, {}, false
	local env = SpecEnv.new({
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
			RemoveGadget = function()
				removed = true
			end,
		},
		UnitDefs = { [TOWER] = { xsize = 2, zsize = 2 }, [SOLAR] = { xsize = 4, zsize = 4 } },
		UnitDefNames = { armllt = { id = TOWER } },
		Spring = {
			GetTeamUnitDefCount = function(teamID, unitDefID)
				local n = 0
				for _, unit in pairs(units) do
					n = n + ((unit.team == teamID and unit.def == unitDefID) and 1 or 0)
				end
				return n
			end,
			GetGameRulesParam = function(name)
				return name == "inMission" and not outsideMission or nil
			end,
			GetUnitsInCylinder = function(x, z, radius)
				local ids = {}
				for id, unit in pairs(units) do
					if ((unit.x or 0) - x) ^ 2 + ((unit.z or 0) - z) ^ 2 <= radius * radius then
						ids[#ids + 1] = id
					end
				end
				return ids
			end,
			GetUnitPosition = function(id)
				return units[id].x or 0, 0, units[id].z or 0
			end,
			GetUnitDefID = function(id)
				return units[id] and units[id].def
			end,
			GetUnitTeam = function(id)
				return units[id] and units[id].team
			end,
			GetUnitIsBeingBuilt = function(id)
				return units[id] ~= nil and units[id].building == true
			end,
			GetFeatureResurrect = function(featureID)
				return featureID == 7 and "armllt" or ""
			end,
			GetTeamList = function()
				return { 0, 1 }
			end,
			DestroyUnit = function(id)
				destroyed[#destroyed + 1] = id
			end,
		},
	})
	env.GG.BuildBlocking = {
		AddBlockedUnit = function(unitDefID, teamID, reason)
			blocked[teamID .. ":" .. unitDefID .. ":" .. reason] = (
				blocked[teamID .. ":" .. unitDefID .. ":" .. reason] or 0
			) + 1
		end,
		RemoveBlockedUnit = function(unitDefID, teamID, reason)
			blocked[teamID .. ":" .. unitDefID .. ":" .. reason] = nil
		end,
	}
	SpecEnv.include(env, GADGET_PATH)
	env.gadget:Initialize()
	return env.gadget, env.GG.UnitTypeLimits, blocked, destroyed, removed
end

describe("api_unit_type_limits", function()
	local units ---@type table
	local gadget ---@type table
	local limits ---@type table
	local blocked ---@type table
	local destroyed ---@type table

	before_each(function()
		units = { [1] = { team = 1, def = TOWER } }
		gadget, limits, blocked, destroyed = loadGadget(units)
	end)

	it("removes itself outside a mission", function()
		local _, outside, _, _, removed = loadGadget(units, true)
		assert.is_true(removed)
		assert.is_nil(outside)
	end)

	it("counts from the engine when a limit is set, and notifies once at the limit while it keeps blocking", function()
		limits.Set(1, TOWER, 2)
		assert.is_nil(blocked["1:50:mission_limit"])
		units[2] = { team = 1, def = TOWER }
		gadget:UnitCreated(2, TOWER, 1)
		assert.are.equal(1, blocked["1:50:mission_limit"])
		gadget:UnitGiven(9, SOLAR, 1, 0)
		assert.are.equal(1, blocked["1:50:mission_limit"], "notified once, not on every unit event")
		assert.is_false(gadget:AllowUnitCreation(TOWER, 9, 1, 100, 0, 100), "still blocked")
	end)

	it("refuses a new one at the limit and lets one through below it", function()
		limits.Set(1, TOWER, 1)
		assert.is_false(gadget:AllowUnitCreation(TOWER, 9, 1, 100, 0, 100))
		assert.is_true(gadget:AllowUnitCreation(SOLAR, 9, 1, 100, 0, 100))
		assert.is_true(gadget:AllowUnitCreation(TOWER, 9, 0, 100, 0, 100), "another team has no limit")
		gadget:UnitDestroyed(1, TOWER, 1)
		assert.is_nil(blocked["1:50:mission_limit"])
		assert.is_true(gadget:AllowUnitCreation(TOWER, 9, 1, 100, 0, 100))
	end)

	it("lets a builder assist a frame already placed at the limit, only on its footprint", function()
		units[1].building, units[1].x, units[1].z = true, 100, 100
		limits.Set(1, TOWER, 1)
		assert.is_true(gadget:AllowUnitCreation(TOWER, 9, 1, 100, 0, 100), "the frame's own spot")
		assert.is_true(gadget:AllowUnitCreation(TOWER, 9, 1, 110, 0, 95), "on its footprint")
		assert.is_false(gadget:AllowUnitCreation(TOWER, 9, 1, 120, 0, 100), "next to it, a new unit")
		assert.is_false(gadget:AllowUnitCreation(TOWER, 9, 1, nil, nil, nil), "a factory has no frame to assist")
		units[1].building = false
		assert.is_false(gadget:AllowUnitCreation(TOWER, 9, 1, 100, 0, 100), "a finished unit is no frame")
	end)

	it("removes a frame started past the limit on the next frame", function()
		limits.Set(1, TOWER, 1)
		units[2] = { team = 1, def = TOWER, building = true }
		gadget:UnitCreated(2, TOWER, 1, 9)
		gadget:GameFrame()
		assert.are.same({ 2 }, destroyed)
	end)

	it("follows a unit given to another team", function()
		limits.Set(0, TOWER, 1)
		limits.Set(1, TOWER, 5)
		assert.is_nil(blocked["0:50:mission_limit"])
		gadget:UnitGiven(1, TOWER, 0, 1)
		assert.are.equal(1, blocked["0:50:mission_limit"])
	end)

	it("refuses a unit shared to a team at its limit and lets a captured one through", function()
		limits.Set(1, TOWER, 1)
		assert.is_false(gadget:AllowUnitTransfer(5, TOWER, 0, 1, false))
		assert.is_true(gadget:AllowUnitTransfer(5, TOWER, 0, 1, true))
		assert.is_true(gadget:AllowUnitTransfer(5, SOLAR, 0, 1, false), "a type without a limit")
		limits.Set(1, TOWER, 2)
		assert.is_true(gadget:AllowUnitTransfer(5, TOWER, 0, 1, false), "below the limit")
	end)

	it("stops a resurrection of a limited type at the limit", function()
		limits.Set(1, TOWER, 1)
		assert.is_false(gadget:AllowFeatureBuildStep(9, 1, 7, 3, 0.1))
		assert.is_true(gadget:AllowFeatureBuildStep(9, 1, 7, 3, -0.1), "reclaim goes on")
		assert.is_true(gadget:AllowFeatureBuildStep(9, 1, 8, 3, 0.1), "another wreck")
	end)

	it("reads the limit and the count back", function()
		limits.Set(1, TOWER, 2)
		assert.are.same({ 2, 1 }, { limits.Get(1, TOWER) })
		assert.is_nil(limits.Get(1, SOLAR))
	end)

	it("takes the limit away with nil", function()
		limits.Set(1, TOWER, 1)
		assert.are.equal(1, blocked["1:50:mission_limit"])
		limits.Set(1, TOWER, nil)
		assert.is_nil(blocked["1:50:mission_limit"])
		assert.is_true(gadget:AllowUnitCreation(TOWER, 9, 1, 100, 0, 100))
	end)
end)
