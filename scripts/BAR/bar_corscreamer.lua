--Piece definitions
local flare = piece("flare");
local base = piece("base");
local turret = piece("turret");
local barrel = piece("barrel");

--Signal definitions
local SIG_AIM = 2;

include("include/util.lua");


function script.Create()
	Spring.UnitScript.Hide(flare);
	Spring.UnitScript.StartThread(smoke_unit, base);
end

function script.AimWeapon1(heading, pitch)
	Spring.UnitScript.Signal(SIG_AIM);
	Spring.UnitScript.SetSignalMask(SIG_AIM);	
	Spring.UnitScript.Turn(turret, y_axis, heading, math.rad(125));
	Spring.UnitScript.Turn(barrel, x_axis, -pitch, math.rad(125));
	Spring.UnitScript.WaitForTurn(turret, y_axis);
	return true;
end

function script.FireWeapon1()
	Spring.UnitScript.Show(flare);
	Sleep(150);
	Spring.UnitScript.Hide(flare);
end

function script.QueryWeapon1()
	return flare;
end

function script.AimFromWeapon1()
	return flare;
end

function script.Killed(recentDamage, maxHealth)
	--For explode types BITMAPONLY see LuaConstCOB.cpp (PF_NONE)
	-- -> BITMAPONLY converts to SFX.NONE as argument to Explode
	--constants.h in mod script folder says: BITMAPONLY=32 and BITMAP=10000001
	--http://springrts.com/wiki/Animation-CobConstants says:
	-- "BITMAP[1...5]: Not used in Spring, may overlap with Spring specific bits."
	-- -> BITMAP converts to nothing at all
	--LuaUnitScript.cpp callin notes say recent/max is equal to COB severity
	local severity = (recentDamage / maxHealth) * 100;
	local corpsetype;
	
	Spring.UnitScript.Hide(flare);
	if severity <= 25 then
		corpsetype = 1;
		Spring.UnitScript.Explode(flare, SFX.NONE + SFX.NO_HEATCLOUD);
		Spring.UnitScript.Explode(base, SFX.NONE + SFX.NO_HEATCLOUD);
		Spring.UnitScript.Explode(barrel, SFX.NONE + SFX.NO_HEATCLOUD);
		Spring.UnitScript.Explode(turret, SFX.NONE + SFX.NO_HEATCLOUD);
		return corpsetype;
	end
	if severity <= 50 then
		corpsetype = 2;
		Spring.UnitScript.Explode(flare, SFX.NONE + SFX.NO_HEATCLOUD);
		Spring.UnitScript.Explode(base, SFX.NONE + SFX.NO_HEATCLOUD);
		Spring.UnitScript.Explode(barrel, SFX.NONE + SFX.NO_HEATCLOUD);
		Spring.UnitScript.Explode(turret, SFX.NONE + SFX.NO_HEATCLOUD);
		return corpsetype;	
	end
	if severity <= 99 then
		corpsetype = 3;
		Spring.UnitScript.Explode(flare, SFX.NONE + SFX.NO_HEATCLOUD);
		Spring.UnitScript.Explode(base, SFX.NONE + SFX.NO_HEATCLOUD);
		Spring.UnitScript.Explode(barrel, SFX.NONE + SFX.NO_HEATCLOUD);
		Spring.UnitScript.Explode(turret, SFX.NONE + SFX.NO_HEATCLOUD);
		return corpsetype;	
	end	
	corpsetype = 3;
	Spring.UnitScript.Explode(flare, SFX.NONE + SFX.NO_HEATCLOUD);
	Spring.UnitScript.Explode(base, SFX.NONE + SFX.NO_HEATCLOUD);
	Spring.UnitScript.Explode(barrel, SFX.NONE + SFX.NO_HEATCLOUD);
	Spring.UnitScript.Explode(turret, SFX.NONE + SFX.NO_HEATCLOUD);
	return corpsetype;	
end
