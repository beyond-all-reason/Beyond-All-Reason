--Piece definitions
local cube1, cube2, cube3 = piece("cube1","cube2","cube3");


include("include/util.lua");

local function wiggle()
	Spring.Echo("Wiggling")
	while true do
		
		local deg90 = math.rad(90)
		Sleep(1000);
		
		
		for axis in ipairs({x_axis, y_axis, z_axis}) do 
			for piecename in ipairs({cube1, cube2, cube3}) do 
				UnitScript.Turn(piecename, axis, deg90, deg90);
			end
			Sleep(1000);
			for piecename in ipairs({cube1, cube2, cube3}) do 
				UnitScript.Turn(piecename, axis, 0, deg90);
			end
			Sleep(1000);
		end
		

		
		for axis in ipairs({x_axis, y_axis, z_axis}) do 
			for piecename in ipairs({cube1, cube2, cube3}) do 
				UnitScript.Move(piecename, axis, 16,16);
			end
			Sleep(1000);
			for piecename in ipairs({cube1, cube2, cube3}) do 
				UnitScript.Move(piecename, axis, 0, 16);
			end
			Sleep(1000);
		end
		
		--[[
		
		UnitScript.Turn(turret, y_axis, 0, math.rad(200));
		UnitScript.Move(turret, y_axis, -44, 100);
		UnitScript.WaitForMove(turret, y_axis);
		UnitScript.WaitForTurn(turret, y_axis);
		
		UnitScript.Move(door1, x_axis, -8.54, 30);
		UnitScript.Move(door2, x_axis, 8.54, 30);
		
		UnitScript.SetUnitValue(COB.ARMORED, 1);
		]]--
	end
end


function script.Create()
	UnitScript.StartThread(wiggle);
end

