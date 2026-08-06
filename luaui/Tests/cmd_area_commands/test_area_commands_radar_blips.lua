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
   4. Spring.GetUnitNeutral reads unit neutrality with INRADAR, untyped.

 TraceScreenRay hits a radar blip or a unit icon but not a unit ghost.
 It uses GuiTraceRay with useRadar=true so treats blips as icon spheres.
 
 The headless TestRunner uses a player read handle and no globallos/godmode.
 
 Of the above, maybe the trace will change? Maybe ghosts will become real?
]]

function skip()
	return Spring.GetGameFrame() <= 0
end

function setup()
	Test.clearMap()
	-- The headless runner spectates with full view
	Spring.SendCommands("specfullview 0")
end

function cleanup()
	-- restore default spectator full view
	Spring.SendCommands("specfullview 3")
	Test.clearMap()
end

-- Together with SetUnitLosMask, we can force exact LOS bits. Without this, the bits are replaced.
local function forceLosState(unitID, allyTeam, state)
	SyncedRun(function(locals)
		Spring.SetUnitLosMask(locals.unitID, locals.allyTeam, { los = true, radar = true, prevLos = true, contRadar = true })
		Spring.SetUnitLosState(locals.unitID, locals.allyTeam, locals.state)
	end)
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

local function spawn(def, teamID, x, z, neutral)
	-- Not `return SyncedRun(...)` to avoid dropping the locals? I think?
	local unitID = SyncedRun(function(locals)
		local y = Spring.GetGroundHeight(locals.x, locals.z)
		local id = Spring.CreateUnit(locals.def, locals.x, y, locals.z, "south", locals.teamID)
		if id and locals.neutral then
			Spring.SetUnitNeutral(id, true)
		end
		return id
	end)
	return unitID
end

function test()
	local def = "armpw"
	local myAllyTeamID = Spring.GetMyAllyTeamID()
	local myTeamID = Spring.GetMyTeamID()
	local enemyTeamID = Spring.GetGaiaTeamID() -- arbitrary choice

	-- Place enemies outside the attacker's sight so only forced LOS is visible.
	local ax, az = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local bx, bz = ax + 1000, az

	local attackerID = spawn(def, myTeamID, ax, az)
	local blipID = spawn(def, enemyTeamID, bx, bz) -- unseen radar blip
	local neutralBlipID = spawn(def, enemyTeamID, ax + 1000, az - 120, true) -- unseen neutral blip
	local typedID = spawn(def, enemyTeamID, ax + 1000, az + 120) -- seen, then radar
	assert(attackerID and blipID and typedID and neutralBlipID, "failed to create units")

	forceLosState(blipID, myAllyTeamID, { los = false, radar = true, prevLos = false, contRadar = false })
	forceLosState(typedID, myAllyTeamID, { los = false, radar = true, prevLos = true, contRadar = true })
	forceLosState(neutralBlipID, myAllyTeamID, { los = false, radar = true, prevLos = false, contRadar = false })

	Test.waitFrames(5) -- begin actual scenario test --

	local _, fullView = Spring.GetSpectatingState()
	assert(not fullView, "read access must be limited to an allyteam")

	assert(isInCylinder(bx, bz, 200, Spring.ENEMY_UNITS, blipID), "radar-only blips excluded from spatial search")

	assert(Spring.GetUnitDefID(blipID) == nil, ("unitDefID should be nil, got %q"):format(Spring.GetUnitDefID(blipID)))
	assert(Spring.GetUnitDefID(neutralBlipID) == nil, ("unitDefID should be nil, got %q"):format(Spring.GetUnitDefID(neutralBlipID)))
	assert(Spring.GetUnitDefID(typedID) ~= nil, "unitDefID should be non-nil when a radar blip has been seen before")

	assert(Spring.GetUnitNeutral(neutralBlipID) == true, "GetUnitNeutral should read true on a neutral radar blip")

	SyncedRun(function(locals)
		-- Order synced: a spectator can't command through the widget handle.
		Spring.GiveOrderToUnit(locals.attackerID, CMD.ATTACK, { locals.blipID }, 0)
	end)
	Test.waitFrames(5)
	assert(Spring.GetUnitCommandCount(attackerID) >= 1, "engine should accept attacks on a radar blip")
end
