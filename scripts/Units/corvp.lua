local pad,base,nano1,nano2,nano3,nano4,fan1,fan2,doorr,doorl,doorf,cagelight,cagelight_emit = piece("pad","base","nano1","nano2","nano3","nano4","fan1","fan2","doorr","doorl","doorf","cagelight","cagelight_emit");

local spray = 0;

local SIGNAL_TURNON = 2;
local SIG_OPENCLOSE = 4;

include("include/util.lua");

function open()
	UnitScript.Signal(SIG_OPENCLOSE);
	UnitScript.SetSignalMask(SIG_OPENCLOSE);
	--Activate
	UnitScript.Move(doorl, x_axis, -17, 17);
	UnitScript.Move(doorr, x_axis, 17, 17);
	UnitScript.Move(doorf, y_axis, -16, 16);
	UnitScript.WaitForMove(doorl, x_axis);
	Sleep(1000);
	--Open yard
	open_yard();
	--Get into buildstance
	UnitScript.SetUnitValue(COB.INBUILDSTANCE, 1);
end

function close()
	UnitScript.Signal(SIG_OPENCLOSE);
	UnitScript.SetSignalMask(SIG_OPENCLOSE);
	--Get out of buildstance
	UnitScript.SetUnitValue(COB.INBUILDSTANCE, 0);
	--Close yard
	close_yard();
	--Deactivate
	UnitScript.Move(doorf, y_axis, 16, 16);
	UnitScript.Move(doorl, x_axis, 0, 17);
	UnitScript.Move(doorr, x_axis, 0, 17);
	UnitScript.Move(doorf, y_axis, 0, 16);
	UnitScript.WaitForMove(doorl, x_axis);
	Sleep(500);
end

function script.Create()
	Hide(nano1);
	Hide(nano2);
	Hide(nano3);
	Hide(nano4);
	Hide (cagelight_emit);
	spray = 0;
	UnitScript.StartThread(smoke_unit, base);
end

function script.QueryNanoPiece()
	local pieceIndex;
	if (spray == 0) then
		pieceIndex = nano1;
	end
	if (spray == 1) then
		pieceIndex = nano2;
	end
	if (spray == 2) then
		pieceIndex = nano3;
	end
	if (spray == 3) then
		pieceIndex = nano4;
	end
	spray = spray + 1;
	if(spray == 4) then
		spray = 0;
	end
	return pieceIndex;
end

function Activate_real()
	UnitScript.Signal(SIGNAL_TURNON);
	UnitScript.StartThread(open);

end

function script.Activate()
	UnitScript.StartThread(Activate_real);
end

function Deactivate_real()
	UnitScript.Signal(SIGNAL_TURNON);
	UnitScript.SetSignalMask(SIGNAL_TURNON);
	Sleep(5000);
	UnitScript.StartThread(close);
end

function script.Deactivate()
	UnitScript.StartThread(Deactivate_real);
end

function script.StartBuilding()
	Show(nano1);
	Show(nano2);
	Show(nano3);
	Show(nano4);
	Show (cagelight_emit);
	Spin (cagelight_emit, y_axis,3);
	UnitScript.Spin(fan1, z_axis, math.rad(200), math.rad(5));
	UnitScript.Spin(fan2, z_axis, math.rad(200), math.rad(5));
end

function script.StopBuilding()
	Hide(nano1);
	Hide(nano2);
	Hide(nano3);
	Hide(nano4);
	Hide (cagelight_emit);
	Turn (cagelight_emit, y_axis,0,15);
	UnitScript.StopSpin(fan1, z_axis, math.rad(3));
	UnitScript.StopSpin(fan2, z_axis, math.rad(3));
end

function script.QueryBuildInfo()
	return pad;
end

function script.Killed(recentDamage, maxHealth)
	local severity = (recentDamage / maxHealth) * 100;
	local corpsetype;

	if (severity <= 25) then
		corpsetype = 1;
		UnitScript.Explode(base,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(doorf,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(doorl,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(doorr,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(fan1,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(fan2,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano1,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano2,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano3,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano4,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(pad,SFX.NONE + SFX.NO_HEATCLOUD);
		return corpsetype;
	end
	if (severity <= 50) then
		corpsetype = 2;
		UnitScript.Explode(base,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(doorf,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(doorl,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(doorr,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(fan1,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(fan2,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano1,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano2,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano3,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano4,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(pad,SFX.NONE + SFX.NO_HEATCLOUD);
		return corpsetype;
	end
	if (severity <= 99) then
		corpsetype = 3;
		UnitScript.Explode(base,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(doorf,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(doorl,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(doorr,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(fan1,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(fan2,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano1,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano2,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano3,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano4,SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(pad,SFX.NONE + SFX.NO_HEATCLOUD);
		return corpsetype;
	end
	corpsetype = 3;
	UnitScript.Explode(base,SFX.NONE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(doorf,SFX.NONE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(doorl,SFX.NONE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(doorr,SFX.NONE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(fan1,SFX.NONE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(fan2,SFX.NONE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(nano1,SFX.NONE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(nano2,SFX.NONE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(nano3,SFX.NONE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(nano4,SFX.NONE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(pad,SFX.NONE + SFX.NO_HEATCLOUD);
	return corpsetype;
end
