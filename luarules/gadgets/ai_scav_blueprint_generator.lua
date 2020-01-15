function gadget:GetInfo()
	return {
	name      = "Scavenger Blueprint Generator",
	desc      = "AAA",
	author    = "Damgam",
	date      = "2020",
	license   = "who cares?",
	layer     = 0,
	enabled   = true, --enabled by default
	}
end

centerposx = {}
centerposz = {}
centerposy = {}
blueprintposx = 0
blueprintposz = 0

if gadgetHandler:IsSyncedCode() then
  -- do gadgetry here
	
else
	function gadget:GotChatMsg(msg, playerID)
		if msg == "scavblp" then 
			local selectedunits = Spring.GetSelectedUnits()
			GetBlueprintCenter()
			Spring.Echo(" ")
			Spring.Echo("Constructor Blueprint: ")
			for i = 1,#selectedunits do
				GenerateBlueprint1(selectedunits[i])
				--Spring.Echo("UnitID"..i..": "..selectedunits[i]) 
			end
			Spring.Echo(" ")
			Spring.Echo("Spawner Blueprint: ")
			for i = 1,#selectedunits do
				GenerateBlueprint2(selectedunits[i])
				--Spring.Echo("UnitID"..i..": "..selectedunits[i]) 
			end
			Spring.Echo(" ")
			Spring.Echo("Useless Echos to make sure whole thing land in infolog: ")
			Spring.Echo("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
			Spring.Echo("i think that's enough... Blueprint Created")
			ClearValues()
		end 
	end
	
	function GenerateBlueprint1(unitID)
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitDefName = UnitDefs[unitDefID].name
		local unitIDFacing = Spring.GetUnitBuildFacing(unitID)
		local posx = math.ceil(centerposx[unitID]-blpcenterpositionx)
		local posz = math.ceil(centerposz[unitID]-blpcenterpositionz)
		local queuethisshit = [["shift"]]
		
		-- Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx-96, posy, posz-48, 0}, {"shift"})
		Spring.Echo("Spring.GiveOrderToUnit(scav, -(UDN."..unitDefName.."_scav.id), {posx+("..posx.."), posy, posz+("..posz.."), "..unitIDFacing.."}, {"..queuethisshit.."})") 
		
	end
	function GenerateBlueprint2(unitID)
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitDefName = UnitDefs[unitDefID].name
		local unitIDFacing = Spring.GetUnitBuildFacing(unitID)
		local posx = math.ceil(centerposx[unitID]-blpcenterpositionx)
		local posz = math.ceil(centerposz[unitID]-blpcenterpositionz)
		local unitDefNameString = [["]]
		
		-- Spring.CreateUnit("corrad"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
		Spring.Echo("Spring.CreateUnit("..unitDefNameString..unitDefName..unitDefNameString.."..nameSuffix, posx+("..posx.."), posy, posz+("..posz.."), "..unitIDFacing..",GaiaTeamID)") 
		
	end
	
	function GetBlueprintCenter()
		local selectedunits = Spring.GetSelectedUnits()
		for i = 1,#selectedunits do
			local unit = selectedunits[i]
			centerposx[unit], centerposy[unit], centerposz[unit] = Spring.GetUnitPosition(unit)
			blueprintposx = blueprintposx + centerposx[unit]
			blueprintposz = blueprintposz + centerposz[unit]
		end
		blpcenterpositionx = blueprintposx/#selectedunits
		blpcenterpositionz = blueprintposz/#selectedunits
	end
	
	function ClearValues()
		blueprintposx = 0
		blueprintposz = 0
		centerposx = {}
		centerposy = {}
		centerposz = {}
	end
end

