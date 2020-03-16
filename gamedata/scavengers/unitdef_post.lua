-- this file gets included in alldefs_post.lua

function scav_Udef_Post(name, uDef)
	if not uDef.customparams then
		uDef.customparams = {}
	end

	-- add unit category
	uDef.category = uDef.category..' SCAVENGER'

	-- add model vertex displacement
	local vertexDisplacement = 5.5 + ((uDef.footprintx + uDef.footprintz) / 12)
	if vertexDisplacement > 10 then
		vertexDisplacement = 10
	end
	uDef.customparams.scavvertdisp = vertexDisplacement

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
		if string.find(string.lower(uDef.explodeas), 'explosiongeneric') or string.find(string.lower(uDef.explodeas), 'buildingexplosiongeneric') then
			uDef.explodeas = uDef.explodeas..'-purple'
		end
	end
	if uDef.selfdestructas then
		if string.find(string.lower(uDef.selfdestructas), 'explosiongeneric') or string.find(string.lower(uDef.selfdestructas), 'buildingexplosiongeneric') then
			uDef.selfdestructas = uDef.selfdestructas..'-purple'
		end
	end

	-- replace buillists with _scav units
	if uDef.buildoptions then
        for k, v in pairs(uDef.buildoptions) do
            if UnitDefs[v..'_scav'] then
                uDef.buildoptions[k] = v..'_scav'
            end
        end
    end
	
	-- add Scavenger name prefix to wrecks
	if uDef.featuredefs then
		if uDef.featuredefs.dead then
			if uDef.featuredefs.dead.description then
				uDef.featuredefs.dead.description = "Scavenger "..uDef.featuredefs.dead.description
			end	
		end
		if uDef.featuredefs.heap then
			if uDef.featuredefs.heap.description then
				uDef.featuredefs.heap.description = "Scavenger "..uDef.featuredefs.heap.description
			end	
		end
	end
	
	-- add Scavenger name prefix to units
	if uDef.name then
		uDef.name = "Scavenger "..uDef.name
	end
	
	if uDef.builder then
		uDef.canresurrect = true
	end
		
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	--[[
	if not uDef.customparams then
		uDef.customparams = {}
	end

	-- add unit category
	uDef.category = uDef.category..' SCAVENGER'

	-- add model vertex displacement
	local vertexDisplacement = 5.5 + ((uDef.footprintx + uDef.footprintz) / 12)
	if vertexDisplacement > 10 then
		vertexDisplacement = 10
	end
	uDef.customparams.scavvertdisp = vertexDisplacement

	-- make barrelshot purple
	uDef.capturable = true
	uDef.hidedamage = false
	--if uDef.builder then
	--	uDef.corpse = ""
	--end
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
		if string.find(string.lower(uDef.explodeas), 'explosiongeneric') or string.find(string.lower(uDef.explodeas), 'buildingexplosiongeneric') then
			uDef.explodeas = uDef.explodeas..'-purple'
		end
	end
	if uDef.selfdestructas then
		if string.find(string.lower(uDef.selfdestructas), 'explosiongeneric') or string.find(string.lower(uDef.selfdestructas), 'buildingexplosiongeneric') then
			uDef.selfdestructas = uDef.selfdestructas..'-purple'
		end
	end

	if uDef.buildoptions then
        for k, v in pairs(uDef.buildoptions) do
            if UnitDefs[v..'_scav'] then
                uDef.buildoptions[k] = v..'_scav'
            end
        end
    end
	
	-- if uDef.featuredefs then
		-- if uDef.featuredefs.dead then
			-- uDef.featuredefs.dead.resurrectable = 0
		-- end
	-- end
	
	if uDef.featuredefs then
		if uDef.featuredefs.dead then
			if uDef.featuredefs.dead.description then
				uDef.featuredefs.dead.description = "Scavenger "..uDef.featuredefs.dead.description
			end	
			if uDef.featuredefs.dead.metal then
				uDef.featuredefs.dead.metal = math.ceil(uDef.featuredefs.dead.metal*0.5)
			end		
		end
	end

	if uDef.featuredefs then
		if uDef.featuredefs.heap then
			if uDef.featuredefs.heap.description then
				uDef.featuredefs.heap.description = "Scavenger "..uDef.featuredefs.heap.description
			end	
			if uDef.featuredefs.heap.metal then
				uDef.featuredefs.heap.metal = math.ceil(uDef.featuredefs.heap.metal*0.5)
			end		
		end
	end
	
	if uDef.name then
		uDef.name = "Scavenger "..uDef.name
	end
	
	if uDef.buildcostenergy then
		uDef.buildcostenergy = math.ceil(uDef.buildcostenergy*0.5)
	end
	if uDef.buildcostmetal then
		uDef.buildcostmetal = math.ceil(uDef.buildcostmetal*0.5)
	end
	-- if uDef.workertime then
		-- uDef.workertime = math.ceil(uDef.workertime*10)
	-- end
	if uDef.energymake then
		uDef.energymake = math.ceil(uDef.energymake*0.66)
	end
	if uDef.metalmake then
		uDef.metalmake = math.ceil(uDef.metalmake*0.66)
	end
	if uDef.maxdamage then
		uDef.maxdamage = math.ceil(uDef.maxdamage*0.5)
	end
	if uDef.maxvelocity then
		uDef.maxvelocity = math.ceil(uDef.maxvelocity*1.2)
	end
	if uDef.radardistancejam then
		uDef.radardistancejam = math.ceil(uDef.radardistancejam*1.25)
	end
	if uDef.sightdistance then
		uDef.sightdistance = math.ceil(uDef.sightdistance*1.25)
	end
	--if uDef.idleautoheal then
		--uDef.idleautoheal = math.ceil(uDef.idleautoheal*4)
	--end
    --if not uDef.cancloak then
 	--	uDef.cancloak = true
 	--	uDef.mincloakdistance = math.max(72, math.ceil(uDef.sightdistance/1.8))
    --end
 	--if not uDef.stealth then
 	--	uDef.stealth = true
 	--end
	
	 if not uDef.maxdamage then
		uDef.autoheal = math.ceil(uDef.maxdamage/100)
		uDef.idleautoheal = math.ceil(uDef.maxdamage/100)
	else 
		uDef.autoheal = 5
		uDef.idleautoheal = 5
	end
	if uDef.turnrate then
		uDef.turnrate = uDef.turnrate*2.5
	end
	if uDef.turninplaceanglelimit then
		uDef.turninplaceanglelimit = 360
	end


	]]--
	
	return uDef
	
end