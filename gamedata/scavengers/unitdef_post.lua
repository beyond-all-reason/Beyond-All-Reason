-- this file gets included in alldefs_post.lua
local ScavengerName = "Scavenger "
function scav_Udef_Post(name, uDef)
    
	if uDef.buildoptions then
        for k, v in pairs(uDef.buildoptions) do
            if UnitDefs[v..'_scav'] then
                uDef.buildoptions[k] = v..'_scav'
            end
        end
    end
	
	if uDef.featuredefs then
		if uDef.featuredefs.dead then
			uDef.featuredefs.dead.resurrectable = 0
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
	if uDef.maxdamage then
		uDef.maxdamage = math.ceil(uDef.maxdamage*0.66)
	end
	if uDef.maxvelocity then
		uDef.maxvelocity = math.ceil(uDef.maxvelocity*1.2)
	end
	if uDef.radardistancejam then
		uDef.radardistancejam = math.ceil(uDef.radardistancejam*1.5)
	end
	-- if uDef.sightdistance then
	-- 	uDef.sightdistance = math.ceil(uDef.sightdistance*1.25)
	-- end
	if uDef.idleautoheal then
		uDef.idleautoheal = math.ceil(uDef.idleautoheal*4)
	end
	if not uDef.cancloak then
		uDef.cancloak = true
		uDef.mincloakdistance = math.max(72, math.ceil(uDef.sightdistance/1.8))
    end

	return uDef
	
end