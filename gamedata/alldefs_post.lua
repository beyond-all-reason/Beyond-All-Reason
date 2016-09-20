--------------------------
-- DOCUMENTATION
-------------------------

-- BA contains weapondefs in its unitdef files
-- Standalone weapondefs are only loaded by Spring after unitdefs are loaded
-- So, if we want to do post processing and include all the unit+weapon defs, and have the ability to bake these changes into files, we must do it after both have been loaded
-- That means, ALL UNIT AND WEAPON DEF POST PROCESSING IS DONE HERE

-- What happens:
-- unitdefs_post.lua calls the _Post functions for unitDefs and any weaponDefs that are contained in the unitdef files
-- unitdefs_post.lua writes the corresponding unitDefs to customparams (if wanted)
-- weapondefs_post.lua fetches any weapondefs from the unitdefs, 
-- weapondefs_post.lua fetches the standlaone weapondefs, calls the _post functions for them, writes them to customparams (if wanted)
-- strictly speaking, alldefs.lua is a misnomer since this file does not handle armordefs, featuredefs or movedefs

-- Switch for when we want to save defs into customparams as strings (so as a widget can then write them to file)
-- The widget to do so can be found in 'etc/Lua/bake_unitdefs_post'
SaveDefsToCustomParams = false


-------------------------
-- DEFS POST PROCESSING
-------------------------

-- process unitdef
function UnitDef_Post(name, uDef)

end

-- process weapondef
function WeaponDef_Post(name, wDef)
  wDef.cratermult = (wDef.cratermult or 1) * 0.3 -- modify cratermult cause Spring v103 made too big craters
end


--------------------------
-- MODOPTIONS
-------------------------

-- process modoptions (last, because they should not get baked)
function ModOptions_Post (UnitDefs, WeaponDefs)
	if (Spring.GetModOptions) then
	local modOptions = Spring.GetModOptions()

		-- transporting enemy coms
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
		
		if (modOptions.betterunitmovement == "enabled") then
		Spring.Echo("[Advanced Unit Movement Modoption] Enabled")
			for id,unitDef in pairs(UnitDefs) do
				--Spring.Echo(unitDef.turnrate)'
				if unitDef.turnrate == nil and unitDef.canmove == true then
					--Spring.Echo(unitDef.name)
					unitDef.turnrate = 1000
				end
				
				if unitDef.turnrate ~= nil and unitDef.canmove == true then
					unitDef.turnrate = unitDef.turnrate * 2
				end
				
				if unitDef.canfly == true and unitDef.hoverattack == false then
					unitDef.turnrate = unitDef.turnrate + 5000
					unitDef.acceleration = unitDef.acceleration + 5
					--Spring.Echo(unitDef.name)
					--Spring.Echo(unitDef.turnrate)
					--Spring.Echo(unitDef.acceleration)
				end
				
				if unitDef.acceleration == nil and unitDef.canmove == true then
					--Spring.Echo(unitDef.name)
					unitDef.acceleration = 1
				end
				if unitDef.acceleration ~= nil and unitDef.canmove == true then
					unitDef.acceleration = unitDef.acceleration + 2
					--Spring.Echo(unitDef.name)
					--Spring.Echo(unitDef.turnrate)
					--Spring.Echo(unitDef.acceleration)
				end
			end
		end
	end
end