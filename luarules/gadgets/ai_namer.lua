

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
	local namelistChicken = {'Attila the Hen', 'Big Bird', 'Chicken Little', 'Cluck Norris', 'Chick Norris', 'Dixie Chick', 'Egghead',
		'Hen Solo', 'Donald Cluck'
	}

	local takenNames = {}
	local takenNamesChicken = {}

	function getName(teamID, chicken)
		local aiName
		if chicken then
			aiName = namelistChicken[math.random(1,#namelistChicken)]
		else
			aiName = namelist[math.random(1,#namelist)]
		end
		if chicken and takenNamesChicken[aiName] == nil then
			takenNamesChicken[aiName] = teamID
			return aiName
		elseif not chicken and takenNames[aiName] == nil then
			takenNames[aiName] = teamID
			return aiName
		else
			return getName(teamID, chicken)
		end
	end

	function gadget:Initialize()
		local t = Spring.GetTeamList()
		for _,teamID in ipairs(t) do
			if select(4,Spring.GetTeamInfo(teamID)) then	-- is AI?
				Spring.SetGameRulesParam('ainame_'..teamID, getName(teamID, string.find(Spring.GetTeamLuaAI(teamID), "Chicken:")))
			end
		end
		gadgetHandler:RemoveGadget(self)
	end
end
