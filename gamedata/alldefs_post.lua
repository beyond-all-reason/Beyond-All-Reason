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

--[[ Sanitize to whole frames (plus leeways because float arithmetic is bonkers).
     The engine uses full frames for actual reload times, but forwards the raw
     value to LuaUI (so for example calculated DPS is incorrect without sanitisation). ]]
local function round_to_frames(wd, key)
	local original_value = wd[key]
	if not original_value then
		-- even reloadtime can be nil (shields, death explosions)
		return
	end

	local frames = math.max(1, math.floor((original_value + 1E-3) * Game.gameSpeed))
	local sanitized_value = frames / Game.gameSpeed

	return sanitized_value
end

local function processWeapons(unitDefName, unitDef)
	local weaponDefs = unitDef.weapondefs
	if not weaponDefs then
		return
	end

	for weaponDefName, weaponDef in pairs(weaponDefs) do
		weaponDef.reloadtime = round_to_frames(weaponDef, "reloadtime")
		weaponDef.burstrate = round_to_frames(weaponDef, "burstrate")

		if weaponDef.customparams and weaponDef.customparams.cluster_def then
			weaponDef.customparams.cluster_def = unitDefName .. "_" .. weaponDef.customparams.cluster_def
			weaponDef.customparams.cluster_number = weaponDef.customparams.cluster_number or 5
		end
	end
end

function UnitDef_Post(name, uDef)
	local modOptions = Spring.GetModOptions()

	local isScav = string.sub(name, -5, -1) == "_scav"
	local basename = isScav and string.sub(name, 1, -6) or name

	if not uDef.icontype then
		uDef.icontype = name
	end

	--global physics behavior changes
	if uDef.health then
		uDef.minCollisionSpeed = 75 / Game.gameSpeed -- define the minimum velocity(speed) required for all units to suffer fall/collision damage.
	end

	-- inidivual unit hat processing
	do
		if modOptions.unithats then
			if modOptions.unithats == "april" then
				if name == "corak" then
					uDef.objectname = "apf/CORAK.s3o"
				elseif name == "corllt" then
					uDef.objectname = "apf/CORllt.s3o"
				elseif name == "corhllt" then
					uDef.objectname = "apf/CORhllt.s3o"
				elseif name == "corack" then
					uDef.objectname = "apf/CORACK.s3o"
				elseif name == "corck" then
					uDef.objectname = "apf/CORCK.s3o"
				elseif name == "armpw" then
					uDef.objectname = "apf/ARMPW.s3o"
				elseif name == "cordemon" then
					uDef.objectname = "apf/cordemon.s3o"
				elseif name == "correap" then
					uDef.objectname = "apf/correap.s3o"
				elseif name == "corstorm" then
					uDef.objectname = "apf/corstorm.s3o"
				elseif name == "armcv" then
					uDef.objectname = "apf/armcv.s3o"
				elseif name == "armrock" then
					uDef.objectname = "apf/armrock.s3o"
				elseif name == "armbull" then
					uDef.objectname = "apf/armbull.s3o"
				elseif name == "armllt" then
					uDef.objectname = "apf/armllt.s3o"
				elseif name == "armwin" then
					uDef.objectname = "apf/armwin.s3o"
				elseif name == "armham" then
					uDef.objectname = "apf/armham.s3o"
				elseif name == "corwin" then
					uDef.objectname = "apf/corwin.s3o"
				elseif name == "corthud" then
					uDef.objectname = "apf/corthud.s3o"
				end
			end
		end
	end

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
		if not uDef.customparams.techlevel then
			uDef.customparams.techlevel = 1
		end
		if not uDef.customparams.subfolder then
			uDef.customparams.subfolder = "none"
		end
		if modOptions.unit_restrictions_notech2 then
			if tonumber(uDef.customparams.techlevel) == 2 or tonumber(uDef.customparams.techlevel) == 3 then
				uDef.maxthisunit = 0
			end
		end

		if modOptions.unit_restrictions_notech3 then
			if tonumber(uDef.customparams.techlevel) == 3 then
				uDef.maxthisunit = 0
			end
		end

		if modOptions.unit_restrictions_notech15 then
			-- Tech 1.5 is a semi offical thing, modoption ported from teiserver meme commands
			local tech15 = {
				corhp		= true,
				corfhp		= true,
				corplat		= true,
				coramsub	= true,

				armhp		= true,
				armfhp		= true,
				armplat		= true,
				armamsub	= true,

				leghp		= true,
				legfhp		= true,
				legplat		= true,
				legamsub	= true,
			}
			if tech15[basename] then
				uDef.maxthisunit = 0
			end
		end

		if modOptions.unit_restrictions_noair then
			if string.find(uDef.customparams.subfolder, "Aircraft") then
				uDef.maxthisunit = 0
			elseif uDef.customparams.unitgroup and uDef.customparams.unitgroup == "aa" then
				uDef.maxthisunit = 0
			elseif uDef.canfly then
				uDef.maxthisunit = 0
			elseif uDef.customparams.disable_when_no_air then --used to remove drone carriers with no other purpose (ex. leghive but not rampart)
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
				legapt3 = true,
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
				legapt3_scav = true,
				armapt3_scav = true,
				legap_scav = true,
				legaap_scav = true,

			}
			if AircraftFactories[name] then
				uDef.maxthisunit = 0
			end
		end

		if modOptions.unit_restrictions_noextractors then
			if (uDef.extractsmetal and uDef.extractsmetal > 0) and (uDef.customparams.metal_extractor and uDef.customparams.metal_extractor > 0) then
				uDef.maxthisunit = 0
			end
		end

		if modOptions.unit_restrictions_noconverters then
			if uDef.customparams.energyconv_capacity and uDef.customparams.energyconv_efficiency then
				uDef.maxthisunit = 0
			end
		end

		if modOptions.unit_restrictions_nofusion then
			if basename == "armdf" or string.sub(basename, -3) == "fus" then
				uDef.maxthisunit = 0
			end
		end

		if modOptions.unit_restrictions_nonukes then
			if uDef.weapondefs then
				for _, weapon in pairs(uDef.weapondefs) do
					if (weapon.interceptor and weapon.interceptor == 1) or (weapon.targetable and weapon.targetable == 1) then
						uDef.maxthisunit = 0
						break
					end
				end
			end
		end

		if modOptions.unit_restrictions_nodefence then
			local whitelist = {
				armllt	= true,
				armrl	= true,
				armfrt	= true,
				armtl	= true,

				corllt	= true,
				corrl	= true,
				cortl	= true,
				corfrt	= true,
				legfrl	= true,

				leglht	= true,
				legrl	= true,
				--sea tl= true,
				--sea aa= true,
			}
			-- "defense" or "defence", as legion doesn't fully follow past conventions
			if not whitelist[name] and string.find(string.lower(uDef.customparams.subfolder), "defen") then
				uDef.maxthisunit = 0
			end
		end

		if modOptions.unit_restrictions_noantinuke then
			if uDef.weapondefs then
				local numWeapons = 0
				local newWdefs = {}
				local hasAnti = false
				for i, weapon in pairs(uDef.weapondefs) do
					if weapon.interceptor and weapon.interceptor == 1 then
						uDef.weapondefs[i] = nil
						hasAnti = true
					else
						numWeapons = numWeapons + 1
						newWdefs[numWeapons] = weapon
					end
				end
				if hasAnti then
					uDef.weapondefs = newWdefs
					if numWeapons == 0 and (not uDef.radardistance or uDef.radardistance < 1500) then
						uDef.maxthisunit = 0
					else
						if uDef.metalcost then
							uDef.metalcost = math.floor(uDef.metalcost * 0.6)	-- give a discount for removing anti-nuke
							uDef.energycost = math.floor(uDef.energycost * 0.6)
						end
					end
				end
			end
		end

		--normal commander respawning
		if modOptions.comrespawn == "all" or (modOptions.comrespawn == "evocom" and modOptions.evocom)then
			if name == "armcom" or name == "corcom" or name == "legcom" then
				uDef.customparams.effigy = "comeffigylvl1"
				uDef.customparams.effigy_offset = 1
				uDef.customparams.respawn_condition = "health"
				uDef.customparams.minimum_respawn_stun = 5
				uDef.customparams.distance_stun_multiplier = 1
				local numBuildoptions = #uDef.buildoptions
				uDef.buildoptions[numBuildoptions + 1] = "comeffigylvl1"
			end
		end


		if modOptions.evocom then
			if uDef.customparams.evocomlvl or name == "armcom" or name == "corcom" or name == "legcom" then
				local comLevel = uDef.customparams.evocomlvl
				if modOptions.comrespawn == "all" or modOptions.comrespawn == "evocom" then--add effigy respawning, if enabled
					uDef.customparams.respawn_condition = "health"

					local numBuildoptions = #uDef.buildoptions
					if comLevel == 2 then
						uDef.buildoptions[numBuildoptions + 1] = "comeffigylvl1"
					elseif comLevel == 3 or comLevel == 4 then
						uDef.buildoptions[numBuildoptions + 1] = "comeffigylvl2"
					elseif comLevel == 5 or comLevel == 6 then
						uDef.buildoptions[numBuildoptions + 1] = "comeffigylvl3"
					elseif comLevel == 7 or comLevel == 8 then
						uDef.buildoptions[numBuildoptions + 1] = "comeffigylvl4"
					elseif comLevel == 9 or comLevel == 10 then
						uDef.buildoptions[numBuildoptions + 1] = "comeffigylvl5"
					end
				end
				uDef.customparams.combatradius = 0
				uDef.customparams.evolution_health_transfer = "percentage"

				if uDef.power then
					uDef.power = uDef.power/modOptions.evocomxpmultiplier
				else
					uDef.power = ((uDef.metalcost+(uDef.energycost/60))/modOptions.evocomxpmultiplier)
				end

				if  name == "armcom" then
					uDef.customparams.evolution_target = "armcomlvl2"
					uDef.customparams.inheritxpratemultiplier = 0.5
					uDef.customparams.childreninheritxp = "TURRET MOBILEBUILT"
					uDef.customparams.parentsinheritxp = "TURRET MOBILEBUILT"
					uDef.customparams.evocomlvl = 1
					elseif name == "corcom" then
					uDef.customparams.evolution_target = "corcomlvl2"
					uDef.customparams.evocomlvl = 1
					elseif name == "legcom" then
					uDef.customparams.evolution_target = "legcomlvl2"
					uDef.customparams.evocomlvl = 1
					end

				if modOptions.evocomlevelupmethod == "dynamic" then
					uDef.customparams.evolution_condition = "power"
					uDef.customparams.evolution_power_multiplier = 1			-- Scales the power calculated based on your own combined power.
					local evolutionPowerThreshold = uDef.customparams.evolution_power_threshold or 10000 --sets threshold for level 1 commanders
					uDef.customparams.evolution_power_threshold = evolutionPowerThreshold*modOptions.evocomlevelupmultiplier
				elseif modOptions.evocomlevelupmethod == "timed" then
					uDef.customparams.evolution_timer = modOptions.evocomleveluptime*60*uDef.customparams.evocomlvl
					uDef.customparams.evolution_condition = "timer_global"
				end

				if comLevel and modOptions.evocomlevelcap <= comLevel then
					uDef.customparams.evolution_health_transfer = nil
					uDef.customparams.evolution_target = nil
					uDef.customparams.evolution_condition = nil
					uDef.customparams.evolution_timer = nil
					uDef.customparams.evolution_power_threshold = nil
					uDef.customparams.evolution_power_multiplier = nil
				end
			end
		end

		if uDef.customparams.evolution_target then
			local udcp                            = uDef.customparams
			udcp.combatradius                     = udcp.combatradius or 1000
			udcp.evolution_announcement_size      = tonumber(udcp.evolution_announcement_size)
			udcp.evolution_condition              = udcp.evolution_condition or "timer"
			udcp.evolution_health_threshold       = tonumber(udcp.evolution_health_threshold) or 0
			udcp.evolution_health_transfer        = udcp.evolution_health_transfer or "flat"
			udcp.evolution_power_enemy_multiplier = tonumber(udcp.evolution_power_enemy_multiplier) or 1
			udcp.evolution_power_multiplier       = tonumber(udcp.evolution_power_multiplier) or 1
			udcp.evolution_power_threshold        = tonumber(udcp.evolution_power_threshold) or 600
			udcp.evolution_timer                  = tonumber(udcp.evolution_timer) or 20
		end

		if modOptions.unit_restrictions_notacnukes then
			local TacNukes = {
				armemp = true,
				cortron = true,
				legperdition = true,
				armemp_scav = true,
				cortron_scav = true,
			}
			if TacNukes[name] then
				uDef.maxthisunit = 0
			end
		end

		if modOptions.unit_restrictions_nolrpc then
			local LRPCs = {
				armbotrail = true,
				armbrtha = true,
				armvulc = true,
				corint = true,
				corbuzz = true,
				leglrpc = true,
				legelrpcmech = true,
				legstarfall = true,
				armbotrail_scav = true,
				armbrtha_scav = true,
				armvulc_scav = true,
				corint_scav = true,
				corbuzz_scav = true,
				legstarfall_scav = true,
				leglrpc_scav = true,
				legelrpcmech_scav = true,
			}
			if LRPCs[name] then
				uDef.maxthisunit = 0
			end
		end

		if modOptions.unit_restrictions_noendgamelrpc then
			local LRPCs = {
				armvulc = true,
				corbuzz = true,
				legstarfall = true,
				armvulc_scav = true,
				corbuzz_scav = true,
				legstarfall_scav = true,
			}
			if LRPCs[name] then
				uDef.maxthisunit = 0
			end
		end
	end

	-- Extra Units ----------------------------------------------------------------------------------------------------------------------------------
	if modOptions.experimentalextraunits then
		-- Armada T1 Land Constructors
		if name == "armca" or name == "armck" or name == "armcv" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Armada T1 Sea Constructors
		if name == "armcs" or name == "armcsa" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armgplat" -- Gun Platform - Light Plasma Defense
			uDef.buildoptions[numBuildoptions + 2] = "armfrock" -- Scumbag - Anti Air Missile Battery
		end

		-- Armada T1 Vehicle Factory
		if name == "armvp" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armzapper" -- Zapper - Light EMP Vehicle
		end

		-- Armada T1 Aircraft Plant
		if name == "armap" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armfify" -- Firefly - Resurrection Aircraft
		end

		-- Armada T2 Land Constructors
		if name == "armaca" or name == "armack" or name == "armacv" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armshockwave" -- Shockwave - T2 EMP Armed Metal Extractor
			uDef.buildoptions[numBuildoptions + 2] = "armwint2" -- T2 Wind Generator
			uDef.buildoptions[numBuildoptions + 3] = "armnanotct2" -- T2 Constructor Turret
			uDef.buildoptions[numBuildoptions + 4] = "armlwall" -- Dragon's Fury - T2 Pop-up Wall Turret
			uDef.buildoptions[numBuildoptions + 5] = "armgatet3" -- Asylum - Advanced Shield Generator
		end

		-- Armada T2 Sea Constructors
		if name == "armacsub" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armfgate" -- Aurora - Floating Plasma Deflector
			uDef.buildoptions[numBuildoptions + 2] = "armnanotc2plat" -- Floating T2 Constructor Turret
		end

		-- Armada T2 Shipyard
		if name == "armasy" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armexcalibur" -- Excalibur - Coastal Assault Submarine
			uDef.buildoptions[numBuildoptions + 2] = "armseadragon" -- Seadragon - Nuclear ICBM Submarine
		end

		-- Armada T3 Gantry
		if name == "armshltx" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armmeatball" -- Meatball - Amphibious Assault Mech
			uDef.buildoptions[numBuildoptions + 2] = "armassimilator" -- Assimilator - Amphibious Battle Mech
		end

		-- Armada T3 Underwater Gantry
		if name == "armshltxuw" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armmeatball" -- Meatball - Amphibious Assault Mech
			uDef.buildoptions[numBuildoptions + 2] = "armassimilator" -- Assimilator - Amphibious Battle Mech
		end

		-- Cortex T1 Land Constructors
		if name == "corca" or name == "corck" or name == "corcv" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Cortex T1 Sea Constructors
		if name == "corcs" or name == "corcsa" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corgplat" -- Gun Platform - Light Plasma Defense
			uDef.buildoptions[numBuildoptions + 2] = "corfrock" -- Janitor - Anti Air Missile Battery
		end

		-- Cortex T1 Bots Factory
		if name == "corlab" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Cortex T2 Land Constructors
		if name == "coraca" or name == "corack" or name == "coracv" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corwint2" -- T2 Wind Generator
			uDef.buildoptions[numBuildoptions + 2] = "cornanotct2" -- T2 Constructor Turret
			uDef.buildoptions[numBuildoptions + 3] = "cormwall" -- Dragon's Rage - T2 Pop-up Wall Turret
			uDef.buildoptions[numBuildoptions + 4] = "corgatet3" -- Sanctuary - Advanced Shield Generator
		end

		-- Cortex T2 Sea Constructors
		if name == "coracsub" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corfgate" -- Atoll - Floating Plasma Deflector
			uDef.buildoptions[numBuildoptions + 2] = "cornanotc2plat" -- Floating T2 Constructor Turret
		end

		-- Cortex T2 Bots Factory
		if name == "coralab" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "cordeadeye"
		end

		-- Cortex T2 Vehicle Factory
		if name == "coravp" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corvac" -- Printer - Armored Field Engineer
			uDef.buildoptions[numBuildoptions + 2] = "corphantom" -- Phantom - Amphibious Stealth Scout
			uDef.buildoptions[numBuildoptions + 3] = "corsiegebreaker" -- Siegebreaker - Heavy Long Range Destroyer
			uDef.buildoptions[numBuildoptions + 4] = "corforge" -- Forge - Flamethrower Combat Engineer
			uDef.buildoptions[numBuildoptions + 5] = "cortorch" -- Torch - Fast Flamethrower Tank
		end

		-- Cortex T2 Aircraft Plant
		if name == "coraap" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Cortex T2 Shipyard
		if name == "corasy" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "coresuppt3" -- Adjudictator - Heavy Heatray Battleship
			uDef.buildoptions[numBuildoptions + 2] = "coronager" -- Onager - Coastal Assault Submarine
			uDef.buildoptions[numBuildoptions + 3] = "cordesolator" -- Desolator - Nuclear ICBM Submarine
		end

		-- Cortex T3 Gantry
		if name == "corgant" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Cortex T3 Underwater Gantry
		if name == "corgantuw" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Legion T1 Land Constructors
		if name == "legca" or name == "legck" or name == "legcv" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Legion T2 Land Constructors
		if name == "legaca" or name == "legack" or name == "legacv" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "legmohocon" -- Advanced Metal Fortifier - Metal Extractor with Constructor Turret
			uDef.buildoptions[numBuildoptions + 2] = "legwint2" -- T2 Wind Generator
			uDef.buildoptions[numBuildoptions + 3] = "legnanotct2" -- T2 Constructor Turret
			uDef.buildoptions[numBuildoptions + 4] = "legrwall" -- Dragon's Constitution - T2 (not Pop-up) Wall Turret
			uDef.buildoptions[numBuildoptions + 5] = "leggatet3" -- Elysium - Advanced Shield Generator
		end

		-- Legion T3 Gantry
		if name == "leggant" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "legbunk" -- Pilum - Fast Assault Mech
		end
	end

	-- Scavengers Units ------------------------------------------------------------------------------------------------------------------------
	if modOptions.scavunitsforplayers then
		-- Armada T1 Land Constructors
		if name == "armca" or name == "armck" or name == "armcv" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Armada T1 Sea Constructors
		if name == "armcs" or name == "armcsa" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Armada T1 Vehicle Factory
		if name == "armvp" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Armada T1 Aircraft Plant
		if name == "armap" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Armada T2 Constructors
		if name == "armaca" or name == "armack" or name == "armacv" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armapt3" -- T3 Aircraft Gantry
			uDef.buildoptions[numBuildoptions + 2] = "armminivulc" -- Mini Ragnarok
			uDef.buildoptions[numBuildoptions + 3] = "armbotrail" -- Pawn Launcher
			uDef.buildoptions[numBuildoptions + 4] = "armannit3" -- Epic Pulsar
			uDef.buildoptions[numBuildoptions + 5] = "armafust3" -- Epic Fusion Reactor
			uDef.buildoptions[numBuildoptions + 6] = "armmmkrt3" -- Epic Energy Converter
		end

		-- Armada T2 Shipyard
		if name == "armasy" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armdronecarry" -- Nexus - Drone Carrier
			uDef.buildoptions[numBuildoptions + 2] = "armptt2" -- Epic Skater
			uDef.buildoptions[numBuildoptions + 3] = "armdecadet3" -- Epic Dolphin
			uDef.buildoptions[numBuildoptions + 4] = "armpshipt3" -- Epic Ellysaw
			uDef.buildoptions[numBuildoptions + 5] = "armserpt3" -- Epic Serpent
			uDef.buildoptions[numBuildoptions + 6] = "armtrident" -- Trident - Depth Charge Drone Carrier
		end

		-- Armada T3 Gantry
		if name == "armshltx" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armrattet4" -- Ratte - Very Heavy Tank
			uDef.buildoptions[numBuildoptions + 2] = "armsptkt4" -- Epic Recluse
			uDef.buildoptions[numBuildoptions + 3] = "armpwt4" -- Epic Pawn
			uDef.buildoptions[numBuildoptions + 4] = "armvadert4" -- Epic Tumbleweed - Nuclear Rolling Bomb
			uDef.buildoptions[numBuildoptions + 5] = "armdronecarryland" -- Nexus Terra - Drone Carrier
		end

		-- Armada T3 Underwater Gantry
		if name == "armshltxuw" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armrattet4" -- Ratte - Very Heavy Tank
			uDef.buildoptions[numBuildoptions + 2] = "armsptkt4" -- Epic Recluse
			uDef.buildoptions[numBuildoptions + 3] = "armpwt4" -- Epic Pawn
			uDef.buildoptions[numBuildoptions + 4] = "armvadert4" -- Epic Tumbleweed - Nuclear Rolling Bomb
		end

		-- Cortex T1 Bots Factory
		if name == "corlab" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corkark" -- Archaic Karkinos
		end

		-- Cortex T2 Land Constructors
		if name == "coraca" or name == "corack" or name == "coracv" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corapt3" -- T3 Aircraft Gantry
			uDef.buildoptions[numBuildoptions + 2] = "corminibuzz" -- Mini Calamity
			uDef.buildoptions[numBuildoptions + 3] = "corhllllt" -- Quad Guard - Quad Light Laser Turret
			uDef.buildoptions[numBuildoptions + 4] = "cordoomt3" -- Epic Bulwark
			uDef.buildoptions[numBuildoptions + 5] = "corafust3" -- Epic Fusion Reactor
			uDef.buildoptions[numBuildoptions + 6] = "cormmkrt3" -- Epic Energy Converter
		end

		-- Cortex T2 Sea Constructors
		if name == "coracsub" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Cortex T2 Bots Factory
		if name == "coralab" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Cortex T2 Vehicle Factory
		if name == "coravp" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corgatreap" -- Laser Tiger
			uDef.buildoptions[numBuildoptions+2] = "corftiger" -- Heat Tiger
		end

		-- Cortex T2 Aircraft Plant
		if name == "coraap" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corcrw" -- Archaic Dragon
		end

		-- Cortex T2 Shipyard
		if name == "corasy" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "cordronecarry" -- Dispenser - Drone Carrier
			uDef.buildoptions[numBuildoptions + 2] = "corslrpc" -- Leviathan - LRPC Ship
			uDef.buildoptions[numBuildoptions + 3] = "corsentinel" -- Sentinel - Depth Charge Drone Carrier
		end

		-- Cortex T3 Gantry
		if name == "corgant" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corkarganetht4" -- Epic Karganeth
			uDef.buildoptions[numBuildoptions + 2] = "corgolt4" -- Epic Tzar
			uDef.buildoptions[numBuildoptions + 3] = "corakt4" -- Epic Grunt
			uDef.buildoptions[numBuildoptions + 4] = "corthermite" -- Thermite/Epic Termite
			uDef.buildoptions[numBuildoptions + 5] = "cormandot4" -- Epic Commando
		end

		-- Cortex T3 Underwater Gantry
		if name == "corgantuw" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corkarganetht4" -- Epic Karganeth
			uDef.buildoptions[numBuildoptions + 2] = "corgolt4" -- Epic Tzar
			uDef.buildoptions[numBuildoptions + 3] = "corakt4" -- Epic Grunt
			uDef.buildoptions[numBuildoptions + 4] = "cormandot4" -- Epic Commando
		end

		-- Legion T1 Land Constructors
		if name == "legca" or name == "legck" or name == "legcv" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Legion T2 Land Constructors
		if name == "legaca" or name == "legack" or name == "legacv" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "legapt3" -- T3 Aircraft Gantry
			uDef.buildoptions[numBuildoptions + 2] = "legministarfall" -- Mini Starfall
			uDef.buildoptions[numBuildoptions + 3] = "legafust3" -- Epic Fusion Reactor
			uDef.buildoptions[numBuildoptions + 4] = "legadveconvt3" -- Epic Energy Converter
		end

		-- Legion T3 Gantry
		if name == "leggant" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "legsrailt4" -- Epic Arquebus
			uDef.buildoptions[numBuildoptions + 2] = "leggobt3" -- Epic Goblin
			uDef.buildoptions[numBuildoptions + 3] = "legpede" -- Mukade - Heavy Multi Weapon Centipede
		end
	end

	-- Release candidate units --------------------------------------------------------------------------------------------------------------------------------------------------------
	if modOptions.releasecandidates or modOptions.experimentalextraunits then

	end

	if string.find(name, "raptor") and uDef.health then
		local raptorHealth = uDef.health
		uDef.activatewhenbuilt = true
		uDef.metalcost = raptorHealth * 0.5
		uDef.energycost = math.min(raptorHealth * 5, 16000000)
		uDef.buildtime = math.min(raptorHealth * 10, 16000000)
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
			uDef.sonardistance = uDef.sightdistance * 2
			uDef.radardistance = uDef.sightdistance * 2
			uDef.airsightdistance = uDef.sightdistance * 2
		end

		if (not uDef.canfly) and uDef.speed then
			uDef.rspeed = uDef.speed * 0.65
			uDef.turnrate = uDef.speed * 10
			uDef.maxacc = uDef.speed * 0.00166
			uDef.maxdec = uDef.speed * 0.00166
		elseif uDef.canfly then
			if modOptions.air_rework == true then
				uDef.speed = uDef.speed * 0.65
				uDef.health = uDef.health * 1.5

				uDef.maxacc = 1
				uDef.maxdec = 1
				uDef.usesmoothmesh = true

				-- flightmodel
				uDef.maxaileron = 0.025
				uDef.maxbank = 0.65
				uDef.maxelevator = 0.025
				uDef.maxpitch = 0.75
				uDef.maxrudder = 0.18
				uDef.wingangle = 0.06593
				uDef.wingdrag = 0.02
				uDef.turnradius = 64
				uDef.turnrate = 50
				uDef.speedtofront = 0.06
				uDef.cruisealtitude = 220
				--uDef.attackrunlength = 32
			else
				uDef.maxacc = 1
				uDef.maxdec = 0.25
				uDef.usesmoothmesh = true

				-- flightmodel
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
	end

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
			local xtab = {}
			for i in string.gmatch(x, "%S+") do
				xtab[#xtab + 1] = i
			end
			uDef.sightemitheight = uDef.sightemitheight + tonumber(xtab[2])
			uDef.radaremitheight = uDef.radaremitheight + tonumber(xtab[2])
		end
		if uDef.collisionvolumeoffsets then
			local x = uDef.collisionvolumeoffsets
			local xtab = {}
			for i in string.gmatch(x, "%S+") do
				xtab[#xtab + 1] = i
			end
			uDef.sightemitheight = uDef.sightemitheight + tonumber(xtab[2])
			uDef.radaremitheight = uDef.radaremitheight + tonumber(xtab[2])
		end
		if uDef.sightemitheight < 40 then
			uDef.sightemitheight = 40
			uDef.radaremitheight = 40
		end
	end

	-- Wreck and heap standardization
	if not uDef.customparams.iscommander and not uDef.customparams.iseffigy then
		if uDef.featuredefs and uDef.health then
			-- wrecks
			if uDef.featuredefs.dead then
				uDef.featuredefs.dead.damage = uDef.health
				if uDef.metalcost and uDef.energycost then
					uDef.featuredefs.dead.metal = math.floor(uDef.metalcost * 0.6)
				end
			end
			-- heaps
			if uDef.featuredefs.heap then
				uDef.featuredefs.heap.damage = uDef.health
				if uDef.metalcost and uDef.energycost then
					uDef.featuredefs.heap.metal = math.floor(uDef.metalcost * 0.25)
				end
			end
		end
	end

	if uDef.maxslope then
		uDef.maxslope = math.floor((uDef.maxslope * 1.5) + 0.5)
	end

	----------------------------------------------------------------------
	-- CATEGORY ASSIGNER
	----------------------------------------------------------------------

	-- uDef.movementclass lists
	local hoverList = {
		HOVER2 = true,
		HOVER3 = true,
		HHOVER4 = true,
		HOVER5 = true
	}

	local shipList = {
		BOAT3 = true,
		BOAT4 = true,
		BOAT5 = true,
		BOAT8 = true,
		EPICSHIP = true
	}

	local subList = {
		UBOAT4 = true,
		EPICSUBMARINE = true
	}

	local amphibList = {
		VBOT6 = true,
		COMMANDERBOT = true,
		SCAVCOMMANDERBOT = true,
		ATANK3 = true,
		ABOT2 = true,
		HABOT5 = true,
		ABOTBOMB2 = true,
		EPICBOT = true,
		EPICALLTERRAIN = true
	}

	local commanderList = {
		COMMANDERBOT = true,
		SCAVCOMMANDERBOT = true
	}

	local categories = {}

	-- Manual categories: OBJECT T4AIR LIGHTAIRSCOUT GROUNDSCOUT RAPTOR
	-- Deprecated caregories: BOT TANK PHIB NOTLAND SPACE

	categories["ALL"] = function() return true end
	categories["MOBILE"] = function(uDef) return uDef.speed and uDef.speed > 0 end
	categories["NOTMOBILE"] = function(uDef) return not categories.MOBILE(uDef) end
	categories["WEAPON"] = function(uDef) return uDef.weapondefs ~= nil end
	categories["NOWEAPON"] = function(uDef) return not categories.WEAPON(uDef) end
	categories["VTOL"] = function(uDef) return uDef.canfly == true end
	categories["NOTAIR"] = function(uDef) return not categories.VTOL(uDef) end
	categories["HOVER"] = function(uDef) return hoverList[uDef.movementclass] and (uDef.maxwaterdepth == nil or uDef.maxwaterdepth < 1) end -- convertible tank/boats have maxwaterdepth
	categories["NOTHOVER"] = function(uDef) return not categories.HOVER(uDef) end
	categories["SHIP"] = function(uDef) return shipList[uDef.movementclass] or (hoverList[uDef.movementclass] and uDef.maxwaterdepth and uDef.maxwaterdepth >=1) end
	categories["NOTSHIP"] = function(uDef) return not categories.SHIP(uDef) end
	categories["NOTSUB"] = function(uDef) return not subList[uDef.movementclass] end
	categories["CANBEUW"] = function(uDef) return amphibList[uDef.movementclass] or uDef.cansubmerge == true end
	categories["UNDERWATER"] = function(uDef) return (uDef.minwaterdepth and uDef.waterline == nil) or (uDef.minwaterdepth and uDef.waterline > uDef.minwaterdepth and uDef.speed and uDef.speed > 0) end
	categories["SURFACE"] = function(uDef) return not (categories.UNDERWATER(uDef) and categories.MOBILE(uDef)) and not categories.VTOL(uDef) end
	categories["MINE"] = function(uDef) return uDef.weapondefs and uDef.weapondefs.minerange end
	categories["COMMANDER"] = function(uDef) return commanderList[uDef.movementclass] end
	categories["EMPABLE"] = function(uDef) return categories.SURFACE(uDef) and uDef.customparams and uDef.customparams.paralyzemultiplier ~= 0 end

	uDef.category = uDef.category or ""
	if not string.find(uDef.category, "OBJECT") then -- objects should not be targetable and therefore are not assigned any other category
		for categoryName, condition in pairs(categories) do
			if uDef.exemptcategory == nil or not string.find(uDef.exemptcategory, categoryName) then
				if condition(uDef) then
						uDef.category = uDef.category.." " .. categoryName
				end
			end
		end
	end

	if uDef.canfly then
		uDef.crashdrag = 0.01    -- default 0.005
		if not (string.find(name, "fepoch") or string.find(name, "fblackhy") or string.find(name, "corcrw") or string.find(name, "legfort")) then
			--(string.find(name, "liche") or string.find(name, "crw") or string.find(name, "fepoch") or string.find(name, "fblackhy")) then
			uDef.collide = false
		end
	end

	if uDef.metalcost and uDef.health and uDef.canmove == true and uDef.mass == nil then
		local healthmass = math.ceil(uDef.health/6)
		uDef.mass = math.max(uDef.metalcost, healthmass)
		if uDef.metalcost < 751 and uDef.mass > 750 then
			uDef.mass = 750
		end
		--if uDef.metalcost < healthmass then
		--	Spring.Echo(name, uDef.mass, uDef.metalcost, uDef.mass - uDef.metalcost)
		--end
	end

	--Juno Rework
	if modOptions.junorework == true then
		if name == "armjuno" then
			uDef.metalcost = 500
			uDef.energycost = 12000
			uDef.buildtime = 15000
			uDef.weapondefs.juno_pulse.energypershot = 7000
			uDef.weapondefs.juno_pulse.metalpershot = 100
		end
		if name == "corjuno" then
			uDef.metalcost = 500
			uDef.energycost = 12000
			uDef.buildtime = 15000
			uDef.weapondefs.juno_pulse.energypershot = 7000
			uDef.weapondefs.juno_pulse.metalpershot = 100
		end
	end

	-- Shield Rework
	if modOptions.shieldsrework == true and uDef.weapondefs then
		local shieldPowerMultiplier = 1.9-- To compensate for always taking full damage from projectiles in contrast to bounce-style only taking partial

		for _, weapon in pairs(uDef.weapondefs) do
			if weapon.shield and weapon.shield.repulser then
				uDef.onoffable = true
			end
		end
		if uDef.customparams.shield_power then
			uDef.customparams.shield_power = uDef.customparams.shield_power * shieldPowerMultiplier
		end
	end

	--- EMP rework
	if modOptions.emprework == true then
		if name == "armstil" then
			uDef.weapondefs.stiletto_bomb.areaofeffect = 250
			uDef.weapondefs.stiletto_bomb.burst = 3
			uDef.weapondefs.stiletto_bomb.burstrate = 0.3333
			uDef.weapondefs.stiletto_bomb.edgeeffectiveness = 0.30
			uDef.weapondefs.stiletto_bomb.damage.default = 3000
			uDef.weapondefs.stiletto_bomb.paralyzetime = 1
		end

		if name == "armspid" then
			uDef.weapondefs.spider.paralyzetime = 2
			uDef.weapondefs.spider.damage.vtol = 100
			uDef.weapondefs.spider.damage.default = 600
			uDef.weapondefs.spider.reloadtime = 1.495
		end

		if name == "armdfly" then
			uDef.weapondefs.armdfly_paralyzer.paralyzetime = 1
			uDef.weapondefs.armdfly_paralyzer.beamdecay = 0.05--testing
			uDef.weapondefs.armdfly_paralyzer.beamtime = 0.1--testing
			uDef.weapondefs.armdfly_paralyzer.areaofeffect = 8--testing
			uDef.weapondefs.armdfly_paralyzer.targetmoveerror = 0.05--testing




			--mono beam settings
			--uDef.weapondefs.armdfly_paralyzer.reloadtime = 0.05--testing
			--uDef.weapondefs.armdfly_paralyzer.damage.default = 150--testing (~2800/s for parity with live)
			--uDef.weapondefs.armdfly_paralyzer.beamdecay = 0.95
			--uDef.weapondefs.armdfly_paralyzer.duration = 200--should be unused?
			--uDef.weapondefs.armdfly_paralyzer.beamttl = 2--frames visible.just leads to laggy ghosting if raised too high.

			--burst testing within monobeam
			--uDef.weapondefs.armdfly_paralyzer.damage.default = 125
			--uDef.weapondefs.armdfly_paralyzer.reloadtime = 1--testing
			--uDef.weapondefs.armdfly_paralyzer.beamttl = 3--frames visible.just leads to laggy ghosting if raised too high.
			--uDef.weapondefs.armdfly_paralyzer.beamBurst = true--testing
			--uDef.weapondefs.armdfly_paralyzer.burst = 10--testing
			--uDef.weapondefs.armdfly_paralyzer.burstRate = 0.1--testing

		end

		if name == "armemp" then
			uDef.weapondefs.armemp_weapon.areaofeffect = 512
			uDef.weapondefs.armemp_weapon.burstrate = 0.3333
			uDef.weapondefs.armemp_weapon.edgeeffectiveness = -0.10
			uDef.weapondefs.armemp_weapon.paralyzetime = 22
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
			uDef.weapondefs.emp.damage.default = 200
			uDef.weapondefs.emp.reloadtime = .5
			uDef.weapondefs.emp.paralyzetime = 1
		end

		if name == "corbw" then
			--uDef.weapondefs.bladewing_lyzer.burst = 4--shotgun mode, outdated but worth keeping
			--uDef.weapondefs.bladewing_lyzer.reloadtime = 0.8
			--uDef.weapondefs.bladewing_lyzer.beamburst = true
			--uDef.weapondefs.bladewing_lyzer.sprayangle = 2100
			--uDef.weapondefs.bladewing_lyzer.beamdecay = 0.5
			--uDef.weapondefs.bladewing_lyzer.beamtime = 0.03
			--uDef.weapondefs.bladewing_lyzer.beamttl = 0.4

			uDef.weapondefs.bladewing_lyzer.damage.default = 300
			uDef.weapondefs.bladewing_lyzer.paralyzetime = 1
		end


		if (name =="corfmd" or name =="armamd" or name =="cormabm" or name =="armscab") then
			uDef.customparams.paralyzemultiplier = 1.5
		end

		if (name == "armvulc" or name == "corbuzz" or name == "legstarfall" or name == "corsilo" or name == "armsilo") then
			uDef.customparams.paralyzemultiplier = 2
		end

		--if name == "corsumo" then
			--uDef.customparams.paralyzemultiplier = 0.9
		--end

		if name == "armmar" then
			uDef.customparams.paralyzemultiplier = 0.8
		end

		if name == "armbanth" then
			uDef.customparams.paralyzemultiplier = 1.6
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


	--Air rework
	if modOptions.air_rework == true then
		local airReworkUnits = VFS.Include("unitbasedefs/air_rework_defs.lua")
		uDef = airReworkUnits.airReworkTweaks(name, uDef)
	end

	-- Skyshift: Air rework
	if modOptions.skyshift == true then
		local skyshiftUnits = VFS.Include("unitbasedefs/skyshiftunits_post.lua")
		uDef = skyshiftUnits.skyshiftUnitTweaks(name, uDef)
	end

	if modOptions.proposed_unit_reworks == true then
		local proposed_unit_reworks = VFS.Include("unitbasedefs/proposed_unit_reworks_defs.lua")
		uDef = proposed_unit_reworks.proposed_unit_reworksTweaks(name, uDef)
	end

	--Lategame Rebalance
	if modOptions.lategame_rebalance == true then
		if name == "armamb" then
			uDef.weapondefs.armamb_gun.reloadtime = 2
			uDef.weapondefs.armamb_gun_high.reloadtime = 7.7
		end
		if name == "cortoast" then
			uDef.weapondefs.cortoast_gun.reloadtime = 2.35
			uDef.weapondefs.cortoast_gun_high.reloadtime = 8.8
		end
		if name == "armpb" then
			uDef.weapondefs.armpb_weapon.reloadtime = 1.7
			uDef.weapondefs.armpb_weapon.range = 700
		end
		if name == "corvipe" then
			uDef.weapondefs.vipersabot.reloadtime = 2.1
			uDef.weapondefs.vipersabot.range = 700
		end
		if name == "armanni" then
			uDef.metalcost = 4000
			uDef.energycost = 85000
			uDef.buildtime = 59000
		end
		if name == "corbhmth" then
			uDef.metalcost = 3600
			uDef.energycost = 40000
			uDef.buildtime = 70000
		end
		if name == "armbrtha" then
			uDef.metalcost = 5000
			uDef.energycost = 71000
			uDef.buildtime = 94000
		end
		if name == "corint" then
			uDef.metalcost = 5100
			uDef.energycost = 74000
			uDef.buildtime = 103000
		end
		if name == "armvulc" then
			uDef.metalcost = 75600
			uDef.energycost = 902400
			uDef.buildtime = 1680000
		end
		if name == "corbuzz" then
			uDef.metalcost = 73200
			uDef.energycost = 861600
			uDef.buildtime = 1680000
		end
		if name == "armmar" then
			uDef.metalcost = 1070
			uDef.energycost = 23000
			uDef.buildtime = 28700
		end
		if name == "armraz" then
			uDef.metalcost = 4200
			uDef.energycost = 75000
			uDef.buildtime = 97000
		end
		if name == "armthor" then
			uDef.metalcost = 9450
			uDef.energycost = 255000
			uDef.buildtime = 265000
		end
		if name == "corshiva" then
			uDef.metalcost = 1800
			uDef.energycost = 26500
			uDef.buildtime = 35000
			uDef.speed = 50.8
			uDef.weapondefs.shiva_rocket.tracks = true
			uDef.weapondefs.shiva_rocket.turnrate = 7500
		end
		if name == "corkarg" then
			uDef.metalcost = 2625
			uDef.energycost = 60000
			uDef.buildtime = 79000
		end
		if name == "cordemon" then
			uDef.metalcost = 6300
			uDef.energycost = 94500
			uDef.buildtime = 94500
		end
		if name == "armstil" then
			uDef.health = 1300
			uDef.weapondefs.stiletto_bomb.burst = 3
			uDef.weapondefs.stiletto_bomb.burstrate = 0.2333
			uDef.weapondefs.stiletto_bomb.damage = {
				default = 3000
			}
		end
		if name == "armlance" then
			uDef.health = 1750
		end
		if name == "cortitan" then
			uDef.health = 1800
		end
		if name == "armyork" then
			uDef.weapondefs.mobileflak.reloadtime = 0.8333
		end
		if name == "corsent" then
			uDef.weapondefs.mobileflak.reloadtime = 0.8333
		end
		if name == "armaas" then
			uDef.weapondefs.mobileflak.reloadtime = 0.8333
		end
		if name == "corarch" then
			uDef.weapondefs.mobileflak.reloadtime = 0.8333
		end
		if name == "armflak" then
			uDef.weapondefs.armflak_gun.reloadtime = 0.6
		end
		if name == "corflak" then
			uDef.weapondefs.armflak_gun.reloadtime = 0.6
		end
		if name == "armmercury" then
			uDef.weapondefs.arm_advsam.reloadtime = 11
			uDef.weapondefs.arm_advsam.stockpile = false
		end
		if name == "corscreamer" then
			uDef.weapondefs.cor_advsam.reloadtime = 11
			uDef.weapondefs.cor_advsam.stockpile = false
		end
		if name == "armfig" then
			uDef.metalcost = 77
			uDef.energycost = 3100
			uDef.buildtime = 3700
		end
		if name == "armsfig" then
			uDef.metalcost = 95
			uDef.energycost = 4750
			uDef.buildtime = 5700
		end
		if name == "armhawk" then
			uDef.metalcost = 155
			uDef.energycost = 6300
			uDef.buildtime = 9800
		end
		if name == "corveng" then
			uDef.metalcost = 77
			uDef.energycost = 3000
			uDef.buildtime = 3600
		end
		if name == "corsfig" then
			uDef.metalcost = 95
			uDef.energycost = 4850
			uDef.buildtime = 5400
		end
		if name == "corvamp" then
			uDef.metalcost = 150
			uDef.energycost = 5250
			uDef.buildtime = 9250
		end
	end

	-- Factory costs test

	if modOptions.factory_costs == true then

		if name == "armmoho" or name == "cormoho" or name == "cormexp" then
			uDef.metalcost = uDef.metalcost + 50
			uDef.energycost = uDef.energycost + 2000
		end
		if name == "armageo" or name == "corageo" then
			uDef.metalcost = uDef.metalcost + 100
			uDef.energycost = uDef.energycost + 4000
		end
		if name == "armavp" or name == "coravp" or name == "armalab" or name == "coralab" or name == "armaap" or name == "coraap" or name == "armasy" or name == "corasy" then
			uDef.metalcost = uDef.metalcost - 1000
			uDef.workertime = 600
			uDef.buildtime = uDef.buildtime * 2
		end
		if name == "armvp" or name == "corvp" or name == "armlab" or name == "corlab" or name == "armsy" or name == "corsy"then
			uDef.metalcost = uDef.metalcost - 50
			uDef.buildtime = uDef.buildtime - 1500
			uDef.energycost = uDef.energycost - 280
		end
		if name == "armap" or name == "corap" or name == "armhp" or name == "corhp" or name == "armfhp" or name == "corfhp" or name == "armplat" or name == "corplat" then
			uDef.metalcost = uDef.metalcost - 100
			uDef.buildtime = uDef.buildtime - 600
			uDef.energycost = uDef.energycost - 100
		end
		if name == "armshltx" or name == "corgant" or name == "armshltxuw" or name == "corgantuw" then
			uDef.workertime = 2000
			uDef.buildtime = uDef.buildtime * 1.33
		end

		if tonumber(uDef.customparams.techlevel) == 2 and uDef.energycost and uDef.metalcost and uDef.buildtime and not (name == "armavp" or name == "coravp" or name == "armalab" or name == "coralab" or name == "armaap" or name == "coraap" or name == "armasy" or name == "corasy") then
			uDef.buildtime = math.ceil(uDef.buildtime * 0.015 / 5) * 500
		end
		if tonumber(uDef.customparams.techlevel) == 3 and uDef.energycost and uDef.metalcost and uDef.buildtime then
			uDef.buildtime = math.ceil(uDef.buildtime * 0.0015) * 1000
		end

		if name == "armnanotc" or name == "cornanotc" or name == "armnanotcplat" or name == "cornanotcplat" then
			uDef.metalcost = uDef.metalcost + 40
		end
	end

	-----------------------------
	-- Split T2 into two Tiers --
	-----------------------------
	
	if modOptions.splittiers then
		if name == "armlab" then
			uDef.buildoptions = {
			[1] = "armck",
			[2] = "armpw",
			[3] = "armrectr",
			[4] = "armrock",
			[5] = "armjeth",
			[6] = "armwar",
			[7] = "armflea",
			}
		elseif name == "armap" then
			uDef.buildoptions = {
			[1] = "armca",
			[2] = "armpeep",
			[3] = "armfig",
			[4] = "armthund",
			[5] = "armatlas",
			[6] = "armkam",
			}
		elseif name == "armalab" then
			uDef.metalcost = 2000
			uDef.buildoptions = {
			[1] = "armack",
			[2] = "armfark",
			[3] = "armfast",
			[4] = "armamph",
			[5] = "armzeus",
			[6] = "armmav",
			[7] = "armspid",
			[8] = "armfido",
			[9] = "armaak",
			[10] = "armvader",
			[11] = "armdecom",
			[12] = "armspy",
		}
		elseif name == "armavp" then
			uDef.metalcost = 2000
			uDef.buildoptions = {
			[1] = "armacv",
			[2] = "armconsul",
			[3] = "armcroc",
			[4] = "armlatnk",
			[5] = "armbull",
			[6] = "armmart",
			[7] = "armyork",
		}
		elseif name == "armaap" then
			uDef.metalcost = 2000
			uDef.buildoptions = {
			[1] = "armaca",
			[2] = "armseap",			
			[3] = "armsb",
			[4] = "armsfig",
			[5] = "armawac",
			[6] = "armsaber",
			[7] = "armhvytrans",
		}
		elseif name == "armplat" then
			uDef.metalcost = 2000
			uDef.buildoptions = {
			[1] = "armaca",
			[2] = "armseap",			
			[3] = "armsb",
			[4] = "armsfig",
			[5] = "armawac",
			[6] = "armsaber",
		}		
		elseif name == "armasy" then
			uDef.metalcost = 2000
			uDef.buildoptions = {
			[1] = "armacsub",
			[2] = "armmls",
			[3] = "armcrus",
			[4] = "armsubk",
			[5] = "armaas",
			[6] = "armantiship",
			[7] = "armlship",
		}
		elseif name == "armack" then
			uDef.metalcost = 300
			uDef.buildoptions = {
			[1] = "armfus",
			[2] = "armckfus",
			[3] = "armgmm",
			[4] = "armuwadves",
			[5] = "armuwadvms",
			[6] = "armarad",
			[7] = "armveil",
			[8] = "armfort",
			[9] = "armasp",
			[10] = "armtarg",
			[11] = "armsd",
			[12] = "armgate",
			[13] = "armpb",
			[14] = "armflak",
			[15] = "armemp",
			[16] = "armamd",
			[17] = "armdf",
			[18] = "armlab",
			[19] = "armalab",
			[20] = "armsalab",
			[21] = "armmoho",			
		}
		elseif name == "armacv" then
			uDef.metalcost = 350
			uDef.buildoptions = {
			[1] = "armfus",
			[2] = "armckfus",
			[3] = "armgmm",
			[4] = "armuwadves",
			[5] = "armuwadvms",
			[6] = "armarad",
			[7] = "armveil",
			[8] = "armfort",
			[9] = "armasp",
			[10] = "armtarg",
			[11] = "armsd",
			[12] = "armgate",
			[13] = "armpb",
			[14] = "armflak",
			[15] = "armemp",
			[16] = "armamd",
			[17] = "armdf",
			[18] = "armvp",
			[19] = "armavp",
			[20] = "armsavp",
			[21] = "armmoho",
		}
		elseif name == "armaca" then
			uDef.metalcost = 350
			uDef.buildoptions = {
			[1] = "armfus",
			[2] = "armckfus",
			[3] = "armgmm",
			[4] = "armuwadves",
			[5] = "armuwadvms",
			[6] = "armarad",
			[7] = "armveil",
			[8] = "armfort",
			[9] = "armasp",
			[10] = "armtarg",
			[11] = "armsd",
			[12] = "armgate",
			[13] = "armpb",
			[14] = "armflak",
			[15] = "armemp",
			[16] = "armamd",
			[17] = "armdf",
			[18] = "armap",
			[19] = "armaap",
			[20] = "armsaap",
			[21] = "armmoho",
		}
		elseif name == "armacsub" then
			uDef.metalcost = 400
			uDef.buildoptions = {
			[1] = "armuwfus",
			[2] = "armuwadves",
			[3] = "armuwadvms",
			[4] = "armasy",
			[5] = "armsy",
			[6] = "armason",
			[7] = "armfatf",
			[8] = "armfflak",
			[9] = "armkraken",
			[10] = "armfasp",
			[11] = "armsasy",
			[12] = "armuwmme",
		}
		elseif name == "armcsa" then
			uDef.metalcost = 450
			uDef.buildoptions = {
			[1] = "armafus",
			[2] = "armageo",
			[3] = "armuwageo",
			[4] = "armmoho",
			[5] = "armmmkr",
			[6] = "armanni",
			[7] = "armmercury",
			[8] = "armsilo",
			[9] = "armbrtha",
			[10] = "armvulc",
			[11] = "armap",
			[12] = "armaap",
			[13] = "armsaap",
			[14] = "armplat",
			[15] = "armshltx",
		}
		elseif name == "coralab" then
			uDef.metalcost = 2000
			uDef.buildoptions = {
			[1] = "corack",
			[2] = "corfast",
			[3] = "corpyro",
			[4] = "coramph",
			[5] = "corcan",
			[6] = "cortermite",
			[7] = "cormort",
			[8] = "coraak",
			[9] = "cordecom",
			[10] = "corspy",
		}
		elseif name == "coravp" then
			uDef.metalcost = 2000
			uDef.buildoptions = {
			[1] = "coracv",
			[2] = "corsala",
			[3] = "correap",
			[4] = "cormart",
			[5] = "corsent",
			[6] = "cormabm",
		}
		elseif name == "corap" then
			uDef.buildoptions = {
			[1] = "corca",
			[2] = "corfink",
			[3] = "corveng",
			[4] = "corshad",
			[5] = "corvalk",
			[6] = "corbw",
		}
		elseif name == "coraap" then
			uDef.metalcost = 2000
			uDef.buildoptions = {		
			[1] = "coraca",
			[2] = "corawac",
			[3] = "corcut",
			[4] = "corsb",
			[5] = "corseap",
			[6] = "corsfig",
			[7] = "corhvytrans",
		}
		elseif name == "corplat" then
			uDef.metalcost = 2000
			uDef.buildoptions = {		
			[1] = "coraca",
			[2] = "corawac",
			[3] = "corcut",
			[4] = "corsb",
			[5] = "corseap",
			[6] = "corsfig",
		}
		elseif name == "corasy" then
			uDef.metalcost = 2000
			uDef.buildoptions = {		
			[1] = "coracsub",
			[2] = "cormls",
			[3] = "corcrus",
			[4] = "corshark",
			[5] = "corarch",
			[6] = "corantiship",
			[7] = "corfship",
		}
		elseif name == "corack" then
			uDef.metalcost = 300
			uDef.buildoptions = {
			[1] = "corfus",
			[2] = "corbhmth",
			[3] = "coruwadves",
			[4] = "coruwadvms",
			[5] = "corarad",
			[6] = "corshroud",
			[7] = "corfort",
			[8] = "corasp",
			[9] = "cortarg",
			[10] = "corsd",
			[11] = "corgate",
			[12] = "corvipe",
			[13] = "corflak",
			[14] = "cortron",
			[15] = "corfmd",
			[16] = "corlab",
			[17] = "coralab",
			[18] = "corsalab",
			[19] = "cormoho",
		}
		elseif name == "coracv" then
			uDef.metalcost = 350
			uDef.buildoptions = {
			[1] = "corfus",
			[2] = "corbhmth",
			[3] = "coruwadves",
			[4] = "coruwadvms",
			[5] = "corarad",
			[6] = "corshroud",
			[7] = "corfort",
			[8] = "corasp",
			[9] = "cortarg",
			[10] = "corsd",
			[11] = "corgate",
			[12] = "corvipe",
			[13] = "corflak",
			[14] = "cortron",
			[15] = "corfmd",
			[16] = "corvp",
			[17] = "coravp",
			[18] = "corsavp",
			[19] = "cormoho",
		}
		elseif name == "coraca" then
			uDef.metalcost = 350
			uDef.buildoptions = {
			[1] = "corfus",
			[2] = "corbhmth",
			[3] = "coruwadves",
			[4] = "coruwadvms",
			[5] = "corarad",
			[6] = "corshroud",
			[7] = "corfort",
			[8] = "corasp",
			[9] = "cortarg",
			[10] = "corsd",
			[11] = "corgate",
			[12] = "corvipe",
			[13] = "corflak",
			[14] = "cortron",
			[15] = "corfmd",
			[16] = "corap",
			[17] = "coraap",
			[18] = "corsaap",
			[19] = "cormoho",
		}
		elseif name == "coracsub" then
			uDef.metalcost = 400
			uDef.buildoptions = {
			[1] = "coruwfus",
			[2] = "coruwadves",
			[3] = "coruwadvms",
			[4] = "corasy",
			[5] = "corsy",
			[6] = "corason",
			[7] = "corfatf",
			[8] = "corenaa",
			[9] = "corfdoom",
			[10] = "corfasp",
			[11] = "corsasy",
			[12] = "coruwmme",
		}
		elseif name == "corcsa" then
			uDef.metalcost = 450
			uDef.buildoptions = {
			[1] = "corafus",
			[2] = "corageo",
			[3] = "coruwageo",
			[4] = "cormexp",
			[5] = "cormmkr",
			[6] = "cortoast",
			[7] = "cordoom",
			[8] = "corscreamer",
			[9] = "corsilo",
			[10] = "corint",
			[11] = "corbuzz",
			[12] = "corap",
			[13] = "coraap",
			[14] = "corplat",
			[15] = "corsaap",
			[16] = "corgant",
		}
		elseif name == "armfido" then
			uDef.weapondefs.bfido.range = 600
			uDef.health = 800
			uDef.speed = 58
			uDef.weapondefs.bfido.weaponvelocity = 450
			uDef.weapondefs.bfido.reloadtime = 4
			uDef.weapondefs.bfido.damage.default = 350			
		elseif name == "armsptk" then
			uDef.weapondefs.adv_rocket.range = 700
			uDef.speed = 42
		elseif name == "armbull" then
			uDef.speed = 50
			uDef.weapondefs.arm_bull.areaofeffect = 150
			uDef.weapondefs.arm_bull.damage.default = 240
			uDef.health = 5100
		elseif name == "armlatnk" then
			uDef.weapondefs.lightning.range = 260
			uDef.health = 1300
		elseif name == "armmart" then
			uDef.speed = 40
			uDef.weapondefs.arm_artillery.range = 760
			uDef.weapondefs.arm_artillery.areaofeffect = 160
			uDef.weapondefs.arm_artillery.damage.default = 220
			uDef.health = 750
		elseif name == "armhlt" then
			uDef.weapondefs.arm_laserh1.range = 700
			uDef.weapondefs.arm_laserh1.reloadtime = 2.7
			uDef.weapondefs.arm_laserh1.damage.default = 580
		elseif name == "armart" then
			uDef.weapondefs.tawf113_weapon.range = 740
			uDef.health = 520
		elseif name == "armrock" then
			uDef.weapondefs.arm_bot_rocket.range = 600
			uDef.weapondefs.arm_bot_rocket.damage.default = 95
			uDef.weapondefs.arm_bot_rocket.weaponvelocity = 170
		elseif name == "armsehak" then
			uDef.metalcost = 250
			uDef.energycost = 9500
			uDef.hoverattack = true
			uDef.sightdistance = 1500
			uDef.radardistance = 2700
		elseif name == "armmoho" then
			uDef.energyupkeep = 150
			uDef.health = 850
		elseif name == "armuwmme" then
			uDef.energyupkeep = 150
			uDef.health = 850
		elseif name == "armmanni" then
			uDef.weapondefs.atam.reloadtime = 9.2
			uDef.weapondefs.atam.damage.default = 4600
			uDef.weapondefs.atam.damage.commanders = 1500
			uDef.weapondefs.atam.energypershot = 3000
			uDef.speed = 35
		elseif name == "cormort" then
			uDef.weapondefs.cor_mort.damage.default = 78
			uDef.weapondefs.cor_mort.reloadtime = 1.2
			uDef.weapondefs.cor_mort.range = 780
			uDef.weapondefs.cor_mort.weaponvelocity = 400
			uDef.speed = 40
			uDef.metalcost = 340
			uDef.health = 700
		elseif name == "corthud" then
			uDef.speed = 55
			uDef.energycost = 1600
			uDef.metalcost = 160
			uDef.weapondefs.arm_ham.range = 425
		elseif name == "corstorm" then
			uDef.weapondefs.cor_bot_rocket.range = 600
			uDef.weapondefs.cor_bot_rocket.damage.default = 105
			uDef.weapondefs.cor_bot_rocket.weaponvelocity = 150
		elseif name == "corwolv" then
			uDef.weapondefs.corwolv_gun.range = 740
			uDef.health = 550
		elseif name == "corhlt" then
			uDef.weapondefs.cor_laserh1.range = 700
			uDef.weapondefs.cor_laserh1.reloadtime = 2.4
			uDef.weapondefs.cor_laserh1.damage.default = 392
		elseif name == "correap" then
			uDef.speed = 55
			uDef.weapondefs.cor_reap.areaofeffect = 90
			uDef.weapondefs.cor_reap.damage.default = 95
			uDef.health = 6200
		elseif name == "cormart" then
			uDef.speed = 40
			uDef.weapondefs.cor_artillery.range = 750
			uDef.weapondefs.cor_artillery.areaofeffect = 170
			uDef.weapondefs.cor_artillery.damage.default = 390
			uDef.health = 850
		elseif name == "cormoho" then
			uDef.energyupkeep = 150
			uDef.health = 1000
		elseif name == "coruwmme" then
			uDef.energyupkeep = 150
			uDef.health = 1000
		elseif name == "corhunt" then
			uDef.metalcost = 250
			uDef.energycost = 9500
			uDef.hoverattack = true
			uDef.sightdistance = 1500
			uDef.radardistance = 2700
		elseif name == "cormexp" then
			uDef.energyupkeep = 150
		elseif name == "cormando" then
			uDef.weapons[1].badtargetcategory = "VTOL"
			uDef.weapons[1].onlytargetcategory = "NOTSUB"
			uDef.weapondefs.commando_blaster.damage.default = 150
			uDef.weapondefs.commando_blaster.weaponvelocity = 600
		end	
	end

	-------------------
	-- Tech Overhaul --
	-------------------

	if modOptions.techoverhaul then
    	-- Bot and Veh lab reworks
		-- T2 lab cost will be increased to around 4k metal
		-- New labs are created - "ha" for half-advanced, called enhanced (placeholder). Tier between T1 and T2
		-- Enhanced labs are given amphibious vehicles and the most expensive T1 + least expensive T2.
		-- Specialty T1 mexes are changed to enhanced mexes with 2x metal income + special aabilities (for faction differentiation)
		if name == "corlab" then
			uDef.metalcost = math.ceil(uDef.metalcost * 0.08) * 10
			uDef.energycost = math.ceil(uDef.energycost * 0.08) * 10
			uDef.buildtime = math.ceil(uDef.buildtime * 0.008) * 100
			uDef.workertime = uDef.workertime * 2 
			uDef.buildoptions = {
				[1] = "corck",
				[2] = "corak",
				[3] = "cornecro",
				[4] = "corstorm",
				[5] = "corthud",
				[6] = "corcrash",
				[7] = "corroach"
			}

		elseif name == "coralab" then
			uDef.metalcost = uDef.metalcost * 2
			uDef.energycost = uDef.energycost * 2
			uDef.buildtime = math.ceil(uDef.buildtime * .02) * 100
			uDef.workertime = uDef.workertime * 6
			uDef.buildoptions = {
				[1] = "corack",
				[2] = "corsumo",
				[3] = "cortermite",
				[4] = "corhrk",
				[5] = "cordecom",
				[6] = "corvoyr",
				[7] = "corspy",
				[8] = "corspec"
			}

		elseif name == "armalab" then
			uDef.metalcost = uDef.metalcost * 2
			uDef.energycost = uDef.energycost * 2
			uDef.buildtime = math.ceil(uDef.buildtime * .02) * 100
			uDef.workertime = uDef.workertime * 6
			uDef.buildoptions = {
				[1] = "armack",
				[2] = "armsnipe",
				[3] = "armfboy",
				[4] = "armmark",
				[5] = "armaser",
				[6] = "armspy",
				[7] = "armdecom",
				[8] = "armscab",
				[9] = "armsptk"
			}

		elseif name == "legalab" then
			uDef.metalcost = uDef.metalcost * 2
			uDef.energycost = uDef.energycost * 2
			uDef.buildtime = math.ceil(uDef.buildtime * .02) * 100
			uDef.workertime = uDef.workertime * 6
			uDef.buildoptions = {
				[1] = "legack",
				[2] = "leginc",
				[3] = "legsrail",
				[4] = "leghrk",
				[5] = "legaradk",
				[6] = "legaspy",
				[7] = "legajamk",
				[8] = "legdecom",
			}

		elseif name == "armvp" then
			uDef.metalcost = math.ceil(uDef.metalcost * 0.08) * 10
			uDef.energycost = math.ceil(uDef.energycost * 0.08) * 10
			uDef.buildtime = math.ceil(uDef.buildtime * 0.008) * 100
			uDef.workertime = uDef.workertime * 2 
			uDef.buildoptions = {
				[1] = "armcv",
				[2] = "armfav",
				[3] = "armflash",
				[4] = "armstump",
				[5] = "armart",
				[6] = "armjanus",
				[7] = "armsam",
			}

		elseif name == "corvp" then
			uDef.metalcost = math.ceil(uDef.metalcost * 0.08) * 10
			uDef.energycost = math.ceil(uDef.energycost * 0.08) * 10
			uDef.buildtime = math.ceil(uDef.buildtime * 0.008) * 100
			uDef.workertime = uDef.workertime * 2 
			uDef.buildoptions = {
				[1] = "corcv",
				[2] = "corfav",
				[3] = "corgator",
				[4] = "corraid",
				[5] = "corlevlr",
				[6] = "corwolv",
				[7] = "cormist",
			}

		elseif name == "legvp" then
			uDef.metalcost = math.ceil(uDef.metalcost * 0.08) * 10
			uDef.energycost = math.ceil(uDef.energycost * 0.08) * 10
			uDef.buildtime = math.ceil(uDef.buildtime * 0.008) * 100
			uDef.workertime = uDef.workertime * 2 
			uDef.buildoptions = {
				[1] = "legscout",
				[2] = "legcv",
				[3] = "leghades",
				[4] = "leghelios",
				[5] = "leggat",
				[6] = "legbar",
				[7] = "legrail",
			}

		elseif name == "armavp" then
			uDef.metalcost = uDef.metalcost * 2
			uDef.energycost = uDef.energycost * 2
			uDef.buildtime = math.ceil(uDef.buildtime * .02) * 100
			uDef.workertime = uDef.workertime * 6
			uDef.buildoptions = {
				[1] = "armacv",
				[2] = "armbull",
				[3] = "armmerl",
				[4] = "armmanni",
				[5] = "armyork",
				[6] = "armseer",
				[7] = "armjam",
			}
		
		elseif name == "coravp" then
			uDef.metalcost = uDef.metalcost * 2
			uDef.energycost = uDef.energycost * 2
			uDef.buildtime = math.ceil(uDef.buildtime * .02) * 100
			uDef.workertime = uDef.workertime * 6
			uDef.buildoptions = {
				[1] = "coracv",
				[2] = "corgol",
				[3] = "corvroc",
				[4] = "cortrem",
				[5] = "corsent",
				[6] = "cormabm",
				[7] = "coreter",
				[8] = "corvrad"
			}

		elseif name == "legavp" then
			uDef.metalcost = uDef.metalcost * 2
			uDef.energycost = uDef.energycost * 2
			uDef.buildtime = math.ceil(uDef.buildtime * .02) * 100
			uDef.workertime = uDef.workertime * 6
			uDef.buildoptions = {
				[1] = "legacv",
				[2] = "legaheattank",
				[3] = "legmed",
				[4] = "legavroc",
				[5] = "leginf",
				[6] = "legvflak",
				[7] = "cormabm",
				[8] = "legavjam",
				[9] = "legavrad",
			}
		-- Con Reworks
		-- Late T1 and Early T2 buildings are given to enhanced constructors
		-- Since mobile radar and jammers are now in the more expensive T2 labs, the enhanced constructors can make stationary t2 radar

		elseif name == "armck" then
			uDef.buildoptions = {
				[1] = "armsolar",
				[2] = "armwin",
				[3] = "armgeo",
				[4] = "armmstor",
				[5] = "armestor",
				[6] = "armmex",
				[7] = "armmakr",
				[8] = "armalab",
				[9] = "armhalab",
				[10] = "armlab",
				[11] = "armvp",
				[12] = "armap",
				[13] = "armhp",
				[14] = "armnanotc",
				[15] = "armeyes",
				[16] = "armrad",
				[17] = "armdrag",
				[18] = "armllt",
				[19] = "armrl",
				[20] = "armdl",
				[21] = "armjamt",
				[22] = "armjuno",
				[23] = "armsy",
			}

		elseif name == "corck" then
			uDef.buildoptions = {
				[1] = "corsolar",
				[2] = "corwin",
				[3] = "corgeo",
				[4] = "cormstor",
				[5] = "corestor",
				[6] = "cormex",
				[7] = "cormakr",
				[8] = "coralab",
				[11] = "corlab",
				[12] = "corhalab",
				[13] = "corvp",
				[14] = "corap",
				[15] = "corhp",
				[16] = "cornanotc",
				[17] = "coreyes",
				[18] = "cordrag",
				[19] = "corllt",
				[20] = "nil",
				[21] = "corrl",
				[22] = "nil",
				[23] = "corrad",
				[24] = "cordl",
				[25] = "corjamt",
				[26] = "corsy",
			}

		elseif name == "legck" then
			uDef.buildoptions = {
			[1] = "legsolar",
			[2] = "legwin",
			[3] = "leggeo",
			[4] = "legmstor",
			[5] = "legestor",
			[6] = "legmex",
			[7] = "legeconv",
			[8] = "legalab",
			[9] = "leglab",
			[10] = "leghalab",
			[11] = "legvp",
			[12] = "legap",
			[13] = "leghp",
			[14] = "legnanotc",
			[15] = "legeyes",
			[16] = "legrad",
			[17] = "legdrag",
			[18] = "leglht",
			[19] = "nil",
			[20] = "legrl",
			[21] = "legctl",
			[22] = "legjam",
			[23] = "corsy",
			}

		elseif name == "armack" then
			uDef.buildoptions = {
				[1] = "armafus",
				[2] = "armckfus",
				[3] = "armshltx",
				[4] = "armageo",
				[5] = "armgmm",
				[6] = "armmoho",
				[7] = "armmmkr",
				[8] = "armuwadves",
				[9] = "armuwadvms",
				[10] = "armfort",
				[11] = "armtarg",
				[12] = "armgate",
				[13] = "armamb",
				[14] = "armpb",
				[15] = "armanni",
				[16] = "armflak",
				[17] = "armmercury",
				[18] = "armemp",
				[19] = "armamd",
				[20] = "armsilo",
				[21] = "armbrtha",
				[22] = "armvulc",
				[23] = "armdf",
				[24] = "armlab",
				[25] = "armhalab",
				[26] = "armalab",
			}

		elseif name == "corack" then
			uDef.buildoptions = {
				[1] = "corafus",
				[3] = "corgant",
				[4] = "corageo",
				[5] = "corbhmth",
				[6] = "cormoho",
				[7] = "cormexp",
				[8] = "cormmkr",
				[9] = "coruwadves",
				[10] = "coruwadvms",
				[11] = "corfort",
				[12] = "corasp",
				[13] = "cortarg",
				[14] = "corgate",
				[15] = "cortoast",
				[16] = "corvipe",
				[17] = "cordoom",
				[18] = "corflak",
				[19] = "corscreamer",
				[20] = "cortron",
				[21] = "corfmd",
				[22] = "corsilo",
				[23] = "corint",
				[24] = "corbuzz",
				[25] = "corlab",
				[26] = "coralab",
				[27] = "corhalab",
			}

		elseif name == "legack" then
			uDef.buildoptions = {
				[1] = "legafus",
				[2] = "leggant",
				[3] = "legageo",
				[4] = "legrampart",
				[5] = "legmoho",
				[6] = "nil",
				[7] = "legadveconv",
				[8] = "legadvestore",
				[9] = "legamstor",
				[10] = "legforti",
				[11] = "corasp",
				[12] = "legtarg",
				[13] = "legdeflector",
				[14] = "legacluster",
				[15] = "legapopupdef",
				[16] = "legbastion",
				[17] = "legflak",
				[18] = "leglraa",
				[19] = "legperdition",
				[20] = "legabm",
				[21] = "legsilo",
				[22] = "leglrpc",
				[23] = "legstarfall",
				[24] = "leglab",
				[25] = "legalab",
				[26] = "leghalab",
			}

		elseif name == "armcv" then
			uDef.buildoptions = {
				[1] = "armsolar",
				[2] = "armwin",
				[3] = "armgeo",
				[4] = "armmstor",
				[5] = "armestor",
				[6] = "armmex",
				[7] = "armmakr",
				[8] = "armavp",
				[9] = "armhavp",
				[10] = "armlab",
				[11] = "armvp",
				[12] = "armap",
				[13] = "armhp",
				[14] = "armnanotc",
				[15] = "armeyes",
				[16] = "armrad",
				[17] = "armdrag",
				[18] = "armllt",
				[19] = "armrl",
				[20] = "armdl",
				[21] = "armjamt",
				[22] = "armjuno",
				[23] = "armsy",
			}

		elseif name == "corcv" then
			uDef.buildoptions = {	
				[1] = "corsolar",
				[2] = "corwin",
				[3] = "corgeo",
				[4] = "cormstor",
				[5] = "corestor",
				[6] = "cormex",
				[7] = "cormakr",
				[8] = "coravp",
				[11] = "corlab",
				[12] = "corhavp",
				[13] = "corvp",
				[14] = "corap",
				[15] = "corhp",
				[16] = "cornanotc",
				[17] = "coreyes",
				[18] = "cordrag",
				[19] = "corllt",
				[20] = "nil",
				[21] = "corrl",
				[22] = "nil",
				[23] = "corrad",
				[24] = "cordl",
				[25] = "corjamt",
				[26] = "corsy",
			}

		elseif name == "legcv" then
			uDef.buildoptions = {
				[1] = "legsolar",
				[2] = "legwin",
				[3] = "leggeo",
				[4] = "legmstor",
				[5] = "legestor",
				[6] = "legmex",
				[7] = "legeconv",
				[8] = "legavp",
				[9] = "leglab",
				[10] = "leghavp",
				[11] = "legvp",
				[12] = "legap",
				[13] = "leghp",
				[14] = "legnanotc",
				[15] = "legeyes",
				[16] = "legrad",
				[17] = "legdrag",
				[18] = "leglht",
				[19] = "nil",
				[20] = "legrl",
				[21] = "legctl",
				[22] = "legjam",
				[23] = "corsy",
			}
		
		elseif name == "armacv" then
			uDef.buildoptions = {
				[1] = "armafus",
				[2] = "armckfus",
				[3] = "armshltx",
				[4] = "armageo",
				[5] = "armgmm",
				[6] = "armmoho",
				[7] = "armmmkr",
				[8] = "armuwadves",
				[9] = "armuwadvms",
				[10] = "armfort",
				[11] = "armtarg",
				[12] = "armgate",
				[13] = "armamb",
				[14] = "armpb",
				[15] = "armanni",
				[16] = "armflak",
				[17] = "armmercury",
				[18] = "armemp",
				[19] = "armamd",
				[20] = "armsilo",
				[21] = "armbrtha",
				[22] = "armvulc",
				[23] = "armdf",
				[24] = "armvp",
				[25] = "armhavp",
				[26] = "armavp",		
			}
		
		elseif name == "coracv" then
			uDef.buildoptions = {
				[1] = "corafus",
				[2] = "corgant",
				[3] = "corageo",
				[4] = "corbhmth",
				[5] = "cormoho",
				[7] = "cormexp",
				[8] = "cormmkr",
				[9] = "coruwadves",
				[10] = "coruwadvms",
				[11] = "corfort",
				[12] = "corasp",
				[13] = "cortarg",
				[14] = "corgate",
				[15] = "cortoast",
				[16] = "corvipe",
				[17] = "cordoom",
				[18] = "corflak",
				[19] = "corscreamer",
				[20] = "cortron",
				[21] = "corfmd",
				[22] = "corsilo",
				[23] = "corint",
				[24] = "corbuzz",
				[25] = "corvp",
				[26] = "coravp",
				[27] = "corhavp",
			}
		
		elseif name == "legacv" then
			uDef.buildoptions = {
				[1] = "legafus",
				[2] = "leggant",
				[3] = "legageo",
				[4] = "legrampart",
				[5] = "legmoho",
				[6] = "legadveconv",
				[7] = "legadvestore",
				[8] = "legamstor",
				[9] = "legforti",
				[10] = "corasp",
				[11] = "legtarg",
				[12] = "legdeflector",
				[13] = "legacluster",
				[14] = "legapopupdef",
				[15] = "legbastion",
				[16] = "legflak",
				[17] = "leglraa",
				[18] = "legperdition",
				[19] = "legabm",
				[20] = "legsilo",
				[21] = "leglrpc",
				[22] = "legstarfall",
				[23] = "legvp",
				[24] = "legavp",
				[25] = "leghavp",
			}

		elseif name == "armca" then
			uDef.buildoptions = {
				[1] = "armsolar",
				[2] = "armwin",
				[3] = "armgeo",
				[4] = "armmstor",
				[5] = "armestor",
				[6] = "armmex",
				[7] = "armmakr",
				[8] = "armaap",
				[9] = nil,
				[10] = "armlab",
				[11] = "armvp",
				[12] = "armap",
				[13] = "armhp",
				[14] = "armnanotc",
				[15] = "armeyes",
				[16] = "armrad",
				[17] = "armdrag",
				[18] = "armllt",
				[19] = "armrl",
				[20] = "armdl",
				[21] = "armjamt",
				[22] = "armjuno",
				[23] = "armsy",
			}

		elseif name == "corca" then 
			uDef.buildoptions = {
				[1] = "corsolar",
				[2] = "corwin",
				[3] = "corgeo",
				[4] = "cormstor",
				[5] = "corestor",
				[6] = "cormex",
				[7] = "cormakr",
				[8] = "coraap",
				[11] = "corlab",
				[12] = "nil",
				[13] = "corvp",
				[14] = "corap",
				[15] = "corhp",
				[16] = "cornanotc",
				[17] = "coreyes",
				[18] = "cordrag",
				[19] = "corllt",
				[20] = "nil",
				[21] = "corrl",
				[22] = "nil",
				[23] = "corrad",
				[24] = "cordl",
				[25] = "corjamt",
				[26] = "corsy",
			}

		elseif name == "legca" then
			uDef.buildoptions = {
				[1] = "legsolar",
				[2] = "legwin",
				[3] = "leggeo",
				[4] = "legmstor",
				[5] = "legestor",
				[6] = "legmex",
				[7] = "legeconv",
				[8] = "legaap",
				[9] = "leglab",
				[10] = "nil",
				[11] = "legvp",
				[12] = "legap",
				[13] = "leghp",
				[14] = "legnanotc",
				[15] = "legeyes",
				[16] = "legrad",
				[17] = "legdrag",
				[18] = "leglht",
				[19] = "nil",
				[20] = "legrl",
				[21] = "legctl",
				[22] = "legjam",
				[23] = "corsy",
			}
			
		-- t1.5 upgraded mexes 

		-- legion gets powerful enhanced mexes in return for weak t1 mexes. 
		-- Legion labs are also cheaper (to-do)
		elseif name == "legmext15" then
			uDef.metalcost = 450
			uDef.energycost = 7500
			uDef.buildtime = 7500
			uDef.health = 900
			uDef.metalstorage = 250
			uDef.energyupkeep = 35
			uDef.extractsmetal = 0.003
			uDef.maxwaterdepth = 10000

		elseif name == "armamex" then
			uDef.metalcost = 220
			uDef.buildtime = 5000
			uDef.energycost = 5000
			uDef.health = 1200
			uDef.metalstorage = 150
			uDef.energyupkeep = 30
			uDef.extractsmetal = 0.002
			uDef.cancloak = false
			uDef.explodeas = "mediumBuildingExplosionGeneric"
			uDef.maxwaterdepth = 10000

		elseif name == "corexp" then
			uDef.metalcost = 235
			uDef.energycost = 4000
			uDef.buildtime = 5500
			uDef.health = 1000
			uDef.energyupkeep = 30
			uDef.extractsmetal = 0.002
			uDef.maxwaterdepth = 10000

		-- T2 mexes rebalance
		-- Mexes cost 60 E/s for 4x extraction
		-- Legion pays a premium for 6x
		elseif name == "armmoho" or name == "cormoho" or name == "coruwmme" or name == "armuwmme" or name == "legmoho"
		then
			uDef.energyupkeep = 60
			uDef.metalcost = math.ceil(uDef.metalcost * .15) * 10
			uDef.energycost = math.ceil(uDef.energycost * .015) * 100
			uDef.buildtime = math.ceil(uDef.buildtime * 0.015) * 100

		elseif name == "cormexp" then 
			uDef.energyupkeep = 60

		-- remove hovers from com
		elseif name == "corcom" or name == "legcom" or name == "armcom" then
			uDef.buildoptions[26] = ""
			uDef.buildoptions[27] = ""

		-- T1 Economy 1.15x HP
		elseif name == "armwin" or name == "corwin" or name == "legwin"
		or name == "armsolar" or name == "corsolar" or name == "legsolar"
		or name == "armtide" or name == "cortide" or name == "legtide" 
		or name == "armmakr" or name == "cormakr" or name == "legeconv"
		or name == "corfmkr" or name == "armfmkr" or name == "legfeconv"
		or name == "cornanotc" or name == "armnanotc" or name == "legnanotc"
		or name == "armnanotcplat" or name == "cornanotcplat" or name == "legnanotcplat"
		then
			uDef.health = math.ceil(uDef.health * 0.115) * 10

		-- T1 Mex Hp buff
		elseif name == "armmex" or name == "cormex" or name == "legmex" then
			uDef.health = math.ceil(uDef.health * 0.15) * 10

		-- Advanced Solar Buff - makes Asolar around the efficiency of constant 9 windc
		elseif name == "armadvsol"
		then
			uDef.metalcost = 330
			uDef.energycost = 2860

		elseif name == "coradvsol"
		then
			uDef.metalcost = 360
			uDef.energycost = 1460

		elseif name == "legadvsol"
		then
			uDef.metalcost = 440
			uDef.energycost = 1940
			uDef.health = 1200

		-- Bedbug T1 Rework

		elseif name == "corroach" then
			uDef.metalcost = 30
			uDef.energycost = 600
			uDef.buildtime = 800
			uDef.health = 120
			uDef.maxwaterdepth = 16
			uDef.movementclass = "BOT1"
			uDef.radardistance = 700
			uDef.radaremitheight = 18
			uDef.speed = 100
			uDef.explodeas = "mediumExplosionGenericSelfd"
			uDef.selfdestructas = "fb_blastsml"
			uDef.customparams.techlevel = 1

		-- Spybots
		elseif name == "corspy" or name == "legaspy" or name == "armspy" then
			uDef.buildtime = 12800

		-- Lab Cost Rework

		-- T1
		elseif name == "armlab" or name == "armap" or name == "armsy" 
		or name == "corap" or name == "corsy" 
		or name == "leglab" or name == "legap" or name == "legsy"
		then 
			uDef.metalcost = uDef.metalcost - 200
			uDef.workertime = 200

		-- T2
		elseif name == "armaap" or name == "armasy" or name == "armalab" or name == "armavp"
		or name == "coraap" or name == "corasy" or name == "coralab" or name == "coravp"
		or name == "legaap" or name == "legasy" or name == "legalab" or name == "legavp"
		then 
			uDef.metalcost = uDef.metalcost * 2
			uDef.energycost = uDef.energycost * 2
			uDef.buildtime = math.ceil(uDef.buildtime * .02) * 100
			uDef.workertime = uDef.workertime * 6

		-- T3
		elseif name == "corgant" or name == "corgantuw" 
		or name == "leggant" or name == "leggantuw" 
		or name == "armshltx" or name == "armshltxuw" then
			uDef.workertime = uDef.workertime * 6


		end

		------------
    	-- Tech down

		if name == "corhack" or name == "coraak" or name == "cormort" or name == "corcan" or name == "cormort"or name == "corcan"or name == "corpyro"or name == "coramph"or name == "cormando"
		or name == "leghack" or name == "legadvaabot"  or name ==  "legstr" or name == "legshot" or name == "leginfestor" or name == "legamph" or name == "legsnapper" or name == "legbart" 
		or name == "armhack" or name == "armfido" or name ==  "armaak" or name == "armzeus" or name == "armmav" or name == "armamph" or name == "armspid" or name == "armfast" or name == "armvader"
		or name == "cormuskrat" or name ==  "corhacv" or name ==   "cormlv" or name ==  "corgarp" or name ==  "corsala" or name ==  "corparrow" or name ==  "corban" or name == "correap" or name ==  "cormart"
		or name == "armhacv" or name ==  "armbeaver" or name ==  "armmlv" or name ==  "armcroc" or name == "armlatnk" or name ==  "armpincer" or name ==  "armmart" or name == "armgremlin"
		or name == "leghacv" or name ==  "legotter" or name ==  "legamphtank" or name ==  "legmlv" or name ==  "legmrv" or name ==  "legfloat" or name ==  "legaskirmtank" or name ==  "legamcluster" or name ==  "legvcarry"
		then
			uDef.customparams.techlevel = 1
		end

		-----------------
		-- T2 BP increase

		if uDef.customparams.techlevel == 2 then 
		uDef.buildtime = math.ceil(uDef.buildtime * 0.0125) * 100
		end

		------------------------------
		-- Armada and Cortex Air Split

		-- Air Labs

		if name == "armplat" then
			uDef.buildoptions = {
			[1] = "armhaac",
			[2] = "armseap",			
			[3] = "armsb",
			[4] = "armsfig",
			[5] = "armawac",
			[6] = "armsaber",
			[7] = "armhvytrans",
		}

		elseif name == "corplat" then
			uDef.buildoptions = {		
			[1] = "corhaac",
			[2] = "corawac",
			[3] = "corcut",
			[4] = "corsb",
			[5] = "corseap",
			[6] = "corsfig",
		}

		elseif name == "armaap" then
			uDef.buildoptions = {
			[1] = "armaca",
			[2] = "armpnix",
			[3] = "armlance",
			[4] = "armhawk",
			[5] = "armdfly",
			[6] = "armbrawl",
			[7] = "armstil",
			[8] = "armliche",
			[9] = "armawac",
			}

		elseif name == "coraap" then
			uDef.buildoptions = {
			[1] = "coraca",
			[2] = "corape",
			[3] = "corhurc",
			[4] = "cortitan",
			[5] = "corvamp",
			[6] = "corseah",
			[7] = "corcrwh",
			[8] = "corawac",
		}
	
		elseif name == "armap" then
			uDef.buildoptions = {
			[1] = "armca",
			[2] = "armpeep",
			[3] = "armfig",
			[4] = "armthund",
			[5] = "armatlas",
			[6] = "armkam",
			}

		elseif name == "corap" then
			uDef.buildoptions = {
			[1] = "corca",
			[2] = "corfink",
			[3] = "corveng",
			[4] = "corshad",
			[5] = "corvalk",
			[6] = "corbw",
		}

		-- Air Cons

		elseif name == "armca" then
			uDef.buildoptions = {
				[1] = "armsolar",
				[2] = "armwin",
				[3] = "armgeo",
				[4] = "armmstor",
				[5] = "armestor",
				[6] = "armmex",
				[7] = "armmakr",
				[8] = "armaap",
				[9] = "armhaap",
				[10] = "armlab",
				[11] = "armvp",
				[12] = "armap",
				[13] = "armhp",
				[14] = "armnanotc",
				[15] = "armeyes",
				[16] = "armrad",
				[17] = "armdrag",
				[18] = "armllt",
				[19] = "armrl",
				[20] = "armdl",
				[21] = "armjamt",
				[22] = "armjuno",
				[23] = "armsy",
			}

		elseif name == "corca" then 
			uDef.buildoptions = {
				[1] = "corsolar",
				[2] = "corwin",
				[3] = "corgeo",
				[4] = "cormstor",
				[5] = "corestor",
				[6] = "cormex",
				[7] = "cormakr",
				[8] = "coraap",
				[11] = "corlab",
				[12] = "corhaap",
				[13] = "corvp",
				[14] = "corap",
				[15] = "corhp",
				[16] = "cornanotc",
				[17] = "coreyes",
				[18] = "cordrag",
				[19] = "corllt",
				[20] = "nil",
				[21] = "corrl",
				[22] = "nil",
				[23] = "corrad",
				[24] = "cordl",
				[25] = "corjamt",
				[26] = "corsy",
			}

		elseif name == "armaca" then
			uDef.buildoptions = {
				[1] = "armafus",
				[2] = "armckfus",
				[3] = "armshltx",
				[4] = "armageo",
				[5] = "armgmm",
				[6] = "armmoho",
				[7] = "armmmkr",
				[8] = "armuwadves",
				[9] = "armuwadvms",
				[10] = "armfort",
				[11] = "armtarg",
				[12] = "armgate",
				[13] = "armamb",
				[14] = "armpb",
				[15] = "armanni",
				[16] = "armflak",
				[17] = "armmercury",
				[18] = "armemp",
				[19] = "armamd",
				[20] = "armsilo",
				[21] = "armbrtha",
				[22] = "armvulc",
				[23] = "armdf",
				[24] = "armap",
				[25] = "armaap",
				[26] = "armhaap",
			}
		
		elseif name == "coraca" then
			uDef.buildoptions = {
				[1] = "corafus",
				[2] = "corgant",
				[3] = "corageo",
				[4] = "corbhmth",
				[5] = "cormoho",
				[7] = "cormexp",
				[8] = "cormmkr",
				[9] = "coruwadves",
				[10] = "coruwadvms",
				[11] = "corfort",
				[12] = "corasp",
				[13] = "cortarg",
				[14] = "corgate",
				[15] = "cortoast",
				[16] = "corvipe",
				[17] = "cordoom",
				[18] = "corflak",
				[19] = "corscreamer",
				[20] = "cortron",
				[21] = "corfmd",
				[22] = "corsilo",
				[23] = "corint",
				[24] = "corbuzz",
				[25] = "corap",
				[26] = "coraap",
				[27] = "corhaap",
			}
		end

		
		------------
		-- Sea Split

		-- Sea Labs

		if name == "armasy" then
			uDef.buildoptions = {
			[1] = "armacsub",
			[2] = "armserp",
			[3] = "armsjam",
			[4] = "armbats",
			[5] = "armmship",
			[6] = "armepoch",
			[7] = "armantiship"
			}

		elseif name == "corasy" then
			uDef.buildoptions = {
			[1] = "coracsub",
			[2] = "corssub",
			[3] = "corsjam",
			[4] = "corbats",
			[5] = "cormship",
			[6] = "corblackhy",
			}

		-- Sea Cons

		elseif name == "armcs" then
			uDef.buildoptions = {
			[1] = "armmex",
			[2] = "armvp",
			[3] = "armap",
			[4] = "armlab",
			[5] = "armeyes",
			[6] = "armdl",
			[7] = "armdrag",
			[8] = "",
			[9] = "armguard",
			[10] = "armtide",
			[11] = "armgeo",
			[12] = "armuwgeo",
			[13] = "armfmkr",
			[14] = "armuwms",
			[15] = "armuwes",
			[16] = "armsy",
			[17] = "armasy",
			[18] = "armnanotcplat",
			[19] = "armfhp",
			[20] = "armhasy",
			[21] = "",
			[22] = "armfrad",
			[23] = "armfdrag",
			[24] = "armtl",
			[25] = "armfrt",
			}

		elseif name == "armacsub" then
			uDef.buildoptions = {
			[1] = "armuwfus",
			[2] = "armuwmmm",
			[3] = "armuwmme",
			[4] = "armuwadves",
			[5] = "armuwadvms",
			[6] = "armshltxuw",
			[7] = "armasy",
			[8] = "armsy",
			[9] = "",
			[10] = "armfatf",
			[11] = "armatl",
			[12] = "armfflak",
			[13] = "",
			[14] = "armuwageo",
			[15] = "",
		}

		elseif name == "coracsub" then




		end
	end


	-- Multipliers Modoptions

	-- Max Speed
	if uDef.speed then
		local x = modOptions.multiplier_maxvelocity
		if x ~= 1 then
			uDef.speed = uDef.speed * x
			if uDef.maxdec then
				uDef.maxdec = uDef.maxdec * ((x - 1) / 2 + 1)
			end
			if uDef.maxacc then
				uDef.maxacc = uDef.maxacc * ((x - 1) / 2 + 1)
			end
		end
	end

	-- Turn Speed
	if uDef.turnrate then
		local x = modOptions.multiplier_turnrate
		if x ~= 1 then
			uDef.turnrate = uDef.turnrate * x
		end
	end

	-- Build Distance
	if uDef.builddistance then
		local x = modOptions.multiplier_builddistance
		if x ~= 1 then
			uDef.builddistance = uDef.builddistance * x
		end
	end

	-- Buildpower
	if uDef.workertime then
		local x = modOptions.multiplier_buildpower
		if x ~= 1 then
			uDef.workertime = uDef.workertime * x
		end

		-- increase terraformspeed to be able to restore ground faster
		uDef.terraformspeed = uDef.workertime * 30
	end

	--energystorage
	--metalstorage
	-- Metal Extraction Multiplier
	if (uDef.extractsmetal and uDef.extractsmetal > 0) and (uDef.customparams.metal_extractor and uDef.customparams.metal_extractor > 0) then
		local x = modOptions.multiplier_metalextraction * modOptions.multiplier_resourceincome
		uDef.extractsmetal = uDef.extractsmetal * x
		uDef.customparams.metal_extractor = uDef.customparams.metal_extractor * x
		if uDef.metalstorage then
			uDef.metalstorage = uDef.metalstorage * x
		end
	end

	-- Energy Production Multiplier
	if uDef.energymake then
		local x = modOptions.multiplier_energyproduction * modOptions.multiplier_resourceincome
		uDef.energymake = uDef.energymake * x
		if uDef.energystorage then
			uDef.energystorage = uDef.energystorage * x
		end
	end
	if uDef.windgenerator and uDef.windgenerator > 0 then
		local x = modOptions.multiplier_energyproduction * modOptions.multiplier_resourceincome
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
		local x = modOptions.multiplier_energyproduction * modOptions.multiplier_resourceincome
		uDef.tidalgenerator = uDef.tidalgenerator * x
		if uDef.energystorage then
			uDef.energystorage = uDef.energystorage * x
		end
	end
	if uDef.energyupkeep and uDef.energyupkeep < 0 then
		-- units with negative upkeep means they produce energy when "on".
		local x = modOptions.multiplier_energyproduction * modOptions.multiplier_resourceincome
		uDef.energyupkeep = uDef.energyupkeep * x
		if uDef.energystorage then
			uDef.energystorage = uDef.energystorage * x
		end
	end

	-- Energy Conversion Multiplier
	if uDef.customparams.energyconv_capacity and uDef.customparams.energyconv_efficiency then
		local x = modOptions.multiplier_energyconversion * modOptions.multiplier_resourceincome
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
		local x = modOptions.multiplier_losrange
		if x ~= 1 then
			uDef.sightdistance = uDef.sightdistance * x
		end
	end

	if uDef.airsightdistance then
		local x = modOptions.multiplier_losrange
		if x ~= 1 then
			uDef.airsightdistance = uDef.airsightdistance * x
		end
	end

	if uDef.radardistance then
		local x = modOptions.multiplier_radarrange
		if x ~= 1 then
			uDef.radardistance = uDef.radardistance * x
		end
	end

	if uDef.sonardistance then
		local x = modOptions.multiplier_radarrange
		if x ~= 1 then
			uDef.sonardistance = uDef.sonardistance * x
		end
	end

	-- add model vertex displacement
	local vertexDisplacement = 5.5 + ((uDef.footprintx + uDef.footprintz) / 12)
	if vertexDisplacement > 10 then
		vertexDisplacement = 10
	end
	uDef.customparams.vertdisp = 1.0 * vertexDisplacement
	uDef.customparams.healthlookmod = 0

	-- Animation Cleanup
	if modOptions.animationcleanup  then
		if uDef.script then
			local oldscript = uDef.script:lower()
			if oldscript:find(".cob", nil, true) and (not oldscript:find("_clean.", nil, true)) then
				local newscript = string.sub(oldscript, 1, -5) .. "_clean.cob"
				if VFS.FileExists('scripts/'..newscript) then
					Spring.Echo("Using new script for", name, oldscript, '->', newscript)
					uDef.script = newscript
				else
					Spring.Echo("Unable to find new script for", name, oldscript, '->', newscript, "using old one")
				end
			end
		end
	end

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
		soundVolume = soundVolume * 0.5
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
	local modOptions = Spring.GetModOptions()

	if not SaveDefsToCustomParams then
		-------------- EXPERIMENTAL MODOPTIONS

		-- Standard Gravity
		local gravityOverwriteExemptions = { --add the name of the weapons (or just the name of the unit followed by _ ) to this table to exempt from gravity standardization.
			'cormship_', 'armmship_'
		}
		if wDef.gravityaffected == "true" and wDef.mygravity == nil then
			local isExempt = false

			for _, exemption in ipairs(gravityOverwriteExemptions) do
				if string.find(name, exemption) then
					isExempt = true
					break
				end
			end
			if not isExempt then
				wDef.mygravity = 0.1445
			end
		end

		----EMP rework

		if modOptions.emprework then
			if name == 'empblast' then
				wDef.areaofeffect = 350
				wDef.edgeeffectiveness = 0.6
				wDef.paralyzetime = 12
				wDef.damage.default = 50000
			end
			if name == 'spybombx' then
				wDef.areaofeffect = 350
				wDef.edgeeffectiveness = 0.4
				wDef.paralyzetime = 20
				wDef.damage.default = 16000
			end
			if name == 'spybombxscav' then
				wDef.edgeeffectiveness = 0.50
				wDef.paralyzetime = 12
				wDef.damage.default = 35000
			end
		end

		--Air rework
		if modOptions.air_rework == true then
			if wDef.weapontype == "BeamLaser" then
				wDef.damage.vtol = wDef.damage.default * 0.25
			end
			if wDef.range == 300 and wDef.reloadtime == 0.4 then
				--comm lasers
				wDef.damage.vtol = wDef.damage.default
			end
			if wDef.weapontype == "Cannon" and wDef.damage.default ~= nil then
				wDef.damage.vtol = wDef.damage.default * 0.35
			end
		end

		--[[Skyshift: Air rework
		if Spring.GetModOptions().skyshift == true then
			skyshiftUnits = VFS.Include("unitbasedefs/skyshiftunits_post.lua")
			wDef = skyshiftUnits.skyshiftWeaponTweaks(name, wDef)
		end]]

		---- SHIELD CHANGES

		if wDef.weapontype == "DGun" then
			wDef.interceptedbyshieldtype = 512 --make dgun (like behemoth) interceptable by shields, optionally
		elseif wDef.weapontype == "StarburstLauncher" and not string.find(name, "raptor") then
			wDef.interceptedbyshieldtype = 1024 --separate from combined MissileLauncher, except raptors
		end

		local shieldModOption = modOptions.experimentalshields

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

		--Shields Rework
		if modOptions.shieldsrework == true then
			-- To compensate for always taking full damage from projectiles in contrast to bounce-style only taking partial
			local shieldPowerMultiplier = 1.9
			local shieldRegenMultiplier = 2.5
			local shieldRechargeCostMultiplier = 1

			-- For balance, paralyzers need to do reduced damage to shields, as their raw raw damage is outsized
			local paralyzerShieldDamageMultiplier = 0.25

			-- VTOL's may or may not do full damage to shields if not defined in weapondefs
			local vtolShieldDamageMultiplier = 0

			local shieldCollisionExemptions = { --add the name of the weapons (or just the name of the unit followed by _ ) to this table to exempt from shield collision.
			'corsilo_', 'armsilo_', 'armthor_empmissile', 'armemp_', 'cortron_', 'corjuno_', 'armjuno_',
			}

			if wDef.damage ~= nil then
				-- Due to the engine not handling overkill damage, we have to store the original shield damage values as a customParam for unit_shield_behavior.lua to reference
				wDef.customparams = wDef.customparams or {}
				if wDef.damage.shields then
					wDef.customparams.shield_damage = wDef.damage.shields
				elseif wDef.damage.default then
					wDef.customparams.shield_damage = wDef.damage.default
				elseif wDef.damage.vtol then
					wDef.customparams.shield_damage = wDef.damage.vtol * vtolShieldDamageMultiplier
				else
					wDef.customparams.shield_damage = 0
				end

				if wDef.paralyzer then
					wDef.customparams.shield_damage = wDef.customparams.shield_damage * paralyzerShieldDamageMultiplier
				end

				-- Set damage to 0 so projectiles always collide with shield. Without this, if damage > shield charge then it passes through.
				-- Applying damage is instead handled in unit_shield_behavior.lua
				wDef.damage.shields = 0

				if wDef.beamtime and wDef.beamtime > 1 / Game.gameSpeed then
					 -- This splits up the damage of hitscan weapons over the duration of beamtime, as each frame counts as a hit in ShieldPreDamaged() callin
					 -- Math.floor is used to sheer off the extra digits of the number of frames that the hits occur
					wDef.customparams.beamtime_damage_reduction_multiplier = 1 / math.floor(wDef.beamtime * Game.gameSpeed)
				end
			end

			if wDef.shield then
				wDef.shield.exterior = true
				if wDef.shield.repulser == true then --isn't an evocom
					wDef.shield.powerregen = wDef.shield.powerregen * shieldRegenMultiplier
					wDef.shield.power = wDef.shield.power * shieldPowerMultiplier
					wDef.shield.powerregenenergy = wDef.shield.powerregenenergy * shieldRechargeCostMultiplier
				end
				wDef.shield.repulser = false
			end

			if ((not wDef.interceptedbyshieldtype or wDef.interceptedbyshieldtype ~= 1) and wDef.weapontype ~= "Cannon") then
				wDef.customparams = wDef.customparams or {}
				wDef.customparams.shield_aoe_penetration = true
			end

			for _, exemption in ipairs(shieldCollisionExemptions) do
				if string.find(name, exemption) then
					wDef.interceptedbyshieldtype = 0
					wDef.customparams.shield_aoe_penetration = true
					break
				end
			end
		end

		if modOptions.multiplier_shieldpower then
			if wDef.shield then
				local multiplier = modOptions.multiplier_shieldpower
				if wDef.shield.power then
					wDef.shield.power = wDef.shield.power * multiplier
				end
				if wDef.shield.powerregen then
					wDef.shield.powerregen = wDef.shield.powerregen * multiplier
				end
				if wDef.shield.powerregenenergy then
					wDef.shield.powerregenenergy = wDef.shield.powerregenenergy * multiplier
				end
				if wDef.shield.startingpower then
					wDef.shield.startingpower = wDef.shield.startingpower * multiplier
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
			wDef.cratermult = (wDef.cratermult or 0) + wDef.craterareaofeffect / 2000
		end

		-- Target borders of unit hitboxes rather than center (-1 = far border, 0 = center, 1 = near border)
		-- wDef.targetborder = 1.0

		if wDef.weapontype == "Cannon" then
			if not wDef.model then
				-- do not cast shadows on plasma shells
				wDef.castshadow = false
			end

			if wDef.stages == nil then
				wDef.stages = 10
				if wDef.damage ~= nil and wDef.damage.default ~= nil and wDef.areaofeffect ~= nil then
					wDef.stages = math.floor(7.5 + math.min(wDef.damage.default * 0.0033, wDef.areaofeffect * 0.13))
					wDef.alphadecay = 1 - ((1 / wDef.stages) / 1.5)
					wDef.sizedecay = 0.4 / wDef.stages
				end
			end
		end

		if modOptions.xmas and wDef.weapontype == "StarburstLauncher" and wDef.model and VFS.FileExists('objects3d\\candycane_' .. wDef.model) then
			wDef.model = 'candycane_' .. wDef.model
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
				wDef.laserflaresize = wDef.laserflaresize * 1.15        -- note: thickness affects this too
			end
			wDef.texture1 = "largebeam"        -- The projectile texture
			wDef.texture3 = "flare2"    -- Flare texture for #BeamLaser
			wDef.texture4 = "flare2"    -- Flare texture for #BeamLaser with largeBeamLaser = true
		end

		-- scavengers
		if string.find(name, '_scav') then
			VFS.Include("gamedata/scavengers/weapondef_post.lua")
			wDef = scav_Wdef_Post(name, wDef)
		end

		ProcessSoundDefaults(wDef)
	end

	-- Multipliers

	-- Weapon Range
	local rangeMult = modOptions.multiplier_weaponrange
	if rangeMult ~= 1 then
		if wDef.range then
			wDef.range = wDef.range * rangeMult
		end
		if wDef.flighttime then
			wDef.flighttime = wDef.flighttime * (rangeMult * 1.5)
		end
		if wDef.weaponvelocity and wDef.weapontype == "Cannon" and wDef.gravityaffected == "true" then
			wDef.weaponvelocity = wDef.weaponvelocity * math.sqrt(rangeMult)
		end
		if wDef.weapontype == "StarburstLauncher" and wDef.weapontimer then
			wDef.weapontimer = wDef.weapontimer + (wDef.weapontimer * ((rangeMult - 1) * 0.4))
		end
	end

	-- Weapon Damage
	local damageMult = modOptions.multiplier_weapondamage
	if damageMult ~= 1 then
		if wDef.damage then
			for damageClass, damageValue in pairs(wDef.damage) do
				wDef.damage[damageClass] = wDef.damage[damageClass] * damageMult
			end
		end
	end

	-- ExplosionSpeed is calculated same way engine does it, and then doubled
	-- Note that this modifier will only effect weapons fired from actual units, via super clever hax of using the weapon name as prefix
	if wDef.damage and wDef.damage.default then
		if string.find(name, '_', nil, true) then
			local prefix = string.sub(name, 1, 3)
			if prefix == 'arm' or prefix == 'cor' or prefix == 'leg' or prefix == 'rap' then
				local globaldamage = math.max(30, wDef.damage.default / 20)
				local defExpSpeed = (8 + (globaldamage * 2.5)) / (9 + (math.sqrt(globaldamage) * 0.70)) * 0.5
				wDef.explosionSpeed = defExpSpeed * 2
			end
		end
	end
end

-- process effects
function ExplosionDef_Post(name, eDef)

end

--------------------------
-- MODOPTIONS
-------------------------

-- process modoptions (last, because they should not get baked)
function ModOptions_Post (UnitDefs, WeaponDefs)

	-- transporting enemy coms
	if Spring.GetModOptions().transportenemy == "notcoms" then
		for name, ud in pairs(UnitDefs) do
			if ud.customparams.iscommander then
				ud.transportbyenemy = false
			end
		end
	elseif Spring.GetModOptions().transportenemy == "none" then
		for name, ud in pairs(UnitDefs) do
			ud.transportbyenemy = false
		end
	end

	-- For Decals GL4, disables default groundscars for explosions
	for _, wDef in pairs(WeaponDefs) do
		wDef.explosionScar = false
	end
end
