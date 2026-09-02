-- Rocketeer aims from a piece on its arm. At rest the arm hangs down, so a
-- ridge between the bot and a ground Set Target blocks the line of fire that
-- both the gadget and the engine measure from that lowered piece. The target
-- stays listed but is never fired at until something else raises the arm.

local CMD_SET_TARGET = GameCMD.UNIT_SET_TARGET
local ATTACKER = "armrock"

local function skip()
	return Spring.GetGameFrame() <= 0
end

local function setup()
	Test.clearMap()
end

local function cleanup()
	Test.clearMap()
	SyncedRun(function()
		Spring.RevertHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, 1.0)
	end)
end

local function echo(...)
	Spring.Echo("[settarget-wall]", ...)
end

local function hasWeaponTarget(unitID)
	local ttype = Spring.GetUnitWeaponTarget(unitID, 1)
	return ttype ~= nil and ttype ~= 0
end

local function probe(unitID, tx, ty, tz)
	local r = SyncedRun(function(locals)
		local unitID, x, y, z = locals.unitID, locals.tx, locals.ty, locals.tz
		local function run()
			local pieces = Spring.GetUnitPieceMap(unitID)
			local function lofFrom(pieceName)
				local px, py, pz = Spring.GetUnitPiecePosDir(unitID, pieces[pieceName])
				return string.format("%s(y=%.1f)=%s", pieceName, py, tostring(Spring.GetUnitWeaponHaveFreeLineOfFire(unitID, 1, px, py, pz, x, y, z)))
			end
			return string.format(
				"range=%s lof: default=%s %s %s %s",
				tostring(Spring.GetUnitWeaponTestRange(unitID, 1, x, y, z)),
				tostring(Spring.GetUnitWeaponHaveFreeLineOfFire(unitID, 1, nil, nil, nil, x, y, z)),
				lofFrom("aimpoint"),
				lofFrom("lbarrel"),
				lofFrom("aimy1")
			)
		end
		return CallAsTeam(Spring.GetUnitTeam(unitID), run)
	end)
	return r
end

local function test()
	local attackerName = ATTACKER
	local myTeam = Spring.GetLocalTeamID()
	local cx, cz = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local dist = 360
	local tx, tz = cx + dist, cz

	-- flatten the area, then raise a ridge halfway to the target
	SyncedRun(function(locals)
		local cx, cz = locals.cx, locals.cz
		Spring.LevelHeightMap(cx - 200, cz - 200, cx + 600, cz + 200, 100)
		Spring.SetHeightMapFunc(function()
			for x = cx + 160, cx + 200, 8 do
				for z = cz - 120, cz + 120, 8 do
					Spring.SetHeightMap(x, z, 100 + 9)
				end
			end
		end)
	end, 100)
	Test.waitFrames(5)
	local ty = Spring.GetGroundHeight(tx, tz)

	local attacker = SyncedRun(function(locals)
		return Spring.CreateUnit(locals.attackerName, locals.cx, 100, locals.cz, 1, locals.myTeam)
	end)
	Test.waitFrames(60)

	echo("arm at rest:", probe(attacker, tx, ty, tz))
	Spring.GiveOrderToUnit(attacker, CMD_SET_TARGET, { tx, ty, tz }, 0)
	local orderFrame = Spring.GetGameFrame()
	Test.waitUntil(function()
		return hasWeaponTarget(attacker) or Spring.GetGameFrame() > orderFrame + 120
	end, 130)
	echo(string.format("weapon picked the target up after %d frames", Spring.GetGameFrame() - orderFrame))
	local listed = SyncedProxy.gadgetHandler.GG.GetUnitTargetList(attacker) ~= nil
	echo(string.format("after set target: listed=%s weaponTarget=%s %s", tostring(listed), tostring(hasWeaponTarget(attacker)), probe(attacker, tx, ty, tz)))
	local restFired = hasWeaponTarget(attacker)

	-- raise the arm: one attack on the open floor in front, then remove the order
	Spring.GiveOrderToUnit(attacker, CMD.ATTACK, { cx + 100, 100, cz }, 0)
	Test.waitFrames(90)
	Spring.GiveOrderToUnit(attacker, CMD.STOP, {}, 0)
	Spring.GiveOrderToUnit(attacker, CMD_SET_TARGET, { tx, ty, tz }, 0)
	Test.waitFrames(60)
	echo(string.format("arm raised: listed=%s weaponTarget=%s %s", tostring(SyncedProxy.gadgetHandler.GG.GetUnitTargetList(attacker) ~= nil), tostring(hasWeaponTarget(attacker)), probe(attacker, tx, ty, tz)))
	local raisedFired = hasWeaponTarget(attacker)

	-- same ridge, but the target is an enemy unit behind it
	local enemy = SyncedRun(function(locals)
		return Spring.CreateUnit("corsolar", locals.tx, 100, locals.tz, 0, Spring.GetGaiaTeamID())
	end)
	local bot2 = SyncedRun(function(locals)
		return Spring.CreateUnit(locals.attackerName, locals.cx, 100, locals.cz + 100, 1, locals.myTeam)
	end)
	Test.waitFrames(60)
	Spring.GiveOrderToUnit(bot2, CMD_SET_TARGET, { enemy }, 0)
	orderFrame = Spring.GetGameFrame()
	Test.waitUntil(function()
		return hasWeaponTarget(bot2) or Spring.GetGameFrame() > orderFrame + 120
	end, 130)
	local unitTargetFired = hasWeaponTarget(bot2)
	echo(string.format("unit target behind ridge: weapon has target=%s after %d frames", tostring(unitTargetFired), Spring.GetGameFrame() - orderFrame))

	-- a Lua-scripted unit must not break the prefire path
	local lus = SyncedRun(function(locals)
		return Spring.CreateUnit("armcom", locals.cx, 100, locals.cz - 100, 1, locals.myTeam)
	end)
	Test.waitFrames(30)
	Spring.GiveOrderToUnit(lus, CMD_SET_TARGET, { tx, ty, tz }, 0)
	Test.waitFrames(60)
	echo("lua-scripted commander with the same target: listed=" .. tostring(SyncedProxy.gadgetHandler.GG.GetUnitTargetList(lus) ~= nil))

	-- a plain Attack order on the ground behind the ridge
	local bot3 = SyncedRun(function(locals)
		return Spring.CreateUnit(locals.attackerName, locals.cx, 100, locals.cz - 60, 1, locals.myTeam)
	end)
	Test.waitFrames(60)
	local sx = Spring.GetUnitPosition(bot3)
	Spring.GiveOrderToUnit(bot3, CMD.ATTACK, { tx, ty, tz - 60 }, 0)
	orderFrame = Spring.GetGameFrame()
	Test.waitUntil(function()
		return hasWeaponTarget(bot3) or Spring.GetGameFrame() > orderFrame + 150
	end, 160)
	local attackFired = hasWeaponTarget(bot3)
	local ex = Spring.GetUnitPosition(bot3)
	echo(string.format("attack order behind ridge: weapon has target=%s after %d frames, walked %.0f elmos", tostring(attackFired), Spring.GetGameFrame() - orderFrame, ex - sx))

	-- an idle bot on fire-at-will with an armed enemy behind the ridge
	local bot4 = SyncedRun(function(locals)
		return Spring.CreateUnit(locals.attackerName, locals.cx, 100, locals.cz + 60, 1, locals.myTeam)
	end)
	local enemy2 = SyncedRun(function(locals)
		return Spring.CreateUnit("corak", locals.tx, 100, locals.tz + 60, 0, Spring.GetGaiaTeamID())
	end)
	orderFrame = Spring.GetGameFrame()
	Test.waitUntil(function()
		return hasWeaponTarget(bot4) or Spring.GetGameFrame() > orderFrame + 200
	end, 210)
	local autoFired = hasWeaponTarget(bot4)
	echo(string.format("auto-target behind ridge: weapon has target=%s after %d frames, enemy in LOS=%s", tostring(autoFired), Spring.GetGameFrame() - orderFrame, tostring(Spring.IsUnitInLos(enemy2, Spring.GetLocalAllyTeamID()))))

	assert(listed, "set target was dropped")
	assert(attackFired, "Rocketeer never fires at an Attack order on ground behind a ridge while its arm is at rest")
	assert(autoFired, "Rocketeer never auto-targets an enemy behind a ridge while its arm is at rest")
	assert(unitTargetFired, "Rocketeer never fires at an enemy unit behind a ridge while its arm is at rest")
	assert(raisedFired, "even with the arm raised the target is not fired at; wall too high for this test")
	assert(restFired, "Rocketeer never fires at a ground Set Target behind a ridge while its arm is at rest")
end

return { skip = skip, setup = setup, test = test, cleanup = cleanup, wall = 40 }
