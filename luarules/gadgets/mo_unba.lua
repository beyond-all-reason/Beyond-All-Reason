local enablegadget = false
if Spring.GetModOptions and Spring.GetModOptions().mo_unba then
	enablegadget = true
end

function gadget:GetInfo()
   return {
      name         = "Unbalanced Units",
      desc         = "Increases costs and experience of units depending on the amount of unit built or active",
      author       = "Doo",
      date         = "17/04/2018",
      license      = "GPL 2.0 or later", -- should be compatible with Spring
      layer        = 0,
      enabled      = enablegadget
   }
end


if (gadgetHandler:IsSyncedCode()) then  --Sync?

	local count = {}
	local exponentfactor = 1 + (2.5/100) -- For each active unit, the cost is increased by 2.5% (exponential, nth unit costs cost[n-1]*1.025)
	local experiencePerBuild = 0.1 / 10 -- Each new build of a unit type is built with +0.1 experience (max 100 units = 10.0)
	-- exceptionNames = {
	-- NO EXCEPTIONS YET, have to discuss wether or not economy buildings should be an exception
	-- Possibly, the exponent could vary depending on unitType
	-- }
	-- for unitDefID, uDef in pairs(UnitDefs) do
		-- if exceptionNames[uDef.name] then
			-- exceptions[unitDefID] = true
		-- end
	-- end

	function gadget:UnitFinished(unitID,unitDefID,unitTeam)
		-- if not exceptions[unitDefID] then
			if not count[unitTeam] then
				count[unitTeam] = {}
			end
			if not count[unitTeam][unitDefID] then
				count[unitTeam][unitDefID] = 1
			else
				count[unitTeam][unitDefID] = count[unitTeam][unitDefID] + 1
			end
			local ct = (count[unitTeam][unitDefID] - 1) * experiencePerBuild
			if ct < 1.0 then
				Spring.SetUnitExperience(unitID, (1/((1/ct) - 1))) -- TooltipExperience = 10*(exp /(exp + 1))
			else
				Spring.SetUnitExperience(unitID, (1/((1/0.9999999) - 1))) -- (using ct = 1 returns NaN, use 0.999999... instead for 10.0 tooltip experience)
			end
			-- _,curExp = Spring.GetUnitExperience(unitID)
			-- if curExp >= 0.99 then  -- OPTIONAL, display a message when a player has mastered (tooltipExp = 10.0) a unittype
				-- a, leader = Spring.GetTeamInfo(unitTeam)
				-- name = Spring.GetPlayerInfo(leader)
				-- ud = UnitDefs[unitDefID].humanName
				-- Spring.Echo("Player " .. name .." has mastered " ..ud.." technology.")
			-- end
		-- end
	end
	
	function gadget:UnitCreated(unitID,unitDefID,unitTeam)
		local ct = Spring.GetTeamUnitDefCount(unitTeam, unitDefID) - 1
		Spring.SetUnitCosts(unitID, { metalCost = UnitDefs[unitDefID].metalCost*exponentfactor^ct, energyCost = UnitDefs[unitDefID].energyCost*exponentfactor^ct, buildTime = UnitDefs[unitDefID].buildTime*exponentfactor^ct})
	end
	
end
