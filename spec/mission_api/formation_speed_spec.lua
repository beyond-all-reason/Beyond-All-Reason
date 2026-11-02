describe("mission_api.formation_speed", function()
	---@type table
	local FormationSpeed
	---@type table<integer, table>
	local units
	---@type table<integer, number>
	local speedsSet

	-- units: unitID -> { x, z, maxSpeed, wanted, moveType, dead, transporter, queue = { { id, x, z }, ... } }
	before_each(function()
		units, speedsSet = {}, {}
		_G.CMD = { MOVE = 10, PATROL = 15, FIGHT = 16, ATTACK = 20 } ---@diagnostic disable-line: global-in-non-module
		_G.Spring = { ---@diagnostic disable-line: global-in-non-module
			GetUnitMoveTypeData = function(unitID)
				local unit = units[unitID]
				return {
					name = unit.moveType or "ground",
					maxSpeed = unit.maxSpeed,
					maxWantedSpeed = unit.wanted or unit.maxSpeed,
				}
			end,
			GetUnitIsDead = function(unitID)
				return units[unitID].dead == true
			end,
			GetUnitTransporter = function(unitID)
				return units[unitID].transporter
			end,
			GetUnitPosition = function(unitID)
				return units[unitID].x, 0, units[unitID].z
			end,
			GetUnitCommandCount = function(unitID)
				return #units[unitID].queue
			end,
			GetUnitCurrentCommand = function(unitID, index)
				local command = units[unitID].queue[index or 1]
				if command then
					if command.x then
						return command.id, 0, 0, command.x, 0, command.z
					end
					return command.id, 0, 0, 99
				end
			end,
			MoveCtrl = {
				SetGroundMoveTypeData = function(unitID, data)
					speedsSet[unitID] = data.maxWantedSpeed
					units[unitID].wanted = data.maxWantedSpeed
				end,
			},
		}
		FormationSpeed = VFS.Include("luarules/mission_api/formation_speed.lua")
	end)

	local spot = { x = 0, z = 1000 }

	local function command(id, x, z)
		return { id = id, x = x, z = z }
	end

	-- A unit at (x, z), with a MOVE to the spot in its queue.
	local function addUnit(unitID, x, z, maxSpeed, moveType)
		units[unitID] = {
			x = x,
			z = z,
			maxSpeed = maxSpeed,
			moveType = moveType,
			queue = { command(CMD.MOVE, spot.x, spot.z) },
		}
	end

	local function matchAll(unitIDs, commandID)
		local targets = {}
		for i = 1, #unitIDs do
			targets[i] = spot
		end
		FormationSpeed.Match(unitIDs, targets, commandID or CMD.MOVE)
	end

	local function near(expected, actual)
		return math.abs(expected - actual) < 1e-6
	end

	-- Two ground units, 1000 and 500 elmos from their spot.
	local function matchPair()
		addUnit(1, 0, 0, 60)
		addUnit(2, 0, 500, 90)
		matchAll({ 1, 2 })
	end

	it("slows each ground unit by how much shorter its way is than the longest", function()
		matchPair()
		assert.is_true(near(60, speedsSet[1]))
		assert.is_true(near(30, speedsSet[2]))
		assert.is_true(FormationSpeed.IsActive())
	end)

	it("leaves units that are not on a ground move type alone", function()
		matchPair()
		addUnit(3, 0, 0, 200, "gunship")
		matchAll({ 1, 2, 3 })
		assert.is_nil(speedsSet[3])
	end)

	it("does nothing for fewer than two ground units", function()
		addUnit(1, 0, 0, 60)
		addUnit(2, 0, 0, 200, "gunship")
		matchAll({ 1, 2 })
		assert.are.same({}, speedsSet)
		assert.is_false(FormationSpeed.IsActive())
	end)

	it("leaves out a unit whose order is not in its queue, as when it was refused", function()
		addUnit(1, 0, 0, 60)
		addUnit(2, 0, 500, 90)
		addUnit(3, 0, 200, 90)
		units[3].queue = { command(CMD.MOVE, 4000, 4000) }
		matchAll({ 1, 2, 3 })
		assert.is_nil(speedsSet[3])
	end)

	it("leaves out a unit in a transport", function()
		matchPair()
		addUnit(3, 0, 0, 60)
		units[3].transporter = 50
		matchAll({ 1, 3 })
		assert.is_nil(speedsSet[3])
	end)

	it("paces the units again from the way they have left", function()
		matchPair()
		units[1].z, units[2].z = 200, 400
		FormationSpeed.Update()
		assert.is_true(near(60, speedsSet[1]))
		assert.is_true(near(45, speedsSet[2]))
	end)

	it("gives a unit its top speed back when its order is done, and lets a lone unit go", function()
		matchPair()
		units[2].queue = {}
		FormationSpeed.Update()
		assert.is_true(near(90, speedsSet[2]))
		assert.is_true(near(60, speedsSet[1]))
		assert.is_false(FormationSpeed.IsActive())
	end)

	it("gives a unit its top speed back once it has arrived", function()
		matchPair()
		addUnit(3, 0, 200, 90)
		matchAll({ 1, 2, 3 })
		units[2].z = 990
		FormationSpeed.Update()
		assert.is_true(near(90, speedsSet[2]))
		assert.is_true(FormationSpeed.IsActive())
	end)

	it("gives a unit its top speed back when it was given another order", function()
		matchPair()
		units[2].queue = { command(CMD.MOVE, 3000, 0) }
		FormationSpeed.Update()
		assert.is_true(near(90, speedsSet[2]))
	end)

	it("leaves a wanted speed alone that something else has set since", function()
		matchPair()
		units[2].wanted = 45
		speedsSet = {}
		FormationSpeed.Update()
		assert.is_nil(speedsSet[2])
		assert.are.equal(45, units[2].wanted)
		assert.is_true(near(60, speedsSet[1]), "the lone unit left gets its top speed back")
	end)

	it("keeps pacing a FIGHT with an attack pushed in front of it", function()
		addUnit(1, 0, 0, 60)
		addUnit(2, 0, 500, 90)
		for _, unitID in ipairs({ 1, 2 }) do
			units[unitID].queue = { command(CMD.FIGHT, spot.x, spot.z) }
		end
		table.insert(units[1].queue, 1, command(CMD.ATTACK))
		matchAll({ 1, 2 }, CMD.FIGHT)
		units[1].z = 200
		FormationSpeed.Update()
		-- Unit 1 still sets the pace: 800 left against unit 2's 500.
		assert.is_true(near(37.5, speedsSet[2]))
		assert.is_true(FormationSpeed.IsActive())
	end)

	describe("PATROL", function()
		-- The engine queues a PATROL back to where the unit stands, then runs each PATROL as a FIGHT to its point.
		local function patrolPair()
			addUnit(1, 0, 0, 60)
			addUnit(2, 0, 500, 90)
			for _, unitID in ipairs({ 1, 2 }) do
				local unit = units[unitID]
				unit.queue = {
					command(CMD.FIGHT, unit.x, unit.z),
					command(CMD.PATROL, spot.x, spot.z),
					command(CMD.PATROL, unit.x, unit.z),
				}
			end
			matchAll({ 1, 2 }, CMD.PATROL)
		end

		local function onLegToSpot(unitID)
			local unit = units[unitID]
			unit.queue = {
				command(CMD.FIGHT, spot.x, spot.z),
				command(CMD.PATROL, 0, 0),
				command(CMD.PATROL, spot.x, spot.z),
			}
		end

		it("paces the units on their way to the patrol point", function()
			patrolPair()
			assert.is_true(near(30, speedsSet[2]))
			onLegToSpot(1)
			onLegToSpot(2)
			units[1].z, units[2].z = 200, 600
			FormationSpeed.Update()
			assert.is_true(near(30, speedsSet[2]))
			assert.is_true(FormationSpeed.IsActive())
		end)

		it("lets a unit go once its leg to the point is done, though the PATROL stays queued", function()
			patrolPair()
			onLegToSpot(1)
			onLegToSpot(2)
			units[1].z = 200
			FormationSpeed.Update()
			units[2].queue = {
				command(CMD.FIGHT, 0, 0),
				command(CMD.PATROL, spot.x, spot.z),
				command(CMD.PATROL, 0, 0),
			}
			units[2].z = 700
			FormationSpeed.Update()
			assert.is_true(near(90, speedsSet[2]))
			assert.is_false(FormationSpeed.IsActive())
		end)
	end)

	it("paces the others from the next slowest once the slowest is gone", function()
		addUnit(1, 0, 0, 60)
		addUnit(2, 0, 500, 90)
		addUnit(3, 0, 0, 90)
		matchAll({ 1, 2, 3 })
		units[1].dead = true
		FormationSpeed.Update()
		assert.is_true(near(90, speedsSet[3]))
		assert.is_true(near(45, speedsSet[2]))
	end)

	it("lets go of a unit loaded into a transport", function()
		addUnit(1, 0, 0, 60)
		addUnit(2, 0, 500, 90)
		addUnit(3, 0, 200, 90)
		matchAll({ 1, 2, 3 })
		units[3].transporter = 50
		FormationSpeed.Update()
		assert.is_true(near(90, speedsSet[3]))
	end)

	it("drops a dead unit without setting its speed", function()
		addUnit(1, 0, 0, 60)
		addUnit(2, 0, 500, 90)
		addUnit(3, 0, 200, 90)
		matchAll({ 1, 2, 3 })
		units[2].dead = true
		speedsSet = {}
		FormationSpeed.Update()
		assert.is_nil(speedsSet[2])
		assert.is_true(FormationSpeed.IsActive())
	end)

	it("gives a unit under MoveCtrl its top speed back once MoveCtrl ends", function()
		matchPair()
		units[2].moveType = "script"
		units[2].queue = {}
		speedsSet = {}
		FormationSpeed.Update()
		assert.is_nil(speedsSet[2])
		assert.is_true(FormationSpeed.IsActive())

		units[2].moveType = nil
		FormationSpeed.Update()
		assert.is_true(near(90, speedsSet[2]))
		assert.is_false(FormationSpeed.IsActive())
	end)

	it("leaves a unit given a newer formation order to its new group", function()
		matchPair()
		addUnit(3, 0, 0, 60)
		local farSpot = { x = 0, z = 2000 }
		units[2].queue = { command(CMD.MOVE, farSpot.x, farSpot.z) }
		FormationSpeed.Match({ 2, 3 }, { farSpot, spot }, CMD.MOVE)
		FormationSpeed.Update()
		-- Unit 2 has 1500 to go and unit 3 1000, paced to unit 3's top speed of 60.
		assert.is_true(near(60, speedsSet[2]))
		assert.is_true(near(40, speedsSet[3]))
	end)
end)
