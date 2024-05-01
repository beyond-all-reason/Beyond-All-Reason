-- -- UnitDef postprocessing specific to Scavenger units only

local function scavUnitDef_Post(name, uDef)

	uDef.category = uDef.category .. ' SCAVENGER'
	uDef.customparams.isscavenger = true
	uDef.capturable = false

 	-- replaced uniticons
	if uDef.buildpic then
		--local nonScavName = string.sub(uDef.unitname, 1, string.len(uDef.unitname)-5)
		if (not string.find(uDef.buildpic, "scavengers"))
		and (not string.find(uDef.buildpic, "raptor"))
		and (not string.find(uDef.buildpic, "critters"))
		and (not string.find(uDef.buildpic, "lootboxes"))
		and (not string.find(uDef.buildpic, "other"))
		and (not string.find(uDef.buildpic, "alternative")) then
			uDef.buildpic = "scavengers/"..uDef.buildpic
		end
	end

	-- add model vertex displacement
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

	
	-- Remove wrecks of units you shouldn't be able to capture
	if uDef.featuredefs and uDef.corpse and (uDef.buildoptions or (not uDef.canmove)) then
		if uDef.corpse == "DEAD" and uDef.featuredefs.heap then
			uDef.corpse = "HEAP"
		elseif uDef.corpse then
			uDef.corpse = nil
		end
	end
	
	-- Set autoheal of scav units
	if uDef.health then
		if not string.find(name, "armscavengerbossv2") then
			if not string.find(name, "scavengerdroppodbeacon") then
				uDef.health = uDef.health * 1.5
				uDef.hidedamage = true
			end
			uDef.autoheal = math.ceil(math.sqrt(uDef.health * 0.1))
			uDef.idleautoheal = math.ceil(math.sqrt(uDef.health * 0.1))
		end
	end

	-- Buff _scav units turnrate
	if uDef.turnrate then
		uDef.turnrate = uDef.turnrate * 1.2
	end
	if uDef.turninplaceanglelimit then
		uDef.turninplaceanglelimit = 360
	end

	-- Buff _scav builders
	if uDef.builder then
	 	if uDef.canmove == true then
	 		uDef.cancapture = true
	 		if uDef.turnrate then
	 			uDef.turnrate = uDef.turnrate * 1.5
	 		end
	 		if uDef.maxdec  then
	 			uDef.maxdec  = uDef.maxdec * 3
	 		end
	 		if uDef.builddistance then
	 			uDef.builddistance = uDef.builddistance * 2
	 		end
	 	end
	end

	-- Remove commander customparams from _scav commanders
	if uDef.customparams.evolution_target then
		uDef.customparams.evolution_target = nil
	end
	if uDef.customparams.evolution_condition then
		uDef.customparams.evolution_condition = nil
	end
	if uDef.customparams.evolution_timer then
		uDef.customparams.evolution_timer = nil
	end
	if uDef.customparams.iscommander then
		uDef.customparams.iscommander = nil
	end

	return uDef
end

return {
	ScavUnitDef_Post = scavUnitDef_Post
}