--NOTE: unitdefs_post does not deal with the normal lua UnitDefs table, it deals with the UnitDefs table built from unit definition files

-- process unitdef
local function UnitDef_Post(name,ud)
    -- slow update fix for 99.0
    if ud.buildcostmetal then ud.buildcostmetal = ud.buildcostmetal * (16/15) end
    if ud.buildcostenergy then ud.buildcostenergy = ud.buildcostenergy * (16/15) end
    if ud.weapons then
        for wname,wd in pairs(ud.weapons) do
            if wd.energypershot then wd.energypershot = wd.energypershot * (16/15) end
            if wd.metalpershot then wd.metalpershot = wd.metalpershot * (16/15) end        
        end    
    end
end

-- process weapondef
local function WeaponDef_Post(wname,wd)

end


for name,ud in pairs(UnitDefs) do
    UnitDef_Post(name,ud)  
    if ud.weapondefs then
        for wname,wd in pairs(ud.weapondefs) do
            WeaponDef_Post(wname,wd)
        end
    end
end

-------------------------

-- save raw unitdef tables to a string in custom params, can then be written to file by widget
-- this allows stuff in unitdefs_post to be painlessly baked into unitdef files
--VFS.Include("gamedata/unitdefs_post_save_to_customparams.lua")

--------------------------

-- implement various modoptions

if (Spring.GetModOptions) then
	local modOptions = Spring.GetModOptions()

  if (modOptions.mo_transportenemy == "notcoms") then
  	for name,ud in pairs(UnitDefs) do  
      if (name == "armcom" or name == "corcom" or name == "armdecom" or name == "cordecom") then
        ud.transportbyenemy = false
      end
    end
  elseif (modOptions.mo_transportenemy == "none") then
  	for name, ud in pairs(UnitDefs) do  
			ud.transportbyenemy = false
		end
  end
  
end