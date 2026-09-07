require("spec_helper")

local RegisterMissionApiModules = require("mission_api.spec_helper")

---Builds loadout.lua against the ambient globals it reads, and captures the
---Spring.CreateUnit calls it makes. loadout.lua walks UnitDefs and reads the Gaia
---team at include time, so all of this has to be in place before it is loaded.
local function loadLoadout()
	local createdUnits = {}

	_G.Game = _G.Game or {}
	_G.Game.squareSize = 8
	_G.Game.maxUnits = 32000
	_G.UnitDefs = {}
	_G.FeatureDefNames = {}
	_G.UnitDefNames = { armflash = { id = 42, xsize = 4, zsize = 4 } }
	_G.BAR = {
		Utilities = {
			IsFacingEW = function()
				return false
			end,
			FacingToHeading = function()
				return 0
			end,
		},
	}

	_G.Spring.GetGroundHeight = function()
		return 100
	end
	_G.Spring.CreateUnit = function(unitDefName, x, y, z, facing, teamID, construction)
		createdUnits[#createdUnits + 1] = {
			unitDefName = unitDefName,
			x = x,
			y = y,
			z = z,
			facing = facing,
			teamID = teamID,
			construction = construction,
		}
		return 1000 + #createdUnits
	end
	_G.Spring.GiveOrderArrayToUnit = function() end
	_G.Spring.SetUnitNeutral = function() end

	_G.GG["MissionAPI"] = {
		Teams = { thePlayerTeam = 0, theEnemyTeam = 5 },
		trackedUnitIDs = {},
		trackedUnitNames = {},
		trackedFeatureIDs = {},
		trackedFeatureNames = {},
	}
	local modules = RegisterMissionApiModules()
	modules.Tracking = { TrackUnit = function() end, TrackFeature = function() end }

	return VFS.Include("luarules/mission_api/loadout.lua"), createdUnits
end

describe("mission_api.loadout", function()
	describe("SpawnUnitLoadout", function()
		-- teamName is resolved to teamID by parameter_processing at load time. Spawning off the
		-- name instead would mean a second lookup per unit, and the earlier "invalid team number
		-- (-2)" crash came from exactly this field being read before it was populated.
		it("spawns onto the resolved teamID", function()
			local loadout, createdUnits = loadLoadout()

			loadout.SpawnUnitLoadout({
				{ unitDefName = "armflash", teamName = "theEnemyTeam", teamID = 5, x = 100, z = 200 },
			})

			assert.are.equal(1, #createdUnits)
			assert.are.equal(5, createdUnits[1].teamID)
		end)

		it("spawns onto team 0 rather than treating it as absent", function()
			local loadout, createdUnits = loadLoadout()

			loadout.SpawnUnitLoadout({
				{ unitDefName = "armflash", teamName = "thePlayerTeam", teamID = 0, x = 100, z = 200 },
			})

			assert.are.equal(0, createdUnits[1].teamID)
		end)

		-- The authored name is kept beside the ID, so reading the wrong one is easy to do and
		-- would reach Spring.CreateUnit as a string.
		it("does not pass the authored team name to the engine", function()
			local loadout, createdUnits = loadLoadout()

			loadout.SpawnUnitLoadout({
				{ unitDefName = "armflash", teamName = "theEnemyTeam", teamID = 5, x = 100, z = 200 },
			})

			assert.are_not.equal("theEnemyTeam", createdUnits[1].teamID)
			assert.is_number(createdUnits[1].teamID)
		end)

		it("spawns one unit per quantity, all on the same team", function()
			local loadout, createdUnits = loadLoadout()

			loadout.SpawnUnitLoadout({
				{ unitDefName = "armflash", teamName = "theEnemyTeam", teamID = 5, x = 100, z = 200, quantity = 3 },
			})

			assert.are.equal(3, #createdUnits)
			for _, created in ipairs(createdUnits) do
				assert.are.equal(5, created.teamID)
			end
		end)

		it("tolerates a mission with no unit loadout", function()
			local loadout = loadLoadout()

			assert.has_no.errors(function()
				loadout.SpawnUnitLoadout(nil)
			end)
		end)

		-- api_missions.lua has to process the top level loadout explicitly, since it is not an
		-- action parameter. If that call is ever dropped, this is the failure mode.
		describe("an unprocessed loadout", function()
			it("is not spawned, rather than spawned onto a nil team", function()
				local loadout, createdUnits = loadLoadout()

				loadout.SpawnUnitLoadout({
					{ unitDefName = "armflash", teamName = "theEnemyTeam", x = 100, z = 200 },
				})

				assert.are.equal(0, #createdUnits)
			end)

			it("is reported with the unit and team it came from", function()
				local loadout = loadLoadout()
				local logged = {}
				_G.Spring.Log = function(_, _, message)
					logged[#logged + 1] = message
				end

				loadout.SpawnUnitLoadout({
					{ unitDefName = "armflash", teamName = "theEnemyTeam", x = 100, z = 200 },
				})

				assert.are.equal(1, #logged)
				assert.is_truthy(logged[1]:find("armflash", 1, true))
				assert.is_truthy(logged[1]:find("theEnemyTeam", 1, true))
			end)

			it("is not given orders, which would take a nil unitID", function()
				local loadout = loadLoadout()
				local orderCalls = 0
				_G.Spring.Log = function() end
				_G.Spring.GiveOrderArrayToUnit = function()
					orderCalls = orderCalls + 1
				end

				loadout.SpawnUnitLoadout({
					{
						unitDefName = "armflash",
						teamName = "theEnemyTeam",
						x = 100,
						z = 200,
						orders = { { CMD.MOVE, { 10, 0, 10 } } },
					},
				})

				assert.are.equal(0, orderCalls)
			end)
		end)
	end)
end)
