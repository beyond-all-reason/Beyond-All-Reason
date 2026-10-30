local Builders = VFS.Include("spec/builders/index.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

-- What MetaUnitAdded would read for each created unit, by unit ID: as its CreateUnit starts,
-- and once a spawn run inside that CreateUnit has returned.
---@type table<integer, table>
local seenAtCreate = {}
---@type table<integer, table>
local seenAfterNestedSpawn = {}
-- Run inside the next CreateUnit, as a MetaUnitAdded trigger whose action spawns units would be.
---@type function?
local nestedSpawn
local lastUnitID = 0

local function spawnGlobals()
	return {
		name = GG["MissionAPI"].nameOfUnitBeingSpawned,
		isBeingBuilt = GG["MissionAPI"].spawnedUnitIsBeingBuilt,
	}
end

local env = MissionSpecEnv.new({
	Game = { squareSize = 8, footprintScale = 2 },
	UnitDefNames = { armpw = { xsize = 2, zsize = 2 } },
	Spring = {
		GetGroundHeight = function()
			return 0
		end,
		CreateUnit = function()
			lastUnitID = lastUnitID + 1
			local unitID = lastUnitID
			seenAtCreate[unitID] = spawnGlobals()
			if nestedSpawn then
				local spawn = nestedSpawn
				nestedSpawn = nil
				spawn()
				seenAfterNestedSpawn[unitID] = spawnGlobals()
			end
			return unitID
		end,
		GiveOrderArrayToUnit = function() end,
	},
})
env.BAR = { Utilities = MissionSpecEnv.include(env, "common/springUtilities/facingFunctions.lua") }

Builders.MissionApi.new():Install(env)

local loadout = MissionSpecEnv.include(env, "luarules/mission_api/loadout.lua")

local function bot(fields)
	local unit = { unitDefName = "armpw", x = 0, z = 0, team = 0 }
	for key, value in pairs(fields) do
		unit[key] = value
	end
	return unit
end

describe("mission_api.loadout spawned unit names", function()
	before_each(function()
		seenAtCreate = {}
		seenAfterNestedSpawn = {}
		nestedSpawn = nil
	end)

	it("shows the unit's name and construction to MetaUnitAdded while it is created", function()
		loadout.SpawnUnitLoadout({ bot({ unitName = "Outpost", construction = true }) })

		assert.are.same({ name = "Outpost", isBeingBuilt = true }, seenAtCreate[lastUnitID])
		assert.is_nil(GG["MissionAPI"].nameOfUnitBeingSpawned)
		assert.is_nil(GG["MissionAPI"].spawnedUnitIsBeingBuilt)
	end)

	it("keeps them for the outer unit when units spawn inside its CreateUnit", function()
		nestedSpawn = function()
			loadout.SpawnUnitLoadout({ bot({ unitName = "Wave" }) })
		end
		loadout.SpawnUnitLoadout({ bot({ unitName = "Outpost", construction = true }) })
		local outpostID, waveID = lastUnitID - 1, lastUnitID

		assert.are.same({ name = "Wave" }, seenAtCreate[waveID])
		assert.are.same({ name = "Outpost", isBeingBuilt = true }, seenAfterNestedSpawn[outpostID])
		assert.is_nil(GG["MissionAPI"].nameOfUnitBeingSpawned)
		assert.is_nil(GG["MissionAPI"].spawnedUnitIsBeingBuilt)
	end)
end)
