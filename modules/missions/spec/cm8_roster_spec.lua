--- The shipped roster stays loadable and keeps declaring the names
--- triggers/*.lua reference, through the same sandbox the loader builds.

local Roster = VFS.Include("modules/missions/lib/roster.lua")
local Verbs = VFS.Include("modules/missions/lib/verbs.lua")

describe("cm8_ashfall roster", function()
	local byName = {}
	local groups = {}

	setup(function()
		local file = Roster.ForFile("cm8_ashfall/units.lua")
		VFS.Include("modules/missions/cm8_ashfall/units.lua", {
			Spawn = file.Spawn,
			Claim = file.Claim,
			UnitDef = Verbs.UnitDef,
		})
		for _, entry in ipairs(file.Finalize()) do
			if entry.name then
				byName[entry.name] = entry
			end
			if entry.group then
				groups[entry.group] = (groups[entry.group] or 0) + 1
			end
		end
	end)

	it("declares every name the trigger files reference", function()
		assert.is_table(byName.outpost_command_hub)
		assert.is_table(byName.enclave_beacon)
		assert.is_table(byName.tenebrium_device)
		assert.is_table(byName.armada_commander)
	end)

	it("claims the player's commander so losing it can mean something", function()
		-- The game already spawned it; the mission binds it. The defeat
		-- trigger speaks its name — an unnamed commander's death is a fact
		-- no trigger can see.
		assert.is_true(byName.player_commander.claim)
		assert.are.equal("player", byName.player_commander.team)
	end)

	it("claims the enemy commander rather than adding a second one", function()
		-- The mission is playable in a skirmish, where the enemy seat already
		-- has a commander. Spawning would leave that team with two, and the
		-- objective pointing at the wrong one.
		assert.is_true(byName.armada_commander.claim)
		assert.are.equal("enemy", byName.armada_commander.team)
		-- and it still says where to build one when the seat is empty, which is
		-- the case in CM8's own single-player game.
		assert.are.equal(0.77, byName.armada_commander.fx)
		assert.are.equal(0.77, byName.armada_commander.fz)
	end)

	it("the whole outpost starts inert, so it cannot shoot its finder", function()
		for name, entry in pairs(byName) do
			if entry.group == "outpost_auto" then
				assert.is_true(entry.neutral, name .. " must not open fire before it is handed over")
			end
		end
		-- and the enclave is emphatically NOT neutral
		assert.is_nil(byName.enclave_beacon.neutral)
		assert.is_nil(byName.tenebrium_device.neutral)
		assert.is_nil(byName.armada_commander.neutral)
	end)

	it("the beacon sits on the enclave's rim, nearer than the device", function()
		-- The discovery order IS the objective order: a push from the outpost
		-- (0.42) meets the beacon before the device, so find_the_enclave
		-- cannot arrive after find_the_tenebrium_device.
		assert.is_true(byName.enclave_beacon.fx < byName.tenebrium_device.fx)
		assert.is_true(byName.enclave_beacon.fz < byName.tenebrium_device.fz)
		assert.are.equal("enemy", byName.enclave_beacon.team)
	end)

	it("the outpost is spawned outright — nothing exists to claim on gaia", function()
		assert.is_nil(byName.outpost_command_hub.claim)
	end)

	it("the protected hub travels with the transferred outpost group", function()
		assert.are.equal("outpost_auto", byName.outpost_command_hub.group)
		assert.is_true(groups.outpost_auto > 1)
	end)

	it("the outpost spawns pilotless and the enclave hostile", function()
		assert.are.equal("gaia", byName.outpost_command_hub.team)
		assert.are.equal("enemy", byName.tenebrium_device.team)
		assert.are.equal("enemy", byName.armada_commander.team)
	end)
end)
