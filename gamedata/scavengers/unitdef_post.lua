-- this file gets included in alldefs_post.lua

local scavUnit = {}
for name,uDef in pairs(UnitDefs) do
    scavUnit[#scavUnit+1] = name..'_scav'
end

scavDifficulty = Spring.GetModOptions().scavdifficulty
if scavDifficulty == "noob" then
	ScavDifficultyMultiplier = 0.1
elseif scavDifficulty == "veryeasy" then
	ScavDifficultyMultiplier = 0.25
elseif scavDifficulty == "easy" then
	ScavDifficultyMultiplier = 0.375
elseif scavDifficulty == "medium" then
	ScavDifficultyMultiplier = 0.5
elseif scavDifficulty == "hard" then
	ScavDifficultyMultiplier = 0.875
elseif scavDifficulty == "veryhard" then
	ScavDifficultyMultiplier = 1
elseif scavDifficulty == "expert" then
	ScavDifficultyMultiplier = 1.5
elseif scavDifficulty == "brutal" then
	ScavDifficultyMultiplier = 2
else
	ScavDifficultyMultiplier = 0.25
end

function scav_Udef_Post(name, uDef)
	if not uDef.customparams then
		uDef.customparams = {}
	end
	uDef.customparams.isscavenger = true
	
	-- add unit category
	uDef.category = uDef.category..' SCAVENGER'
	
	-- replaced uniticons
	if uDef.buildpic then
		--local nonScavName = string.sub(uDef.unitname, 1, string.len(uDef.unitname)-5)
		if (not string.find(uDef.buildpic, "scavengers"))
		and (not string.find(uDef.buildpic, "chicken"))
		and (not string.find(uDef.buildpic, "critters"))
		and (not string.find(uDef.buildpic, "lootboxes"))
		and (not string.find(uDef.buildpic, "other"))
		and (not string.find(uDef.buildpic, "alternative")) then
			uDef.buildpic = "scavengers/"..uDef.buildpic
		end
	end

	-- add model vertex displacement

	--local udefVertDisp = uDef.customparams.vertdisp1 or 0
	--uDef.customparams.vertdisp = 2.0 * udefVertDisp
	uDef.customparams.healthlookmod = 0.40

	-- make barrelshot purple
	if uDef.customparams.firingceg then
		if string.find(uDef.customparams.firingceg, 'barrelshot') then
			uDef.customparams.firingceg = uDef.customparams.firingceg..'-purple'
		end
	end
	if uDef.sfxtypes then
		-- make barrelshot purple
		if uDef.sfxtypes.explosiongenerators then
			for k,v in pairs(uDef.sfxtypes.explosiongenerators) do
				if string.find(v, 'barrelshot') then
					uDef.sfxtypes.explosiongenerators[k] = v..'-purple'
				end
			end
		end
		-- make deathcegs purple
		if uDef.sfxtypes.pieceexplosiongenerators then
			for k,v in pairs(uDef.sfxtypes.pieceexplosiongenerators) do
				if string.find(v, 'deathceg') then
					uDef.sfxtypes.pieceexplosiongenerators[k] = v..'-purple'
				end
			end
		end
	end
	-- make unit explosion purple
	if uDef.explodeas then
		if string.find(string.lower(uDef.explodeas), 'explosiongeneric') or
			string.find(string.lower(uDef.explodeas), 'buildingexplosiongeneric') or
			string.find(string.lower(uDef.explodeas), 'explosiont3') or
			string.find(string.lower(uDef.explodeas), 'bantha') or
			string.find(string.lower(uDef.explodeas), 'lootbox')
		then
			uDef.explodeas = uDef.explodeas..'-purple'
		end
	end
	if uDef.selfdestructas then
		if string.find(string.lower(uDef.selfdestructas), 'explosiongeneric') or
			string.find(string.lower(uDef.selfdestructas), 'buildingexplosiongeneric') or
		 	string.find(string.lower(uDef.selfdestructas), 'explosiont3') or
			string.find(string.lower(uDef.selfdestructas), 'bantha') or
			string.find(string.lower(uDef.selfdestructas), 'lootbox')
		then
			uDef.selfdestructas = uDef.selfdestructas..'-purple'
		end
	end

	-- replace buildlists with _scav units
	if uDef.buildoptions then
        for k, v in pairs(uDef.buildoptions) do
            if UnitDefs[v..'_scav'] then
                uDef.buildoptions[k] = v..'_scav'
            end
        end
    end

	-- add Scavenger name prefix to wrecks
	if uDef.featuredefs then
		if uDef.featuredefs.dead and uDef.featuredefs.dead.description then
				uDef.featuredefs.dead.description = Spring.I18N('units.scavenger', { name = uDef.featuredefs.dead.description })
		end

		if uDef.featuredefs.heap and uDef.featuredefs.heap.description then
				uDef.featuredefs.heap.description = Spring.I18N('units.scavenger', { name = uDef.featuredefs.heap.description })
		end
	end

	-- add Scavenger name prefix to units
	if uDef.name then
		uDef.name = Spring.I18N('units.scavenger', { name = uDef.name })
	end
  
  if math and math.random then
    
  local randomMultiplier = 1.0 
  if math.random() ~= nil then  --for mission editor math.random() somehow returns nil
     randomMultiplier = (math.random()*0.25)+0.875 -- results in random between 0.875 and 1.125
  end
	
	if uDef.buildcostenergy then
		uDef.buildcostenergy = math.ceil(uDef.buildcostenergy*0.85*randomMultiplier)
	end

	if uDef.buildcostmetal then
		uDef.buildcostmetal = math.ceil(uDef.buildcostmetal*0.85*randomMultiplier)
	end

	if uDef.buildtime then
		uDef.buildtime = math.ceil(uDef.buildtime*0.85*randomMultiplier)
	end
	
	if uDef.energymake then
		uDef.energymake = math.ceil(uDef.energymake*0.85*randomMultiplier)
	end

	if uDef.metalmake then
		uDef.metalmake = math.ceil(uDef.metalmake*0.85*randomMultiplier)
	end

	if uDef.maxdamage then
		if name ~= 'armcomboss_scav' and name ~= 'corcomboss_scav' then
			uDef.maxdamage = math.ceil(uDef.maxdamage*0.85*randomMultiplier)
		end
	end

	-- if uDef.maxvelocity then
		-- uDef.maxvelocity = uDef.maxvelocity*1.1
	-- end

	--if uDef.radardistancejam then
		--uDef.radardistancejam = math.ceil(uDef.radardistancejam*1.25*randomMultiplier)
	--end

	if uDef.maxdamage then
		if name ~= 'armcomboss_scav' and name ~= 'corcomboss_scav' then
			uDef.autoheal = math.ceil(math.sqrt(uDef.maxdamage*0.1*randomMultiplier))
			uDef.idleautoheal = math.ceil(math.sqrt(uDef.maxdamage*0.1*randomMultiplier))
		else
			uDef.autoheal = 0
			uDef.idleautoheal = 0
		end
	else
		uDef.autoheal = 1
		uDef.idleautoheal = 1
	end

	if uDef.turnrate then
		uDef.turnrate = uDef.turnrate*1.2*randomMultiplier
	end

	if uDef.turninplaceanglelimit then
		uDef.turninplaceanglelimit = 360
	end

	-- don't let players get scav constructors
	if uDef.builder then
		if uDef.workertime then 
			local workertimemultipliermodoption = Spring.GetModOptions().scavbuildspeedmultiplier
			uDef.workertime = uDef.workertime*workertimemultipliermodoption
		end
		-- if uDef.maxvelocity then
		-- 	uDef.maxvelocity = uDef.maxvelocity*2*randomMultiplier
		-- end
		if uDef.canmove == true then
			uDef.cancapture = true
			if uDef.workertime then
				uDef.workertime = uDef.workertime*1.5*ScavDifficultyMultiplier
			end
			if uDef.turnrate then
				uDef.turnrate = uDef.turnrate*1.5
			end
			if uDef.brakerate then
				uDef.brakerate = uDef.brakerate*3*randomMultiplier
			end
			if uDef.builddistance then
				uDef.builddistance = uDef.builddistance*2*randomMultiplier
			end
		end
		if uDef.featuredefs then
			--if uDef.featuredefs.dead then
				--if uDef.featuredefs.dead.damage then
					--uDef.featuredefs.dead.damage = 1
				--end
			--end
			-- if uDef.featuredefs.dead then
				-- uDef.featuredefs.dead.resurrectable = 0
			-- end
			-- if uDef.featuredefs.heap then
				-- uDef.featuredefs.heap.resurrectable = 0
			-- end
		end
	end
	
	if uDef.weapondefs then
		for weaponDefName, weaponDef in pairs (uDef.weapondefs) do
			for category, damage in pairs (weaponDef.damage) do
				uDef.weapondefs[weaponDefName].damage[category] = math.floor((damage * randomMultiplier))
			end
		end
	end
  
  end -- end mission editor compat

	if uDef.customparams.fighter then
		uDef.maxvelocity = uDef.maxvelocity*2
	end

	return uDef

end
