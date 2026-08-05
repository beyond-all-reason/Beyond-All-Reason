--[[
 In-engine verification of the line-of-sight & radar facts that the Area Command
 Filter widget relies on and can only stub in its cmd_area_commands_filter_spec.
 
 This seems generally useful enough not to include under a specific widget name.
 If the tests are expanded, then identify this file per the area_commands file.
 
 The busted spec models a radar blip as "a unit present in queries whose
 GetUnitDefID returns nil". That model is only valid if the engine does so:
 
   1. Spring.GetUnitsInCylinder(..., ENEMY_UNITS) returns a radar-only blip
      because IsUnitVisible includes INRADAR.
   2. Spring.GetUnitDefID(blip) is nil for an unseen blip (IsUnitTyped).
   3. It is non-nil for a unit that was seen, then tracked (PREVLOS+CONTRADAR).
 
 TraceScreenRay hits a radar blip or a unit icon but not a unit ghost.
 It uses GuiTraceRay with useRadar=true so treats blips as icon spheres.
 
 The headless TestRunner uses a player read handle and no globallos/godmode.
 
 Of the above, maybe the trace will change? Maybe ghosts will become real?
]]

local ATTACKER_DEF = "armpw"
local ENEMY_DEF = "armpw"

function skip()
	return Spring.GetGameFrame() <= 0
end

function setup()
	Test.clearMap()
end

function cleanup()
	Test.clearMap()
end

-- Together with SetUnitLosMask, we can force exact LOS bits. Without this, the bits are replaced.
local function forceLosState(unitID, allyTeam, state)
	SyncedRun(
		function(locals)
			Spring.SetUnitLosMask(
				locals.unitID, locals.allyTeam,
				{ los = true, radar = true, prevLos = true, contRadar = true }
			)
			Spring.SetUnitLosState(locals.unitID, locals.allyTeam, locals.state)
		end,
		50,
		{ unitID = unitID, allyTeam = allyTeam, state = state }
	)
end

local function isInCylinder(cx, cz, radius, allegiance, unitID)
	local units = Spring.GetUnitsInCylinder(cx, cz, radius, allegiance)
	for i = 1, #units do
		if units[i] == unitID then
			return true
		end
	end
	return false
end

function test()
	local myAllyTeamID = Spring.GetMyAllyTeamID()
	local myTeamID = Spring.GetMyTeamID()
	local enemyTeamID = Spring.GetGaiaTeamID() -- arbitrary choice

	-- Check outside the attacker's sight distance so the only visibility is what we force.
	local ax, az = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local ex, ez = ax + 1000, az
	local tx, tz = ax + 1000, az + 120

	local attackerID = SyncedRun(function(locals)
		local y = Spring.GetGroundHeight(locals.ax, locals.az)
		return Spring.CreateUnit(locals.def, locals.ax, y, locals.az, "south", locals.myTeamID)
	end, 50, { def = ATTACKER_DEF, ax = ax, az = az, myTeamID = myTeamID })
	assert(attackerID, "failed to create attacker")

	local blipID = SyncedRun(function(locals)
		local y = Spring.GetGroundHeight(locals.ex, locals.ez)
		return Spring.CreateUnit(locals.def, locals.ex, y, locals.ez, "south", locals.enemyTeamID)
	end, 50, { def = ENEMY_DEF, ex = ex, ez = ez, enemyTeamID = enemyTeamID })
	assert(blipID, "failed to create unseen radar blip")

	local typedID = SyncedRun(function(locals)
		local y = Spring.GetGroundHeight(locals.tx, locals.tz)
		return Spring.CreateUnit(locals.def, locals.tx, y, locals.tz, "south", locals.enemyTeamID)
	end, 50, { def = ENEMY_DEF, tx = tx, tz = tz, enemyTeamID = enemyTeamID })
	assert(typedID, "failed to create typed radar blip")

	forceLosState(blipID, myAllyTeamID, { los = false, radar = true, prevLos = false, contRadar = false })
	forceLosState(typedID, myAllyTeamID, { los = false, radar = true, prevLos = true, contRadar = true })

	Test.waitFrames(5) -- begin actual scenario test --

	assert(not Spring.GetSpectatingState(), "test must run as a player")

	assert(isInCylinder(ex, ez, 200, Spring.ENEMY_UNITS, blipID), "radar-only blips excluded from spatial search")

	assert(Spring.GetUnitDefID(blipID) == nil, "unitDefID should be nil, got " .. tostring(Spring.GetUnitDefID(blipID)))

	assert(Spring.GetUnitDefID(typedID) ~= nil, "unitDefID should be non-nil when a radar blip has been seen before")

	Spring.GiveOrderToUnit(attackerID, CMD.ATTACK, { blipID }, 0)
	Test.waitFrames(5)
	assert(Spring.GetUnitCommandCount(attackerID) >= 1, "engine should accept attacks on a radar blip")
end
