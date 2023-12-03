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

	-- Wrecks
	
	if uDef.featuredefs then
		if uDef.buildoptions or (not uDef.canmove) then
			uDef.corpse = nil
			if uDef.featuredefs.dead then
				uDef.featuredefs.dead = nil
			end
			if uDef.featuredefs.heap then
				uDef.corpse = "HEAP"
			end
		end
	end
	

	if uDef.health then
		if not string.find(name, "armscavengerbossv2") then
 			uDef.autoheal = math.ceil(math.sqrt(uDef.health * 0.1))
 			uDef.idleautoheal = math.ceil(math.sqrt(uDef.health * 0.1))
		end
	end

if uDef.turnrate then
	uDef.turnrate = uDef.turnrate * 1.2
end

if uDef.turninplaceanglelimit then
	uDef.turninplaceanglelimit = 360
end

if uDef.builder then
 	if uDef.canmove == true then
 		uDef.cancapture = true
 		if uDef.turnrate then
 			uDef.turnrate = uDef.turnrate * 1.5
 		end
 		if uDef.maxdec  then
 			uDef.maxdec  = uDef.maxdec  * 3
 		end
 		if uDef.builddistance then
 			uDef.builddistance = uDef.builddistance * 2
 		end
 	end
end
	return uDef
end

return {
	ScavUnitDef_Post = scavUnitDef_Post
}