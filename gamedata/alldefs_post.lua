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
		
	for id,unitDef in pairs(UnitDefs) do
		-- Enable default Nanospray
		unitDef.shownanospray = true
	end
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
		
		if (modOptions.logicalbuildtime == "enabled") then
			--Spring.Echo("Begin Buildtime Values----------------------------------------------------------------------------")
			--Spring.Echo("\n")
			for id,unitDef in pairs(UnitDefs) do
				--Spring.Echo("[Buildtime-Old] " .. unitDef.objectname .. " (" .. unitDef.name .. ")" .. ": " .. unitDef.buildtime)
				unitDef.buildtime = unitDef.buildtime * 0.01
				--Spring.Echo("[Buildtime-New] " .. unitDef.objectname .. " (" .. unitDef.name .. ")" .. ": " .. unitDef.buildtime)
				--Spring.Echo("\n")
			end
			--Spring.Echo("End Buildtime Values----------------------------------------------------------------------------")
			--Spring.Echo("\n")
			--Spring.Echo("\n")
			
			--Spring.Echo("Begin Workertime Values----------------------------------------------------------------------------")
			--Spring.Echo("\n")
			for id,unitDef in pairs(UnitDefs) do
				if unitDef.workertime then
				
					--Make terraform really fast
					if unitDef.terraformspeed then
						unitDef.terraformspeed = unitDef.terraformspeed * 0.01 + 1000
					end
					
					if unitDef.reclaimspeed then
						unitDef.resurrectspeed = unitDef.resurrectspeed * 0.01
					end
					
					if unitDef.reclaimspeed then
						unitDef.reclaimspeed = unitDef.reclaimspeed * 0.01
					end
					
					if unitDef.capturespeed then
						unitDef.capturespeed = unitDef.capturespeed * 0.01
					end
					
					if unitDef.repairspeed then
						unitDef.repairspeed = unitDef.repairspeed * 0.01
					end
					
					--Spring.Echo("[Workertime-Old] " .. unitDef.objectname .. " (" .. unitDef.name .. ")" .. ": " .. unitDef.workertime)
					unitDef.workertime = unitDef.workertime * 0.01
					--Spring.Echo("[Workertime-New] " .. unitDef.objectname .. " (" .. unitDef.name .. ")" .. ": " .. unitDef.workertime)
					--Spring.Echo("\n")
					
					--Set Repairspeed to be less of buildspeed
					if unitDef.repairspeed then
						unitDef.repairspeed = unitDef.workertime * 0.6
					end
					if unitDef.reclaimspeed then
						unitDef.resurrectspeed = unitDef.workertime * 0.6
						unitDef.reclaimspeed = unitDef.workertime * 0.6
					end
				end
			end
			--Spring.Echo("End Workertime Values----------------------------------------------------------------------------")
			--Spring.Echo("\n")
			--Spring.Echo("\n")
		end
		
		if (modOptions.minimumbuilddistance == "enabled") then
		--Set a minimum for builddistance
			minimumbuilddistancerange = tonumber(modOptions.minimumbuilddistancerange) or 200
			for id,unitDef in pairs(UnitDefs) do
				if unitDef.builddistance ~= nil and unitDef.builddistance < minimumbuilddistancerange then
					unitDef.builddistance = minimumbuilddistancerange
				end
			end
		end

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
		
		if (modOptions.nonlaggybuildplates == "enabled") then
			for id,unitDef in pairs(UnitDefs) do
				if unitDef.usebuildinggrounddecal == true then
					unitDef.buildinggrounddecaltype = "groundplate.dds"
				end
			end
		end
		
		if (modOptions.betterunitmovement == "enabled") then
			Spring.Echo("[Advanced Unit Movement Modoption] Enabled")
			additionalTurnrate = tonumber(modOptions.additionalturnrate) or 500
			turnrateMultiplier = tonumber(modOptions.turnratemultiplier) or 2
			additionalAcceleration = tonumber(modOptions.additionalacceleration) or 1.25
			accelerationMultiplier = tonumber(modOptions.accelerationmultiplier) or 1
			for id,unitDef in pairs(UnitDefs) do
			
			--Exclude all aircraft
				--Spring.Echo(unitDef.turnrate)	
				if unitDef.turnrate ~= nil and unitDef.canmove == true and unitDef.canfly ~= true then
					unitDef.turnrate = unitDef.turnrate + additionalTurnrate * turnrateMultiplier
				end
				
				if unitDef.acceleration == nil and unitDef.canmove == true and unitDef.canfly ~= true then
					--Spring.Echo(unitDef.name)
					unitDef.acceleration = 1
				end
				
				if unitDef.acceleration ~= nil and unitDef.canmove == true and unitDef.canfly ~= true then
					unitDef.acceleration = unitDef.acceleration + additionalAcceleration * accelerationMultiplier
					--Spring.Echo(unitDef.name)
					--Spring.Echo(unitDef.turnrate)
					--Spring.Echo(unitDef.acceleration)
				end
				
			--Target aircraft specifically
				if unitDef.canfly == true then
				
				--unitDef.brakerate = 1
				--unitDef.turnrate = unitDef.turnrate + 1000
				--unitDef.collide = false
					
					if unitDef.hoverattack == true then
						--unitDef.airhoverfactor = 0.001
						--unitDef.airstrafe = false
						--unitDef.maxacc	= 0.1
					else
						--unitDef.acceleration = unitDef.acceleration + 5
						--unitDef.maxacc	= 0.3
					end
				end
			end
		end
		
		--Fire through friendly needs fixed hitspeheres, likewise, fixed hitspheres needs fire through friendly.
		--For the sake of keeping it simple, rolled both into one modoption.
		
		--Uncomment/recommend the following line for easier testing
		--modOptions.firethroughfriendly = "enabled"
		if (modOptions.firethroughfriendly == "enabled") then
			Spring.Echo("[Fire through friendlies Modoption] Enabled")
			for id,weaponDef in pairs(WeaponDefs) do
				--Spring.Echo(weaponDef.name)
				weaponDef.avoidFriendly = false
				weaponDef.collideFriendly = false
				weaponDef.avoidFeature = false
				weaponDef.collideFeature = false
				--Spring.Echo(weaponDef.avoidFriendly)
				--Spring.Echo(weaponDef.collideFriendly)
			end
			for id,unitDef in pairs(UnitDefs) do
				unitDef.collisionvolumetype = nil
				unitDef.usepiececollisionvolumes = nil
				--unitDef.collisionVolumeScales = [[0.0 0.0 0.0]]
				--unitDef.collisionvolumeoffsets = [[0.0 0.0 0.0]]
				--Spring.Echo(unitDef.name)
				--Spring.Echo(unitDef.collisionvolumetype)
				--unitDef.useFootPrintCollisionVolume = true
			end
		end
		
	end
end