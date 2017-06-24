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
local minimumbuilddistancerange = 155

local vehUnits = {
	-- t1
	armbeamver='', armcv='', armfav='', armflash='', armjanus='', armmlv='', armpincer='', armsam='', armstump='', armart='',
	-- t2
	armacv='', armbull='', armcroc='', armjam='', armlatnk='', armmanni='', armmart='', armmerl='', armseer='', armst='', armyork='', armconsul='',
	-- t1
	corcv='', corfav='', corgarp='', corgator='', corlevlr='', cormist='', cormlv='', cormuskrat='', corraid='', corwolv='',
	-- t2
	coracv='', coreter='', corgol='', cormabm='', cormart='', corparrow='', correap='', corseal='', corsent='', corvrad='', corvroc='', corintr='', corban='', cortrem='',
}
local vehAdditionalTurnrate = 0
local vehTurnrateMultiplier = 1.045

local vehAdditionalAcceleration = 0.01
local vehAccelerationMultiplier = 1.17

local vehAdditionalVelocity = 0
local vehVelocityMultiplier = 1.02


local kbotUnits = {
	-- t1
	armck='', armflea='', armham='', armjeth='', armpw='', armrectr='', armrock='', armwar='',
	-- t2
	armaak='', armack='', armamph='', armaser='', armdecom='', armfark='', armfast='', armfboy='', armfido='', armmark='', armmav='', armscab='', armsnipe='', armspid='', armsptk='', armspy='', armvader='', armzues='',
	-- t1
	corak='', corck='', corcrash='', cornecro='', corstorm='', corthud='',
	-- t2
	cormando='', coraak='', coramph='', corcan='', cordecom='', corfast='', corhrk='', cormort='', corpyro='', corroach='', corsktl='', corspec='', corspy='', corsumo='', cortermite='', corvoyr='',
}
local kbotAdditionalTurnrate = 0
local kbotTurnrateMultiplier = 1

local kbotAdditionalAcceleration = 0
local kbotAccelerationMultiplier = 0.75
local kbotBrakerateMultiplier = 0.75


function UnitDef_Post(name, uDef)

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Set building Mask 0 for all units that can be built in Control Victory points
	--
	if Spring.GetModOptions and (Spring.GetModOptions().scoremode ~= nil or Spring.GetModOptions().scoremode ~= "disabled") then
		if uDef.customparams and uDef.customparams.cvbuildable == true then
			uDef.buildingmask = 0
		end
	end

	-- Enable default Nanospray
	uDef.shownanospray = true

	-- vehicles
	if vehUnits[name] ~= nil then
		if uDef.turnrate ~= nil then
			uDef.turnrate = (uDef.turnrate + vehAdditionalTurnrate) * vehTurnrateMultiplier
		end

		if uDef.acceleration ~= nil then
			uDef.acceleration = (uDef.acceleration + vehAdditionalAcceleration) * vehAccelerationMultiplier
		end

		if uDef.maxvelocity ~= nil then
			uDef.maxvelocity = (uDef.maxvelocity + vehAdditionalVelocity) * vehVelocityMultiplier
		end

		if uDef.turninplace == 0 then
			uDef.turninplacespeedlimit = uDef.maxvelocity * 0.82
		end
	end

	-- kbots
	if kbotUnits[name] ~= nil then
		if uDef.turnrate ~= nil then
			uDef.turnrate = (uDef.turnrate + kbotAdditionalTurnrate) * kbotTurnrateMultiplier
		end

		if uDef.acceleration ~= nil then
			uDef.acceleration = (uDef.acceleration + kbotAdditionalAcceleration) * kbotAccelerationMultiplier
		end

		if uDef.brakerate ~= nil then
			uDef.brakerate = uDef.brakerate * kbotBrakerateMultiplier
		end

		if uDef.turninplace ~= 0 then
			uDef.turninplaceanglelimit = uDef.turninplaceanglelimit * 0.75
		end
	end

	--Set a minimum for builddistance
	if uDef.builddistance ~= nil and uDef.builddistance < minimumbuilddistancerange then
		uDef.builddistance = minimumbuilddistancerange
	end
end


-- process weapondef
function WeaponDef_Post(name, wDef)
  wDef.cratermult = (wDef.cratermult or 1) * 0.3 -- modify cratermult cause Spring v103 made too big craters
  
	if wDef.weapontype == "Cannon" then
		if wDef.stages == nil then
			wDef.stages = 9
			if wDef.damage ~= nil and wDef.damage.default ~= nil and wDef.areaofeffect ~= nil then
				wDef.stages = math.floor(7.5 + math.min(wDef.damage.default * 0.0033, wDef.areaofeffect * 0.13))
				wDef.alphadecay = 1.16
				wDef.sizedecay = 0.02
			end
		end
	end
	if wDef.weapontype == "BeamLaser" then
		if wDef.beamttl == 0 then
			wDef.beamttl = 5
			wDef.beamdecay = 0.55
		end
	end
end





--------------------------
-- MODOPTIONS
-------------------------

-- process modoptions (last, because they should not get baked)
function ModOptions_Post (UnitDefs, WeaponDefs)
	if (Spring.GetModOptions) then
	local modOptions = Spring.GetModOptions()
		if (modOptions.mo_seaplatforms == "enabled") then
			Spring.Echo("Sea Platforms enabled")
			
				for id,unitDef in pairs(UnitDefs) do
					if unitDef.name == "Platform" then
						cubeID = id
					end
				end
				for id,unitDef in pairs(UnitDefs) do

					if unitDef.objectname == "CORMLS" then
						unitDef["buildoptions"][21] = "armcube"
					end
					if unitDef.objectname == "ARMMLS" then
						unitDef["buildoptions"][21] = "armcube"
					end
					if unitDef.objectname == "CORCSA" then
						unitDef["buildoptions"][15] = "armcube"
					end
					if unitDef.objectname == "ARMCSA" then
						unitDef["buildoptions"][15] = "armcube"
					end
					if unitDef.objectname == "ARMCONSUL" then
						unitDef["buildoptions"][23] = "armcube"
					end
					if unitDef.objectname == "CORFAST" then
						unitDef["buildoptions"][23] = "armcube"
					end
					if unitDef.objectname == "CORCH" then
						unitDef["buildoptions"][44] = "armcube"
					end
					if unitDef.objectname == "ARMCH" then
						unitDef["buildoptions"][44] = "armcube"
					end
					if unitDef.objectname == "CORCK" then
						unitDef["buildoptions"][31] = "armcube"
					end
					if unitDef.objectname == "ARMCK" then
						unitDef["buildoptions"][31] = "armcube"
					end
					if unitDef.objectname == "CORCV" then
						unitDef["buildoptions"][31] = "armcube"
					end
					if unitDef.objectname == "ARMCV" then
						unitDef["buildoptions"][31] = "armcube"
					end
				end
		end
		
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
				end
			end
			--Spring.Echo("End Workertime Values----------------------------------------------------------------------------")
			--Spring.Echo("\n")
			--Spring.Echo("\n")
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
		else
			-- forbs setting was:
			--for id,weaponDef in pairs(WeaponDefs) do
			--	weaponDef.avoidFriendly = true
			--	weaponDef.collideFriendly = false
			--	weaponDef.avoidFeature = true
			--	weaponDef.collideFeature = true
			--end
		end
		
	end
end
