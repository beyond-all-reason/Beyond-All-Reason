

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
		'Subionic','C3PO','R2D2','Mr.Robot','EVE','Wall-E','Chip','x86','Johnny 5','Skynet','Dolores','KITT',
		'Bender','J.A.R.V.I.S','Autobot','Data','Gadget','Micro','Brainstorm','GlaDOS','Optimus Prime','Maria',
		'Astro'
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
				Spring.SetTeamRulesParam(teamID, 'ainame', getName(teamID))
			end
		end
		gadgetHandler:RemoveGadget(self)
	end
end
