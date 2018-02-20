--Maybe use not Spring.GetUnitIsBuilding(unitID) ?
--Returns true if Cob BUILD_PERCENT_LEFT is not zero
function still_building()
	local _,_,_,_,buildProgress = Spring.GetUnitHealth(unitID);
	if (buildProgress == 1) then return false; else return true; end
end

function get_health_percent()
	local health,maxHealth = Spring.GetUnitHealth(unitID);
	return ((health / maxHealth) * 100);
end

function smoke_unit(emit_piece)
	while still_building() do Sleep(400); end
	
	while (true) do
		local health_percent = get_health_percent();
		
		if (health_percent < 66) then
			local smoketype = 258;
			if (math.random(1, 66) < health_percent) then smoketype = 257; end
			Spring.UnitScript.EmitSfx(emit_piece, smoketype);
		end
		
		local sleep_time = health_percent * 50;
		if (sleep_time < 200) then sleep_time = 200; end
		Sleep(sleep_time);
	end
end

function open_yard()
	UnitScript.SetUnitValue(COB.YARD_OPEN, 1);
	while (UnitScript.GetUnitValue(COB.YARD_OPEN) == 0) do
		UnitScript.SetUnitValue(COB.BUGGER_OFF, 1);
		Sleep(1500);
		UnitScript.SetUnitValue(COB.YARD_OPEN, 1);
	end
	UnitScript.SetUnitValue(COB.BUGGER_OFF, 0);
end

function close_yard()
	UnitScript.SetUnitValue(COB.YARD_OPEN, 0);
	while(UnitScript.GetUnitValue(COB.YARD_OPEN) ~= 0) do
		UnitScript.SetUnitValue(COB.BUGGER_OFF, 1);
		Sleep(1500);
		UnitScript.SetUnitValue(COB.YARD_OPEN, 0);
	end
	UnitScript.SetUnitValue(COB.BUGGER_OFF, 0);
end
