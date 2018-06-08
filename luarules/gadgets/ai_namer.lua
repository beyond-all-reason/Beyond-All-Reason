

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
				local chickensEnabled = false
				local luaAI = Spring.GetTeamLuaAI(teamID)
				if string.find(luaAI, "Chicken:") then
					if luaAI == "Chicken: Very Easy" or
							luaAI == "Chicken: Easy" or
							luaAI == "Chicken: Normal" or
							luaAI == "Chicken: Hard" or
							luaAI == "Chicken: Very Hard" or
							luaAI == "Chicken: Epic!" or
							luaAI == "Chicken: Custom" or
							luaAI == "Chicken: Survival" then
						chickensEnabled = true
					end
				end
				if not chickensEnabled then
					Spring.SetGameRulesParam('ainame_'..teamID, getName(teamID))
				end
			end
		end
		gadgetHandler:RemoveGadget(self)
	end
end
