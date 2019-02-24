-- BA does not use unitdefs_post, see alldefs_post.lua 
-- basically, DONT TOUCH this! 


if Spring.GetModOptions and (tonumber(Spring.GetModOptions().barmodels) or 0) ~= 0 then
    Spring.Echo("barmodels modoption is enabled")  -- notify that barmodels is enabled so infolog shows this
end

-- see alldefs.lua for documentation
-- load the games _Post functions for defs, and find out if saving to custom params is wanted
VFS.Include("gamedata/alldefs_post.lua")
-- load functionality for saving to custom params
VFS.Include("gamedata/post_save_to_customparams.lua")

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- handle unba modoption
if (Spring.GetModOptions) and Spring.GetModOptions().unba and Spring.GetModOptions().unba == "enabled" then
	VFS.Include("unbaconfigs/unbacom_post.lua")
	VFS.Include("unbaconfigs/stats.lua")
	VFS.Include("unbaconfigs/buildoptions.lua")
	UnbaCom_Post("armcom")
	UnbaCom_Post("corcom")
end




-- create BAR alternatives
--if not (Spring.GetModOptions and (tonumber(Spring.GetModOptions().barmodels) or 0) ~= 0) then
--    if Game and Game.gameVersion and (string.find(Game.gameVersion, 'test') or string.find(Game.gameVersion, '$VERSION')) then
--        local oldUnitName = {	-- mostly duplicates
--            armdecom = 'armcom',
--            cordecom = 'corcom',
--            armdf = 'armfus',
--            corgantuw = 'corgant',
--            armshltxuw = 'armshltx',
--        }
--        local barUnitDefs = {}
--        for name,uDef in pairs(UnitDefs) do
--            local barUnitName = oldUnitName[name] and oldUnitName[name] or name
--            if VFS.FileExists('objects3d/BAR/'..uDef.objectname..'.s3o') or VFS.FileExists('objects3d/BAR/'..barUnitName..'.s3o') then
--                barUnitDefs[name..'_bar'] = deepcopy(uDef)
--            end
--        end
--        for name,ud in pairs(barUnitDefs) do
--            UnitDefs[name] = ud
--        end
--    end
--end

-- handle unitdefs and the weapons they contain
for name,ud in pairs(UnitDefs) do
  UnitDef_Post(name,ud)
  if ud.weapondefs then
	for wname,wd in pairs(ud.weapondefs) do
	  WeaponDef_Post(wname,wd)
	end
  end 
  
  --ud.acceleration = 0.75
  --ud.turnrate = 800
  
  if SaveDefsToCustomParams then
      SaveDefToCustomParams("UnitDefs", name, ud)    
  end
end