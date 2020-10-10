
function RandomEventRebelion1(CurrentFrame)
	Spring.Echo("Rebelion 1 Event")
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
table.insert(RandomEventsList,RandomEventRebelion1)