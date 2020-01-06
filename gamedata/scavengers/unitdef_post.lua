-- this file gets included in alldefs_post.lua

function scav_Udef_Post(name, uDef)
    if uDef.buildoptions then
        for k, v in pairs(uDef.buildoptions) do
            if UnitDefs[v..'_scav'] then
                uDef.buildoptions[k] = v..'_scav'
            end
        end
    end
    return uDef
end