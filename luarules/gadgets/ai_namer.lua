

function gadget:GetInfo()
	return {
		name	= "AI namer",
		desc	= "Assignes names to AI teams",
		author	= "Floris",
		date	= "May 2018",
		layer	= 0,
		enabled = true,
	}
end


if gadgetHandler:IsSyncedCode() then

	local namelist = {
		'Alfa', 'Bravo', 'Charlie', 'Delta', 'Echo', 'Foxtrot', 'Golf', 'Hotel', 'India', 'Juliett', 'Kila', 'Lima', 'Mike',
		'November', 'Oscar', 'Papa', 'Quebec', 'Romeo', 'Sierra', 'Tango', 'Uniform', 'Victor', 'Whiskey', 'Xray', 'Yankee', 'Zulu',
	}
	local takenNames = {}

	function getName(teamID)
		local aiName = namelist[math.random(1,#namelist)]
		if takenNames[aiName] == nil then
			takenNames[aiName] = teamID
			return aiName
		else
			return getName(teamID)
		end
	end

	function gadget:Initialize()
		local t = Spring.GetTeamList()
		for _,teamID in ipairs(t) do
			if select(4,Spring.GetTeamInfo(teamID)) then	-- is AI?
				if not string.find(Spring.GetTeamLuaAI(teamID), "Chicken:") then
					Spring.SetGameRulesParam('ainame_'..teamID, getName(teamID))
				end
			end
		end
		gadgetHandler:RemoveGadget(self)
	end
end
