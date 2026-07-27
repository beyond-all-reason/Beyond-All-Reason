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
		assert.is_table(byName.tenebrium_device)
		assert.is_table(byName.armada_commander)
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
