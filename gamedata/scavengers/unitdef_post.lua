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
	return uDef
	
end