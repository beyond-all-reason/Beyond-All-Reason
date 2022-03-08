-- UnitDef postprocessing specific to Scavenger units only

local scavDifficulty = Spring.GetModOptions().scavdifficulty
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

local function scavUnitDef_Post(name, uDef)
	uDef.category = uDef.category .. ' SCAVENGER'
	uDef.customparams.isscavenger = true

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

	local baseMultiplier = 0.90
	local function randomMultiplier()
		return (math.random() * 0.5) + 0.75 -- results in random between 0.75 and 1.25
	end
	
	if uDef.buildcostenergy then
		uDef.buildcostenergy = math.ceil(uDef.buildcostenergy * baseMultiplier * randomMultiplier())
	end

	if uDef.buildcostmetal then
		uDef.buildcostmetal = math.ceil(uDef.buildcostmetal * baseMultiplier * randomMultiplier())
	end

	if uDef.buildtime then
		uDef.buildtime = math.ceil(uDef.buildtime * baseMultiplier * randomMultiplier())
	end

	if uDef.energymake then
		uDef.energymake = math.ceil(uDef.energymake * baseMultiplier * randomMultiplier())
	end

	if uDef.metalmake then
		uDef.metalmake = math.ceil(uDef.metalmake * baseMultiplier * randomMultiplier())
	end

	if uDef.maxdamage then
		uDef.maxdamage = math.ceil(uDef.maxdamage * baseMultiplier * randomMultiplier())
	end

	-- Wrecks
	if uDef.featuredefs then
		if uDef.featuredefs.dead then
			if uDef.featuredefs.dead.damage then
				uDef.featuredefs.dead.damage = math.ceil(uDef.featuredefs.dead.damage * baseMultiplier * randomMultiplier())
			end
			if uDef.featuredefs.dead.metal then
				uDef.featuredefs.dead.metal = math.ceil(uDef.featuredefs.dead.metal * baseMultiplier * randomMultiplier())
			end
			if uDef.featuredefs.dead.energy then
				uDef.featuredefs.dead.energy = math.ceil(uDef.featuredefs.dead.energy * baseMultiplier * randomMultiplier())
			end
		end
		if uDef.featuredefs.heap then
			if uDef.featuredefs.heap.damage then
				uDef.featuredefs.heap.damage = math.ceil(uDef.featuredefs.heap.damage * baseMultiplier * randomMultiplier())
			end
			if uDef.featuredefs.heap.metal then
				uDef.featuredefs.heap.metal = math.ceil(uDef.featuredefs.heap.metal * baseMultiplier * randomMultiplier())
			end
			if uDef.featuredefs.heap.energy then
				uDef.featuredefs.heap.energy = math.ceil(uDef.featuredefs.heap.energy * baseMultiplier * randomMultiplier())
			end
		end
	end

	if uDef.maxdamage then
		if name ~= 'armcomboss_scav' and name ~= 'corcomboss_scav' then
			uDef.autoheal = math.ceil(math.sqrt(uDef.maxdamage * 0.1 * randomMultiplier()))
			uDef.idleautoheal = math.ceil(math.sqrt(uDef.maxdamage * 0.1 * randomMultiplier()))
		else
			uDef.autoheal = 0
			uDef.idleautoheal = 0
		end
	else
		uDef.autoheal = 1
		uDef.idleautoheal = 1
	end

	if uDef.turnrate then
		uDef.turnrate = uDef.turnrate * 1.2 * randomMultiplier()
	end

	if uDef.turninplaceanglelimit then
		uDef.turninplaceanglelimit = 360
	end

	if uDef.builder then
		if uDef.workertime then
			local workertimemultipliermodoption = Spring.GetModOptions().scavbuildspeedmultiplier
			uDef.workertime = uDef.workertime * workertimemultipliermodoption
		end
		if uDef.canmove == true then
			uDef.cancapture = true
			if uDef.turnrate then
				uDef.turnrate = uDef.turnrate * 1.5 * randomMultiplier()
			end
			if uDef.brakerate then
				uDef.brakerate = uDef.brakerate * 3 * randomMultiplier()
			end
			if uDef.builddistance then
				uDef.builddistance = uDef.builddistance * 2 * randomMultiplier()
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
				uDef.weapondefs[weaponDefName].damage[category] = math.floor((damage * randomMultiplier()))
			end
		end
	end

	if uDef.customparams.fighter then
		uDef.maxvelocity = uDef.maxvelocity * 2
	end

	return uDef
end

return {
	ScavUnitDef_Post = scavUnitDef_Post
}