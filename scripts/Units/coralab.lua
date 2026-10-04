local base, pad, head1, head2, nano1, nano2, nano3, nano4, center1, center2, side1, side2, mount1, mount2, cagelight, cagelight_emit, cagelight2, cagelight_emit2 = piece("base", "pad", "head1", "head2", "nano1", "nano2", "nano3", "nano4", "center1", "center2", "side1", "side2", "mount1", "mount2", "cagelight", "cagelight_emit", "cagelight2", "cagelight_emit2");

local spray = 0;

local SIG_ACTIVATE = 2;
local SIG_OPENCLOSE = 4;
local SIG_BUILD = 8;

include("include/util.lua");

local litelab = UnitDefs[unitDefID].customParams.litelab ~= nil

function open()
	UnitScript.Signal(SIG_OPENCLOSE);
	UnitScript.SetSignalMask(SIG_OPENCLOSE);
	--Activate
	--UnitScript.Move(side1, z_axis, 0);
	if not litelab then
		UnitScript.Move(side1, z_axis, 24, 24);
		Sleep(908);
		UnitScript.Move(side2, z_axis, 10, 2.777771);
		Sleep(828);
		--Open yard
	end
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
	if not litelab then
		UnitScript.Move(side1, z_axis, 0, 24);
		Sleep(908);
		UnitScript.Move(side2, z_axis, 0, 2.777771);
		Sleep(828);
	end
end

function script.Create()
	if litelab then
		UnitScript.Move(side1, z_axis, 24, 1000);
		UnitScript.Move(side2, z_axis, 10, 1000);
	end
	Hide(nano1);
	Hide(nano2);
	Hide(nano3);
	Hide(nano4);
	Hide(cagelight_emit);
	Hide(cagelight_emit2);
	spray = 0;
	UnitScript.StartThread(smoke_unit, base);
end

function script.QueryNanoPiece()
	local piecenum;
	if (spray == 0) then
		piecenum = nano1;
	end
	if (spray == 1) then
		piecenum = nano2;
	end
	if (spray == 2) then
		piecenum = nano3;
	end
	if (spray == 3) then
		piecenum = nano4;
	end
	spray = spray + 1;
	if(spray == 4) then
		spray = 0;
	end
	return piecenum;
end

function Activate_real()
	UnitScript.Signal(SIG_ACTIVATE);
	UnitScript.StartThread(open);
end

function script.Activate()
	UnitScript.StartThread(Activate_real);
end

function Deactivate_real()
	UnitScript.Signal(SIG_ACTIVATE);
	UnitScript.SetSignalMask(SIG_ACTIVATE);
	Sleep(5000);
	UnitScript.StartThread(close);
end

function script.Deactivate()
	UnitScript.StartThread(Deactivate_real);
end

function Build()
	UnitScript.SetSignalMask(SIG_BUILD);
	while true do
		if math.random() > 0.5 then
			local t = math.random(0,48);
			UnitScript.Move(mount1, z_axis, t, 24);
			UnitScript.Turn(head1 , y_axis, math.rad(-1.6 * t), math.rad(36) );
			UnitScript.WaitForMove(mount1, z_axis)
		else
			local t = math.random(0,48);
			UnitScript.Move(mount2, z_axis, t, 24);
			UnitScript.Turn(head2 , y_axis, math.rad(1.6 * t), math.rad(36) );
			UnitScript.WaitForMove(mount2, z_axis)
		end

	end
end

function script.StartBuilding()
	Show(nano1);
	Show(nano2);
	Show(nano3);
	Show(nano4);
	Show(cagelight_emit);
	Show(cagelight_emit2);
	Spin(cagelight_emit, y_axis,4);
	Spin(cagelight_emit2, y_axis,4);
	UnitScript.Signal(SIG_BUILD);
	UnitScript.StartThread(Build)
end



function script.StopBuilding()
	Hide(nano1);
	Hide(nano2);
	Hide(nano3);
	Hide(nano4);
	UnitScript.Signal(SIG_BUILD);
	Hide(cagelight_emit);
	Hide(cagelight_emit2);
	Turn(cagelight_emit, y_axis,0,15);
	Turn(cagelight_emit2, y_axis,0,15);

	UnitScript.Move(mount1, z_axis, 0, 24);
	UnitScript.Turn(head1 , y_axis, 0, math.rad(36) );
	UnitScript.Move(mount2, z_axis, 0, 24);
	UnitScript.Turn(head2 , y_axis, 0, math.rad(36) );

	UnitScript.Move(center1, z_axis, 0);
	UnitScript.Move(center1, z_axis, 10, 20);
	UnitScript.Move(center2, z_axis, 0);
	UnitScript.WaitForMove(center1, z_axis);

	UnitScript.Move(center2, z_axis, 10, 20);
	UnitScript.Move(center1, z_axis, 0, 20);
	UnitScript.WaitForMove(center2, z_axis);
	UnitScript.Move(center2, z_axis, 0, 20);
	UnitScript.WaitForMove(center2, z_axis);
end

function script.QueryBuildInfo()
	return pad;
end

function script.Killed(recentDamage, maxHealth)
	local severity = (recentDamage / maxHealth) * 100;
	local corpsetype;

	if (severity <= 25) then
		corpsetype = 1;
		UnitScript.Explode(base, SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(head1, SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(head2, SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(side1, SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(side2, SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano1, SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano2, SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano3, SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano4, SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(center1, SFX.NONE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(center2, SFX.NONE + SFX.NO_HEATCLOUD);
		return corpsetype;
	end
	if (severity <= 50) then
		corpsetype = 2;
		UnitScript.Explode(base, SFX.NONE);
		UnitScript.Explode(head1,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(head2,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(side1,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(side2,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano1,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano2,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano3,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano4,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(center1,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(center2,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		return corpsetype;
	end
	if (severity <= 99) then
		corpsetype = 3;
		UnitScript.Explode(base,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(head1,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(head2,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(side1,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(side2,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano1,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano2,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano3,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(nano4,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(center1,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		UnitScript.Explode(center2,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
		return corpsetype;
	end
	corpsetype = 3;
	UnitScript.Explode(base,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(head1,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(head2,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(side1,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(side2,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(nano1,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(nano2,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(nano3,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(nano4,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(center1,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
	UnitScript.Explode(center2,  SFX.SMOKE + SFX.FIRE+ SFX.EXPLODE + SFX.NO_HEATCLOUD);
	return corpsetype;
end
