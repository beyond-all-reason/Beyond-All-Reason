--NOTE: unitdefs_post does not deal with the normal lua UnitDefs table, it deals with the UnitDefs table built from unit definition files.







-------------------------

-- save raw unitdef tables to a string in custom params, can then be written to file as widget
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