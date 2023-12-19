--------------------------
-- DOCUMENTATION
-------------------------

-- BAR contains weapondefs in its unitdef files
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
-- The widget to do so is included in the game and detects these customparams auto-enables itself
-- and writes them to Spring/baked_defs
SaveDefsToCustomParams = false

-------------------------
-- DEFS PRE-BAKING
--
-- This section is for testing changes to defs and baking them into the def files
-- Only the changes in this section will get baked, all other changes made in post will not
--
-- 1. Add desired def changes to this section
-- 2. Test changes in-game
-- 3. Bake changes into def files
-- 4. Delete changes from this section
-------------------------

function PrebakeUnitDefs()
	for name, unitDef in pairs(UnitDefs) do
		-- UnitDef changes go here
	end
end

-------------------------
-- DEFS POST PROCESSING
-------------------------

-- process unitdef
--local vehAdditionalTurnrate = 0
--local vehTurnrateMultiplier = 1.0
--
--local vehAdditionalAcceleration = 0.00
--local vehAccelerationMultiplier = 1
--
--local vehAdditionalVelocity = 0
--local vehVelocityMultiplier = 1

--[[ Sanitize to whole frames (plus leeways because float arithmetic is bonkers).
     The engine uses full frames for actual reload times, but forwards the raw
     value to LuaUI (so for example calculated DPS is incorrect without sanitisation). ]]
local function round_to_frames(name, wd, key)
	local original_value = wd[key]
	if not original_value then
		-- even reloadtime can be nil (shields, death explosions)
		return
	end

	local Game_gameSpeed = 30 --for mission editor backwards compat (engine 104.0.1-287)
	if Game and Game.gameSpeed then Game_gameSpeed = Game.gameSpeed end

	local frames = math.max(1, math.floor((original_value + 1E-3) * Game_gameSpeed))
	local sanitized_value = frames / Game_gameSpeed

	return sanitized_value
end

local function processWeapons(unitDefName, unitDef)
	local weaponDefs = unitDef.weapondefs
	if not weaponDefs then
		return
	end

	for weaponDefName, weaponDef in pairs (weaponDefs) do
		local fullWeaponName = unitDefName .. "." .. weaponDefName
		weaponDef.reloadtime = round_to_frames(fullWeaponName, weaponDef, "reloadtime")
		weaponDef.burstrate = round_to_frames(fullWeaponName, weaponDef, "burstrate")
	end
end

function UnitDef_Post(name, uDef)
	-- Reverse Gear
	if Spring.GetModOptions().experimentalreversegear == true then
		if (not uDef.canfly) and uDef.speed then
			uDef.rspeed = uDef.speed*0.65
		end
	end

	-- Rebalance Candidates

	if Spring.GetModOptions().experimentalrebalancet2labs == true then --
		if name == "coralab" or name == "coravp" or name == "armalab" or name == "armavp" then
			uDef.metalcost = 1800 --2900
		end
		if name == "coraap" or name == "corasy" or name == "armaap" or name == "armasy" then
			uDef.metalcost = 2100 --3200
		end
	end

	if Spring.GetModOptions().experimentalrebalancet2metalextractors == true then
		if name == "armmoho" or name == "armuwmme" then
			uDef.extractsmetal = 0.002 --0.004
			uDef.metalcost = 240 --620
			uDef.energycost = 3000 --7700
			uDef.buildtime = 12000 --14938
			uDef.health = 1000 --2500
			uDef.energyupkeep = 10 --20
		end
		if name == "cormoho" or name == "coruwmme" then
			uDef.extractsmetal = 0.002 --0.004
			uDef.metalcost = 250 --640
			uDef.energycost = 3100 --8100
			uDef.buildtime = 11000 --14125
			uDef.health = 1400 --3500
			uDef.energyupkeep = 10 --20
		end
		if name == "cormexp" then
			uDef.extractsmetal = 0.002 --0.004
			uDef.metalcost = 2000 --2400
			uDef.energycost = 8500 --12000
			uDef.health = 2800 --3500
			uDef.energyupkeep = 10 --20
		end
	end

	if Spring.GetModOptions().experimentalrebalancet2energy == true then
		if name == "armaca" or name == "armack" or name == "armacv" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "armwint2"
		end
		if name == "coraca" or name == "corack" or name == "coracv" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corwint2"
		end
	end

	if Spring.GetModOptions().expandedt2sea == true then
		if name == "corcrus" then
			uDef.speed = 54
			uDef.health = 6200
			uDef.weapondefs.adv_decklaser.reloadtime = 0.333
			uDef.weapondefs.cor_crus.range = 500
		end
		if name == "armcrus" then
			uDef.speed = 60
			uDef.health = 5600
			uDef.weapondefs.laser.reloadtime = 0.333
			uDef.weapondefs.gauss.range = 500
		end
		if name == "armasy" then
			for ix, UnitName in pairs(uDef.buildoptions) do
				if UnitName == "armcarry" then
					uDef.buildoptions[ix] = "armantiship"
				end
			end
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "armdronecarry"
			uDef.buildoptions[numBuildoptions+2] = "armlship"
		end
		if name == "corasy" then
			for ix, UnitName in pairs(uDef.buildoptions) do
				if UnitName == "corcarry" then
					uDef.buildoptions[ix] = "corantiship"
				end
			end
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "cordronecarry"
			uDef.buildoptions[numBuildoptions+2] = "corfship"
		end
	end

	-- Control Mode Tweaks
	if Spring.GetModOptions().scoremode ~= "disabled" then
		if Spring.GetModOptions().scoremode_chess == true then
			-- Disable Wrecks
			uDef.corpse = nil
			-- Disable Bad Units
			local factories = {
				armaap = true,
				armalab = true,
				armap = true,
				armavp = true,
				armhp = true,
				armlab = true,
				armshltx = true,
				armvp = true,
				armamsub = true,
				armasy = true,
				armfhp = true,
				armplat = true,
				armshltxuw = true,
				armsy = true,
				coraap = true,
				coralab = true,
				corap = true,
				coravp = true,
				corgant = true,
				corhp = true,
				corlab = true,
				corvp = true,
				coramsub = true,
				corasy = true,
				corfhp = true,
				corplat = true,
				corgantuw = true,
				corsy = true,
				armapt3 = true,	-- scav T3 air factory
				corapt3 = true,	-- scav T3 air factory
				armnanotc = true,
				armnanotcplat = true,
				cornanotc = true,
				cornanotcplat = true,
				armbotrail = true, -- it spawns units so it will add dead launched peewees to respawn queue.
			}
			if factories[name] then
				uDef.maxthisunit = 0
			end
		else

		end
	end

	-- test New sound system!
	--VFS.Include('luarules/configs/gui_soundeffects.lua')
	--if not (GUIUnitSoundEffects[name] or (GUIUnitSoundEffects[string.sub(name, 1, string.len(name)-5)] and string.find(name, "_scav"))) then
	--	Spring.Echo("[gui_soundeffects.lua] Missing Sound Effects for unit: "..name)
	--end

	if uDef.sounds then
		if uDef.sounds.ok then
			uDef.sounds.ok = nil
		end
	end

	if uDef.sounds then
		if uDef.sounds.select then
			uDef.sounds.select = nil
		end
	end

	if uDef.sounds then
		if uDef.sounds.activate then
			uDef.sounds.activate = nil
		end
		if uDef.sounds.deactivate then
			uDef.sounds.deactivate = nil
		end
		if uDef.sounds.build then
			uDef.sounds.build = nil
		end
	end

	-- Unit Restrictions
	if uDef.customparams then
		if not uDef.customparams.techlevel then uDef.customparams.techlevel = 1 end
		if not uDef.customparams.subfolder then uDef.customparams.subfolder = "none" end

		if Spring.GetModOptions().unit_restrictions_notech2 then
			if tonumber(uDef.customparams.techlevel) == 2 or tonumber(uDef.customparams.techlevel) == 3 then
				uDef.maxthisunit = 0
			end
		end

		if Spring.GetModOptions().unit_restrictions_notech3 then
			if tonumber(uDef.customparams.techlevel) == 3 then
				uDef.maxthisunit = 0
			end
		end

		if Spring.GetModOptions().unit_restrictions_noair then
			if string.find(uDef.customparams.subfolder, "Aircraft") then
				uDef.maxthisunit = 0
			elseif uDef.canfly then
				uDef.maxthisunit = 0
			end
			local AircraftFactories = {
				armap = true,
				armaap = true,
				armplat = true,
				corap = true,
				coraap = true,
				corplat = true,
				corapt3 = true,
				armapt3 = true,
				legap = true,
				legaap = true,
				armap_scav = true,
				armaap_scav = true,
				armplat_scav = true,
				corap_scav = true,
				coraap_scav = true,
				corplat_scav = true,
				corapt3_scav = true,
				armapt3_scav = true,
				legap_scav = true,
				legaap_scav = true,

			}
			if AircraftFactories[name] then
				uDef.maxthisunit = 0
			end
		end

		if Spring.GetModOptions().unit_restrictions_noextractors then
			if (uDef.extractsmetal and uDef.extractsmetal > 0) and (uDef.customparams.metal_extractor and uDef.customparams.metal_extractor > 0) then
				uDef.maxthisunit = 0
			end
		end

		if Spring.GetModOptions().unit_restrictions_noconverters then
			if uDef.customparams.energyconv_capacity and uDef.customparams.energyconv_efficiency then
				uDef.maxthisunit = 0
			end
		end

		if Spring.GetModOptions().unit_restrictions_nonukes then
			local Nukes = {
				armamd = true,
				armsilo = true,
				armscab = true,
				corfmd = true,
				corsilo = true,
				cormabm = true,
				armamd_scav = true,
				armsilo_scav = true,
				armscab_scav = true,
				corfmd_scav = true,
				corsilo_scav = true,
				cormabm_scav = true,
			}
			if Nukes[name] then
				uDef.maxthisunit = 0
			end
		end

		if Spring.GetModOptions().unit_restrictions_notacnukes then
			local TacNukes = {
				armemp = true,
				cortron = true,
				armemp_scav = true,
				cortron_scav = true,
			}
			if TacNukes[name] then
				uDef.maxthisunit = 0
			end
		end

		if Spring.GetModOptions().unit_restrictions_nolrpc then
			local LRPCs = {
				armbotrail = true,
				armbrtha = true,
				armvulc = true,
				corint = true,
				corbuzz = true,
				legstarfall = true,
				armbotrail_scav = true,
				armbrtha_scav = true,
				armvulc_scav = true,
				corint_scav = true,
				corbuzz_scav = true,
				legstarfall_scav = true,
			}
			if LRPCs[name] then
				uDef.maxthisunit = 0
			end
		end
	end

	-- Add balanced extras
	if Spring.GetModOptions().releasecandidates then
	
	
		--Better Dragon
		if name == "coraap" then			
			for ix, UnitName in pairs(uDef.buildoptions) do
				if UnitName == "corcrw" then
					uDef.buildoptions[ix] = "corcrwh"
				end
			end
		end

		--Shockwave mex
		if name == "armaca" or name == "armack" or name == "armacv" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "armshockwave"
		end	
	

		if name == "coravp" then
			for ix, UnitName in pairs(uDef.buildoptions) do
				if UnitName == "corseal" then
					uDef.buildoptions[ix] = "corsala"
				end
			end

			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corvac" --corprinter
			--uDef.buildoptions[numBuildoptions+2] = "corsala"
			--uDef.buildoptions[numBuildoptions+3] = "corforge"
			--uDef.buildoptions[numBuildoptions+4] = "cortorch"
		end
		if name == "coramsub" then
			for ix, UnitName in pairs(uDef.buildoptions) do
				if UnitName == "corseal" then
					uDef.buildoptions[ix] = "corsala"
				end
			end

		end

		-- demon

		if name == "corgant" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "cordemont4"		
		end

		if name == "corgantuw" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "cordemont4"
			
			for ix, UnitName in pairs(uDef.buildoptions) do
				if UnitName == "corseal" then
					uDef.buildoptions[ix] = "corsala"
				end
			end
		end
	end

	-- Add scav units to normal factories and builders
	if Spring.GetModOptions().experimentalextraunits then
		if name == "armshltx" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "armrattet4"
			uDef.buildoptions[numBuildoptions+2] = "armsptkt4"
			uDef.buildoptions[numBuildoptions+3] = "armpwt4"
			uDef.buildoptions[numBuildoptions+4] = "armvadert4"
			-- uDef.buildoptions[numBuildoptions+5] = "armlunchbox"
			uDef.buildoptions[numBuildoptions+6] = "armmeatball"
			uDef.buildoptions[numBuildoptions+7] = "armassimilator"
			uDef.buildoptions[numBuildoptions+8] = "armdronecarryland"
		elseif name == "armshltxuw" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "armrattet4"
			uDef.buildoptions[numBuildoptions+2] = "armpwt4"
			uDef.buildoptions[numBuildoptions+3] = "armvadert4"
			uDef.buildoptions[numBuildoptions+4] = "armmeatball"
		elseif name == "corgant" or name == "leggant" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "cordemont4"
			uDef.buildoptions[numBuildoptions+2] = "corkarganetht4"
			uDef.buildoptions[numBuildoptions+3] = "corgolt4"
			uDef.buildoptions[numBuildoptions+4] = "corakt4"
			uDef.buildoptions[numBuildoptions+5] = "corthermite"
		elseif name == "corgantuw" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corgolt4"
		elseif name == "armvp" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "armzapper"
		elseif name == "coravp" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corgatreap"
			uDef.buildoptions[numBuildoptions+2] = "corforge"
			uDef.buildoptions[numBuildoptions+3] = "corvac" --corprinter
			uDef.buildoptions[numBuildoptions+4] = "corftiger"
			uDef.buildoptions[numBuildoptions+5] = "cortorch"
			uDef.buildoptions[numBuildoptions+6] = "corsala"
		elseif name == "armca" or name == "armck" or name == "armcv" then
			--local numBuildoptions = #uDef.buildoptions
		elseif name == "corca" or name == "corck" or name == "corcv" then
			--local numBuildoptions = #uDef.buildoptions
		elseif name == "legca" or name == "legck" or name == "legcv" then
			--local numBuildoptions = #uDef.buildoptions
		elseif name == "corcs" or name == "corcsa" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corgplat"
			uDef.buildoptions[numBuildoptions+2] = "corfrock"
		elseif name == "armcs" or name == "armcsa" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "armgplat"
			uDef.buildoptions[numBuildoptions+2] = "armfrock"
		elseif name == "coracsub" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corfgate"
		elseif name == "armacsub" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "armfgate"
		elseif name == "armaca" or name == "armack" or name == "armacv" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "armapt3"
			uDef.buildoptions[numBuildoptions+2] = "armminivulc"
			uDef.buildoptions[numBuildoptions+3] = "armwint2"
			uDef.buildoptions[numBuildoptions+5] = "armbotrail"
			uDef.buildoptions[numBuildoptions+6] = "armannit3"
			uDef.buildoptions[numBuildoptions+7] = "armnanotct2"
			uDef.buildoptions[numBuildoptions+8] = "armlwall"
		elseif name == "coraca" or name == "corack" or name == "coracv" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corapt3"
			uDef.buildoptions[numBuildoptions+2] = "corminibuzz"
      		uDef.buildoptions[numBuildoptions+3] = "corwint2"
			uDef.buildoptions[numBuildoptions+4] = "corhllllt"
			uDef.buildoptions[numBuildoptions+6] = "cordoomt3"
			uDef.buildoptions[numBuildoptions+7] = "cornanotct2"
			uDef.buildoptions[numBuildoptions+8] = "cormwall"
		elseif name == "legaca" or name == "legack" or name == "legacv" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corapt3"
			uDef.buildoptions[numBuildoptions+2] = "corminibuzz"
      		uDef.buildoptions[numBuildoptions+3] = "corwint2"
			uDef.buildoptions[numBuildoptions+4] = "corhllllt"
			uDef.buildoptions[numBuildoptions+6] = "cordoomt3"
			uDef.buildoptions[numBuildoptions+7] = "cornanotct2"
		elseif name == "armasy" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "armptt2"
			uDef.buildoptions[numBuildoptions+2] = "armdecadet3"
			uDef.buildoptions[numBuildoptions+3] = "armpshipt3"
			uDef.buildoptions[numBuildoptions+4] = "armserpt3"
			uDef.buildoptions[numBuildoptions+5] = "armcarry2"
		elseif name == "corasy" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corslrpc"
			uDef.buildoptions[numBuildoptions+2] = "coresuppt3"
			uDef.buildoptions[numBuildoptions+3] = "corcarry2"
		end
	end

	-- if Spring.GetModOptions().experimentalmassoverride then
	-- 	-- mass override
	-- 	Spring.Echo("-------------------------")
	-- 	if uDef.name then
	-- 		Spring.Echo("Processing Mass Override for unit: "..uDef.name)
	-- 	else
	-- 		Spring.Echo("Processing Mass Override for unit: unknown-unit")
	-- 	end
	-- 	Spring.Echo("-------------------------")

	-- 	massoverrideFootprintX = 1
	-- 	if uDef.footprintx and uDef.footprintx > 0 then
	-- 		massoverrideFootprintX = uDef.footprintx
	-- 		Spring.Echo("Footprint X: "..uDef.footprintx)
	-- 	else
	-- 		Spring.Echo("Missing Footprint X")
	-- 	end

	-- 	massoverrideFootprintZ = 1
	-- 	if uDef.footprintz and uDef.footprintz > 0 then
	-- 		massoverrideFootprintZ = uDef.footprintz
	-- 		Spring.Echo("Footprint Z: "..uDef.footprintz)
	-- 	else
	-- 		Spring.Echo("Missing Footprint Z")
	-- 	end

	-- 	massoverrideMetalCost = 1
	-- 	if uDef.metalcost and uDef.metalcost > 0 then
	-- 		massoverrideMetalCost = uDef.metalcost
	-- 		Spring.Echo("Metal Cost: "..uDef.metalcost)
	-- 	else
	-- 		Spring.Echo("Missing Metal Cost")
	-- 	end

	-- 	massoverrideHealth = 1
	-- 	if uDef.health and uDef.health > 0 then
	-- 		massoverrideHealth = uDef.health
	-- 		Spring.Echo("Max Health: "..uDef.health)
	-- 	else
	-- 		Spring.Echo("Missing Max Health")
	-- 	end

	-- 	uDef.mass = math.ceil((massoverrideFootprintX * massoverrideFootprintZ * (massoverrideMetalCost + massoverrideHealth))*0.33)
	-- 	Spring.Echo("-------------------------")
	-- 	Spring.Echo("Result Mass: "..uDef.mass)
	-- 	Spring.Echo("-------------------------")
	-- end

	-- mass remove push resistance
	if uDef.pushresistant and uDef.pushresistant == true then
		uDef.pushresistant = false
		if not uDef.mass then
			--Spring.Echo("[PUSH RESISTANCE REMOVER] Push Resistant Unit with no mass: "..name)
			uDef.mass = 4999
		end
	end

	--[[
	if uDef.metalcost and uDef.health then
		uDef.mass = uDef.metalcost
		if uDef.mass and uDef.name then
			Spring.Echo(uDef.name.."'s mass is:"..uDef.mass)
		end
	end
	]]
	if string.find(name, "raptor") and uDef.health then
		local raptorHealth = uDef.health
		uDef.activatewhenbuilt = true
		uDef.metalcost = raptorHealth*0.5
		uDef.energycost = math.min(raptorHealth*5, 16000000)
		uDef.buildtime = math.min(raptorHealth*10, 16000000)
		uDef.hidedamage = true
		uDef.mass = raptorHealth
		uDef.canhover = true
		uDef.autoheal = math.ceil(math.sqrt(raptorHealth * 0.2))
		uDef.customparams.paralyzemultiplier = uDef.customparams.paralyzemultiplier or .2
		uDef.idleautoheal = math.ceil(math.sqrt(raptorHealth * 0.2))
		uDef.idletime = 1
		uDef.customparams.areadamageresistance = "_RAPTORACID_"
		uDef.upright = false
		uDef.floater = true
		uDef.turninplace = true
		uDef.turninplaceanglelimit = 360
		uDef.capturable = false
		uDef.leavetracks = false
		uDef.maxwaterdepth = 0

		if uDef.cancloak then
			uDef.cloakcost = 0
			uDef.cloakcostmoving = 0
			uDef.mincloakdistance = 100
			uDef.seismicsignature = 3
			uDef.initcloaked = 1
		else
			uDef.seismicsignature = 0
		end

		if uDef.sightdistance then
			uDef.sonardistance = uDef.sightdistance*2
			uDef.radardistance = uDef.sightdistance*2
			uDef.airsightdistance = uDef.sightdistance*2
		end

		if (not uDef.canfly) and uDef.speed then
			uDef.rspeed = uDef.speed*0.65
			uDef.turnrate = uDef.speed*10
			uDef.maxacc = uDef.speed*0.00166
			uDef.maxdec  = uDef.speed*0.00166
		elseif uDef.canfly then
			uDef.maxacc = 0.8
			uDef.maxdec  = 0.1
			uDef.usesmoothmesh = true

			-- flightmodel
			uDef.maxacc = 0.25
			uDef.maxaileron = 0.025
			uDef.maxbank = 0.8
			uDef.maxelevator = 0.025
			uDef.maxpitch = 0.75
			uDef.maxrudder = 0.025
			uDef.wingangle = 0.06593
			uDef.wingdrag = 0.835
			uDef.turnradius = 64
			uDef.turnrate = 1600
			uDef.speedtofront = 0.01
			uDef.cruisealtitude = 220
			--uDef.attackrunlength = 32
		end
	end

	-- if (uDef.buildpic and uDef.buildpic == "") or not uDef.buildpic then
	-- 	Spring.Echo("[BUILDPIC] Missing Buildpic: ".. uDef.name)
	-- end

	--[[ Sanitize to whole frames (plus leeways because float arithmetic is bonkers).
         The engine uses full frames for actual reload times, but forwards the raw
         value to LuaUI (so for example calculated DPS is incorrect without sanitisation). ]]
	processWeapons(name, uDef)

	-- make los height a bit more forgiving	(20 is the default)
	--uDef.sightemitheight = (uDef.sightemitheight and uDef.sightemitheight or 20) + 20
	if true then
		uDef.sightemitheight = 0
		uDef.radaremitheight = 0
		if uDef.collisionvolumescales then
			local x = uDef.collisionvolumescales
			--Spring.Echo(x)
			local xtab = {}
			for i in string.gmatch(x, "%S+") do
				xtab[#xtab+1] = i
			end
			--Spring.Echo("Result of volume scales: "..tonumber(xtab[2]))
			uDef.sightemitheight = uDef.sightemitheight+tonumber(xtab[2])
			uDef.radaremitheight = uDef.radaremitheight+tonumber(xtab[2])
		end
		if uDef.collisionvolumeoffsets then
			local x = uDef.collisionvolumeoffsets
			--Spring.Echo(x)
			local xtab = {}
			for i in string.gmatch(x, "%S+") do
				xtab[#xtab+1] = i
			end
			--Spring.Echo("Result of volume offsets: "..tonumber(xtab[2]))
			uDef.sightemitheight = uDef.sightemitheight+tonumber(xtab[2])
			uDef.radaremitheight = uDef.radaremitheight+tonumber(xtab[2])
		end
                if uDef.sightemitheight < 40 then
                        uDef.sightemitheight = 40
                        uDef.radaremitheight = 40
                end
		--Spring.Echo("Final Emit Height: ".. uDef.sightemitheight)
	end

	if not uDef.customparams.iscommander then
		--local wreckinfo = ''
		if uDef.featuredefs and uDef.health then
			if uDef.featuredefs.dead then
				uDef.featuredefs.dead.damage = uDef.health
				if Spring.GetModOptions().experimentalrebalancewreckstandarization then
					if uDef.metalcost and uDef.energycost then
						if name and not string.find(name, "_scav") then
							-- if (name and uDef.featuredefs.dead.metal) or uDef.name then
							-- 	--wreckinfo = wreckinfo .. name ..  " Wreck Before: " .. tostring(uDef.featuredefs.dead.metal) .. ','
							-- end
							uDef.featuredefs.dead.metal = math.floor(uDef.metalcost*0.6)
							-- if name and not string.find(name, "_scav") then
							-- 	--wreckinfo = wreckinfo .. " Wreck After: " .. tostring(uDef.featuredefs.dead.metal) .. " ; "
							-- end
						end
					end
				end
			end
		end

		if uDef.featuredefs and uDef.health then
			if uDef.featuredefs.heap then
				uDef.featuredefs.heap.damage = uDef.health
				if Spring.GetModOptions().experimentalrebalancewreckstandarization then
					if uDef.metalcost and uDef.energycost then
						if name and not string.find(name, "_scav") then
							-- if (name and uDef.featuredefs.heap.metal) or uDef.name then
							-- 	--wreckinfo = wreckinfo .. name ..  " Heap Before: " .. tostring(uDef.featuredefs.heap.metal) .. ','
							-- end
							uDef.featuredefs.heap.metal = math.floor(uDef.metalcost*0.25)
							-- if name and not string.find(name, "_scav") then
							-- 	--wreckinfo = wreckinfo ..  " Heap After: " .. tostring(uDef.featuredefs.heap.metal)
							-- end
						end
					end
				end
			end
		end
		--if wreckinfo ~= '' then Spring.Echo(wreckinfo) end
    end

	if uDef.maxslope then
		uDef.maxslope = math.floor((uDef.maxslope * 1.5) + 0.5)
	end

	-- make sure all paralyzable units have the correct EMPABLE category applied (or removed)
	if uDef.category then
		local empable = string.find(uDef.category, "EMPABLE")
		if uDef.customparams and uDef.customparams.paralyzemultiplier then
			if tonumber(uDef.customparams.paralyzemultiplier) == 0 then
				if empable then
					uDef.category = string.sub(uDef.category, 1, empable) .. string.sub(uDef.category, empable+7)
				end
			elseif not empable then
				uDef.category = uDef.category .. ' EMPABLE'
			end
		elseif not empable then
			uDef.category = uDef.category .. ' EMPABLE'
		end
	end

	--if Spring.GetModOptions().airrebalance then
		--if uDef.weapons then
		--	local aaMult = 1.05
		--	for weaponID, w in pairs(uDef.weapons) do
		--		if w.onlytargetcategory == 'VTOL' then
		--			local wdef = string.lower(w.def)
		--			if uDef.weapondefs[wdef] and uDef.weapondefs[wdef].range < 2000 then -- excluding mercury/screamer
		--				uDef.weapondefs[wdef].range = math.floor((uDef.weapondefs[wdef].range * aaMult) + 0.5)
		--				if uDef.weapondefs[wdef].flighttime then
		--					uDef.weapondefs[wdef].flighttime = uDef.weapondefs[wdef].flighttime * (aaMult-((aaMult-1)/3))
		--				end
		--			end
		--		end
		--	end
		--end

		if uDef.canfly then

			uDef.crashdrag = 0.01	-- default 0.005

			if not (string.find(name, "fepoch") or string.find(name, "fblackhy") or string.find(name, "corcrw") or string.find(name, "legfort")) then--(string.find(name, "liche") or string.find(name, "crw") or string.find(name, "fepoch") or string.find(name, "fblackhy")) then
				if not Spring.GetModOptions().experimentalnoaircollisions then
					uDef.collide = false
				else
					uDef.collide = true
				end

				--local airmult = 1.3
				--if uDef.energycost then
				--	uDef.energycost = math.ceil(uDef.energycost*airmult)
				--end
				--
				--if uDef.buildtime then
				--	uDef.buildtime = math.ceil(uDef.buildtime*airmult)
				--end
				--
				--if uDef.metalcost then
				--	uDef.metalcost = math.ceil(uDef.metalcost*airmult)
				--end
				--
				--if uDef.builder then
				--	uDef.workertime = math.floor((uDef.workertime*airmult) + 0.5)
				--end

				if uDef.customparams.fighter then

					--if uDef.health then
					--	uDef.health = math.ceil(uDef.health*1.8)
					--end
--
					--if uDef.weapondefs then
					--	local reloadtimeMult = 1.8
					--	for weaponDefName, weaponDef in pairs (uDef.weapondefs) do
					--		uDef.weapondefs[weaponDefName].reloadtime = uDef.weapondefs[weaponDefName].reloadtime * reloadtimeMult
					--		for category, damage in pairs (weaponDef.damage) do
					--			uDef.weapondefs[weaponDefName].damage[category] = math.floor((damage * reloadtimeMult) + 0.5)
					--		end
					--	end
					--end
					--
					--uDef.speed = uDef.maxvelocity*1.15
					--
					--uDef.maxacc = uDef.maxacc*1.3
					--
					---- turn speeds x,y,z
					--local movementMult = 1.1
					--uDef.maxelevator = uDef.maxelevator*movementMult
					--uDef.maxrudder  = uDef.maxrudder*movementMult
					--uDef.maxaileron = uDef.maxaileron*movementMult
					--
					--uDef.turnradius = uDef.turnradius*0.9
					--
					--uDef.maxbank = uDef.maxbank*movementMult
					--uDef.maxpitch = uDef.maxpitch*movementMult
					--
					--uDef.maxbank = uDef.maxbank*movementMult
					--uDef.maxpitch = uDef.maxpitch*movementMult

				else 	-- not fighters

					--local rangeMult = 0.65
					--if uDef.airsightdistance then
					--	uDef.airsightdistance = math.floor((uDef.airsightdistance*rangeMult) + 0.5)
					--end
					--
					--if uDef.health then
					--	uDef.health = math.floor((uDef.health*airmult) + 0.5)
					--end
					--
					--if uDef.weapondefs then
					--	for weaponDefName, weaponDef in pairs (uDef.weapondefs) do
					--		uDef.weapondefs[weaponDefName].range = math.floor((uDef.weapondefs[weaponDefName].range * rangeMult) + 0.5)
					--		for category, damage in pairs (weaponDef.damage) do
					--			uDef.weapondefs[weaponDefName].damage[category] = math.floor((damage * airmult) + 0.5)
					--		end
					--	end
					--end
				end
			end
		end
	--end

	-- vehicles
    --if uDef.category and string.find(uDef.category, "TANK") then
    --	if uDef.turnrate ~= nil then
    --		uDef.turnrate = (uDef.turnrate + vehAdditionalTurnrate) * vehTurnrateMultiplier
    --	end
    --    	if uDef.maxacc~= nil then
    --		uDef.maxacc= (uDef.maxacc+ vehAdditionalAcceleration) * vehAccelerationMultiplier
    --	end
    --    	if uDef.speed ~= nil then
    --		uDef.speed = (uDef.maxvelocity + vehAdditionalVelocity) * vehVelocityMultiplier
    --	end
    --end

	-- Unbacom

	if Spring.GetModOptions().unba == true then
		unbaUnits = VFS.Include("unbaconfigs/unbaunits_post.lua")
		uDef = unbaUnits.unbaUnitTweaks(name, uDef)
	end


if Spring.GetModOptions().emprework == true then

		if name == "armstil" then		
			uDef.weapondefs.stiletto_bomb.areaofeffect = 250
			uDef.weapondefs.stiletto_bomb.burst = 3
			uDef.weapondefs.stiletto_bomb.burstrate = 0.3333
			uDef.weapondefs.stiletto_bomb.edgeeffectiveness = 0.30
			uDef.weapondefs.stiletto_bomb.damage.default = 1600
			uDef.weapondefs.stiletto_bomb.paralyzetime = 5			
		end

		if name == "armspid" then
			uDef.weapondefs.spider.paralyzetime = 5			
			uDef.weapondefs.spider.damage.vtol = 175			
			uDef.weapondefs.spider.damage.default = 700
		end

		if name == "armdfly" then
			uDef.weapondefs.armdfly_paralyzer.paralyzetime = 8			
		end
		

		if name == "armemp" then
			uDef.weapondefs.armemp_weapon.areaofeffect = 512
			uDef.weapondefs.armemp_weapon.burstrate = 0.3333
			uDef.weapondefs.armemp_weapon.edgeeffectiveness = -0.10
			uDef.weapondefs.armemp_weapon.paralyzetime = 23
			uDef.weapondefs.armemp_weapon.damage.default = 60000
			
		end
		if name == "armshockwave" then
			uDef.weapondefs.hllt_bottom.areaofeffect = 150
			uDef.weapondefs.hllt_bottom.edgeeffectiveness = 0.15
			uDef.weapondefs.hllt_bottom.reloadtime = 1.4
			uDef.weapondefs.hllt_bottom.paralyzetime = 5
			uDef.weapondefs.hllt_bottom.damage.default = 800
		end
		

		if name == "armthor" then
			uDef.weapondefs.empmissile.areaofeffect = 250
			uDef.weapondefs.empmissile.edgeeffectiveness = -0.50
			uDef.weapondefs.empmissile.damage.default = 20000
			uDef.weapondefs.empmissile.paralyzetime = 5	
			uDef.weapondefs.emp.damage.default = 275
			uDef.weapondefs.emp.reloadtime = .5
			uDef.weapondefs.emp.paralyzetime = 5	
		end

		if name == "corbw" then
			--uDef.weapondefs.bladewing_lyzer.burst = 4
			--uDef.weapondefs.bladewing_lyzer.reloadtime = 0.8
			--uDef.weapondefs.bladewing_lyzer.beamburst = true
			--uDef.weapondefs.bladewing_lyzer.sprayangle = 2100
			--uDef.weapondefs.bladewing_lyzer.beamdecay = 0.5
			--uDef.weapondefs.bladewing_lyzer.beamtime = 0.03
			--uDef.weapondefs.bladewing_lyzer.beamttl = 0.4
			
			uDef.weapondefs.bladewing_lyzer.damage.default = 300
			uDef.weapondefs.bladewing_lyzer.paralyzetime = 5	
		end


		if (name == "corsilo" or name == "armsilo" or name == "armvulc" or name == "corbuzz" or name == "legstarfall") then
			uDef.customparams.paralyzemultiplier = 1.4
		end
		
		--if name == "corsumo" then
			--uDef.customparams.paralyzemultiplier = 0.9
		--end
		
		--if name == "armmar" then
			--uDef.customparams.paralyzemultiplier = 1.3
		--end
		
		if name == "armbanth" then
			uDef.customparams.paralyzemultiplier = 1
		end

		--if name == "armraz" then
			--uDef.customparams.paralyzemultiplier = 1.2
		--end
		--if name == "armvang" then
			--uDef.customparams.paralyzemultiplier = 1.1
		--end
		
		--if name == "armlun" then
			--uDef.customparams.paralyzemultiplier = 1.05
		--end
		
		--if name == "corshiva" then
			--uDef.customparams.paralyzemultiplier = 1.1
		--end
		
		--if name == "corcat" then
			--uDef.customparams.paralyzemultiplier = 1.05
		--end
		
		--if name == "corkarg" then
			--uDef.customparams.paralyzemultiplier = 1.2
		--end
		--if name == "corsok" then
			--uDef.customparams.paralyzemultiplier = 1.1
		--end
		--if name == "cordemont4" then
			--uDef.customparams.paralyzemultiplier = 1.2
		--end

end



	-- Multipliers Modoptions

	-- Health
	if uDef.health then
		local x = Spring.GetModOptions().multiplier_maxdamage
		if x ~= 1 then
			if uDef.health*x > 15000000 then
				uDef.health = 15000000
			else
				uDef.health = uDef.health*x
			end
			if uDef.autoheal then
				uDef.autoheal = uDef.autoheal*x
			end
			if uDef.idleautoheal then
				uDef.idleautoheal = uDef.idleautoheal*x
			end
		end
	end

	-- Max Speed
	if uDef.speed then
		local x = Spring.GetModOptions().multiplier_maxvelocity
		if x ~= 1 then
			uDef.speed = uDef.speed*x
			if uDef.maxdec  then
				uDef.maxdec  = uDef.maxdec *((x-1)/2 + 1)
			end
			if uDef.maxacc then
				uDef.maxacc= uDef.maxacc*((x-1)/2 + 1)
			end
		end
	end

	-- Turn Speed
	if uDef.turnrate then
		local x = Spring.GetModOptions().multiplier_turnrate
		if x ~= 1 then
			uDef.turnrate = uDef.turnrate*x
		end
	end

	-- Build Distance
	if uDef.builddistance then
		local x = Spring.GetModOptions().multiplier_builddistance
		if x ~= 1 then
			uDef.builddistance = uDef.builddistance*x
		end
	end

	-- Buildpower
	if uDef.workertime then
		local x = Spring.GetModOptions().multiplier_buildpower
		if x ~= 1 then
			uDef.workertime = uDef.workertime*x
		end

		-- increase terraformspeed to be able to restore ground faster
		uDef.terraformspeed = uDef.workertime * 30
	end

	-- Unit Cost
	if uDef.metalcost then
		local x = Spring.GetModOptions().multiplier_metalcost
		if x ~= 1 then
			uDef.metalcost = math.min(uDef.metalcost*x, 16000000)
		end
	end
	if uDef.energycost then
		local x = Spring.GetModOptions().multiplier_energycost
		if x ~= 1 then
			uDef.energycost = math.min(uDef.energycost*x, 16000000)
		end
	end
	if uDef.buildtime then
		local x = Spring.GetModOptions().multiplier_buildtimecost
		if x ~= 1 then
			uDef.buildtime = math.min(uDef.buildtime*x, 16000000)
		end
	end



	--energystorage
	--metalstorage
	-- Metal Extraction Multiplier
	if (uDef.extractsmetal and uDef.extractsmetal > 0) and (uDef.customparams.metal_extractor and uDef.customparams.metal_extractor > 0) then
		local x = Spring.GetModOptions().multiplier_metalextraction * Spring.GetModOptions().multiplier_resourceincome
		uDef.extractsmetal = uDef.extractsmetal * x
		uDef.customparams.metal_extractor = uDef.customparams.metal_extractor * x
		if uDef.metalstorage then
			uDef.metalstorage = uDef.metalstorage * x
		end
	end

	-- Energy Production Multiplier
	if uDef.energymake then
		local x = Spring.GetModOptions().multiplier_energyproduction * Spring.GetModOptions().multiplier_resourceincome
		uDef.energymake = uDef.energymake * x
		if uDef.energystorage then
			uDef.energystorage = uDef.energystorage * x
		end
	end
	if uDef.windgenerator and uDef.windgenerator > 0 then
		local x = Spring.GetModOptions().multiplier_energyproduction * Spring.GetModOptions().multiplier_resourceincome
		uDef.windgenerator = uDef.windgenerator * x
		if uDef.customparams.energymultiplier then
			uDef.customparams.energymultiplier = tonumber(uDef.customparams.energymultiplier) * x
		else
			uDef.customparams.energymultiplier = x
		end
		if uDef.energystorage then
			uDef.energystorage = uDef.energystorage * x
		end
	end
	if uDef.tidalgenerator then
		local x = Spring.GetModOptions().multiplier_energyproduction * Spring.GetModOptions().multiplier_resourceincome
		uDef.tidalgenerator = uDef.tidalgenerator * x
		if uDef.energystorage then
			uDef.energystorage = uDef.energystorage * x
		end
	end
	if name == "armsolar" or name == "corsolar" then -- special case
		local x = Spring.GetModOptions().multiplier_energyproduction * Spring.GetModOptions().multiplier_resourceincome
		uDef.energyupkeep = uDef.energyupkeep * x
		if uDef.energystorage then
			uDef.energystorage = uDef.energystorage * x
		end
	end

	-- Energy Conversion Multiplier
	if uDef.customparams.energyconv_capacity and uDef.customparams.energyconv_efficiency then
		local x = Spring.GetModOptions().multiplier_energyconversion * Spring.GetModOptions().multiplier_resourceincome
		--uDef.customparams.energyconv_capacity = uDef.customparams.energyconv_capacity * x
		uDef.customparams.energyconv_efficiency = uDef.customparams.energyconv_efficiency * x
		if uDef.metalstorage then
			uDef.metalstorage = uDef.metalstorage * x
		end
		if uDef.energystorage then
			uDef.energystorage = uDef.energystorage * x
		end
	end

	-- Sensors range
	if uDef.sightdistance then
		local x = Spring.GetModOptions().multiplier_losrange
		if x ~= 1 then
			uDef.sightdistance = uDef.sightdistance*x
		end
	end

	if uDef.airsightdistance then
		local x = Spring.GetModOptions().multiplier_losrange
		if x ~= 1 then
			uDef.airsightdistance = uDef.airsightdistance*x
		end
	end

	if uDef.radardistance then
		local x = Spring.GetModOptions().multiplier_radarrange
		if x ~= 1 then
			uDef.radardistance = uDef.radardistance*x
		end
	end

	if uDef.sonardistance then
		local x = Spring.GetModOptions().multiplier_radarrange
		if x ~= 1 then
			uDef.sonardistance = uDef.sonardistance*x
		end
	end

	-- add model vertex displacement
	local vertexDisplacement = 5.5 + ((uDef.footprintx + uDef.footprintz) / 12)
	if vertexDisplacement > 10 then
		vertexDisplacement = 10
	end
	uDef.customparams.vertdisp = 1.0 * vertexDisplacement
	uDef.customparams.healthlookmod = 0
end

local function ProcessSoundDefaults(wd)
	local forceSetVolume = not wd.soundstartvolume or not wd.soundhitvolume or not wd.soundhitwetvolume
	if not forceSetVolume then
		return
	end

	local defaultDamage = wd.damage and wd.damage.default

	if not defaultDamage or defaultDamage <= 50 then
	-- old filter that gave small weapons a base-minumum sound volume, now fixed with noew math.min(math.max)
	-- if not defaultDamage then
		wd.soundstartvolume = 5
		wd.soundhitvolume = 5
		wd.soundhitwetvolume = 5
		return
	end

	local soundVolume = math.sqrt(defaultDamage * 0.5)

	if wd.weapontype == "LaserCannon" then
		soundVolume = soundVolume*0.5
	end

	if not wd.soundstartvolume then
		wd.soundstartvolume = soundVolume
	end
	if not wd.soundhitvolume then
		wd.soundhitvolume = soundVolume
	end
	if not wd.soundhitwetvolume then
		if wd.weapontype == "LaserCannon" or "BeamLaser" then
			wd.soundhitwetvolume = soundVolume * 0.3
		else
			wd.soundhitwetvolume = soundVolume * 1.4
		end
	end
end

-- process weapondef
function WeaponDef_Post(name, wDef)
	if not SaveDefsToCustomParams then
		-------------- EXPERIMENTAL MODOPTIONS
		-- Standard Gravity
		local gravityModOption = Spring.GetModOptions().experimentalstandardgravity

		--Spring.Echo(wDef.name,wDef.mygravity)
		if gravityModOption == "low" then
			if wDef.mygravity == nil then
				wDef.mygravity = 0.0889 --80/900
			end
		elseif gravityModOption == "standard" then
			if wDef.mygravity == nil then
				wDef.mygravity = 0.1333 --120/900
			end
		elseif gravityModOption == "high" then
			if wDef.mygravity == nil then
				wDef.mygravity = 0.1667 --150/900
			end
		end



		----EMP rework

		if Spring.GetModOptions().emprework==true then

			if name == 'empblast' then
				--wDef.areaofeffect = 350
				wDef.edgeeffectiveness = 0.6
				--wDef.paralyzetime = 12
				wDef.damage.default = 50000
			end
			if name == 'spybombx' then
				wDef.areaofeffect = 340
				wDef.edgeeffectiveness = 0.75
				wDef.paralyzetime = 20
				wDef.damage.default = 40000
			end
			if name == 'spybombxscav' then
				wDef.edgeeffectiveness = 0.50
				wDef.paralyzetime = 12
				wDef.damage.default = 35000
			end


		end


		---- SHIELD CHANGES
		local shieldModOption = Spring.GetModOptions().experimentalshields

		if shieldModOption == "absorbplasma" then
			if wDef.shield and wDef.shield.repulser and wDef.shield.repulser ~= false then
				wDef.shield.repulser = false
			end
		elseif shieldModOption == "absorbeverything" then
			if wDef.shield and wDef.shield.repulser and wDef.shield.repulser ~= false then
				wDef.shield.repulser = false
			end
			if (not wDef.interceptedbyshieldtype) or wDef.interceptedbyshieldtype ~= 1 then
				wDef.interceptedbyshieldtype = 1
			end
		elseif shieldModOption == "bounceeverything" then
			if wDef.shield then
				wDef.shield.repulser = true
			end
			if (not wDef.interceptedbyshieldtype) or wDef.interceptedbyshieldtype ~= 1 then
				wDef.interceptedbyshieldtype = 1
			end
		end

		if Spring.GetModOptions().multiplier_shieldpower then
			if wDef.shield then
				local multiplier = Spring.GetModOptions().multiplier_shieldpower
				if wDef.shield.power then
					wDef.shield.power = wDef.shield.power*multiplier
				end
				if wDef.shield.powerregen then
					wDef.shield.powerregen = wDef.shield.powerregen*multiplier
				end
				if wDef.shield.powerregenenergy then
					wDef.shield.powerregenenergy = wDef.shield.powerregenenergy*multiplier
				end
				if wDef.shield.startingpower then
					wDef.shield.startingpower = wDef.shield.startingpower*multiplier
				end
			end
		end
		----------------------------------------

		--Use targetborderoverride in weapondef customparams to override this global setting
		--Controls whether the weapon aims for the center or the edge of its target's collision volume. Clamped between -1.0 - target the far border, and 1.0 - target the near border.
		if wDef.customparams and wDef.customparams.targetborderoverride == nil then
			wDef.targetborder = 1 --Aim for just inside the hitsphere
		elseif wDef.customparams and wDef.customparams.targetborderoverride ~= nil then
			wDef.targetborder = tonumber(wDef.customparams.targetborderoverride)
		end

		if wDef.craterareaofeffect then
			wDef.cratermult = (wDef.cratermult or 0) + wDef.craterareaofeffect/2000
		end

		-- Target borders of unit hitboxes rather than center (-1 = far border, 0 = center, 1 = near border)
		-- wDef.targetborder = 1.0

		if wDef.weapontype == "Cannon" then
			if not wDef.model then -- do not cast shadows on plasma shells
				wDef.castshadow = false
			end

			if wDef.stages == nil then
				wDef.stages = 10
				if wDef.damage ~= nil and wDef.damage.default ~= nil and wDef.areaofeffect ~= nil then
					wDef.stages = math.floor(7.5 + math.min(wDef.damage.default * 0.0033, wDef.areaofeffect * 0.13))
					wDef.alphadecay = 1 - ((1/wDef.stages)/1.5)
					wDef.sizedecay = 0.4 / wDef.stages
				end
			end
		end

		-- prepared to strip these customparams for when we remove old deferred lighting widgets
		--if wDef.customparams then
		--	wDef.customparams.expl_light_opacity = nil
		--	wDef.customparams.expl_light_heat_radius = nil
		--	wDef.customparams.expl_light_radius = nil
		--	wDef.customparams.expl_light_color = nil
		--	wDef.customparams.expl_light_nuke = nil
		--	wDef.customparams.expl_light_skip = nil
		--	wDef.customparams.expl_light_heat_life_mult = nil
		--	wDef.customparams.expl_light_heat_radius_mult = nil
		--	wDef.customparams.expl_light_heat_strength_mult = nil
		--	wDef.customparams.expl_light_life = nil
		--	wDef.customparams.expl_light_life_mult = nil
		--	wDef.customparams.expl_noheatdistortion = nil
		--	wDef.customparams.light_skip = nil
		--	wDef.customparams.light_fade_time = nil
		--	wDef.customparams.light_fade_offset = nil
		--	wDef.customparams.light_beam_mult = nil
		--	wDef.customparams.light_beam_start = nil
		--	wDef.customparams.light_beam_mult_frames = nil
		--	wDef.customparams.light_camera_height = nil
		--	wDef.customparams.light_ground_height = nil
		--	wDef.customparams.light_color = nil
		--	wDef.customparams.light_radius = nil
		--	wDef.customparams.light_radius_mult = nil
		--	wDef.customparams.light_mult = nil
		--	wDef.customparams.fake_Weapon = nil
		--end

		if wDef.damage ~= nil then
			wDef.damage.indestructable = 0
		end

		if wDef.weapontype == "BeamLaser" then
			if wDef.beamttl == nil then
				wDef.beamttl = 3
				wDef.beamdecay = 0.7
			end
			if wDef.corethickness then
				wDef.corethickness = wDef.corethickness * 1.21
			end
			if wDef.thickness then
				wDef.thickness = wDef.thickness * 1.27
			end
			if wDef.laserflaresize then
				wDef.laserflaresize = wDef.laserflaresize * 1.15		-- note: thickness affects this too
			end
			wDef.texture1 = "largebeam"		-- The projectile texture
			--wDef.texture2 = ""		-- The end-of-beam texture for #LaserCannon, #BeamLaser
			wDef.texture3 = "flare2"	-- Flare texture for #BeamLaser
			wDef.texture4 = "flare2"	-- Flare texture for #BeamLaser with largeBeamLaser = true
		end

		-- scavengers
		if string.find(name, '_scav') then
			VFS.Include("gamedata/scavengers/weapondef_post.lua")
			wDef = scav_Wdef_Post(name, wDef)
		end

		ProcessSoundDefaults(wDef)
	end
	if Spring.GetModOptions().unba == true then
		unbaUnits = VFS.Include("unbaconfigs/unbaunits_post.lua")
		wDef = unbaUnits.unbaWeaponTweaks(name, wDef)
	end

	-- Multipliers

	-- Weapon Range
	if true then -- dumb way to keep the x local here
		local x = Spring.GetModOptions().multiplier_weaponrange
		if x ~= 1 then
			if wDef.range then
				wDef.range = wDef.range*x
			end
			if wDef.flighttime then
				wDef.flighttime = wDef.flighttime*(x*1.5)
			end
			-- if wDef.mygravity and wDef.mygravity ~= 0 then
			-- 	wDef.mygravity = wDef.mygravity*(1/x)
			-- else
			-- 	wDef.mygravity = Game.gravity / (Game.gameSpeed ^ 2) / x
			-- end
			if wDef.weaponvelocity and wDef.weapontype == "Cannon" and wDef.gravityaffected == "true" then
				wDef.weaponvelocity = wDef.weaponvelocity*math.sqrt(x)
			end
			if wDef.weapontype == "StarburstLauncher" and wDef.weapontimer then
				wDef.weapontimer = wDef.weapontimer+(wDef.weapontimer*((x-1)*0.4))
			end
		end
	end

	-- Weapon Damage
	if true then -- dumb way to keep the x local here
		local x = Spring.GetModOptions().multiplier_weapondamage
		if x ~= 1 then
			if wDef.damage then
				for damageClass, damageValue in pairs(wDef.damage) do
					wDef.damage[damageClass] = wDef.damage[damageClass] * x
				end
			end
		end
	end

	-- ExplosionSpeed is calculated same way engine does it, and then doubled
	-- Note that this modifier will only effect weapons fired from actual units, via super clever hax of using the weapon name as prefix
	if wDef.damage and wDef.damage.default then
		if string.find(name,'_', nil, true) then
			local prefix = string.sub(name,1,3)
			if prefix == 'arm' or prefix == 'cor' or prefix == 'leg' or prefix == 'rap' then
				local globaldamage = math.max(30, wDef.damage.default / 20)
				local defExpSpeed = (8 + (globaldamage * 2.5))/ (9 + (math.sqrt(globaldamage) * 0.70)) * 0.5
				wDef.explosionSpeed = defExpSpeed * 2
				--Spring.Echo("Changing explosionSpeed for weapon:", name, wDef.name, wDef.weapontype, wDef.damage.default, wDef.explosionSpeed)
			end
		end
	end
end
-- process effects
function ExplosionDef_Post(name, eDef)
	--[[
    -- WIP on #645
    Spring.Echo(name)
    for k,v in pairs(eDef) do
        Spring.Echo(" ", k, v, type(k), type(v))
        if type(v)=="table" then
            for k1,v1 in pairs(v) do
                Spring.Echo("  ", k1,v1)
            end
        end
    end
    if eDef.usedefaultexplosions=="1" then

    end
    ]]
end

--------------------------
-- MODOPTIONS
-------------------------

-- process modoptions (last, because they should not get baked)
function ModOptions_Post (UnitDefs, WeaponDefs)
	local map_tidal = Spring.GetModOptions().map_tidal

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

	-- transporting enemy coms
	if Spring.GetModOptions().transportenemy == "notcoms" then
		for name,ud in pairs(UnitDefs) do
			if name == "armcom" or name == "corcom" or name == "armdecom" or name == "cordecom" then
				ud.transportbyenemy = false
			end
		end
	elseif Spring.GetModOptions().transportenemy == "none" then
		for name, ud in pairs(UnitDefs) do
			ud.transportbyenemy = false
		end
	end

	-- For Decals GL4, disables default groundscars for explosions
	for id,wDef in pairs(WeaponDefs) do
		wDef.explosionScar = false
	end


	--[[
	-- Make BeamLasers do their damage up front instead of over time
	-- Do this at the end so that we don't mess up any magic math
	for id,wDef in pairs(WeaponDefs) do
		-- Beamlasers do damage up front
		if wDef.beamtime ~= nil then
			beamTimeInFrames = wDef.beamtime * 30
			--Spring.Echo(wDef.name)
			--Spring.Echo(beamTimeInFrames)
			wDef.beamttl = beamTimeInFrames
			--Spring.Echo(wDef.beamttl)
			wDef.beamtime = 0.01
		end
	end
	]]--
end
