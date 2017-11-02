

function gadget:GetInfo()
	return {
		name		= "Xmas effects",
		desc		= "",
		author		= "Floris",
		date		= "Oct ,2017",
		license		= "",
		layer		= 0,
		enabled		= true,
	}
end


if gadgetHandler:IsSyncedCode() then

	local enableUnitDecorations = false		-- burst out xmas ball after unit death

	local hasDecoration = {}
	for udefID,def in ipairs(UnitDefs) do
		if def.name == 'xmasball' then
			xmasballUdefID = udefID
		end
		if def.customParams.iscommander ~= nil then
			hasDecoration[udefID] = 15
		end
	end

	local decorationLifeTime = 20*25
	local decorationLifeTimeVariation = 30*5

	local decorations = {}
	local decorationsTerminal = {}
	local createDecorations = {}
	local createdDecorations = {}

	local GaiaTeam = Spring.GetGaiaTeamID()

	local function setGaiaUnitSpecifics(unitID)
		Spring.SetUnitNeutral(unitID, true)
		Spring.SetUnitNoSelect(unitID, true)
		Spring.SetUnitStealth(unitID, true)
		Spring.SetUnitNoMinimap(unitID, true)
		--Spring.SetUnitMaxHealth(unitID, 2)
		Spring.SetUnitBlocking(unitID, false)
		Spring.SetUnitSensorRadius(unitID, 'los', 0)
		Spring.SetUnitSensorRadius(unitID, 'airLos', 0)
		Spring.SetUnitSensorRadius(unitID, 'radar', 0)
		Spring.SetUnitSensorRadius(unitID, 'sonar', 0)
		for weaponID, _ in pairs(UnitDefs[Spring.GetUnitDefID(unitID)].weapons) do
			Spring.UnitWeaponHoldFire(unitID, weaponID)
		end
	end

	function gadget:GameFrame(n)
		if n % 30 == 1 then
			for unitID, frame in pairs(decorations) do
				if frame < n then
					decorations[unitID] = nil
					local x,y,z = Spring.GetUnitPosition(unitID)
					local gy = Spring.GetGroundHeight(x,z)

					decorationsTerminal[unitID] = n+300+((y - gy) * 33)		-- allows if in sea to take longer to go under seafloor
					if decorationsTerminal[unitID] > n+1800 then	-- limit time to 1 min
						decorationsTerminal[unitID] = n+1800
					end
					local env = Spring.UnitScript.GetScriptEnv(unitID)
					Spring.UnitScript.CallAsUnit(unitID,env.Sink)
				end
			end
		end
		if n % 90 == 1 then
			for unitID, frame in pairs(decorationsTerminal) do

				if frame < n then
					decorationsTerminal[unitID] = nil
					if Spring.GetUnitIsDead(unitID) == false then
						Spring.DestroyUnit(unitID, false, false)
					end
				end
			end
		end

		-- add destroyed unit decorations
		if enableUnitDecorations then
			for _, data in ipairs(createDecorations) do
				local i = 0
				local uID
				local amount = hasDecoration[data[5]]
				while i < amount do
					uID = Spring.CreateUnit(xmasballUdefID, data[1],data[2],data[3], 0, data[4])
					decorations[uID] = Spring.GetGameFrame() + decorationLifeTime + (math.random()*decorationLifeTimeVariation)
					setGaiaUnitSpecifics(uID)
					Spring.SetUnitRotation(uID,math.random()*360,math.random()*360,math.random()*360)
					Spring.AddUnitImpulse(uID, (math.random()-0.5)*3.3, 1+(math.random()*3), (math.random()-0.5)*3.3)
					i = i + 1
				end
			end
			createDecorations = {}
		end

		-- add gifted unit decorations
		for _, unitID in ipairs(createdDecorations) do
			if decorations[unitID] == nil then
				decorations[unitID] = Spring.GetGameFrame() + decorationLifeTime + (math.random()*decorationLifeTimeVariation)
				setGaiaUnitSpecifics(unitID)
				--local x,y,z = Spring.GetUnitPosition(unitID)
				--Spring.SetUnitPosition(unitID,x,y,z)
				--Spring.SetUnitVelocity(unitID,0,math.random()*20,0)
				Spring.SetUnitRotation(unitID,math.random()*360,math.random()*360,math.random()*360)
				Spring.AddUnitImpulse(unitID, (math.random()-0.5)*1.5, 2.5+(math.random()*1), (math.random()-0.5)*1.5)
			end
		end
		createdDecorations = {}
	end

	function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
		if enableUnitDecorations and hasDecoration[unitDefID] ~= nil then
			local x,y,z = Spring.GetUnitPosition(unitID)
			table.insert(createDecorations, {x,y,z, teamID, unitDefID})
		end
		if unitDefID == xmasballUdefID then
			if decorations[unitID] ~= nil then
				decorations[unitID] = nil
			elseif decorationsTerminal[unitID] ~= nil then
				decorationsTerminal[unitID] = nil
			end
		end
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		if unitDefID == xmasballUdefID then
			table.insert(createdDecorations, unitID)
		end
	end

end
