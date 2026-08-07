-- Base-game tripwire for the "allow-consume" behavior (which has some bad consequences).
--
-- Some commands are consumed inside a gadget's :AllowCommand (it returns false), so the
-- engine drops them before firing :UnitCommand. We have no way to probe for this result
-- when the result we are looking for is a successfully executed command, not a failure.
--
-- luarules/mission_api/validation.lua warns mission authors about exactly these commands
-- (its `consumedInAllowCommand` list). This test is then a "tripwire": if a gadget stops
-- consuming one of these, :UnitCommand starts firing for it, and the matching case below
-- fails -- and the consumed list (and anything else blocked by allow-consume) can update.
--
-- Runs under the in-game Test Runner (luaui/Tests; headless via tools/headless_testing).
-- The runner observes the *unsynced* :UnitCommand, but allow-consume blocks the command
-- for everyone, so its absence here faithfully means the synced :UnitCommand never fired.

function skip()
	return Spring.GetGameFrame() <= 0
end

function setup()
	Test.clearMap()
	Test.expectCallin("UnitCommand")
end

function cleanup()
	Test.clearMap()
end

-- Assert that, after `order`, :UnitCommand never fires for `cmdID` within `frames`.
-- A timeout (the command was consumed) is the success case, so we have to catch it.
local function assertConsumed(label, cmdID, fired)
	assert(not fired, label .. ": command reached :UnitCommand, but a gadget should consume it in :AllowCommand")
end

function test()
	local myTeamID = Spring.GetMyTeamID()

	local control = SyncedRun(function(locals)
		local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
		return Spring.CreateUnit("armpw", x, Spring.GetGroundHeight(x, z), z, 0, locals.myTeamID)
	end)
	assert(control, "failed to spawn control unit")

	Spring.GiveOrderToUnit(control, CMD.SELFD, {}, 0)
	Test.waitUntilCallinArgs("UnitCommand", { nil, nil, nil, CMD.SELFD }, 10)
	assert(Spring.GetUnitSelfDTime(control) > 0, "control: SELFD should have applied")

	local commander = SyncedRun(function(locals)
		local x, z = Game.mapSizeX / 2 + 256, Game.mapSizeZ / 2
		return Spring.CreateUnit("armcom", x, Spring.GetGroundHeight(x, z), z, 0, locals.myTeamID)
	end)
	assert(commander, "failed to spawn commander")

	Spring.GiveOrderToUnit(commander, CMD.CLOAK, { 1 }, 0)
	assertConsumed("CMD.CLOAK (unit_cloak)", CMD.CLOAK, yieldable_pcall(function()
		Test.waitUntilCallinArgs("UnitCommand", { nil, nil, nil, CMD.CLOAK }, 15)
	end))

	----------------------------------------------------------------------------
	-- Consumed: Set Target -> unit_target_on_the_move -------------------------
	local shooter = SyncedRun(function(locals)
		local x, z = Game.mapSizeX / 2 - 256, Game.mapSizeZ / 2
		return Spring.CreateUnit("armpw", x, Spring.GetGroundHeight(x, z), z, 0, locals.myTeamID)
	end)
	assert(shooter, "failed to spawn shooter")

	local tx, tz = Game.mapSizeX / 2, Game.mapSizeZ / 2
	Spring.GiveOrderToUnit(shooter, GameCMD.UNIT_SET_TARGET, { tx, Spring.GetGroundHeight(tx, tz), tz }, 0)
	assertConsumed("Set Target (unit_target_on_the_move)", GameCMD.UNIT_SET_TARGET, yieldable_pcall(function()
		Test.waitUntilCallinArgs("UnitCommand", { nil, nil, nil, GameCMD.UNIT_SET_TARGET }, 15)
	end))

	-- TODO: All remaining commands. It's quite a list.
end
