require("spec_helper")

-- Installs the command ids convertOrdersTargetingNames keys its table by.
require("mission_api.spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The real facing helpers, rather than a stub: IsFacingEW swaps the footprint of
-- non-square units, which decides the grid a quantity spawn lays out on. Taken from
-- the module directly, since common/springFunctions.lua drags in colour utilities
-- that need more ambient state than a spec has.
_G.BAR = _G.BAR or {}
_G.BAR.Utilities = _G.BAR.Utilities or VFS.Include("common/springUtilities/facingFunctions.lua")

local TEAMS = { thePlayerTeam = 0, theEnemyTeam = 5 }

---Builds loadout.lua against the ambient state it reads and captures the
---Spring.CreateUnit calls it makes. loadout.lua walks UnitDefs and reads the Gaia
---team at include time, so all of this has to be in place before it is loaded.
local function loadLoadout()
	Builders.MissionApi.new():WithTeams(TEAMS):Install()
	_G.Spring = Builders.Spring.new():Build()

	-- Def tables and unit spawning are not modelled by the Spring builder, so the few
	-- things loadout.lua touches are pinned here.
	_G.Game.squareSize = 8
	_G.UnitDefs = {}
	_G.FeatureDefNames = {}
	_G.UnitDefNames = { armflash = { id = 42, xsize = 4, zsize = 4 } }

	local createdUnits = {}
	Spring.GetGroundHeight = function()
		return 100
	end
	Spring.CreateUnit = function(unitDefName, x, y, z, facing, teamID, construction)
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
	Spring.GiveOrderArrayToUnit = function() end
	Spring.SetUnitNeutral = function() end

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
				Spring.Log = function(_, _, message)
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
				Spring.Log = function() end
				Spring.GiveOrderArrayToUnit = function()
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
