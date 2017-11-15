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

local vehAdditionalTurnrate = 0
local vehTurnrateMultiplier = 1.0

local vehAdditionalAcceleration = 0.00
local vehAccelerationMultiplier = 0.92

local vehAdditionalVelocity = 0
local vehVelocityMultiplier = 0.92
local vehRSpeedFactor = 0.35

local kbotAdditionalTurnrate = 0
local kbotTurnrateMultiplier = 1

local kbotAdditionalAcceleration = 0
local kbotAccelerationMultiplier = 0.75
local kbotBrakerateMultiplier = 0.75


function UnitDef_Post(name, uDef)

	--if uDef.category['chicken'] ~= nil then	-- doesnt seem to work
	--	uDef.turnrate = 1800
	--	uDef.turninplaceanglelimit = 90
	--end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Set building Mask 0 for all units that can be built in Control Victory points
	--
	if Spring.GetModOptions and (Spring.GetModOptions().scoremode ~= nil or Spring.GetModOptions().scoremode ~= "disabled") then
		if uDef.customparams and uDef.customparams.cvbuildable == true then
			uDef.buildingmask = 0
		end
	end
	if uDef.workertime then
	if uDef.reclaimspeed then 
	uDef.reclaimspeed =  0.90 * uDef.reclaimspeed
	else 
	uDef.reclaimspeed = 0.90 * uDef.workertime
	end
	end
	
	if uDef.icontype and uDef.icontype == "sea" then
		if uDef.featuredefs and uDef.featuredefs.dead and uDef.featuredefs.dead.metal and uDef.buildcostmetal then
			uDef.featuredefs.dead.metal = uDef.buildcostmetal * 0.5
		end
		if uDef.featuredefs and uDef.featuredefs.heap and uDef.featuredefs.heap.metal and uDef.buildcostmetal then
			uDef.featuredefs.heap.metal = uDef.buildcostmetal * 0.25
		end
	end
	--Aircraft movements here:
	if uDef.canfly == true and not uDef.hoverattack == true then
		turn = (((uDef.turnrate)*0.16)/360)/30
		wingsurffactor = tonumber(uDef.customparams and uDef.customparams.wingsurface) or 1
		uDef.usesmoothmesh = true
		uDef.wingdrag = uDef.brakerate * 4
		uDef.wingangle = turn
		uDef.speedtofront = 0.07*wingsurffactor
		uDef.turnradius =64
		uDef.maxbank = 0.8
		uDef.maxpitch = 0.8
		uDef.maxaileron =turn
		uDef.maxelevator =turn
		uDef.maxrudder = turn
		uDef.maxacc = uDef.acceleration
	end
	-- Enable default Nanospray
	uDef.shownanospray = true

	-- vehicles
	if uDef.category["tank"] ~= nil then
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
		
		-- if (uDef.maxreversevelocity == nil or uDef.maxreversevelocity == 0) then --and not (name == "armcv" or name == "armacv" or name == "armconsul" or name == "armbeaver" or name == "corcv" or name == "coracv" or name == "cormuskrat") then
			-- uDef.maxreversevelocity = (uDef.maxvelocity) * vehRSpeedFactor
		-- end
		if uDef.turnrate ~= nil then
			uDef.turninplaceanglelimit = uDef.turnrate*30/180
		end
		
		if uDef.turninplaceanglelimit then
			uDef.customparams.anglelimit = uDef.turninplaceanglelimit
		end
		
	end

	-- kbots
	if uDef.category["kbot"] ~= nil then
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

	-- EdgeEffectiveness global buff to counterbalance smaller hitboxes
	wDef.edgeeffectiveness = (wDef.edgeeffectiveness or 0) + 0.15
	if wDef.edgeeffectiveness >= 1 then
	wDef.edgeeffectiveness = 1
	end
	
	-- Target borders of unit hitboxes rather than center (-1 = far border, 0 = center, 1 = near border)
	wDef.targetborder = 1.0
	
  -- artificial Armordefs tree: Default < heavyunits < hvyboats, allows me to specify bonus damages towards ships
	if (not (wDef["damage"].hvyboats)) and (wDef["damage"].heavyunits) then 
		wDef["damage"].hvyboats = wDef["damage"].heavyunits 
	elseif (not (wDef["damage"].hvyboats)) and (not wDef["damage"].heavyunits) then 
		wDef["damage"].hvyboats = wDef["damage"].default
	end
  -- end of artificial ArmorDefs tree
 
	if wDef.weapontype == "Cannon" then
		if wDef.stages == nil then
			wDef.stages = 10
			if wDef.damage ~= nil and wDef.damage.default ~= nil and wDef.areaofeffect ~= nil then
				wDef.stages = math.floor(7.5 + math.min(wDef.damage.default * 0.0033, wDef.areaofeffect * 0.13))
				wDef.alphadecay = 1 - ((1/wDef.stages)/1.5)
				wDef.sizedecay = 0.4 / wDef.stages
			end
		end
	end
	if wDef.weapontype == "BeamLaser" then
		if wDef.beamttl == 0 then
			wDef.beamttl = 5
			wDef.beamdecay = 0.55
		end
	end

	--Flare texture has been scaled down to half, so correcting the result of that a bit
	if wDef ~= nil and wDef.laserflaresize ~= nil and wDef.laserflaresize > 0 then
		wDef.laserflaresize = wDef.laserflaresize * 1.1
	end
end





--------------------------
-- MODOPTIONS
-------------------------

-- process modoptions (last, because they should not get baked)
function ModOptions_Post (UnitDefs, WeaponDefs)
	if (Spring.GetModOptions) then
	local modOptions = Spring.GetModOptions()
	local map_tidal = modOptions and modOptions.map_tidal
		if map_tidal and map_tidal ~= "unchanged" then
			for id, unitDef in pairs(UnitDefs) do
					if unitDef.tidalgenerator == 1 then
						unitDef.tidalgenerator = 0
						if map_tidal == "low" then
							unitDef.energymake = 13
						elseif map_tidal == "medium" then
							unitDef.energymake = 18
						elseif map_tidal == "high" then
							unitDef.energymake = 23
						end
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
