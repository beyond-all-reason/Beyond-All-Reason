---@diagnostic disable: undefined-field

local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local GADGET_PATH = "luarules/gadgets/api_unit_type_limits.lua"
local TOWER, SOLAR = 50, 51

-- A world of units { id = { team, def, building, x, z } } and the engine calls the gadget reads.
local function loadGadget(units)
	local blocked, destroyed = {}, {}
	local env = SpecEnv.new({
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
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
			GetUnitsInCylinder = function()
				local ids = {}
				for id in pairs(units) do
					ids[#ids + 1] = id
				end
				return ids
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
	return env.gadget, env.GG.UnitTypeLimits, blocked, destroyed
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

	it("counts from the engine when a cap is set, and blocks once at the cap", function()
		limits.Set(1, TOWER, 2)
		assert.is_nil(blocked["1:50:mission_limit"])
		units[2] = { team = 1, def = TOWER }
		gadget:UnitCreated(2, TOWER, 1)
		assert.are.equal(1, blocked["1:50:mission_limit"])
		gadget:UnitGiven(9, SOLAR, 1, 0)
		assert.are.equal(1, blocked["1:50:mission_limit"], "published once, not on every unit event")
	end)

	it("refuses a new one at the cap and lets one through below it", function()
		limits.Set(1, TOWER, 1)
		assert.is_false(gadget:AllowUnitCreation(TOWER, 9, 1, 100, 0, 100))
		assert.is_true(gadget:AllowUnitCreation(SOLAR, 9, 1, 100, 0, 100))
		assert.is_true(gadget:AllowUnitCreation(TOWER, 9, 0, 100, 0, 100), "another team has no cap")
		gadget:UnitDestroyed(1, TOWER, 1)
		assert.is_nil(blocked["1:50:mission_limit"])
		assert.is_true(gadget:AllowUnitCreation(TOWER, 9, 1, 100, 0, 100))
	end)

	it("lets a builder assist a frame already placed at the cap", function()
		units[1].building = true
		limits.Set(1, TOWER, 1)
		assert.is_true(gadget:AllowUnitCreation(TOWER, 9, 1, 100, 0, 100))
		assert.is_false(gadget:AllowUnitCreation(TOWER, 9, 1, nil, nil, nil), "a factory has no frame to assist")
	end)

	it("removes a frame started past the cap on the next frame", function()
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

	it("stops a resurrection of a capped type at the cap", function()
		limits.Set(1, TOWER, 1)
		assert.is_false(gadget:AllowFeatureBuildStep(9, 1, 7, 3, 0.1))
		assert.is_true(gadget:AllowFeatureBuildStep(9, 1, 7, 3, -0.1), "reclaim goes on")
		assert.is_true(gadget:AllowFeatureBuildStep(9, 1, 8, 3, 0.1), "another wreck")
	end)

	it("takes the cap away with nil", function()
		limits.Set(1, TOWER, 1)
		assert.are.equal(1, blocked["1:50:mission_limit"])
		limits.Set(1, TOWER, nil)
		assert.is_nil(blocked["1:50:mission_limit"])
		assert.is_true(gadget:AllowUnitCreation(TOWER, 9, 1, 100, 0, 100))
	end)
end)
