-- BA does not use unitdefs_post, see alldefs_post.lua 
-- basically, DONT TOUCH this! 


-- see alldefs.lua for documentation
-- load the games _Post functions for defs, and find out if saving to custom params is wanted
VFS.Include("gamedata/alldefs_post.lua")
-- load functionality for saving to custom params
VFS.Include("gamedata/post_save_to_customparams.lua")

-- handle unitdefs and the weapons they contain
for name,ud in pairs(UnitDefs) do
  UnitDef_Post(name,ud)
  if ud.weapondefs then
	for wname,wd in pairs(ud.weapondefs) do
	  WeaponDef_Post(wname,wd)
	end
  end 
  
  if SaveDefsToCustomParams then
      SaveDefToCustomParams("UnitDefs", name, ud)    
  end
end