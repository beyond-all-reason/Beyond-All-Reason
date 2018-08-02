local enablegadget = false
if Spring.GetModOptions and Spring.GetModOptions().unba then
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
      enabled      = false
   }
end


if (gadgetHandler:IsSyncedCode()) then  --Sync?
	
	VFS.Include("unbaconfigs/categories.lua")
	VFS.Include("unbaconfigs/taxvalues.lua")
	expvalues = {}
	taxvalue = {}	
	oldteams = {}
	
	for unitDefID, uDef in pairs(UnitDefs) do
		categories[unitDefID] = categories[UnitDefs[unitDefID].name] or 'other'
		categories[UnitDefs[unitDefID].name] = nil
		expvalues[unitDefID] = math.sqrt(uDef.metalCost + uDef.energyCost/60)/500
		taxvalues[unitDefID] = taxvalues[categories[unitDefID]] or 1.025
		taxvalues[categories[unitDefID]] = nil
	end
	
	experiences = {}
	taxes = {}

	local function AddExperienceValue(team, cat, value)
		if not experiences[team] then 
			experiences[team] = {} 
		end
		if not experiences[team][cat] then 
			experiences[team][cat] = 0 
		else
			experiences[team][cat] = experiences[team][cat] + value
		end
		if experiences[team][cat] < 0 then 
			experiences[team][cat] = 0
		end
	end
	
	local function SetUnitExp(unitID, team, cat)
		if experiences[team] and experiences[team][cat] then
			local ct = experiences[team][cat]
			if ct < 1.0 then
				Spring.SetUnitExperience(unitID, (1/((1/ct) - 1))) -- TooltipExperience = 10*(exp /(exp + 1))
			else
				Spring.SetUnitExperience(unitID, (1/((1/0.9999999) - 1))) -- (using ct = 1 returns NaN, use 0.999999... instead for 10.0 tooltip experience)
			end
		end
	end
			
	local function AddTax(team, cat, value)
		if not taxes[team] then 
			taxes[team] = {} 
		end
		if not taxes[team][cat] then 
			taxes[team][cat] = 1 
		else
			taxes[team][cat] = taxes[team][cat] * value
		end
		if taxes[team][cat] < 0 then 
			taxes[team][cat] = 0
		end
	end
	
	local function SetUnitTax(unitID, team, cat)
		if taxes[team] and taxes[team][cat] then
			local ct = taxes[team][cat]
			local unitDefID = Spring.GetUnitDefID(unitID)
			Spring.SetUnitCosts(unitID, { metalCost = UnitDefs[unitDefID].metalCost*ct, energyCost = UnitDefs[unitDefID].energyCost*ct, buildTime = UnitDefs[unitDefID].buildTime*ct})
		end
	end

	function gadget:UnitFinished(unitID,unitDefID,unitTeam)
		local category = categories[unitDefID]
		local expvalue = expvalues[unitDefID]
			AddExperienceValue(unitTeam, category, expvalue)
			SetUnitExp(unitID, unitTeam, category)
	end
	
	function gadget:UnitCreated(unitID,unitDefID,unitTeam)
		local category = categories[unitDefID]
		local taxvalue = taxvalues[unitDefID]
			AddTax(unitTeam, category, taxvalue)
			SetUnitTax(unitID, unitTeam, category)
	end
	
	function gadget:UnitDestroyed(unitID,unitDefID,unitTeam)
		local category = categories[unitDefID]
		local taxvalue = taxvalues[unitDefID]
		local invtaxvalue = 1/taxvalue
		if oldteams[unitID] then
			team = oldteams[unitID]
		else
			team = unitTeam
		end
			AddTax(team, category, invtaxvalue)
			oldteams[unitID] = nil
	end
	
	function gadget:UnitGiven(unitID,unitDefID,newTeam, oldTeam)
		if Spring.AreTeamsAllied(newTeam, oldTeam) == true then
			if not oldteams[unitID] then
				oldteams[unitID] = oldTeam
			else
				oldteams[unitID] = oldteams[unitID]
			end		
		else
			gadget:UnitDestroyed(unitID, unitDefID, oldTeam)
			gadget:UnitCreated(unitID, unitDefID, newTeam)
		end
	end
	
end
