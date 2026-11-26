-- Aerodynamic Lua unit script for C-130 / AC-130 (with 4 spinning propellers), A-10, and HQ Bunker
-- Supports dynamic nose pitch (x_axis) and wing banking / roll (z_axis) driven by flight physics!
local pieceMap = Spring.GetUnitPieceMap(unitID) or {}
local function safePiece(name)
	if pieceMap[name] then
		return piece(name)
	end
	return nil
end

local base = safePiece("base")
local fuselage = safePiece("fuselage") or safePiece("body") or base
local flare = safePiece("flare")
local prop1 = safePiece("prop1")
local prop2 = safePiece("prop2")
local prop3 = safePiece("prop3")
local prop4 = safePiece("prop4")

local spGetUnitRulesParam = Spring.GetUnitRulesParam
local unitDefID = Spring.GetUnitDefID(unitID)
local isAircraft = (unitDefID and UnitDefs[unitDefID] and UnitDefs[unitDefID].canFly) or false

local function FlightAttitudeLoop()
	while true do
		local pitch = spGetUnitRulesParam(unitID, "zdef_flight_pitch") or 0.0
		local roll = spGetUnitRulesParam(unitID, "zdef_flight_roll") or 0.0
		if fuselage then
			-- In Recoil piece coordinates (+X left, +Y up, +Z forward):
			-- Negative x_axis rotation pitches nose UP; positive x_axis pitches nose DOWN.
			-- z_axis rotation banks wings left/right.
			Turn(fuselage, x_axis, -pitch, math.rad(280))
			Turn(fuselage, z_axis, roll, math.rad(320))
		end
		Sleep(30)
	end
end

function script.Create()
	if flare and flare ~= fuselage and flare ~= base then
		Hide(flare)
	end
	if prop1 then Spin(prop1, z_axis, math.rad(1080)) end
	if prop2 then Spin(prop2, z_axis, math.rad(-1080)) end
	if prop3 then Spin(prop3, z_axis, math.rad(1080)) end
	if prop4 then Spin(prop4, z_axis, math.rad(-1080)) end
	if isAircraft and fuselage then
		StartThread(FlightAttitudeLoop)
	end
end

function script.AimFromWeapon1()
	return fuselage or base
end

function script.QueryWeapon1()
	return flare or fuselage or base
end

function script.AimWeapon1(heading, pitch)
	return true
end

function script.FireWeapon1()
end

function script.Killed(recentDamage, maxHealth)
	if fuselage then
		Explode(fuselage, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE)
	end
	return 1
end
