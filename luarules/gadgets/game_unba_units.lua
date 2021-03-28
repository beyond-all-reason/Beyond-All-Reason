
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


if gadgetHandler:IsSyncedCode() then  --Sync?

	local defaultTaxValue = 1.025
	local taxvalues = {
		corcat = 1.1,
		corjugg = 1.1,
		corkarg = 1.1,
		corkorg = 1.1,
		corshiva = 1.1,

		armlun = 1.1,
		corsok = 1.1,

		armafus = 1.1,
		corafus = 1.1,

		armvulc = 1.1,
		corbuzz = 1.1,
	}


	local oldteams = {}
	local expvalues = {}

	local categories = {}
	for unitDefID, uDef in pairs(UnitDefs) do

		if uDef.decoyFor ~= '' and UnitDefNames[uDef.decoyFor] then
			uDef = UnitDefNames[uDef.decoyFor]
		end

		if uDef.canFly then
			if uDef.maxWaterDepth < 0 then
				categories[unitDefID] = 'seaplane'
			else
				categories[unitDefID] = 'aircraft'
			end

		elseif uDef.modCategories["commander"] ~= nil then
			categories[unitDefID] = 'bot'
		elseif uDef.modCategories["bot"] ~= nil then
			categories[unitDefID] = 'bot'

		elseif uDef.modCategories["tank"] ~= nil then
			categories[unitDefID] = 'tank'

		elseif uDef.modCategories["ship"] ~= nil then
			categories[unitDefID] = 'ship'
		elseif uDef.modCategories["underwater"] ~= nil and uDef.speed > 0 then
			categories[unitDefID] = 'ship'

		elseif uDef.modCategories["hover"] ~= nil then
			categories[unitDefID] = 'hover'

		elseif uDef.isBuilding or uDef.speed <= 0  then
			if uDef.isFactory and #uDef.buildOptions > 0 then
				categories[unitDefID] = 'factory'

			elseif uDef.weapons[1] ~= nil then
				categories[unitDefID] = 'defence'

			elseif uDef.customParams.energyconv_capacity and uDef.customParams.energyconv_efficiency then
				categories[unitDefID] = 'economy'
			elseif uDef.tidalGenerator > 0 or uDef.windGenerator > 0 then
				categories[unitDefID] = 'economy'
			elseif uDef.metalMake > 0.5 or uDef.energyMake > 5 or uDef.energyUpkeep < 0 then
				categories[unitDefID] = 'economy'

			else
				categories[unitDefID] = 'util'
			end
		else
			categories[unitDefID] = 'util'
		end
	end


	for unitDefID, uDef in pairs(UnitDefs) do
		if categories[unitDefID] then
			expvalues[unitDefID] = math.sqrt(uDef.metalCost + uDef.energyCost/60)/500
			taxvalues[unitDefID] = taxvalues[categories[unitDefID]] or defaultTaxValue
			taxvalues[categories[unitDefID]] = nil
		end
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
		if category then
			local expvalue = expvalues[unitDefID]
			AddExperienceValue(unitTeam, category, expvalue)
			SetUnitExp(unitID, unitTeam, category)
		end
	end

	function gadget:UnitCreated(unitID,unitDefID,unitTeam)
		local category = categories[unitDefID]
		if category then
			local taxvalue = taxvalues[unitDefID]
			AddTax(unitTeam, category, taxvalue)
			SetUnitTax(unitID, unitTeam, category)
		end
	end

	function gadget:UnitDestroyed(unitID,unitDefID,unitTeam)
		local category = categories[unitDefID]
		if category then
			local taxvalue = taxvalues[unitDefID]
			local invtaxvalue = 1/taxvalue
			local team
			if oldteams[unitID] then
				team = oldteams[unitID]
			else
				team = unitTeam
			end
			AddTax(team, category, invtaxvalue)
			oldteams[unitID] = nil
		end
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
