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

	if not uDef.icontype then
		uDef.icontype = name
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

		if modOptions.unit_restrictions_nonukes then
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

		if modOptions.evocom then	
			if uDef.customparams.isevocom or uDef.customparams.iscommander then
				uDef.customparams.combatradius = 0
				if uDef.power then
					uDef.power = uDef.power/modOptions.evocomxpmultiplier 
				else
					uDef.power = ((uDef.metalcost+(uDef.energycost/60))/modOptions.evocomxpmultiplier)
				end
				uDef.customparams.evolution_timer = modOptions.evocomleveluprate*60
				if  name == "armcom" then
				uDef.customparams.evolution_announcement = "Armada commanders have upgraded to level 2"
				uDef.customparams.evolution_announcement_size = 18.5
				uDef.customparams.evolution_target = "armcomlvl2"
				uDef.customparams.evolution_condition = "timer"
				elseif name == "corcom" then
				uDef.customparams.evolution_announcement = "Cortex commanders have upgraded to level 2"
				uDef.customparams.evolution_announcement_size = 18.5
				uDef.customparams.evolution_target = "corcomlvl2"
				uDef.customparams.evolution_condition = "timer"
				elseif name == "legcomlvl2" then
					uDef.energymake = 50
					uDef.metalmake = 3
				elseif name == "legcomlvl3" then
				uDef.customparams.evolution_announcement = "Legion commanders have upgraded to level 4"
				uDef.energymake = 75
				uDef.metalmake = 5
				elseif name == "legcomlvl4" then
				uDef.customparams.evolution_announcement = "Legion commanders have upgraded to level 5"
				uDef.customparams.evolution_announcement_size = 18.5
				uDef.customparams.evolution_target = "legcomlvl5"
				uDef.customparams.evolution_condition = "timer"
				uDef.customparams.workertimeboost = 5
				uDef.customparams.wtboostunittype = "MOBILE"
				uDef.energymake = 125
				uDef.metalmake = 9
				uDef.customparams.inheritxpratemultiplier = 0.5
        		uDef.customparams.childreninheritxp = "DRONE BOTCANNON"
        		uDef.customparams.parentsinheritxp = "MOBILEBUILT DRONE BOTCANNON"
				end
			end
		end

		if modOptions.unit_restrictions_notacnukes then
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

		if modOptions.unit_restrictions_nolrpc then
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

			uDef.buildoptions[numBuildoptions + 1] = "corgatreap"
			uDef.buildoptions[numBuildoptions + 2] = "corforge"
			uDef.buildoptions[numBuildoptions + 3] = "corftiger"
			uDef.buildoptions[numBuildoptions + 4] = "cortorch"
			uDef.buildoptions[numBuildoptions + 5] = "corvac" --corprinter
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
			if (printerpresent==false) then -- assuming sala and vac stay paired, this is tidiest solution
				uDef.buildoptions[numBuildoptions+6] = "corvac" --corprinter

			end
		elseif name == "corgant" or name == "leggant" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corkarganetht4"
			uDef.buildoptions[numBuildoptions + 2] = "corgolt4"
			uDef.buildoptions[numBuildoptions + 3] = "corakt4"
			uDef.buildoptions[numBuildoptions + 4] = "corthermite"
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
			uDef.buildoptions[numBuildoptions + 1] = "corapt3"
			uDef.buildoptions[numBuildoptions + 2] = "legministarfall"
			uDef.buildoptions[numBuildoptions + 3] = "legwint2"
			uDef.buildoptions[numBuildoptions + 4] = "corhllllt"
			uDef.buildoptions[numBuildoptions + 5] = "cordoomt3"
			uDef.buildoptions[numBuildoptions + 6] = "cornanotct2"
		elseif name == "armasy" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armptt2"
			uDef.buildoptions[numBuildoptions + 2] = "armdecadet3"
			uDef.buildoptions[numBuildoptions + 3] = "armpshipt3"
			uDef.buildoptions[numBuildoptions + 4] = "armserpt3"
			uDef.buildoptions[numBuildoptions + 5] = "armtrident"
		elseif name == "corasy" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corslrpc"
			uDef.buildoptions[numBuildoptions + 2] = "coresuppt3"
			uDef.buildoptions[numBuildoptions + 3] = "corsentinel"
		end
	end

	-- mass remove push resistance
	if uDef.pushresistant and uDef.pushresistant == true then
		uDef.pushresistant = false
		if not uDef.mass then
			uDef.mass = 4999
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
	if not uDef.customparams.iscommander then
		if uDef.featuredefs and uDef.health then
			-- wrecks
			if uDef.featuredefs.dead then
				uDef.featuredefs.dead.damage = uDef.health
				if uDef.metalcost and uDef.energycost then
					if name and not string.find(name, "_scav") then
						uDef.featuredefs.dead.metal = math.floor(uDef.metalcost * 0.6)
					end
				end
			end
			-- heaps
			if uDef.featuredefs.heap then
				uDef.featuredefs.heap.damage = uDef.health
				if uDef.metalcost and uDef.energycost then
					if name and not string.find(name, "_scav") then
						uDef.featuredefs.heap.metal = math.floor(uDef.metalcost * 0.25)
					end
				end
			end
		end
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
					uDef.category = string.sub(uDef.category, 1, empable) .. string.sub(uDef.category, empable + 7)
				end
			elseif not empable then
				uDef.category = uDef.category .. ' EMPABLE'
			end
		elseif not empable then
			uDef.category = uDef.category .. ' EMPABLE'
		end
	end

	if uDef.canfly then
		uDef.crashdrag = 0.01    -- default 0.005
		if not (string.find(name, "fepoch") or string.find(name, "fblackhy") or string.find(name, "corcrw") or string.find(name, "legfort")) then
			--(string.find(name, "liche") or string.find(name, "crw") or string.find(name, "fepoch") or string.find(name, "fblackhy")) then
			if not modOptions.experimentalnoaircollisions then
				uDef.collide = false
			else
				uDef.collide = true
			end
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
		if name == "armvp" then
			for ix, UnitName in pairs(uDef.buildoptions) do
				if UnitName == "armsam" then
					uDef.buildoptions[ix] = "armsam2"
				end
			end
		end
		if name == "corvp" then
			for ix, UnitName in pairs(uDef.buildoptions) do
				if UnitName == "cormist" then
					uDef.buildoptions[ix] = "cormist2"
				end
			end
		end
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

	-- Health
	if uDef.health then
		local x = modOptions.multiplier_maxdamage
		if x ~= 1 then
			if uDef.health * x > 15000000 then
				uDef.health = 15000000
			else
				uDef.health = uDef.health * x
			end
			if uDef.autoheal then
				uDef.autoheal = uDef.autoheal * x
			end
			if uDef.idleautoheal then
				uDef.idleautoheal = uDef.idleautoheal * x
			end
		end
	end

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

	-- Unit Cost
	if uDef.metalcost then
		local x = modOptions.multiplier_metalcost
		if x ~= 1 then
			uDef.metalcost = math.min(uDef.metalcost * x, 16000000)
		end
	end
	if uDef.energycost then
		local x = modOptions.multiplier_energycost
		if x ~= 1 then
			uDef.energycost = math.min(uDef.energycost * x, 16000000)
		end
	end
	if uDef.buildtime then
		local x = modOptions.multiplier_buildtimecost
		if x ~= 1 then
			uDef.buildtime = math.min(uDef.buildtime * x, 16000000)
		end
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
		local gravityModOption = modOptions.experimentalstandardgravity

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
			if wDef.weapontype == "BeamLaser" or wDef.weapontype == "LaserCannon" then
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
