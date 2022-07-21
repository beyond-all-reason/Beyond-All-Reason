
local function rebellion1(currentFrame)
	ScavSendNotification("scav_eventmalfunctions")
	local scavUnits = Spring.GetTeamUnits(ScavengerTeamID)
	for y = 1,#scavUnits do
		local unitID = scavUnits[y]
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitName = UnitDefs[unitDefID].name
		if unitName ~= "armcom_scav" and unitName ~= "corcom_scav" and unitName ~= "armcomboss_scav" and unitName ~= "corcomboss_scav" and unitName ~= "armcom" and unitName ~= "corcom" and unitName ~= "scavsafeareabeacon_scav" and unitName ~= staticUnitList.scavSpawnBeacon and unitName ~= staticUnitList.scavSpawnEffectUnit then										
			for _,teamID in ipairs(Spring.GetTeamList()) do
				if teamID ~= ScavengerTeamID and teamID ~= Spring.GetGaiaTeamID() then
					local i = teamID
					local _,_,teamisDead = Spring.GetTeamInfo(i)
					local randomchance = math.random(0,teamcount+3)
					if randomchance == 0 and (not teamisDead) then
						Spring.TransferUnit(unitID, i, true)
						break
					end
				end
			end
		end
	end
end

local function rebellion2(currentFrame)
	local scavUnits = Spring.GetTeamUnits(ScavengerTeamID)
	if #scavUnits > 1 then
		ScavSendNotification("scav_eventmalfunctions")
		local rebelionCenter = scavUnits[math.random(1,#scavUnits)]
		local posx, posy, posz = Spring.GetUnitPosition(rebelionCenter)
		local areaUnits = Spring.GetUnitsInCylinder(posx, posz, math.random(200,500), ScavengerTeamID)
		for y = 1,#areaUnits do
			local unitID = areaUnits[y]
			local unitDefID = Spring.GetUnitDefID(unitID)
			local unitName = UnitDefs[unitDefID].name
			--local unitTeam = Spring.GetUnitTeam(unitID)
			if unitName ~= "armcom_scav" and unitName ~= "corcom_scav" and unitName ~= "armcomboss_scav" and unitName ~= "corcomboss_scav" and unitName ~= "armcom" and unitName ~= "corcom" and unitName ~= "scavsafeareabeacon_scav" and unitName ~= staticUnitList.scavSpawnBeacon and unitName ~= staticUnitList.scavSpawnEffectUnit then										
				for _,teamID in ipairs(Spring.GetTeamList()) do
					if teamID ~= ScavengerTeamID and teamID ~= Spring.GetGaiaTeamID() then
						local i = teamID
						local _,_,teamisDead = Spring.GetTeamInfo(i)
						--local randomchance = math.random(0,teamcount)
						if i == bestTeam and (not teamisDead or teamisDead ~= false) then
							Spring.TransferUnit(unitID, i, true)
							break
						end
					end
				end
			end
		end
	end
end

local function blueScreenOfDeath(currentFrame)
	ScavSendNotification("scav_eventmalfunctions")
	local scavUnits = Spring.GetTeamUnits(ScavengerTeamID)
	for y = 1,#scavUnits do
		local unitID = scavUnits[y]
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitName = UnitDefs[unitDefID].name
		if unitName ~= "armcomboss_scav" and unitName ~= "corcomboss_scav" then										
			local uhealth, umaxhealth, uparalyze = Spring.GetUnitHealth(unitID)
			local paralyzemult = (math.random(10,120))*0.025
			if uparalyze <= umaxhealth then
				local paralyzedamage = (umaxhealth-uparalyze)+(umaxhealth*paralyzemult)
				Spring.SetUnitHealth(unitID, {paralyze = paralyzedamage})
			else
				local paralyzedamage = (umaxhealth*paralyzemult)+uparalyze
				Spring.SetUnitHealth(unitID, {paralyze = paralyzedamage})
			end
		end
	end
end

return {
	-- rebellion1,
	--rebellion2,
	blueScreenOfDeath,
	blueScreenOfDeath,
}