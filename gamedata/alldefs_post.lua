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

		if modOptions.unit_restrictions_noair and not uDef.customparams.ignore_noair then
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
			uDef.buildoptions[numBuildoptions + 4] = "corprince" -- Black Prince - Shore bombardment battleship
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
			uDef.buildoptions[numBuildoptions + 4] = "legeheatraymech_old" -- Old Sol Invictus - Quad Heatray Mech
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
				--uDef.attackrunlength = 32
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

	----------------
	-- Tech Split --
	----------------

	if modOptions.techsplit then
    	-- Bot and Veh lab reworks
		-- T2 lab cost will be increased to around 4k metal
		-- New labs are created - "ha" for half-advanced, called enhanced (placeholder). Tier between T1 and T2
		-- Enhanced labs are given amphibious vehicles and the most expensive T1 + least expensive T2.
		-- Specialty T1 mexes are changed to enhanced mexes with 2x metal income + special aabilities (for faction differentiation)
		if name == "coralab" then
			uDef.buildoptions = {
				[1] = "corack",
				[2] = "coraak",
				[3] = "cormort",
				[4] = "corcan",
				[5] = "corpyro",
				[6] = "corspy",
				[7] = "coramph",
				[8] = "cormando",
				[9] = "cortermite",
				[10] = "corhrk",
				[11] = "corvoyr",
				[12] = "corroach",
			}

		elseif name == "armalab" then
			uDef.buildoptions = {
				[1] = "armack",
				[2] = "armfido",
				[3] = "armaak",
				[4] = "armzeus",
				[5] = "armmav",
				[6] = "armamph",
				[7] = "armspid",
				[8] = "armfast",
				[9] = "armvader",
				[10] = "armmark",
				[11] = "armsptk",
				[12] = "armspy",
			}

		elseif name == "legalab" then
			uDef.buildoptions = {
				[1] = "legack",
				[2] = "legadvaabot",
				[3] = "legstr",
				[4] = "legshot",
				[5] = "leginfestor",
				[6] = "legamph",
				[7] = "legsnapper",
				[8] = "legbart",
				[9] = "leghrk",
				[10] = "legaspy",

			}

		elseif name == "armavp" then
			uDef.buildoptions = {
				[1] = "armacv",
				[2] = "armch",
				[3] = "armcroc",
				[4] = "armlatnk",
				[5] = "armah",
				[6] = "armmart",
				[7] = "armseer",
				[8] = "armmh",
				[9] = "armanac",
				[10] = "armsh",
				[11] = "armgremlin"
			}
		
		elseif name == "coravp" then
			uDef.buildoptions = {
				[1] = "corch",
				[2] = "coracv",
				[3] = "corsala",
				[4] = "correap",
				[5] = "cormart",
				[6] = "corhal",
				[7] = "cormh",
				[8] = "corsnap",
				[9] = "corah",
				[10] = "corsh",
				[11] = "corvrad",
				[12] = "corban"
			}

		elseif name == "legavp" then
			uDef.buildoptions = {
				[1] = "legacv",
				[2] = "legch",
				[3] = "legcar",
				[4] = "legmlv",
				[5] = "legmrv",
				[6] = "legfloat",
				[7] = "legaskirmtank",
				[8] = "legamcluster",
				[9] = "legvcarry",
				[10] = "legner",
				[11] = "legmh",
				[12] = "legah"
			}


		-- Con Reworks
		-- T1 constructors are given basic/low cost build options
		-- T2 constructors get advanced/high cost build options
		-- T3 constructors get experimental/expensive build options
		elseif name == "armck" then
			uDef.buildoptions = {
				[1] = "armsolar",
				[2] = "armwin",
				[3] = "armamex",
				[4] = "armmstor",
				[5] = "armestor",
				[6] = "armmex",
				[7] = "armmakr",
				[8] = "armalab",
				[9] = "armlab",
				[10] = "armvp",
				[11] = "armap",
				[12] = "armnanotc",
				[13] = "armeyes",
				[14] = "armrad",
				[15] = "armdrag",
				[16] = "armllt",
				[17] = "armrl",
				[18] = "armdl",
				[19] = "armjamt",
				[22] = "armsy",
				[23] = "armgeo",
				[24] = "armbeamer",
				[25] = "armhlt",
				[26] = "armferret",
				[27] = "armclaw",
				[28] = "armjuno",
				[29] = "armadvsol",
				[30] = "armguard"
			}

		elseif name == "corck" then
			uDef.buildoptions = {
				[1] = "corsolar",
				[2] = "corwin",
				[3] = "cormstor",
				[4] = "corestor",
				[5] = "cormex",
				[6] = "cormakr",
				[10] = "corlab",
				[11] = "coralab",
				[12] = "corvp",
				[13] = "corap",
				[14] = "cornanotc",
				[15] = "coreyes",
				[16] = "cordrag",
				[17] = "corllt",
				[18] = "corrl",
				[19] = "corrad",
				[20] = "cordl",
				[21] = "corjamt",
				[22] = "corsy",
				[23] = "corexp",
				[24] = "corgeo",
				[25] = "corhllt",
				[26] = "corhlt",
				[27] = "cormaw",
				[28] = "cormadsam",
				[29] = "coradvsol",
				[30] = "corpun"
			}

		elseif name == "legck" then
			uDef.buildoptions = {
				[1]  = "legsolar",
				[2]  = "legwin",
				[3]  = "leggeo",
				[4]  = "legmstor",
				[5]  = "legestor",
				[6]  = "legmex",
				[7]  = "legeconv",
				[9]  = "leglab",
				[10] = "legalab",
				[11] = "legvp",
				[12] = "legap",
				[13] = "leghp",
				[14] = "legnanotc",
				[15] = "legeyes",
				[16] = "legrad",
				[17] = "legdrag",
				[18] = "leglht",
				[20] = "legrl",
				[21] = "legctl",
				[22] = "legjam",
				[23] = "corsy",
			}

		elseif name == "armack" then
			uDef.mass = 2700
			uDef.buildoptions = {
				[1] = "armadvsol",
				[2] = "armmoho",
				[3] = "armbeamer",
				[4] = "armhlt",
				[5] = "armguard",
				[6] = "armferret",
				[7] = "armcir",
				[8] = "armjuno",
				[9] = "armclaw",
				[10] = "armarad",
				[11] = "armveil",
				[12] = "armfus",
				[13] = "armgmm",
				[14] = "armhalab",
				[15] = "armlab",
				[16] = "armalab",
				[17] = "armsd",
				[18] = "armmakr",
				[19] = "armestor",
				[20] = "armmstor",
				[21] = "armageo",
				[22] = "armckfus",
				[23] = "armdl",
				[24] = "armdf",
				[25] = "armvp",
				[26] = "armsy",
				[27] = "armap",
			}

		elseif name == "corack" then
			uDef.mass = 2700
			uDef.buildoptions = {
				[1] = "coradvsol",
				[2] = "cormoho",
				[3] = "cormaw",
				[4] = "corhllt",
				[5] = "corpun",
				[6] = "cormadsam",
				[7] = "corerad",
				[8] = "corjuno",
				[9] = "corfus",
				[10] = "corarad",
				[11] = "corshroud",
				[12] = "corsd",
				[13] = "corlab",
				[14] = "corhalab",
				[15] = "coralab",
				[16] = "cormakr",
				[17] = "corestor",
				[18] = "cormstor",
				[19] = "corageo",
				[20] = "corhlt",
				[21] = "cordl",
				[22] = "corvp",
				[23] = "corap",
				[24] = "corsy",
			}

		elseif name == "legack" then
			uDef.mass = 2700
			uDef.buildoptions = {
				[1] = "legadvsol",
				[2] = "legmext15",
				[3] = "legdtr",
				[4] = "legmg",
				[5] = "legrhapsis",
				[6] = "leglupara",
				[7] = "legjuno",
				[8] = "leghive",
				[9] = "legfus",
				[10] = "legarad",
				[11] = "legajam",
				[12] = "legsd",
				[13] = "leglab",
				[14] = "legalab",
				[15] = "leghalab",
				[16] = "legcluster",
				[17] = "legeconv"
			}

		elseif name == "armcv" then
			uDef.buildoptions = {
				[1] = "armsolar",
				[2] = "armwin",
				[3] = "armamex",
				[4] = "armmstor",
				[5] = "armestor",
				[6] = "armmex",
				[7] = "armmakr",
				[8] = "armavp",
				[9] = "armlab",
				[10] = "armvp",
				[11] = "armap",
				[12] = "armnanotc",
				[13] = "armeyes",
				[14] = "armrad",
				[15] = "armdrag",
				[16] = "armllt",
				[17] = "armrl",
				[18] = "armdl",
				[19] = "armjamt",
				[22] = "armsy",
				[23] = "armgeo",
				[24] = "armbeamer",
				[25] = "armhlt",
				[26] = "armferret",
				[27] = "armclaw",
				[28] = "armjuno",
				[29] = "armadvsol",
				[30] = "armguard"
			}

		elseif name == "armbeaver" then
			uDef.buildoptions = {
				[1] = "armsolar",
				[2] = "armwin",
				[3] = "armamex",
				[4] = "armmstor",
				[5] = "armestor",
				[6] = "armmex",
				[7] = "armmakr",
				[8] = "armavp",
				[9] = "armlab",
				[10] = "armvp",
				[11] = "armap",
				[12] = "armnanotc",
				[13] = "armeyes",
				[14] = "armrad",
				[15] = "armdrag",
				[16] = "armllt",
				[17] = "armrl",
				[18] = "armdl",
				[19] = "armjamt",
				[20] = "armsy",
				[21] = "armtide",
				[22] = "armfmkr",
				[23] = "armasy",
				[24] = "armfrt",
				[25] = "armtl",
				[26] = "armgeo",
				[27] = "armbeamer",
				[27] = "armhlt",
				[28] = "armferret",
				[29] = "armclaw",
				[30] = "armjuno",
				[31] = "armfrad",
				[32] = "armadvsol",
				[33] = "armguard"
			}

		elseif name == "corcv" then
			uDef.buildoptions = {
				[1] = "corsolar",
				[2] = "corwin",
				[3] = "cormstor",
				[4] = "corestor",
				[5] = "cormex",
				[6] = "cormakr",
				[10] = "corlab",
				[11] = "coravp",
				[12] = "corvp",
				[13] = "corap",
				[14] = "cornanotc",
				[15] = "coreyes",
				[16] = "cordrag",
				[17] = "corllt",
				[18] = "corrl",
				[19] = "corrad",
				[20] = "cordl",
				[21] = "corjamt",
				[22] = "corsy",
				[23] = "corexp",
				[24] = "corgeo",
				[25] = "corhllt",
				[26] = "corhlt",
				[27] = "cormaw",
				[28] = "cormadsam",
				[29] = "coradvsol",
				[30] = "corpun"
			}

		elseif name == "cormuskrat" then
			uDef.buildoptions = {
				[1] = "corsolar",
				[2] = "corwin",
				[3] = "cormstor",
				[4] = "corestor",
				[5] = "cormex",
				[6] = "cormakr",
				[7] = "corlab",
				[8] = "coravp",
				[9] = "corvp",
				[10] = "corap",
				[11] = "cornanotc",
				[12] = "coreyes",
				[13] = "cordrag",
				[14] = "corllt",
				[15] = "corrl",
				[16] = "corrad",
				[17] = "cordl",
				[18] = "corjamt",
				[19] = "corsy",
				[20] = "corexp",
				[21] = "corgeo",
				[22] = "corhllt",
				[23] = "corhlt",
				[24] = "cormaw",
				[25] = "cormadsam",
				[26] = "corfrad",
				[27] = "cortide",
				[28] = "corasy",
				[29] = "cortl",
				[30] = "coradvsol",
				[31] = "corpun"
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
				[8] = "leglab",
				[9] = "legavp",
				[10] = "legvp",
				[11] = "legap",
				[12] = "leghp",
				[13] = "legnanotc",
				[14] = "legeyes",
				[15] = "legrad",
				[16] = "legdrag",
				[17] = "leglht",
				[18] = "legrl",
				[19] = "legctl",
				[20] = "legjam",
				[21] = "corsy",
			}
		
		elseif name == "armacv" then
			uDef.mass = 2700
			uDef.buildoptions = {
				[1] = "armadvsol",
				[2] = "armmoho",
				[3] = "armbeamer",
				[4] = "armhlt",
				[5] = "armguard",
				[6] = "armferret",
				[7] = "armcir",
				[8] = "armjuno",
				[9] = "armclaw",
				[10] = "armarad",
				[11] = "armveil",
				[12] = "armfus",
				[13] = "armgmm",
				[14] = "armhavp",
				[15] = "armlab",
				[16] = "armavp",
				[17] = "armsd",
				[18] = "armmakr",
				[19] = "armestor",
				[20] = "armmstor",
				[21] = "armageo",
				[22] = "armckfus",
				[23] = "armdl",
				[24] = "armdf",
				[25] = "armvp",
				[26] = "armsy",
				[27] = "armap",
			}
		
		elseif name == "coracv" then
			uDef.mass = 2700
			uDef.buildoptions = {
				[1] = "coradvsol",
				[2] = "cormoho",
				[3] = "cormaw",
				[4] = "corhllt",
				[5] = "corpun",
				[6] = "cormadsam",
				[7] = "corerad",
				[8] = "corjuno",
				[9] = "corfus",
				[10] = "corarad",
				[11] = "corshroud",
				[12] = "corsd",
				[13] = "corvp",
				[14] = "corhavp",
				[15] = "coravp",
				[16] = "cormakr",
				[17] = "corestor",
				[18] = "cormstor",
				[19] = "corageo",
				[20] = "corhlt",
				[21] = "cordl",
				[22] = "corlab",
				[23] = "corap",
				[24] = "corsy",
			}
		
		elseif name == "legacv" then
			uDef.mass = 2700
			uDef.buildoptions = {
				[1] = "legadvsol",
				[2] = "legmext15",
				[3] = "legdtr",
				[4] = "legmg",
				[5] = "legrhapsis",
				[6] = "leglupara",
				[7] = "legjuno",
				[8] = "leghive",
				[9] = "legfus",
				[10] = "legarad",
				[11] = "legajam",
				[12] = "legsd",
				[13] = "leghavp",
				[14] = "legavp",
				[15] = "legvp",
				[16] = "legcluster",
				[17] = "legeconv"
			}
		end

		------------------------------
		-- Armada and Cortex Air Split

		-- Air Labs

		if name == "armaap" then
			uDef.buildpic = "ARMHAAP.DDS"
			uDef.objectname = "Units/ARMAAPLAT.s3o"
			uDef.script = "Units/techsplit/ARMHAAP.cob"
			uDef.customparams.buildinggrounddecaltype = "decals/armamsub_aoplane.dds"
			uDef.customparams.buildinggrounddecalsizex = 13
			uDef.customparams.buildinggrounddecalsizey = 13
			uDef.featuredefs.dead["object"] = "Units/armaaplat_dead.s3o"
			uDef.buildoptions = {
				[1] = "armaca",
				[2] = "armseap",			
				[3] = "armsb",
				[4] = "armsfig",
				[5] = "armsehak",
				[6] = "armsaber",
				[7] = "armhvytrans"
			}
			uDef.sfxtypes = {
				explosiongenerators = {
					[1] = "custom:radarpulse_t1_slow",
				},
				pieceexplosiongenerators = {
					[1] = "deathceg2",
					[2] = "deathceg3",
					[3] = "deathceg4",
				},
			}
			uDef.sounds = {
				build = "seaplok1",
				canceldestruct = "cancel2",
				underattack = "warning1",
				unitcomplete = "untdone",
				count = {
					[1] = "count6",
					[2] = "count5",
					[3] = "count4",
					[4] = "count3",
					[5] = "count2",
					[6] = "count1",
				},
				select = {
					[1] = "seaplsl1",
				},
			}

		elseif name == "coraap" then
			uDef.buildpic = "CORHAAP.DDS"
			uDef.objectname = "Units/CORAAPLAT.s3o"
			uDef.script = "Units/CORHAAP.cob"
			uDef.buildoptions = {
				[1] = "coraca",
				[2] = "corhunt",
				[3] = "corcut",
				[4] = "corsb",
				[5] = "corseap",
				[6] = "corsfig",
				[7] = "corhvytrans",
			}
			uDef.featuredefs.dead["object"] = "Units/coraaplat_dead.s3o"
			uDef.customparams.buildinggrounddecaltype = "decals/coraap_aoplane.dds"
			uDef.customparams.buildinggrounddecalsizex = 6
			uDef.customparams.buildinggrounddecalsizey = 6
			uDef.customparams.sfxtypes = {
				pieceexplosiongenerators = {
					[1] = "deathceg2",
					[2] = "deathceg3",
					[3] = "deathceg4",
				},
			}
			uDef.customparams.sounds = {
				build = "seaplok2",
				canceldestruct = "cancel2",
				underattack = "warning1",
				unitcomplete = "untdone",
				count = {
					[1] = "count6",
					[2] = "count5",
					[3] = "count4",
					[4] = "count3",
					[5] = "count2",
					[6] = "count1",
				},
				select = {
					[1] = "seaplsl2",
				},
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
				[3] = "armmstor",
				[4] = "armestor",
				[5] = "armmex",
				[6] = "armmakr",
				[7] = "armaap",
				[8] = "armlab",
				[9] = "armvp",
				[10] = "armap",
				[11] = "armnanotc",
				[12] = "armeyes",
				[13] = "armrad",
				[14] = "armdrag",
				[15] = "armllt",
				[16] = "armrl",
				[17] = "armdl",
				[18] = "armjamt",
				[19] = "armsy",
				[20] = "armamex",
				[21] = "armgeo",
				[22] = "armbeamer",
				[23] = "armhlt",
				[24] = "armferret",
				[25] = "armclaw",
				[26] = "armjuno",
				[27] = "armadvsol",
				[30] = "armguard"
			}


		elseif name == "corca" then	
			uDef.buildoptions = {
				[1] = "corsolar",
				[2] = "corwin",
				[3] = "cormstor",
				[4] = "corestor",
				[5] = "cormex",
				[6] = "cormakr",
				[10] = "corlab",
				[11] = "coraap",
				[12] = "corvp",
				[13] = "corap",
				[14] = "cornanotc",
				[15] = "coreyes",
				[16] = "cordrag",
				[17] = "corllt",
				[18] = "corrl",
				[19] = "corrad",
				[20] = "cordl",
				[21] = "corjamt",
				[22] = "corsy",
				[23] = "corexp",
				[24] = "corgeo",
				[25] = "corhllt",
				[26] = "corhlt",
				[27] = "cormaw",
				[28] = "cormadsam",
				[29] = "coradvsol",
				[30] = "corpun"
			}

		elseif name == "armaca" then
			uDef.buildpic = "ARMCSA.DDS"
			uDef.objectname = "Units/ARMCSA.s3o"
			uDef.script = "units/ARMCSA.cob"
			uDef.buildoptions = {
				[1] = "armadvsol",
				[2] = "armmoho",
				[3] = "armbeamer",
				[4] = "armhlt",
				[5] = "armguard",
				[6] = "armferret",
				[7] = "armcir",
				[8] = "armjuno",
				[9] = "armclaw",
				[10] = "armarad",
				[11] = "armveil",
				[12] = "armfus",
				[13] = "armgmm",
				[14] = "armhaap",
				[15] = "armlab",
				[16] = "armalab",
				[17] = "armsd",
				[18] = "armmakr",
				[19] = "armestor",
				[20] = "armmstor",
				[21] = "armageo",
				[22] = "armckfus",
				[23] = "armdl",
				[24] = "armdf",
				[25] = "armvp",
				[26] = "armsy",
				[27] = "armap",
			}
		
		elseif name == "coraca" then
			uDef.buildpic = "CORCSA.DDS"
			uDef.objectname = "Units/CORCSA.s3o"
			uDef.script = "units/CORCSA.cob"
			uDef.buildoptions = {
				[1] = "coradvsol",
				[2] = "cormoho",
				[3] = "cormaw",
				[4] = "corhllt",
				[5] = "corpun",
				[6] = "cormadsam",
				[7] = "corerad",
				[8] = "corjuno",
				[9] = "corfus",
				[10] = "corarad",
				[11] = "corshroud",
				[12] = "corsd",
				[13] = "corap",
				[14] = "corhaap",
				[15] = "coraap",
				[16] = "cormakr",
				[17] = "corestor",
				[18] = "cormstor",
				[19] = "corageo",
				[20] = "corhlt",
				[21] = "cordl",
				[22] = "corvp",
				[23] = "corlab",
				[24] = "corsy",
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
				[10] = "legvp",
				[11] = "legap",
				[12] = "leghp",
				[13] = "legnanotc",
				[14] = "legeyes",
				[15] = "legrad",
				[16] = "legdrag",
				[17] = "leglht",
				[18] = "legrl",
				[19] = "legctl",
				[20] = "legjam",
				[21] = "corsy",
			}
		end
		
		------------
		-- Sea Split

		-- Sea Labs

		if name == "armasy" then
			uDef.buildoptions = {
				[1] = "armacsub",
				[2] = "armmship",
				[3] = "armcrus",
				[4] = "armsubk",
				[5] = "armah",
				[6] = "armlship",
				[7] = "armcroc",
				[8] = "armsh",
				[9] = "armanac",
				[10] = "armch",
				[11] = "armmh",
				[12] = "armsjam"
			}

		elseif name == "corasy" then
			uDef.buildoptions = {		
				[1] = "coracsub",
				[2] = "corcrus",
				[3] = "corshark",
				[4] = "cormship",
				[5] = "corfship",
				[6] = "corah",
				[7] = "corsala",
				[8] = "corsnap",
				[9] = "corsh",
				[10] = "corch",
				[11] = "cormh",
				[12] = "corsjam",
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
				[8] = "armtide",
				[9] = "armuwgeo",
				[10] = "armfmkr",
				[11] = "armuwms",
				[12] = "armuwes",
				[13] = "armsy",
				[14] = "armnanotcplat",
				[15] = "armasy",
				[16] = "armfrad",
				[17] = "armfdrag",
				[18] = "armtl",
				[19] = "armfrt",
				[20] = "armfhlt",
				[21] = "armbeamer",
				[22] = "armclaw",
				[23] = "armferret",
				[24] = "armjuno",
				[25] = "armguard",
			}

		elseif name == "corcs" then
			uDef.buildoptions = {
				[1] = "cormex",
				[2] = "corvp",
				[3] = "corap",
				[4] = "corlab",
				[5] = "coreyes",
				[6] = "cordl",
				[7] = "cordrag",
				[8] = "cortide",
				[9] = "corfmkr",
				[10] = "coruwms",
				[11] = "coruwes",
				[12] = "corsy",
				[13] = "cornanotcplat",
				[14] = "corasy",
				[15] = "corfrad",
				[16] = "corfdrag",
				[17] = "cortl",
				[18] = "corfrt",
				[19] = "cormadsam",
				[20] = "corfhlt",
				[21] = "corhllt",
				[22] = "cormaw",
				[23] = "coruwgeo",
				[24] = "corjuno",
				[30] = "corpun"
			}

		elseif name == "armacsub" then
			uDef.mass = 2700
			uDef.buildoptions = {
				[1] = "armtide",
				[2] = "armuwageo",
				[3] = "armveil",
				[4] = "armarad",
				[5] = "armclaw",
				[7] = "armasy",
				[8] = "armguard",
				[9] = "armfhlt",
				[10] = "armhasy",
				[11] = "armfmkr",
				[12] = "armason",
				[13] = "armuwfus",
				[17] = "armfdrag",
				[18] = "armsy",
				[19] = "armuwmme",
				[20] = "armatl",
				[21] = "armkraken",
				[22] = "armfrt",
				[23] = "armuwes",
				[24] = "armuwms",
				[25] = "armhaapuw",
				[26] = "armvp",
				[27] = "armlab",
				[28] = "armap",
				[29] = "armferret",
				[30] = "armcir",
				[31] = "armsd",
			}

		elseif name == "coracsub" then
			uDef.mass = 2700
			uDef.buildoptions = {
				[1] = "cortide",
				[2] = "coruwmme",
				[3] = "corshroud",
				[4] = "corarad",
				[5] = "cormaw",
				[6] = "corsy",
				[7] = "corasy",
				[8] = "corhasy",
				[9] = "corfhlt",
				[10] = "corpun",
				[11] = "corason",
				[12] = "coruwfus",
				[13] = "corfmkr",
				[14] = "corfdrag",
				[15] = "corfrt",
				[16] = "coruwes",
				[17] = "coruwms",
				[18] = "coruwageo",
				[19] = "corhaapuw",
				[20] = "coratl",
				[21] = "corsd",
				[22] = "corvp",
				[23] = "corlab",
				[24] = "corsy",
				[25] = "corasy",
			}
		end

		-- T4
		if name == "armshltx" then
			uDef.footprintx = 15
			uDef.footprintz = 15
			uDef.collisionvolumescales = "225 150 205"
			uDef.yardmap = "ooooooooooooooo ooooooooooooooo ooooooooooooooo ooooooooooooooo ooooooooooooooo ooooooooooooooo ooooooooooooooo eeeeeeeeeeeeeee eeeeeeeeeeeeeee eeeeeeeeeeeeeee eeeeeeeeeeeeeee eeeeeeeeeeeeeee eeeeeeeeeeeeeee eeeeeeeeeeeeeee eeeeeeeeeeeeeee"
			uDef.objectname = "Units/ARMSHLTXBIG.s3o"
			uDef.script = "Units/techsplit/ARMSHLTXBIG.cob"
			uDef.featuredefs.armshlt_dead.object = "Units/armshltxbig_dead.s3o"
			uDef.featuredefs.armshlt_dead.footprintx = 11
			uDef.featuredefs.armshlt_dead.footprintz = 11
			uDef.featuredefs.armshlt_dead.collisionvolumescales = "155 95 180"
			uDef.customparams.techlevel = 4
			uDef.customparams.buildinggrounddecalsizex = 18
			uDef.customparams.buildinggrounddecalsizez = 18
		end 

		if name == "corgant" then
			uDef.footprintx = 15
			uDef.footprintz = 15
			uDef.collisionvolumescales = "245 135 245"
			uDef.yardmap = "oooooooooooooo ooooooooooooooo ooooooooooooooo ooooooooooooooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo"
			uDef.objectname = "Units/CORGANTBIG.s3o"
			uDef.script = "Units/techsplit/CORGANTBIG.cob"
			uDef.featuredefs.dead.object = "Units/corgant_dead.s3o"
			uDef.featuredefs.dead.footprintx = 15
			uDef.featuredefs.dead.footprintz = 15
			uDef.featuredefs.dead.collisionvolumescales = "145 90 160"
			uDef.customparams.techlevel = 4
			uDef.customparams.buildinggrounddecalsizex = 18
			uDef.customparams.buildinggrounddecalsizez = 18
		end

		-- remove hovers from com
		if name == "corcom" or name == "legcom" or name == "armcom" then
			uDef.buildoptions[26] = ""
			uDef.buildoptions[27] = ""

		-- T2 labs are priced as t1.5 but require more BP
		elseif name == "armaap" or name == "armasy" or name == "armalab" or name == "armavp"
		or name == "coraap"  or name == "corasy" or name == "coralab" or name == "coravp"
		or name == "legaap" or name == "legasy" or name == "legalab" or name == "legavp"
		then
			uDef.metalcost = uDef.metalcost - 1300
			uDef.energycost = uDef.energycost - 5000
			uDef.buildtime = math.ceil(uDef.buildtime * 0.015) * 100
		
		-- T2 cons are priced as t1.5
		elseif name == "armack" or name == "armacv" or name == "armaca" or name == "armacsub"
		or name == "corack" or name == "coracv" or name == "coraca" or name == "coracsub"
		or name == "legack" or name == "legacv" or name == "legaca" or name == "legacsub"
		then
			uDef.metalcost = uDef.metalcost - 200
			uDef.energycost = uDef.energycost - 2000
			uDef.buildtime = math.ceil(uDef.buildtime * 0.008) * 100
		
		-- Hover cons are priced as t2
		elseif name == "armch" or name == "corch" or name == "legch"
		then
			uDef.mass = 2700
			uDef.metalcost = uDef.metalcost * 2
			uDef.energycost = uDef.energycost * 2
			uDef.buildtime = uDef.buildtime * 2
			uDef.customparams.techlevel = 2
		end

		----------------------------------------------
		-- T2 mexes upkeep increased, health decreased
		if name == "armmoho"or name == "armuwmme" 
		then
			uDef.energyupkeep = 48
			uDef.health = uDef.health - 1200
		elseif name == "cormoho" or name == "coruwmme" 
		then
			uDef.energyupkeep = 48
			uDef.health = uDef.health - 1700
		elseif name == "cormexp" then
			uDef.energyupkeep = 48
		end

		

		-------------------------------
		-- T3 mobile jammers have radar

		if name == "armaser" or name == "corspec" 
		or name == "armjam" or name == "coreter"
		then
			uDef.metalcost = uDef.metalcost + 100
			uDef.energycost = uDef.energycost + 1250
			uDef.buildtime = uDef.buildtime + 3800
			uDef.radardistance = 2500
			uDef.sightdistance = 1000
		end

		if name == "armantiship" or name == "corantiship" then
			uDef.radardistancejam = 450
		end

		----------------------------
		-- T2 ship jammers get radar

		if name == "armsjam" or name == "corsjam" then
			uDef.metalcost = uDef.metalcost + 90
			uDef.energycost = uDef.energycost + 1050
			uDef.buildtime = uDef.buildtime + 3000
			uDef.radarDistance = 2200
			uDef.sightdistance = 900
		end

		-----------------------------------
		-- Pinpointers are T3 radar/jammers

		if name == "armtarg" or name == "cortarg"
		or name == "armfatf" or name == "corfatf"
		then
			uDef.radardistance = 5000
			uDef.sightdistance = 1200
			uDef.radardistancejam = 900
		end
		
		-----------------------------
    	-- Correct Tier for Announcer

		if name == "armch" or name == "armsh" or name == "armanac" or name == "armah" or name == "armmh"
		or name == "armcsa" or name == "armsaber" or name == "armsb" or name == "armseap" or name == "armsfig" or name == "armsehak" or name == "armhvytrans"
		or name == "corch" or name == "corsh" or name == "corsnap" or name == "corah" or name == "cormh" or name == "corhal"
		or name == "corcsa" or name == "corcut" or name == "corsb" or name == "corseap" or name == "corsfig" or name == "corhunt" or name == "corhvytrans"
		then
			uDef.customparams.techlevel = 2
		
		elseif name == "armsnipe" or name == "armfboy" or name == "armaser" or name == "armdecom" or name == "armscab"
		or name == "armbull" or name == "armmerl" or name == "armmanni" or name == "armyork" or name == "armjam"
		or name == "armserp" or name == "armbats" or name == "armepoch" or name == "armantiship" or name == "armaas"
		or name == "armhawk" or name == "armpnix" or name == "armlance" or name == "armawac" or name == "armdfly" or name == "armliche" or name == "armblade" or name == "armbrawl" or name == "armstil"
		or name == "corsumo" or name == "cordecom" or name == "corsktl" or name == "corspec"
		or name == "corgol" or name == "corvroc" or name == "cortrem" or name == "corsent" or name == "coreter" or name == "corparrow"
		or name == "corssub" or name == "corbats" or name == "corblackhy" or name == "corarch" or name == "corantiship"
		or name == "corape" or name == "corhurc" or name == "cortitan" or name == "corvamp" or name == "corseah" or name == "corawac" or name == "corcrwh"
		then
			uDef.customparams.techlevel = 3
		end

		--------------------------
		-- Legion Air Placeholders

		if name == "legaca" then
			uDef.buildoptions = {
			[1] = "legadvsol",
			[2] = "legmext15",
			[3] = "legdtr",
			[4] = "legmg",
			[5] = "legrhapsis",
			[6] = "leglupara",
			[7] = "legjuno",
			[8] = "leghive",
			[9] = "legfus",
			[10] = "legarad",
			[11] = "legajam",
			[12] = "legsd",
			[13] = "legap",
			[14] = "legaap",
			[15] = "leghaap",
			[16] = "legcluster",
			[17] = "legeconv"
		}
		end		

		-----------------------------------------
		-- Hovers, Sea Planes and Amphibious Labs
		

		-- Hover labs removed
			
		-- hover cons
		if name == "armch" then
			uDef.buildoptions = {
				[1] = "armadvsol",
				[2] = "armmoho",
				[3] = "armbeamer",
				[4] = "armhlt",
				[5] = "armguard",
				[6] = "armferret",
				[7] = "armcir",
				[8] = "armjuno",
				[9] = "armclaw",
				[10] = "armarad",
				[11] = "armveil",
				[12] = "armfus",
				[13] = "armgmm",
				[14] = "armhavp",
				[15] = "armlab",
				[16] = "armsd",
				[17] = "armmakr",
				[18] = "armestor",
				[19] = "armmstor",
				[20] = "armageo",
				[21] = "armckfus",
				[22] = "armdl",
				[23] = "armdf",
				[24] = "armvp",
				[25] = "armsy",
				[26] = "armap",
				[27] = "armavp",
				[28] = "armasy",
				[29] = "armhasy",
				[30] = "armtl",
				[31] = "armason",
				[32] = "armdrag",
				[33] = "armfdrag",
				[34] = "armuwmme",
				[35] = "armguard"
			}

		elseif name == "corch" then
			uDef.buildoptions = {
				[1] = "coradvsol",
				[2] = "cormoho",
				[3] = "cormaw",
				[4] = "corhllt",
				[5] = "corpun",
				[6] = "cormadsam",
				[7] = "corerad",
				[8] = "corjuno",
				[9] = "corfus",
				[10] = "corarad",
				[11] = "corshroud",
				[12] = "corsd",
				[13] = "corvp",
				[14] = "corhavp",
				[15] = "coravp",
				[16] = "cormakr",
				[17] = "corestor",
				[18] = "cormstor",
				[19] = "corageo",
				[20] = "cordl",
				[21] = "coruwmme",
				[22] = "cordrag",
				[23] = "corfdrag",
				[24] = "corason",
				[25] = "corlab",
				[26] = "corap",
				[27] = "corsy",
				[28] = "corasy",
				[29] = "corhlt",
				[30] = "cortl",
				[31] = "corhasy",
				[32] = "corpun"
			}

		elseif name == "legch" then 
			uDef.buildoptions = {
			[1] = "legsolar",
			[2] = "legadvsol",
			[3] = "legwin",
			[4] = "leggeo",
			[5] = "legmstor",
			[6] = "legestor",
			[7] = "legmex",
			[8] = "",
			[9] = "legeconv",
			[10] = "",
			[11] = "",
			[12] = "",
			[13] = "leghp",
			[14] = "leghavp",
			[15] = "legnanotc",
			[16] = "legnanotcplat",
			[17] = "legeyes",
			[18] = "legrad",
			[19] = "legdrag",
			[20] = "legdtr",
			[21] = "leglht",
			[22] = "legmg",
			[23] = "legcluster",
			[24] = "legrl",
			[25] = "legrhapsis",
			[26] = "leglupara",
			[27] = "legjuno",
			[28] = "legctl",
			[29] = "legjam",
			[30] = "legfhp",
			[31] = "legamphlab",
			[32] = "legplat",
			[33] = "",
			[34] = "legtide",
			[35] = "legfeconv",
			[36] = "leguwmstore",
			[37] = "leguwestore",
			[38] = "legfdrag",
			[39] = "legfrad",
			[40] = "legfmg",
			[41] = "legfrl",
			[42] = "legtl",
			[43] = "leguwgeo",
			[44] = "leghasy",
			[45] = "leghive",
			[46] = "legfhive",
			}
		end
		-- Seaplane Platforms removed, become T2 air labs. 
		-- T2 air labs have sea variants
		-- Made by hover cons and enhanced ship cons 
		-- Enhanced ships given seaplanes instead of static AA
	end

	if modOptions.techsplit_balance == true then
		local techsplit_balanceUnits = VFS.Include("unitbasedefs/techsplit_balance_defs.lua")
		uDef = techsplit_balanceUnits.techsplit_balanceTweaks(name, uDef)
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
		if wDef.customparams and wDef.customparams.overrange_distance then
			wDef.customparams.overrange_distance = wDef.customparams.overrange_distance * rangeMult
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
