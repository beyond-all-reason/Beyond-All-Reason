common = {

	CustomEmitter = function (pieceName, effectName)
		--Spring.Echo(pieceName, effectName)
		local x,y,z,dx,dy,dz	= Spring.GetUnitPiecePosDir(unitID,pieceName)
				
		Spring.SpawnCEG(effectName, x,y,z, dx, dy, dz)
	end,
	
	HbotLift = function ()
		Move(base, y_axis, 20, 200)
		--Spring.Echo("Bruh I lift")
	end,
	
    setSFXoccupy = function (setSFXoccupy_argument)
		--Spring.Echo(type(setSFXoccupy_argument))
		--Spring.Echo("common.setSFXoccupy is being called", setSFXoccupy_argument)
		--Spring.Echo(setSFXoccupy_argument == 1, setSFXoccupy_argument == 2)
		--Spring.Echo(setSFXoccupy_argument == 4, setSFXoccupy_argument == 3, setSFXoccupy_argument == 0)
            if setSFXoccupy_argument == 1 or setSFXoccupy_argument == 2 then
				Move(base, y_axis, 0, 50)
				SetUnitValue(COB.UPRIGHT, 1)
				--Spring.Echo("Setting Upright: 1")
            elseif setSFXoccupy_argument == 4 or setSFXoccupy_argument == 3 or setSFXoccupy_argument == 0 then
				SetUnitValue(COB.UPRIGHT, 0)
				--Spring.Echo("Setting Upright: 0")
			end
    end,
	
	DirtTrail = function ()
		while isMoving do
			common.CustomEmitter(dirt, "dirt") -- Second argument is the piece name, third argument needs to be a string because it will be the name of the CEG effect used
			Sleep(400)
		end
	end,
	
	SmokeUnit = function (smokePieces)
		local n = #smokePieces
		while (GetUnitValue(COB.BUILD_PERCENT_LEFT) ~= 0) do
			Sleep(1000)
		end
		while true do
			local health = GetUnitValue(COB.HEALTH)
			if (health <= 66) then -- only smoke if less then 2/3rd health left
				common.CustomEmitter(smokePieces[math.random(1,n)], "blacksmoke") --CEG name in quotes (string)
			end
			Sleep(20*health + 200)
		end
	end,
}
return common