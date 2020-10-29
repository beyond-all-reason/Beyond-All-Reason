
function RandomEventRebelion1(CurrentFrame)
	ScavSendNotification("scav_eventmalfunctions")
	local scavUnits = Spring.GetTeamUnits(GaiaTeamID)
	for y = 1,#scavUnits do
		local unitID = scavUnits[y]
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitName = UnitDefs[unitDefID].name
		if unitName ~= "armcom_scav" and unitName ~= "corcom_scav" and unitName ~= "armcomboss_scav" and unitName ~= "corcomboss_scav" and unitName ~= "armcom" and unitName ~= "corcom" and unitName ~= "scavsafeareabeacon_scav" and unitName ~= "scavengerdroppodbeacon_scav" and unitName ~= "scavengerdroppod_scav" then										
			for _,teamID in ipairs(Spring.GetTeamList()) do
				if teamID ~= GaiaTeamID and teamID ~= Spring.GetGaiaTeamID() then
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
--table.insert(RandomEventsList,RandomEventRebelion1)

function RandomEventRebelion2(CurrentFrame)
	ScavSendNotification("scav_eventmalfunctions")
	local scavUnits = Spring.GetTeamUnits(GaiaTeamID)
	local rebelionCenter = scavUnits[math.random(1,#scavUnits)]
	local posx, posy, posz = Spring.GetUnitPosition(rebelionCenter)
	local areaUnits = Spring.GetUnitsInCylinder(posx, posz, math.random(200,500), GaiaTeamID)
	for y = 1,#areaUnits do
		local unitID = areaUnits[y]
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitName = UnitDefs[unitDefID].name
		--local unitTeam = Spring.GetUnitTeam(unitID)
		if unitName ~= "armcom_scav" and unitName ~= "corcom_scav" and unitName ~= "armcomboss_scav" and unitName ~= "corcomboss_scav" and unitName ~= "armcom" and unitName ~= "corcom" and unitName ~= "scavsafeareabeacon_scav" and unitName ~= "scavengerdroppodbeacon_scav" and unitName ~= "scavengerdroppod_scav" then										
			for _,teamID in ipairs(Spring.GetTeamList()) do
				if teamID ~= GaiaTeamID and teamID ~= Spring.GetGaiaTeamID() then
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
table.insert(RandomEventsList,RandomEventRebelion2)

function RandomEventBlueScreenOfDeath(CurrentFrame)
	ScavSendNotification("scav_eventmalfunctions")
	local scavUnits = Spring.GetTeamUnits(GaiaTeamID)
	for y = 1,#scavUnits do
		local unitID = scavUnits[y]
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitName = UnitDefs[unitDefID].name
		if unitName ~= "armcomboss_scav" and unitName ~= "corcomboss_scav" then										
			local uhealth, umaxhealth, uparalyze = Spring.GetUnitHealth(unitID)
			local paralyzemult = (math.random(30,60))*0.025
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
table.insert(RandomEventsList,RandomEventBlueScreenOfDeath)