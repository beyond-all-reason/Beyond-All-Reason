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
local function round_to_frames(name, wd, key)
	local original_value = wd[key]
	if not original_value then
		-- even reloadtime can be nil (shields, death explosions)
		return
	end

	local Game_gameSpeed = 30 --for mission editor backwards compat (engine 104.0.1-287)
	if Game and Game.gameSpeed then
		Game_gameSpeed = Game.gameSpeed
	end

	local frames = math.max(1, math.floor((original_value + 1E-3) * Game_gameSpeed))
	local sanitized_value = frames / Game_gameSpeed

	return sanitized_value
end

local function processWeapons(unitDefName, unitDef)
	local weaponDefs = unitDef.weapondefs
	if not weaponDefs then
		return
	end

	for weaponDefName, weaponDef in pairs(weaponDefs) do
		local fullWeaponName = unitDefName .. "." .. weaponDefName
		weaponDef.reloadtime = round_to_frames(fullWeaponName, weaponDef, "reloadtime")
		weaponDef.burstrate = round_to_frames(fullWeaponName, weaponDef, "burstrate")
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
			local Nukes = {
				armamd = true,
				armsilo = true,
				armscab = true,
				corfmd = true,
				corsilo = true,
				cormabm = true,
				legsilo =  true,
				legabm = true,
				armamd_scav = true,
				armsilo_scav = true,
				armscab_scav = true,
				corfmd_scav = true,
				corsilo_scav = true,
				cormabm_scav = true,
				legsilo_scav =  true,
				legabm_scav = true,
			}
			if Nukes[name] then
				uDef.maxthisunit = 0
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
				for _, weapon in pairs(uDef.weapondefs) do
					if weapon.interceptor and weapon.interceptor == 1 then
						uDef.maxthisunit = 0
						break
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

	-- Release candidate units
	if modOptions.releasecandidates then

		--Shockwave mex
		if name == "armaca" or name == "armack" or name == "armacv" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armshockwave"
		end

		--Printer

		if name == "coravp" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corvac" --corprinter
			uDef.buildoptions[numBuildoptions + 2] = "corphantom"
			uDef.buildoptions[numBuildoptions + 3] = "corsiegebreaker"
		end
		if name == "legavp" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corvac" --corprinter
		end

		--Drone Carriers

		if name == "armasy" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armdronecarry"
		end
		if name == "corasy" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "cordronecarry"
		end
	end

	-- Add scav units to normal factories and builders
	if modOptions.experimentalextraunits then

		if name == "armshltx" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armrattet4"
			uDef.buildoptions[numBuildoptions + 2] = "armsptkt4"
			uDef.buildoptions[numBuildoptions + 3] = "armpwt4"
			uDef.buildoptions[numBuildoptions + 4] = "armvadert4"
			-- uDef.buildoptions[numBuildoptions+5] = "armlunchbox"
			uDef.buildoptions[numBuildoptions + 6] = "armmeatball"
			uDef.buildoptions[numBuildoptions + 7] = "armassimilator"
			uDef.buildoptions[numBuildoptions + 8] = "armdronecarryland"
		elseif name == "armshltxuw" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armrattet4"
			uDef.buildoptions[numBuildoptions + 2] = "armpwt4"
			uDef.buildoptions[numBuildoptions + 3] = "armvadert4"
			uDef.buildoptions[numBuildoptions + 4] = "armmeatball"
		elseif name == "corgantuw" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corgolt4"
			uDef.buildoptions[numBuildoptions + 2] = "corakt4"
		elseif name == "armvp" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armzapper"
		elseif name == "legavp" then
			local numBuildoptions = #uDef.buildoptions
		elseif name == "coravp" then
			local printerpresent = false

			for ix, UnitName in pairs(uDef.buildoptions) do
				if UnitName == "corvac" then
					printerpresent = true
				end
			end

			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corgatreap"
			uDef.buildoptions[numBuildoptions+2] = "corforge"
			uDef.buildoptions[numBuildoptions+3] = "corftiger"
			uDef.buildoptions[numBuildoptions+4] = "cortorch"
			uDef.buildoptions[numBuildoptions+5] = "corsiegebreaker"
			uDef.buildoptions[numBuildoptions+6] = "corphantom"
			if (printerpresent==false) then -- assuming sala and vac stay paired, this is tidiest solution
				uDef.buildoptions[numBuildoptions+7] = "corvac" --corprinter

			end
		elseif name == "coralab" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "cordeadeye"
		elseif name == "coraap" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corcrw"
		elseif name == "corgant" or name == "leggant" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corkarganetht4"
			uDef.buildoptions[numBuildoptions + 2] = "corgolt4"
			uDef.buildoptions[numBuildoptions + 3] = "corakt4"
			uDef.buildoptions[numBuildoptions + 4] = "corthermite"
			uDef.buildoptions[numBuildoptions + 5] = "cormandot4"
		elseif name == "armca" or name == "armck" or name == "armcv" then
			--local numBuildoptions = #uDef.buildoptions
		elseif name == "corca" or name == "corck" or name == "corcv" then
			--local numBuildoptions = #uDef.buildoptions
		elseif name == "legca" or name == "legck" or name == "legcv" then
			--local numBuildoptions = #uDef.buildoptions
		elseif name == "corcs" or name == "corcsa" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corgplat"
			uDef.buildoptions[numBuildoptions + 2] = "corfrock"
		elseif name == "armcs" or name == "armcsa" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armgplat"
			uDef.buildoptions[numBuildoptions + 2] = "armfrock"
		elseif name == "coracsub" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corfgate"
			uDef.buildoptions[numBuildoptions + 2] = "cornanotc2plat"
		elseif name == "armacsub" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armfgate"
			uDef.buildoptions[numBuildoptions + 2] = "armnanotc2plat"
		elseif name == "armaca" or name == "armack" or name == "armacv" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armapt3"
			uDef.buildoptions[numBuildoptions + 2] = "armminivulc"
			uDef.buildoptions[numBuildoptions + 3] = "armwint2"
			uDef.buildoptions[numBuildoptions + 5] = "armbotrail"
			uDef.buildoptions[numBuildoptions + 6] = "armannit3"
			uDef.buildoptions[numBuildoptions + 7] = "armnanotct2"
			uDef.buildoptions[numBuildoptions + 8] = "armlwall"
		elseif name == "coraca" or name == "corack" or name == "coracv" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corapt3"
			uDef.buildoptions[numBuildoptions + 2] = "corminibuzz"
			uDef.buildoptions[numBuildoptions + 3] = "corwint2"
			uDef.buildoptions[numBuildoptions + 4] = "corhllllt"
			uDef.buildoptions[numBuildoptions + 6] = "cordoomt3"
			uDef.buildoptions[numBuildoptions + 7] = "cornanotct2"
			uDef.buildoptions[numBuildoptions + 8] = "cormwall"
		elseif name == "legaca" or name == "legack" or name == "legacv" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "legapt3"
			uDef.buildoptions[numBuildoptions + 2] = "legministarfall"
			uDef.buildoptions[numBuildoptions + 3] = "legwint2"
			uDef.buildoptions[numBuildoptions + 4] = "legnanotct2"
		elseif name == "armasy" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armptt2"
			uDef.buildoptions[numBuildoptions + 2] = "armdecadet3"
			uDef.buildoptions[numBuildoptions + 3] = "armpshipt3"
			uDef.buildoptions[numBuildoptions + 4] = "armserpt3"
			uDef.buildoptions[numBuildoptions + 5] = "armexcalibur"
			uDef.buildoptions[numBuildoptions + 6] = "armseadragon"
			uDef.buildoptions[numBuildoptions + 7] = "armtrident"
			uDef.buildoptions[numBuildoptions + 8] = "armdronecarry"
		elseif name == "corasy" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corslrpc"
			uDef.buildoptions[numBuildoptions + 2] = "coresuppt3"
			uDef.buildoptions[numBuildoptions + 3] = "coronager"
			uDef.buildoptions[numBuildoptions + 4] = "cordesolator"
			uDef.buildoptions[numBuildoptions + 5] = "corsentinel"
			uDef.buildoptions[numBuildoptions + 6] = "cordronecarry"
		end
	end

	-- mass remove push resistance
	if uDef.pushresistant and uDef.pushresistant == true then
		uDef.pushresistant = false
		if not uDef.mass then
			uDef.mass = 4999
		end
	end

	--experimental mass standardization based on size
	if modOptions.mass_impulse_rework and (uDef.mass or uDef.metalcost) then
		
		--imperically selected. This scales how much impulse weapons will deal proportionally to affect each tier of sizeMasses table entries.
		local targetImpulseMultiplier = 3.25

		--this is used to make units transportable by prior weight class and by setting the weight class of the transports.
		local transportDeduction = 1

		--size tables
		local sizeMasses = {
			tiny = 60,--36,
			small = 98,--100,
			medium = 240,--250,
			large = 480,--700,
			huge = 960,--1800,
			gargantuan = 2880,--4500,
			colossal = 12000,--11700
			commander = 20000
		}

		--do not set land units below 1x multiplier to avoid transportability issues
		local hovercraftMassMultiplier = 1
		local boatMassMultiplier = 1.5
		local treadedMassMultiplier = 1.5
		local twoLeggedMassMultiplier = 1
		local fourLeggedMassMultiplier = 1.1
		local sixLeggedMassMultiplier = 1.5
		local submarineMassMultiplier = 1
		local aircraftMassMultiplier  = 0.6
		local massPerExtraTechLevelMultiplier = 1

		--for diagnostics
		local originalMass = uDef.mass or uDef.metalcost
		local sizeMass = 0

		--mass category tables. YOU MAY CHANGE THE NUMBERS. Keep them within 0.75-1.25 so consistency is maintained.
		local tinyMassesTable = {
			armfav = 1, armflea = 1, armvader = 1, corfav = 1, corroach = 1, corsktl = 1, legscout = 1, legsnapper = 1
		}
		local smallMassesTable = {
			armamph = 1, armfast = 1, armfark = 1, armflash = 1, armgremlin = 1, armham = 1, armjeth = 1, armmark = 1, armpw = 1, armrectr = 1,
			armrock = 1, armsh = 1, armspid = 1, armspy = 1, armstil = 1, armsaber = 1, armkam = 1, armzapper = 1, corak = 1, corbw = 1,
			corcrash = 1, corfast = 1, corfink = 1, corgator = 1, corhunt = 1, cornecro = 1, corstorm = 1, corsh = 1, corsfig = 1, corspy = 1,
			corthud = 1, corvamp = 1, corveng = 1, corvoyr = 1, legcen = 1, legcib = 1, legfig = 1, legglob = 1, leggob = 1, leggremlin = 1,
			leghelios = 1, leghades = 1, legkam = 1, legmos = 1, legsh = 1, legvenator = 1
		}
		local mediumMassesTable = {
			armah = 1, armanac = 1, armch = 1, armck = 1, armconsul = 1, armdecade = 1, armfido = 1, armfig = 1, armhawk = 1, armjam = 1,
			armjanus = 1, armkam = 1, armlatnk = 1, armmart = 1, armmh = 1, armmlv = 1, armpincer = 1, armpt = 1, armsam = 1, armsnipe = 1,
			armsptk = 1, armseer = 1, armsehak = 1, armsub = 1, armstump = 1, armwar = 1, armzues = 1, armbrawl = 1, armblade = 1, armca = 1,
			armcsa = 1, armseap = 1, armatlas = 1, armawac = 1, coraak = 1, coracsub = 1, corah = 1, coramph = 1, corape = 1, corca = 1,
			corch = 1, corck = 1, corcsa = 1, corfig = 1, corgarp = 1, corhunt = 1, cormando = 1, cormh = 1, cormist = 1, cormlv = 1,
			cormort = 1, corpyro = 1, coronager = 1, corphantom = 1, corraid = 1, corsala = 1, corsnap = 1, corspec = 1, corsub = 1,
			corsupp = 1, cortitan = 1, cortorch = 1, corvrad = 1, corwolv = 1, legaceb = 1, legah = 1, legamphtank = 1, legbal = 1, legbar = 1,
			legca = 1, legck = 1, leggat = 1, leginfestor = 1, legkark = 1, legmh = 1, legmlv = 1, legmrv = 1, legner = 1, legrail = 1,
			legwhisper = 1, legionnaire = 1
		}
		local largeMassesTable = {
			armacsub = 1, armaas = 1, armaca = 1, armack = 1, armbeaver = 1, armcom = 1, armcs = 1, armcv = 1, armdecom = 1, armlance = 1,
			armlship = 1, armmart = 1, armmav = 1, armmis = 1, armnap = 1, armpship = 1, armrecl = 1, armserp = 1, armsb = 1, armsjam = 1,
			armsubk = 1, armyork = 1, armexcalibur = 1, armthund = 1, armseap = 1, armhvytrans = 1, armatlas = 1, armdfly = 1, coracsub = 1,
			coraca = 1, corarch = 1, corcan = 1, corcom = 1, corcs = 1, corcut = 1, corcv = 1, cordecom = 1, correcl = 1, corforge = 1,
			corfship = 1, corhal = 1, corhrk = 1, corhurc = 1, corlance = 1, cormart = 1, cormls = 1, cormuskrat = 1, corpship = 1,
			corftiger = 1, corsb = 1, corsent = 1, corshark = 1, corsjam = 1, corssub = 1, coreter = 1, cordeadeye = 1, legaca = 1, legack = 1,
			legacv = 1, legamcluster = 1, legcar = 1, legcom = 1, legcv = 1, legdecom = 1, legmineb = 1, legnap = 1, legotter = 1, legphoenix = 1,
			legshot = 1, legstr = 1
		}
		local hugeMassesTable = {
			armacv = 1, armaat = 1, armbull = 1, armcrus = 1, armcroc = 1, armfboy = 1, armmar = 1, armmanni = 1, armmship = 1, armmerl = 1,
			armroy = 1, armscab = 1, armlun = 1, coracv = 1, corcrus = 1, corparrow = 1, correap = 1, corshiva = 1, corsok = 1, cormabm = 1,
			cortrem = 1, corvroc = 1, corroy = 1, corsentinel = 1, cormship = 1, legacv = 1, legaheattank = 1, legavroc = 1, legbart = 1,
			legfloat = 1, legmed = 1, legsrail = 1, legvcarry = 1
		}
		local gargantuanMassesTable = {
			armantiship = 1, armbats = 1, armraz = 1, armvang = 1, corantiship = 1, corbats = 1, corcat = 1, cordesolator = 1, cordronecarry = 1,
			corgol = 1, corkarg = 1, leginc = 1, leginf = 1, legkeres = 1, legpede = 1, cordronecarryair = 1, corcrw = 1, legfort = 1, legstronghold = 1,
			corcrwh = 1, corseah = 1, corthermite = 1, armdronecarry = 1, armptt2 = 1, armpshipt3 = 1, corakt4 = 1, cormandot4 = 1,
			corsiegebreaker = 1, corgatreap = 1, corvac = 1, armtrident = 1, armassimilator = 1, armmeatball = 1, armsptkt4 = 1
		}
		local colossalMassesTable = {
			armbanth = 1, armdecadet3 = 1, armepoc = 1, armthor = 1, corblackhy = 1, cordemon = 1, corjugg = 1, corkorg = 1, corkarganetht4 = 1,
			corgolt4 = 1, corsirpc = 1, coresuppt3 = 1, leegmech = 1, corcrwt4 = 1, armlichet4 = 1, legfortt4 = 1, corfblackhyt4 = 1, armfepocht4 = 1,
			armthundt4 = 1, armserpt3 = 1, armseadragon = 1, armvadert4 = 1, armrattet4 = 1, armdronecarryland = 1
		}

		local transportableLikePreviousSizeTable = {
			armbeaver = true, armcv = true, corcv = true, cormuskrat = true, legcv = true, legotter = true
		}

		local sixLeggedMassTable = {
			armspid = true, armscab = true, armsptk = true, armsptkt4 = true,
			corkarg = true, corroach = true, corthermite = true, corkarganetht4 = true,
			legaceb = true, leginfestor = true, legpede = true, legsnapper = true, legsrail = true,
		}

		local fourLeggedMassTable = {
			armfido = true, armflea = true, armvang = true,
			coraak = true, corack = true, corcrash = true, corjugg = true, corkorg = true, corsktl = true, corsumo = true, cordeadeye = true,
			legack = true, legcen = true, legck = true, leginc = true
		}

		local twoLeggedMassTable = {
			armaak = true, armack = true, armaser = true, armassimilator = true, armcom = true, armcomcon = true, armcomboss = true,
			armcomlvl10 = true, armcomlvl2 = true, armcomlvl3 = true, armcomlvl4 = true, armcomlvl5 = true, armcomlvl6 = true, armcomlvl7 = true,
			armcomlvl8 = true, armcomlvl9 = true, armdecom = true, armdecomlvl3 = true, armdecomlvl6 = true, armdecomlvl10 = true, armfark = true,
			armfboy = true, armfast = true, armham = true, armjeth = true, armlunchbox = true, armmar = true, armmeatball = true, armmav = true,
			armpwt4 = true, armpw = true, armraz = true, armrock = true, armspy = true, armsnipe = true, armscavengerbossv2_easy = true, armscavengerbossv2_hard = true,
			armscavengerbossv2_normal = true, armscavengerbossv2_veryhard = true, armvader = true, armwar = true, armzeus = true, babyleglob = true, babylegshot = true,
			babyarmvader = true, chip = true, comeffigylvl1 = true, comeffigylvl2 = true, comeffigylvl3 = true, comeffigylvl5 = true, cordecom = true, cordecomlvl3 = true,
			cordecomlvl6 = true, cordecomlvl10 = true, coramph = true, corcan = true, corcat = true, corcom = true, corcomboss = true, corcomcon = true, corcomlvl2 = true,
			corcomlvl3 = true, corcomlvl5 = true, corcomlvl7 = true, corcomlvl8 = true, corcomlvl9 = true, corcomlvl10 = true, cordeadeye = true, cordemon = true, corfast = true,
			corhrk = true, corpyro = true, corshiva = true, corspec = true, corspy = true, corstorm = true, corthermite = true, corthud = true, corvoyr = true, leegmech = true,
			legack = true, legbal = true, legbart = true, legcom = true, legcomecon = true, legcomlvl2 = true, legcomlvl3 = true, legcomlvl4 = true, legcomlvl5 = true,
			legcomlvl6 = true, legcomlvl7 = true, legcomlvl10 = true, legcomoff = true, legcomt2com = true, legcomt2def = true, legcomt2off = true, legdecom = true,
			legdecomlvl3 = true, legdecomlvl6 = true, legdecomlvl10 = true, leggob = true, legkark = true, legshot = true, legstr = true, leglob = true, leghades = true,
			squadcorak = true, squadcorakt4 = true, squadcorkarg = true, squadarmpwt4 = true, squadarmsptk = true, corakt4 = true, cormandot4 = true,
		}

		--assign the masses and transport weights
		if uDef.customparams and uDef.customparams.iscommander then
			uDef.mass = sizeMasses.commander
			--uDef.customparams.unit_weight_class = 1
		elseif tinyMassesTable[name] then
			uDef.mass = sizeMasses.tiny * tinyMassesTable[name]
			--uDef.customparams.unit_weight_class = 1
		elseif smallMassesTable[name] then
			uDef.mass = sizeMasses.small * smallMassesTable[name]
			--uDef.customparams.unit_weight_class = 2
		elseif mediumMassesTable[name] then
			uDef.mass = sizeMasses.medium * mediumMassesTable[name]
			--uDef.customparams.unit_weight_class = 3
		elseif largeMassesTable[name] then
			uDef.mass = sizeMasses.large * largeMassesTable[name]
			--uDef.customparams.unit_weight_class = 4
		elseif hugeMassesTable[name] then
			uDef.mass = sizeMasses.huge * hugeMassesTable[name]
			--uDef.customparams.unit_weight_class = 5
		elseif gargantuanMassesTable[name] then
			uDef.mass = sizeMasses.gargantuan * gargantuanMassesTable[name]
			--uDef.customparams.unit_weight_class = 6
		elseif colossalMassesTable[name] then
			uDef.mass = sizeMasses.colossal * colossalMassesTable[name]
			--uDef.customparams.unit_weight_class = 7
		else
			uDef.mass = uDef.mass or uDef.metalcost
			--uDef.customparams.unit_weight_class = 5
		end
		sizeMass = uDef.mass
		if uDef.customparams.techlevel and uDef.customparams.techlevel > 1 then
			local techMultiplierCount = uDef.customparams.techlevel - 1
			uDef.mass = uDef.mass * massPerExtraTechLevelMultiplier * techMultiplierCount
		end

		--assign mass bonuses
		if uDef.movementclass and (string.find(name, "cor") or string.find(name, "arm") or string.find(name, "leg")) then
			local mc = uDef.movementclass
			if uDef.customparams and uDef.customparams.iscommander then
				--Spring.Echo(name, uDef.mass, "commander")
			end
			if transportableLikePreviousSizeTable[name] then
				uDef.mass = uDef.mass - transportDeduction
				--Spring.Echo(name, uDef.mass, "Previous Size Transportable")
			elseif fourLeggedMassTable[name] then
				uDef.mass = uDef.mass * fourLeggedMassMultiplier
				--Spring.Echo(name, uDef.mass, "4 legged")
			elseif sixLeggedMassTable[name] then
				uDef.mass = uDef.mass * sixLeggedMassMultiplier
				--Spring.Echo(name, uDef.mass, "6 legged")
			elseif twoLeggedMassTable[name] then
				uDef.mass = uDef.mass * twoLeggedMassMultiplier
				--Spring.Echo(name, uDef.mass, "BOT")
			elseif mc == "TANK2" or mc == "TANK3" or mc == "MTANK3" or mc == "HTANK4" or mc == "HTANK5" or mc == "ATANK3" then
				uDef.mass = uDef.mass * treadedMassMultiplier
				--Spring.Echo(name, uDef.mass, "Treaded")
			elseif mc == "BOAT3" or mc == "BOAT4" or mc == "BOAT5" or mc == "BOAT8" or mc == "EPICSHIP" then
				uDef.mass = uDef.mass * boatMassMultiplier
				--Spring.Echo(name, uDef.mass, "Boat")
			elseif mc == "HOVER2" or mc == "HOVER3" or mc == "HHOVER4" then
				uDef.mass = uDef.mass * hovercraftMassMultiplier
				--Spring.Echo(name, uDef.mass, "Hover")
			elseif mc == "UBOAT4" or mc == "EPICSUBMARINE" then
				uDef.mass = uDef.mass * submarineMassMultiplier
				--Spring.Echo(name, uDef.mass, "Submarine")
			end
		elseif uDef.canfly == true then
			uDef.mass = uDef.mass * aircraftMassMultiplier
			--Spring.Echo(name, uDef.mass, "VTOL")
		else
			-- Spring.Echo(name, "Invalid")
		end

		--any units you want to give impulse to, add an entry to this table. Giving it a string size category will produce optimal yeetage for that amount of mass.
		--add weapon impulses. Acceptable formats are: String representing the key entry in sizeMasses table from above, arbitrary number of desired resultant impulse,
		--if number is < 10 then it'll be directly assigned as impulseFactor. For units with multiple weapons, use a table of:
		--key = (either string/number value as mentioned before) based on the key of each weapon listed in the unit's weapondefs.
		local impulseUnits = {
			--johannas' picks
			corshiva = {shiva_gun = "medium", shiva_rocket = "large"}, armliche = "gargantuan", cortrem = "medium", armbrtha = "gargantuan", corint = "gargantuan", 
			armvang = "huge", armvulc = "large", corbuzz = "large", armfboy = "huge", corgol = "huge", armmav = "medium", armsilo = "gargantuan", corsilo = "gargantuan",
			cortron = "gargantuan", corcat = "large", corban = "huge", corparrow = "medium", corvroc = "huge", armmerl = "huge", corhrk = "large", cortoast = "huge",
			armamb = "huge", corpun = "large", armguard = "large", armjanus = "medium", corlevlr = "medium",
			--seth's suggestions
			armart = "tiny", corwolv = "tiny", legrail = "medium", legkark = {corlevlr_weapon = "medium", corwar_laser = 0.123}, legsrail = "large", armsnipe = "medium",
			armfido = "tiny", armsptk = "medium", armmart = "medium", cormart = "medium", armcroc = {arm_triton = "medium"}, legavroc = "huge", legaskirmtank = "tiny",
			legamcluster = {arm_artillery = "medium", cluster_munition = "small"}, legmed = {legmed_missile = "medium"}, legfloat = {legfloat_gauss = "medium"},
			legfort = {plasma = "medium"}, corape = "small", armblade = "small", armpnix = "medium", corhurc = "medium", corshad = "small", armthund = "small",
		}

		--ignore this nerdinese, it just assigns the impulse values derived from the above table entries.
		if impulseUnits[name] then
			for weaponName, weaponDef in pairs(uDef.weapondefs) do
				if type(impulseUnits[name]) == "number" then
					local damage = weaponDef.damage.default or next(weaponDef.damage)
					if damage and damage > 0 then
						if impulseUnits[name] <= 10 then
							weaponDef.impulsefactor = impulseUnits[name]
							--Spring.Echo(name, "impulsefactor", weaponDef.impulsefactor)
						else
						local targetImpulse = impulseUnits[name]
						weaponDef.impulsefactor = math.ceil((targetImpulse / damage) * 100) / 100
						--Spring.Echo(name, "impulsefactor", weaponDef.impulsefactor)
						end
					end
				elseif type(impulseUnits[name]) == "string" then
					local damage = weaponDef.damage.default or next(weaponDef.damage)
					if damage and damage > 0 then
						local targetImpulse = sizeMasses[impulseUnits[name]] * targetImpulseMultiplier
						weaponDef.impulsefactor = math.ceil((targetImpulse / damage) * 100) / 100
						--Spring.Echo(name, "impulsefactor", weaponDef.impulsefactor)
					end
				elseif type(impulseUnits[name]) == "table" then
					for impulseUnitsWeaponName, data in pairs(impulseUnits[name]) do
						if weaponName == impulseUnitsWeaponName then
							if type(data) == "number" then
								local damage = weaponDef.damage.default or next(weaponDef.damage)
								if damage and damage > 0 then
									if data <= 10 then
										weaponDef.impulsefactor = data
										--Spring.Echo(name, impulseUnitsWeaponName, "impulseFactor", weaponDef.impulsefactor, data)
									else
									local targetImpulse = data
									weaponDef.impulsefactor = math.ceil((targetImpulse / damage) * 100) / 100
									--Spring.Echo(name, impulseUnitsWeaponName, "impulseFactor", weaponDef.impulsefactor, data)
									end
								end
							elseif type(data) == "string" then
								local damage = weaponDef.damage.default or next(weaponDef.damage)
								if damage and damage > 0 then
									local targetImpulse = sizeMasses[data] * targetImpulseMultiplier
									weaponDef.impulsefactor = math.ceil((targetImpulse / damage) * 100) / 100
									--Spring.Echo(name, impulseUnitsWeaponName, "impulseFactor", weaponDef.impulsefactor, data)
								end
							end
							break
						end
					end
				end
			end
		elseif uDef.weapondefs then
					--remove impulse from unlisted units
			-- for weaponName, weaponDef in pairs(uDef.weapondefs) do
			-- 	if weaponDef.impulsefactor and weaponDef.impulsefactor > 0 then
			-- 		weaponDef.impulsefactor = 0.123
			-- 	end
			-- 	weaponDef.impulseboost = nil
			-- end
		end
		
		--assign the category the transport is ~UNABLE~ to carry
		local transportUnits = { 
			armatlas = "large", armhvytrans = "gargantuan", armdfly = "gargantuan", corvalk = "large", corhvytrans = "gargantuan", corseah = "gargantuan", legatrans = "large", legstronghold = "gargantuan"
		}
		if transportUnits[name] then
			uDef.transportmass = sizeMasses[transportUnits[name]] - transportDeduction
		end

		--populate newMassToMetalRatios tables for later echo'ing
		if uDef.mass and uDef.mass ~= originalMass and not uDef.customparams.evocomlvl then
			local newMassToMetalRatio = math.ceil((uDef.mass / originalMass) * 100)
			Spring.Echo(name.." "..newMassToMetalRatio.."%")--, "old "..originalMass, "new "..uDef.mass, )
			if smallMassesTable[name] then
				local sizeMassToMetalRatio = math.ceil((sizeMass / originalMass) * 100)
				--Spring.Echo(name.." "..sizeMassToMetalRatio.."%")
			end
		end
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
		VBOT5 = true,
		COMMANDERBOT = true,
		SCAVCOMMANDERBOT = true,
		ATANK3 = true,
		ABOT2 = true,
		HABOT4 = true,
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
	categories["EMPABLE"] = function(uDef) return uDef.customparams and uDef.customparams.paralyzemultiplier ~= 0 end
	
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
	if name == "armsolar" or name == "corsolar" or name == "legsolar" then
		-- special case (but why?)
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
		
		-- Accurate Lasers		
		if modOptions.accuratelasers then
			if wDef.weapontype and wDef.weapontype == 'BeamLaser' then
				wDef.targetmoveerror = nil
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

		if modOptions.shieldsrework == true then
			-- For balance, paralyzers need to do reduced damage to shields, as their raw raw damage is outsized
			local paralyzerShieldDamageMultiplier = 0.25

			-- VTOL's may or may not do full damage to shields if not defined in weapondefs
			local vtolShieldDamageMultiplier = 0

			local shieldCollisionExemptions = { --add the name of the weapons (or just the name of the unit followed by _ ) to this table to exempt from shield collision. 
			'corsilo_', 'armsilo_', 'armthor_empmissile', 'armemp_', 'cortron_', 'corjuno_', 'armjuno_'
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
				wDef.shield.repulser = false
				wDef.shield.exterior = true
			end

			wDef.interceptedbyshieldtype = 1

			for _, exemption in ipairs(shieldCollisionExemptions) do
				if string.find(name, exemption)then
					wDef.interceptedbyshieldtype = 2
					wDef.customparams.shield_aoe_penetration = true
					break
				end
			end
		end

		if modOptions.evocom == true and wDef.weapontype == "DGun" then
			wDef.interceptedbyshieldtype = 1
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
