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

local function prebakeUnitDefs()
	for name, unitDef in pairs(UnitDefs) do
		-- UnitDef changes go here
	end
end

-------------------------
-- DEFS POST PROCESSING
-------------------------

local modOptions = Spring.GetModOptions()

local holidays = Spring.Utilities.Gametype.GetCurrentHolidays()
local isAprilFools = holidays.aprilfools
local isHalloween = holidays.halloween
local isXmas = holidays.xmas
local holidayModels = VFS.Include("unitbasedefs/holiday_models.lua")

local evocomTweaks = VFS.Include("unitbasedefs/evocom.lua").Tweaks
local extraUnitsTweaks = VFS.Include("unitbasedefs/experimental_extra_units.lua").Tweaks
local scavUnitsForPlayers = VFS.Include("unitbasedefs/scavenger_units_for_players.lua").Tweaks
local airReworkTweaks = VFS.Include("unitbasedefs/air_rework_defs.lua").airReworkTweaks
local skyshiftUnitTweaks = VFS.Include("unitbasedefs/skyshiftunits_post.lua").skyshiftUnitTweaks
local proposed_unit_reworksTweaks = VFS.Include("unitbasedefs/proposed_unit_reworks_defs.lua").proposed_unit_reworksTweaks
local communityBalanceTweaks = VFS.Include("unitbasedefs/community_balance_patch_defs.lua").communityBalanceTweaks
local techsplitTweaks = VFS.Include("unitbasedefs/techsplit_defs.lua").techsplitTweaks
local techsplit_balanceTweaks = VFS.Include("unitbasedefs/techsplit_balance_defs.lua").techsplit_balanceTweaks
local scavWeaponDefPost = VFS.Include("gamedata/scavengers/weapondef_post.lua").scavWeaponDefPost

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
	for weaponDefName, weaponDef in pairs(unitDef.weapondefs) do
		weaponDef.reloadtime = round_to_frames(weaponDef, "reloadtime")
		weaponDef.burstrate = round_to_frames(weaponDef, "burstrate")

		-- weaponDef is not processed by weapondefs_post, may not have some subtables:
		table.ensureTable(weaponDef, "customparams")

		if weaponDef.customparams.cluster_def then
			weaponDef.customparams.cluster_def = unitDefName .. "_" .. weaponDef.customparams.cluster_def
			weaponDef.customparams.cluster_number = weaponDef.customparams.cluster_number or 5
		end
	end
end

-- uDef.movementclass lists
local hoverList = {
	HOVER2 = true,
	HOVER3 = true,
	HHOVER4 = true,
	AHOVER2 = true
}

local shipList = {
	BOAT3 = true,
	BOAT4 = true,
	BOAT5 = true,
	BOAT9 = true,
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
	ABOT3 = true,
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
categories["WEAPON"] = function(uDef) return next(uDef.weapondefs) ~= nil end
categories["NOWEAPON"] = function(uDef) return next(uDef.weapondefs) == nil end
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
categories["MINE"] = function(uDef) return uDef.weapondefs.minerange end
categories["COMMANDER"] = function(uDef) return commanderList[uDef.movementclass] end
categories["EMPABLE"] = function(uDef) return categories.SURFACE(uDef) and uDef.customparams.paralyzemultiplier ~= 0 end

-------------------------
-- MODULE FUNCTIONS
-------------------------

local function unitDef_Post(name, uDef)
	local isScav = string.sub(name, -5, -1) == "_scav"
	local basename = isScav and string.sub(name, 1, -6) or name
	local customparams = uDef.customparams
	local buildoptions = uDef.buildoptions
	local weapondefs = uDef.weapondefs
	local weapons = uDef.weapons

	if not uDef.icontype then
		uDef.icontype = name
	end

	--global physics behavior changes
	if uDef.health then
		uDef.minCollisionSpeed = 75 / Game.gameSpeed -- define the minimum velocity(speed) required for all units to suffer fall/collision damage.
	end

	-- Event Model Replacements: -----------------------------------------------------------------------------

	if isAprilFools and holidayModels.AprilFools[basename] then
		uDef.objectname = holidayModels.AprilFools[basename]
	elseif isHalloween and holidayModels.Halloween[basename] then
		uDef.objectname = holidayModels.Halloween[basename]
	elseif isXmas and holidayModels.Xmas[basename] then
		uDef.objectname = holidayModels.Xmas[basename]
	end

	----------------------------------------------------------------------------------------------------------



	if uDef.sounds then
		if uDef.sounds.ok then
			uDef.sounds.ok = nil
		end

		if uDef.sounds.select then
			uDef.sounds.select = nil
		end

		if uDef.sounds.activate then
			uDef.sounds.activate = nil
		end
		if uDef.sounds.deactivate then
			uDef.sounds.deactivate = nil
		end
		if uDef.sounds.build then
			uDef.sounds.build = nil
		end

		if uDef.sounds.underattack then
			uDef.sounds.underattack = nil
		end
	end

	-- Unit Restrictions
	if not customparams.techlevel then
		customparams.techlevel = 1
	end
	if not customparams.subfolder then
		customparams.subfolder = "none"
	end

	if modOptions.unit_restrictions_notech15 then
		if tonumber(customparams.techlevel) == 1.5 then
			customparams.modoption_blocked = true
		end
	end

	if modOptions.unit_restrictions_notech2 then
		if tonumber(customparams.techlevel) == 2 then
			customparams.modoption_blocked = true
		end
	end

	if modOptions.unit_restrictions_notech3 then
		if tonumber(customparams.techlevel) == 3 then
			customparams.modoption_blocked = true
		end
	end

	if modOptions.unit_restrictions_noair and (not (customparams.restrictions_exclusion and string.find(customparams.restrictions_exclusion, "_noair_"))) then
		if string.find(customparams.subfolder, "Aircraft", 1, true) then
			customparams.modoption_blocked = true
		elseif customparams.unitgroup and customparams.unitgroup == "aa" then
			customparams.modoption_blocked = true
		elseif uDef.canfly then
			customparams.modoption_blocked = true
		elseif (customparams.restrictions_inclusion and string.find(customparams.restrictions_inclusion, "_noair_")) then --used to remove factories and drone carriers with no other purpose (ex. leghive but not rampart)
			customparams.modoption_blocked = true
		end
	end

	if modOptions.unit_restrictions_nosea and (not (customparams.restrictions_exclusion and string.find(customparams.restrictions_exclusion, "_nosea_"))) then
		if (uDef.minwaterdepth and uDef.minwaterdepth > 0) or (uDef.category and string.find(uDef.category, "SHIP")) or (customparams.restrictions_inclusion and string.find(customparams.restrictions_inclusion, "_nosea_")) then
			customparams.modoption_blocked = true
		end
	end

	if modOptions.unit_restrictions_noextractors then
		if (uDef.extractsmetal and uDef.extractsmetal > 0) and (customparams.metal_extractor and customparams.metal_extractor > 0) then
			customparams.modoption_blocked = true
		end
	end

	if modOptions.legionsimplifiedmexes then
		local legiont15mex = {
			legmext15	= true,
		}
		if legiont15mex[basename] then
			uDef.customparams.modoption_blocked = true
		end
	end

	if modOptions.unit_restrictions_noconverters then
		if customparams.energyconv_capacity and customparams.energyconv_efficiency then
			customparams.modoption_blocked = true
		end
	end

	if modOptions.unit_restrictions_nonukes then
		for _, weapon in pairs(weapondefs) do
			if (weapon.targetable and weapon.targetable == 1) then
				customparams.modoption_blocked = true
				break
			end
		end
	end

	if modOptions.unit_restrictions_nonukes or modOptions.unit_restrictions_noantinuke then
		if next(weapondefs) then
			local numWeapons = 0
			local newWdefs = {}
			local hasAnti = false
			for i, weapon in pairs(weapondefs) do
				if weapon.interceptor and weapon.interceptor == 1 then
					weapondefs[i] = nil
					hasAnti = true
				else
					numWeapons = numWeapons + 1
					newWdefs[numWeapons] = weapon
				end
			end
			if hasAnti then
				uDef.weapondefs = newWdefs
				if numWeapons == 0 and (not (customparams.restrictions_exclusion and string.find(customparams.restrictions_exclusion, "_noantinuke_"))) then
					customparams.modoption_blocked = true
				else
					if uDef.metalcost then
						uDef.metalcost = math.floor(uDef.metalcost * 0.6)	-- give a discount for removing anti-nuke
						uDef.energycost = math.floor(uDef.energycost * 0.6)
					end
				end
			end
		end
	end

	if modOptions.unit_restrictions_nofusion then
		if (customparams.restrictions_inclusion and string.find(customparams.restrictions_inclusion, "_nofusion_")) then
			customparams.modoption_blocked = true
		end
	end

	if modOptions.unit_restrictions_notacnukes then
		if (customparams.restrictions_inclusion and string.find(customparams.restrictions_inclusion, "_notacnukes_")) then
			customparams.modoption_blocked = true
		end
	end

	if modOptions.unit_restrictions_nolrpc then
		if (customparams.restrictions_inclusion and string.find(customparams.restrictions_inclusion, "_nolrpc_")) then
			customparams.modoption_blocked = true
		end
	end

	if modOptions.unit_restrictions_noendgamelrpc then
		if (customparams.restrictions_inclusion and string.find(customparams.restrictions_inclusion, "_noendgamelrpc_")) then
			customparams.modoption_blocked = true
		end
	end

	--normal commander respawning
	if modOptions.comrespawn == "all" or (modOptions.comrespawn == "evocom" and modOptions.evocom)then
		if name == "armcom" or name == "corcom" or name == "legcom" then
			customparams.effigy = "comeffigylvl1"
			customparams.effigy_offset = 1
			customparams.respawn_condition = "health"
			customparams.minimum_respawn_stun = 5
			customparams.distance_stun_multiplier = 1
			local numBuildoptions = #buildoptions
			buildoptions[numBuildoptions + 1] = "comeffigylvl1"
		end
	end

	if modOptions.evocom then
		evocomTweaks(uDef, modOptions) -- also adds effigies for higher-level commanders
	end

	if customparams.evolution_target then
		customparams.combatradius                     = customparams.combatradius or 1000
		customparams.evolution_announcement_size      = tonumber(customparams.evolution_announcement_size)
		customparams.evolution_condition              = customparams.evolution_condition or "timer"
		customparams.evolution_health_threshold       = tonumber(customparams.evolution_health_threshold) or 0
		customparams.evolution_health_transfer        = customparams.evolution_health_transfer or "flat"
		customparams.evolution_power_enemy_multiplier = tonumber(customparams.evolution_power_enemy_multiplier) or 1
		customparams.evolution_power_multiplier       = tonumber(customparams.evolution_power_multiplier) or 1
		customparams.evolution_power_threshold        = tonumber(customparams.evolution_power_threshold) or 600
		customparams.evolution_timer                  = tonumber(customparams.evolution_timer) or 20
	end

	-- Tech Blocking System -------------------------------------------------------------------------------------------------------------------------
	if modOptions.tech_blocking then
		local techLevel = customparams.techlevel or 1
		if #buildoptions > 0 and (not uDef.speed or uDef.speed == 0) then
			if techLevel == 1 then
				customparams.tech_points_gain = customparams.tech_points_gain or 1
			elseif techLevel == 2 then
				customparams.tech_points_gain = customparams.tech_points_gain or 6
				customparams.tech_build_blocked_until_level = customparams.tech_build_blocked_until_level or 2
			elseif techLevel == 3 then
				customparams.tech_points_gain = customparams.tech_points_gain or 9
				customparams.tech_build_blocked_until_level = customparams.tech_build_blocked_until_level or 3
			end
		end
	end

	-- Extra Units ----------------------------------------------------------------------------------------------------------------------------------
	if modOptions.experimentalextraunits then
		extraUnitsTweaks(name, uDef)
	end

	-- Scavengers Units ------------------------------------------------------------------------------------------------------------------------
	if modOptions.scavunitsforplayers then
		scavUnitsForPlayers(name, uDef)
	end

	-- Release candidate units --------------------------------------------------------------------------------------------------------------------------------------------------------
	if modOptions.releasecandidates or modOptions.experimentalextraunits then

	end

	if string.find(name, "raptor", 1, true) and uDef.health then
		local raptorHealth = uDef.health
		uDef.activatewhenbuilt = true
		uDef.metalcost = raptorHealth * 0.5
		uDef.energycost = math.min(raptorHealth * 5, 16000000)
		uDef.buildtime = math.min(raptorHealth * 10, 16000000)
		uDef.hidedamage = true
		uDef.mass = raptorHealth
		uDef.canhover = true
		uDef.autoheal = math.ceil(math.sqrt(raptorHealth * 0.8))
		customparams.paralyzemultiplier = customparams.paralyzemultiplier or .2
		customparams.areadamageresistance = "_RAPTORACID_"
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
		local sightHeight = 0
		local radarHeight = 0

		if uDef.collisionvolumescales then
			local _, yScale = string.match(uDef.collisionvolumescales, "([^%s]+)%s+([^%s]+)")
			if yScale then
				local yVal = tonumber(yScale)
				sightHeight = sightHeight + yVal
				radarHeight = radarHeight + yVal
			end
		end

		if uDef.collisionvolumeoffsets then
			local _, yOffset = string.match(uDef.collisionvolumeoffsets, "([^%s]+)%s+([^%s]+)")
			if yOffset then
				local yVal = tonumber(yOffset)
				sightHeight = sightHeight + yVal
				radarHeight = radarHeight + yVal
			end
		end

		if sightHeight < 40 then
			sightHeight = 40
			radarHeight = 40
		end

		uDef.sightemitheight = sightHeight
		uDef.radaremitheight = radarHeight
	end

	-- Wreck and heap standardization
	if not customparams.iscommander and not customparams.iseffigy then
		if uDef.featuredefs and uDef.health then
			local wreckRatio = modOptions.wreck_metal_ratio or 0.6
			local heapRatio = modOptions.heap_metal_ratio or 0.25
			-- wrecks
			if uDef.featuredefs.dead then
				uDef.featuredefs.dead.damage = uDef.health
				if uDef.metalcost and uDef.energycost then
					uDef.featuredefs.dead.metal = math.floor(uDef.metalcost * wreckRatio)
				end
			end
			-- heaps
			if uDef.featuredefs.heap then
				uDef.featuredefs.heap.damage = uDef.health
				if uDef.metalcost and uDef.energycost then
					uDef.featuredefs.heap.metal = math.floor(uDef.metalcost * heapRatio)
				end
			end
		end
	end

	if uDef.maxslope then
		uDef.maxslope = math.floor((uDef.maxslope * 1.5) + 0.5)
	end

	local category = uDef.category or ""
	if not string.find(category, "OBJECT", 1, true) then -- objects should not be targetable and therefore are not assigned any other category
		local exemptcategory = uDef.exemptcategory
		for categoryName, condition in pairs(categories) do
			if not exemptcategory or not string.find(exemptcategory, categoryName, 1, true) then
				if condition(uDef) then
					category = category .. " " .. categoryName
				end
			end
		end
		uDef.category = category
	end

	if uDef.canfly then
		uDef.crashdrag = 0.01    -- default 0.005
		if not (string.find(name, "fepoch", 1, true) or string.find(name, "fblackhy", 1, true) or string.find(name, "corcrw", 1, true) or string.find(name, "legfort", 1, true)) then
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

	-- Sets idleautoheal to 5hp/s after 1800 frames aka 1 minute.
	if uDef.idleautoheal == nil then
		uDef.idleautoheal = 5
	end
	if uDef.idletime == nil then
		uDef.idletime = 1800
	end

	--Juno Rework
	if modOptions.junorework == true then
		if name == "armjuno" then
			uDef.metalcost = 500
			uDef.energycost = 12000
			uDef.buildtime = 15000
			weapondefs.juno_pulse.energypershot = 7000
			weapondefs.juno_pulse.metalpershot = 100
		end
		if name == "corjuno" then
			uDef.metalcost = 500
			uDef.energycost = 12000
			uDef.buildtime = 15000
			weapondefs.juno_pulse.energypershot = 7000
			weapondefs.juno_pulse.metalpershot = 100
		end
	end


	--- EMP rework
	if modOptions.emprework == true then
		if name == "armstil" then
			weapondefs.stiletto_bomb.areaofeffect = 250
			weapondefs.stiletto_bomb.burst = 3
			weapondefs.stiletto_bomb.burstrate = 0.3333
			weapondefs.stiletto_bomb.edgeeffectiveness = 0.30
			weapondefs.stiletto_bomb.damage.default = 3000
			weapondefs.stiletto_bomb.paralyzetime = 1
		end

		if name == "armspid" then
			weapondefs.spider.paralyzetime = 2
			weapondefs.spider.damage.vtol = 100
			weapondefs.spider.damage.default = 600
			weapondefs.spider.reloadtime = 1.495
		end

		if name == "armdfly" then
			weapondefs.armdfly_paralyzer.paralyzetime = 1
			weapondefs.armdfly_paralyzer.beamdecay = 0.05--testing
			weapondefs.armdfly_paralyzer.beamtime = 0.1--testing
			weapondefs.armdfly_paralyzer.areaofeffect = 8--testing
			weapondefs.armdfly_paralyzer.targetmoveerror = 0.05--testing




			--mono beam settings
			--weapondefs.armdfly_paralyzer.reloadtime = 0.05--testing
			--weapondefs.armdfly_paralyzer.damage.default = 150--testing (~2800/s for parity with live)
			--weapondefs.armdfly_paralyzer.beamdecay = 0.95
			--weapondefs.armdfly_paralyzer.duration = 200--should be unused?
			--weapondefs.armdfly_paralyzer.beamttl = 2--frames visible.just leads to laggy ghosting if raised too high.

			--burst testing within monobeam
			--weapondefs.armdfly_paralyzer.damage.default = 125
			--weapondefs.armdfly_paralyzer.reloadtime = 1--testing
			--weapondefs.armdfly_paralyzer.beamttl = 3--frames visible.just leads to laggy ghosting if raised too high.
			--weapondefs.armdfly_paralyzer.beamBurst = true--testing
			--weapondefs.armdfly_paralyzer.burst = 10--testing
			--weapondefs.armdfly_paralyzer.burstRate = 0.1--testing

		end

		if name == "armemp" then
			weapondefs.armemp_weapon.areaofeffect = 512
			weapondefs.armemp_weapon.burstrate = 0.3333
			weapondefs.armemp_weapon.edgeeffectiveness = -0.10
			weapondefs.armemp_weapon.paralyzetime = 22
			weapondefs.armemp_weapon.damage.default = 60000

		end
		if name == "armshockwave" then
			weapondefs.hllt_bottom.areaofeffect = 150
			weapondefs.hllt_bottom.edgeeffectiveness = 0.15
			weapondefs.hllt_bottom.reloadtime = 1.4
			weapondefs.hllt_bottom.paralyzetime = 5
			weapondefs.hllt_bottom.damage.default = 800
		end

		if name == "armthor" then
			weapondefs.empmissile.areaofeffect = 250
			weapondefs.empmissile.edgeeffectiveness = -0.50
			weapondefs.empmissile.damage.default = 20000
			weapondefs.empmissile.paralyzetime = 5
			weapondefs.emp.damage.default = 200
			weapondefs.emp.reloadtime = .5
			weapondefs.emp.paralyzetime = 1
		end

		if name == "corbw" then
			--weapondefs.bladewing_lyzer.burst = 4--shotgun mode, outdated but worth keeping
			--weapondefs.bladewing_lyzer.reloadtime = 0.8
			--weapondefs.bladewing_lyzer.beamburst = true
			--weapondefs.bladewing_lyzer.sprayangle = 2100
			--weapondefs.bladewing_lyzer.beamdecay = 0.5
			--weapondefs.bladewing_lyzer.beamtime = 0.03
			--weapondefs.bladewing_lyzer.beamttl = 0.4

			weapondefs.bladewing_lyzer.damage.default = 300
			weapondefs.bladewing_lyzer.paralyzetime = 1
		end


		if (name =="corfmd" or name =="armamd" or name =="cormabm" or name =="armscab") then
			customparams.paralyzemultiplier = 1.5
		end

		if (name == "armvulc" or name == "corbuzz" or name == "legstarfall" or name == "corsilo" or name == "armsilo") then
			customparams.paralyzemultiplier = 2
		end

		--if name == "corsumo" then
			--customparams.paralyzemultiplier = 0.9
		--end

		if name == "armmar" then
			customparams.paralyzemultiplier = 0.8
		end

		if name == "armbanth" then
			customparams.paralyzemultiplier = 1.6
		end

		--if name == "armraz" then
			--customparams.paralyzemultiplier = 1.2
		--end
		--if name == "armvang" then
			--customparams.paralyzemultiplier = 1.1
		--end

		--if name == "armlun" then
			--customparams.paralyzemultiplier = 1.05
		--end

		--if name == "corshiva" then
			--customparams.paralyzemultiplier = 1.1
		--end

		--if name == "corcat" then
			--customparams.paralyzemultiplier = 1.05
		--end

		--if name == "corkarg" then
			--customparams.paralyzemultiplier = 1.2
		--end
		--if name == "corsok" then
			--customparams.paralyzemultiplier = 1.1
		--end
		--if name == "cordemont4" then
			--customparams.paralyzemultiplier = 1.2
		--end

	end

	--Air rework
	if modOptions.air_rework == true then
		uDef = airReworkTweaks(name, uDef)
	end

	-- Skyshift: Air rework
	if modOptions.skyshift == true then
		uDef = skyshiftUnitTweaks(name, uDef)
	end

	-- Proposed Unit Reworks
	if modOptions.proposed_unit_reworks == true then
		uDef = proposed_unit_reworksTweaks(name, uDef)
	end

	-- Community Balance Patch
	if modOptions.community_balance_patch ~= "disabled" then
		uDef = communityBalanceTweaks(name, uDef, modOptions)
	end

	-- Legion Simplified Mex Rebalance
	if modOptions.legionsimplifiedmexes == true then
		if name == "legmex" then
			uDef.energyupkeep = 3
			uDef.extractsmetal = 0.001
		end
		if name == "legck" then
			uDef.metalcost = math.ceil(uDef.metalcost*1.1)
			uDef.energycost = math.ceil(uDef.energycost*0.8)
		end
		if name == "leggob" then
			uDef.metalcost = math.ceil(uDef.metalcost*1.25)
			uDef.energycost = math.ceil(uDef.energycost*0.7)
		end
		if name == "leglob" then
			uDef.metalcost = math.ceil(uDef.metalcost*1.1)
			uDef.energycost = math.ceil(uDef.energycost*0.8)
		end
		if name == "legaabot" then
			uDef.metalcost = math.ceil(uDef.metalcost*1.1)
			uDef.energycost = math.ceil(uDef.energycost*0.8)
		end
		if name == "legcen" then
			uDef.metalcost = math.ceil(uDef.metalcost*0.9)
			uDef.energycost = math.ceil(uDef.energycost*1.1)
		end
		if name == "legkark" then
			uDef.metalcost = math.ceil(uDef.metalcost*0.9)
			uDef.energycost = math.ceil(uDef.energycost*1.3)
		end
		if name == "legbal" then
			uDef.metalcost = math.ceil(uDef.metalcost*0.9)
			uDef.energycost = math.ceil(uDef.energycost*1.2)
		end
		if name == "legcv" then
			uDef.metalcost = math.ceil(uDef.metalcost*1.1)
			uDef.energycost = math.ceil(uDef.energycost*0.8)
		end
		if name == "leghades" then
			uDef.metalcost = math.ceil(uDef.metalcost*1.2)
			uDef.energycost = math.ceil(uDef.energycost*0.6)
		end
		if name == "leghelios" then
			uDef.metalcost = math.ceil(uDef.metalcost*1.1)
			uDef.energycost = math.ceil(uDef.energycost*0.8)
		end
		if name == "legbar" then
			uDef.metalcost = math.ceil(uDef.metalcost*0.9)
			uDef.energycost = math.ceil(uDef.energycost*1.3)
		end
		if name == "legrail" then
			uDef.metalcost = math.ceil(uDef.metalcost*0.95)
			uDef.energycost = math.ceil(uDef.energycost*1.05)
		end
		if name == "leggat" then
			uDef.metalcost = math.ceil(uDef.metalcost*0.9)
			uDef.energycost = math.ceil(uDef.energycost*1.3)
		end
		if name == "legnavyscout" then
			uDef.metalcost = math.ceil(uDef.metalcost*1.15)
			uDef.energycost = math.ceil(uDef.energycost*0.7)
		end
		if name == "legnavyaaship" then
			uDef.metalcost = math.ceil(uDef.metalcost*1.15)
			uDef.energycost = math.ceil(uDef.energycost*0.7)
		end
		if name == "legnavysub" then
			uDef.metalcost = math.ceil(uDef.metalcost*1.05)
			uDef.energycost = math.ceil(uDef.energycost*0.9)
		end
		if name == "legnavysub" then
			uDef.metalcost = math.ceil(uDef.metalcost*1.05)
			uDef.energycost = math.ceil(uDef.energycost*0.9)
		end
		if name == "legnavyfrigate" then
			uDef.metalcost = math.ceil(uDef.metalcost*1.2)
			uDef.energycost = math.ceil(uDef.energycost*0.6)
		end
		if name == "legnavyconship" then
			uDef.metalcost = math.ceil(uDef.metalcost*1.1)
			uDef.energycost = math.ceil(uDef.energycost*0.8)
		end
		if name == "legnavydestro" then
			uDef.metalcost = math.ceil(uDef.metalcost*0.95)
			uDef.energycost = math.ceil(uDef.energycost*1.1)
		end
		if name == "legnavyartyship" then
			uDef.metalcost = math.ceil(uDef.metalcost*0.95)
			uDef.energycost = math.ceil(uDef.energycost*1.1)
		end
	end

	-- Naval Balance Adjustments, if anything breaks here blame ZephyrSkies
	if modOptions.naval_balance_tweaks == true then
		local buildOptionReplacements = {
			-- t1 arm cons
			armcs = { ["armfhlt"] = "armnavaldefturret" },
			armch = { ["armfhlt"] = "armnavaldefturret" },
			armbeaver = { ["armfhlt"] = "armnavaldefturret" },
			armcsa = { ["armfhlt"] = "armnavaldefturret" },

			-- t1 cor cons
			corcs = { ["corfhlt"] = "cornavaldefturret" },
			corch = { ["corfhlt"] = "cornavaldefturret" },
			cormuskrat = { ["corfhlt"] = "cornavaldefturret" },
			corcsa = { ["corfhlt"] = "cornavaldefturret" },

			-- t1 leg cons
			legnavyconship = { ["legfmg"]  = "legnavaldefturret" },
			legch = { ["legfmg"]  = "legnavaldefturret" },
			legotter = { ["legfmg"]  = "legnavaldefturret" },
			legspcon = { ["legfmg"]  = "legnavaldefturret" },

			-- t2 arm cons
			armacsub = { ["armkraken"]  = "armanavaldefturret" },
			armmls = {
				["armfhlt"]  = "armnavaldefturret",
				["armkraken"] = "armanavaldefturret",
			},

			-- t2 cor cons
			coracsub = { ["corfdoom"]  = "coranavaldefturret" },
			cormls = {
				["corfhlt"]  = "cornavaldefturret",
				["corfdoom"] = "coranavaldefturret",
			},

			-- t2 leg cons
			leganavyengineer = {
				["legfmg"]  = "legnavaldefturret",
			},
		}

		if buildOptionReplacements[name] then
			local replacements = buildOptionReplacements[name]
			for i, buildOption in ipairs(buildoptions) do
				if replacements[buildOption] then
					buildoptions[i] = replacements[buildOption]
				end
			end
		end

		if name == "armfrad" then
			uDef.sightdistance = 800
		end
		if name == "corfrad" then
			uDef.sightdistance = 800
		end
		if name == "legfrad" then
			uDef.sightdistance = 800
		end

	end

	--Lategame Rebalance
	if modOptions.lategame_rebalance == true then
		if name == "armamb" then
			weapondefs.armamb_gun.reloadtime = 2
			weapondefs.armamb_gun_high.reloadtime = 7.7
		end
		if name == "cortoast" then
			weapondefs.cortoast_gun.reloadtime = 2.35
			weapondefs.cortoast_gun_high.reloadtime = 8.8
		end
		if name == "armpb" then
			weapondefs.armpb_weapon.reloadtime = 1.7
			weapondefs.armpb_weapon.range = 700
		end
		if name == "corvipe" then
			weapondefs.vipersabot.reloadtime = 2.1
			weapondefs.vipersabot.range = 700
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
			weapondefs.shiva_rocket.tracks = true
			weapondefs.shiva_rocket.turnrate = 7500
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
			weapondefs.stiletto_bomb.burst = 3
			weapondefs.stiletto_bomb.burstrate = 0.2333
			weapondefs.stiletto_bomb.damage = {
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
			weapondefs.mobileflak.reloadtime = 0.8333
		end
		if name == "corsent" then
			weapondefs.mobileflak.reloadtime = 0.8333
		end
		if name == "armaas" then
			weapondefs.mobileflak.reloadtime = 0.8333
		end
		if name == "corarch" then
			weapondefs.mobileflak.reloadtime = 0.8333
		end
		if name == "armflak" then
			weapondefs.armflak_gun.reloadtime = 0.6
		end
		if name == "corflak" then
			weapondefs.armflak_gun.reloadtime = 0.6
		end
		if name == "armmercury" then
			weapondefs.arm_advsam.reloadtime = 11
			weapondefs.arm_advsam.stockpile = false
		end
		if name == "corscreamer" then
			weapondefs.cor_advsam.reloadtime = 11
			weapondefs.cor_advsam.stockpile = false
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

		if tonumber(customparams.techlevel) == 2 and uDef.energycost and uDef.metalcost and uDef.buildtime and not (name == "armavp" or name == "coravp" or name == "armalab" or name == "coralab" or name == "armaap" or name == "coraap" or name == "armasy" or name == "corasy") then
			uDef.buildtime = math.ceil(uDef.buildtime * 0.015 / 5) * 500
		end
		if tonumber(customparams.techlevel) == 3 and uDef.energycost and uDef.metalcost and uDef.buildtime then
			uDef.buildtime = math.ceil(uDef.buildtime * 0.0015) * 1000
		end

		if name == "armnanotc" or name == "cornanotc" or name == "armnanotcplat" or name == "cornanotcplat" then
			uDef.metalcost = uDef.metalcost + 40
		end
	end

	----------------
	-- Tech Split --
	----------------

	if modOptions.techsplit == true then
		uDef = techsplitTweaks(name, uDef)
	end

	if modOptions.techsplit_balance == true then
		uDef = techsplit_balanceTweaks(name, uDef)
	end

	-- Experimental Low Priority Pacifists
	if modOptions.experimental_low_priority_pacifists then
		if uDef.energycost and uDef.metalcost and not next(weapons) and uDef.speed and uDef.speed > 0 and
		(string.find(name, "arm") or string.find(name, "cor") or string.find(name, "leg")) then
			uDef.power = uDef.power or ((uDef.metalcost + uDef.energycost / 60) * 0.1) --recreate the default power formula obtained from the spring wiki for target prioritization
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
	if (uDef.extractsmetal and uDef.extractsmetal > 0) and (customparams.metal_extractor and customparams.metal_extractor > 0) then
		local x = modOptions.multiplier_metalextraction * modOptions.multiplier_resourceincome
		uDef.extractsmetal = uDef.extractsmetal * x
		customparams.metal_extractor = customparams.metal_extractor * x
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
		if customparams.energymultiplier then
			customparams.energymultiplier = tonumber(customparams.energymultiplier) * x
		else
			customparams.energymultiplier = x
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
	if customparams.energyconv_capacity and customparams.energyconv_efficiency then
		local x = modOptions.multiplier_energyconversion * modOptions.multiplier_resourceincome
		--customparams.energyconv_capacity = customparams.energyconv_capacity * x
		customparams.energyconv_efficiency = customparams.energyconv_efficiency * x
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

	-- bounce shields
	if modOptions.experimentalshields == "bounceplasma" or modOptions.experimentalshields == "bounceeverything" then
		local shieldPowerMultiplier = 0.529 --converts to pre-shield rework vanilla integration
		if customparams.shield_power then
			customparams.shield_power = customparams.shield_power * shieldPowerMultiplier
		end
	end

	-- add model vertex displacement
	local vertexDisplacement = 5.5 + ((uDef.footprintx + uDef.footprintz) / 12)
	if vertexDisplacement > 10 then
		vertexDisplacement = 10
	end
	customparams.vertdisp = 1.0 * vertexDisplacement
	customparams.healthlookmod = 0

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

	if next(buildoptions) then
		-- Remove invalid unit defs.
		for index, option in pairs(buildoptions) do
			if not UnitDefs[option] then
				Spring.Log("AllDefs", LOG.INFO, "Removed buildoption (unit not loaded?): " .. tostring(option))
				buildoptions[index] = nil
			end
		end
		-- Deduplicate buildoptions (various modoptions or later mods can add the same units)
		-- Multiple unit defs can share the same table reference, so we create a new table for each
		uDef.buildoptions = table.getUniqueArray(buildoptions)
	end

	if next(weapondefs) then
		-- Some units can switch between exclusive weapon sets via their unit scripts.
		-- [<0] := never active, [0] := always active, [1] := primary set, [>1] := alternate sets
		for weaponName, weaponDef in pairs(weapondefs) do
			local groupNumber = 0
			if table.any(weapons, function(weapon) return weaponName:lower() == (weapon.def or ""):lower() end) then
				groupNumber = tonumber(weaponDef.customparams.weapons_group or 0) or 0
			else
				groupNumber = -1
			end
			weaponDef.customparams.weapons_group = groupNumber
		end
	end

	-- Suppress engine default piece explosion effects (handled by gfx_death_fire_smoke_gl4 widget)
	if not uDef.sfxtypes then
		uDef.sfxtypes = {}
	end
	if not uDef.sfxtypes.pieceexplosiongenerators then
		uDef.sfxtypes.pieceexplosiongenerators = { "blank" }
	end
	-- Suppress engine default crash explosion effects (handled by gfx_death_fire_smoke_gl4 widget)
	if not uDef.sfxtypes.crashexplosiongenerators then
		uDef.sfxtypes.crashexplosiongenerators = { "blank" }
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
local function weaponDef_Post(name, wDef)
	local customparams = wDef.customparams
	local damage = wDef.damage
	local shield = wDef.shield

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
				damage.default = 50000
			end
			if name == 'spybombx' then
				wDef.areaofeffect = 350
				wDef.edgeeffectiveness = 0.4
				wDef.paralyzetime = 20
				damage.default = 16000
			end
			if name == 'spybombxscav' then
				wDef.edgeeffectiveness = 0.50
				wDef.paralyzetime = 12
				damage.default = 35000
			end
		end


		--Air rework
		if modOptions.air_rework == true then
			if wDef.weapontype == "BeamLaser" then
				damage.vtol = damage.default * 0.25
			end
			if wDef.range == 300 and wDef.reloadtime == 0.4 then
				--comm lasers
				damage.vtol = damage.default
			end
			if wDef.weapontype == "Cannon" and damage.default then
				damage.vtol = damage.default * 0.35
			end
		end

		--[[Skyshift: Air rework
		if modoptions.skyshift == true then
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
			if shield then
				shield.repulser = false
			end
		elseif shieldModOption == "absorbeverything" then
			if shield then
				shield.repulser = false
			end
			if (not wDef.interceptedbyshieldtype) or wDef.interceptedbyshieldtype ~= 1 then
				wDef.interceptedbyshieldtype = 1
			end
		elseif shieldModOption == "bounceeverything" then
			if shield then
				shield.repulser = true
			end
			if (not wDef.interceptedbyshieldtype) or wDef.interceptedbyshieldtype ~= 1 then
				wDef.interceptedbyshieldtype = 1
			end
		end


		local bounceShields = shieldModOption == "bounceeverything" or shieldModOption == "bounceplasma"
		if bounceShields then
			if shield then
				local shieldPowerMultiplier = 0.529 --converts to pre-shield rework vanilla integration
				local shieldRegenMultiplier = 0.4 --converts to pre-shield rework vanilla integration
				shield.power = shield.power * shieldPowerMultiplier
				shield.powerregen = shield.powerregen * shieldRegenMultiplier
				shield.startingpower = shield.startingpower * shieldPowerMultiplier
				shield.repulser = true
			end
		end

		-- allows unblocked weapons' aoe to reach inside shields
		if ((not wDef.interceptedbyshieldtype or wDef.interceptedbyshieldtype ~= 1) and wDef.weapontype ~= "Cannon") then
			customparams.shield_aoe_penetration = true
		end

		-- Due to the engine not handling overkill damage, we have to store the original shield damage values as a customParam for unit_shield_behavior.lua to reference
		if damage then
			-- For balance, paralyzers need to do reduced damage to shields, as their raw raw damage is outsized
			local paralyzerShieldDamageMultiplier = 0.25
			-- VTOL's may or may not do full damage to shields if not defined in weapondefs
			local vtolShieldDamageMultiplier = 0

			if not bounceShields then --this is for the block-style shields gadget to use.
				if damage.shields then
					customparams.shield_damage = damage.shields
				elseif damage.default then
					customparams.shield_damage = damage.default
				elseif damage.vtol then
					customparams.shield_damage = damage.vtol * vtolShieldDamageMultiplier
				else
					customparams.shield_damage = 0
				end

				if wDef.paralyzer then
					customparams.shield_damage = customparams.shield_damage * paralyzerShieldDamageMultiplier
				end

				-- Set damage to 0 so projectiles always collide with shield. Without this, if damage > shield charge then it passes through.
				-- Applying damage is instead handled in unit_shield_behavior.lua
				damage.shields = 0

				if wDef.beamtime and wDef.beamtime > 1 / Game.gameSpeed then
					-- This splits up the damage of hitscan weapons over the duration of beamtime, as each frame counts as a hit in ShieldPreDamaged() callin
					-- Math.floor is used to sheer off the extra digits of the number of frames that the hits occur
					customparams.beamtime_damage_reduction_multiplier = 1 / math.floor(wDef.beamtime * Game.gameSpeed)
				end
			end
		end

		if modOptions.multiplier_shieldpower then
			if shield then
				local multiplier = modOptions.multiplier_shieldpower
				if shield.power then
					shield.power = shield.power * multiplier
				end
				if shield.powerregen then
					shield.powerregen = shield.powerregen * multiplier
				end
				if shield.powerregenenergy then
					shield.powerregenenergy = shield.powerregenenergy * multiplier
				end
				if shield.startingpower then
					shield.startingpower = shield.startingpower * multiplier
				end
			end
		end
		----------------------------------------

		--Controls whether the weapon aims for the center or the edge of its target's collision volume. Clamped between -1.0 - target the far border, and 1.0 - target the near border.
		if wDef.targetborder == nil then
			wDef.targetborder = 1 --Aim for just inside the hitsphere

			if Engine.FeatureSupport.targetBorderBug and wDef.weapontype == "BeamLaser" or wDef.weapontype == "LightningCannon" then
				wDef.targetborder = 0.33 --approximates in current engine with bugged calculation, to targetborder = 1.
			end
		end

		-- Prevent weapons from aiming only at auto-generated targets beyond their own range.
		if wDef.proximitypriority then
			local range = math.max(wDef.range or 10, 1) -- prevent div0 -- todo: account for multiplier_weaponrange
			local rangeBoost = math.max(range + ((customparams.exclude_preaim and 0) or (customparams.preaim_range or math.max(range * 0.1, 20))), range) -- see unit_preaim
			local proximity = math.max(wDef.proximitypriority, (-0.4 * rangeBoost - 100) / range) -- see CGameHelper::GenerateWeaponTargets
			wDef.proximitypriority = math.clamp(proximity, -1, 10) -- upper range allowed for targeting weapons for drone bombers which can overrange massively
		end

		if wDef.craterareaofeffect then
			wDef.cratermult = (wDef.cratermult or 0) + wDef.craterareaofeffect / 2000
		end

		if wDef.weapontype == "Cannon" then
			if not wDef.model then
				-- do not cast shadows on plasma shells
				wDef.castshadow = false
			end

			if wDef.stages == nil then
				wDef.stages = 10
				if damage and damage.default and wDef.areaofeffect then
					wDef.stages = math.floor(7.5 + math.min(damage.default * 0.0033, wDef.areaofeffect * 0.13))
					wDef.alphadecay = 1 - ((1 / wDef.stages) / 1.5)
					wDef.sizedecay = 0.4 / wDef.stages
				end
			end
		end

		if isXmas and wDef.weapontype == "StarburstLauncher" and wDef.model and VFS.FileExists('objects3d\\candycane_' .. wDef.model) then
			wDef.model = 'candycane_' .. wDef.model
		end

		-- prepared to strip these customparams for when we remove old deferred lighting widgets
		--if customparams then
		--	customparams.expl_light_opacity = nil
		--	customparams.expl_light_heat_radius = nil
		--	customparams.expl_light_radius = nil
		--	customparams.expl_light_color = nil
		--	customparams.expl_light_nuke = nil
		--	customparams.expl_light_skip = nil
		--	customparams.expl_light_heat_life_mult = nil
		--	customparams.expl_light_heat_radius_mult = nil
		--	customparams.expl_light_heat_strength_mult = nil
		--	customparams.expl_light_life = nil
		--	customparams.expl_light_life_mult = nil
		--	customparams.expl_noheatdistortion = nil
		--	customparams.light_skip = nil
		--	customparams.light_fade_time = nil
		--	customparams.light_fade_offset = nil
		--	customparams.light_beam_mult = nil
		--	customparams.light_beam_start = nil
		--	customparams.light_beam_mult_frames = nil
		--	customparams.light_camera_height = nil
		--	customparams.light_ground_height = nil
		--	customparams.light_color = nil
		--	customparams.light_radius = nil
		--	customparams.light_radius_mult = nil
		--	customparams.light_mult = nil
		--	customparams.fake_Weapon = nil
		--end

		if damage then
			damage.indestructable = 0
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
		if string.find(name, '_scav', 1, true) then
			wDef = scavWeaponDefPost(name, wDef)
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
		if customparams.overrange_distance then
			customparams.overrange_distance = customparams.overrange_distance * rangeMult
		end
		if customparams.preaim_range then
			customparams.preaim_range = customparams.preaim_range * rangeMult
		end
	end

	-- Weapon Damage
	local damageMult = modOptions.multiplier_weapondamage
	if damageMult ~= 1 then
		if damage then
			for damageClass, damageValue in pairs(damage) do
				damage[damageClass] = damage[damageClass] * damageMult
			end
		end
	end

	-- ExplosionSpeed is calculated same way engine does it, and then doubled
	-- Note that this modifier will only effect weapons fired from actual units, via super clever hax of using the weapon name as prefix
	if damage and damage.default then
		if string.find(name, '_', 1, true) then
			local prefix = string.sub(name, 1, 3)
			if prefix == 'arm' or prefix == 'cor' or prefix == 'leg' or prefix == 'rap' then
				local globaldamage = math.max(30, damage.default / 20)
				local defExpSpeed = (8 + (globaldamage * 2.5)) / (9 + (math.sqrt(globaldamage) * 0.70)) * 0.5
				wDef.explosionSpeed = defExpSpeed * 2
			end
		end
	end
end

-- process effects
local function explosionDef_Post(name, eDef)

end

--------------------------
-- MODOPTIONS
-------------------------

-- process modoptions (last, because they should not get baked)
local function modOptions_Post (UnitDefs, WeaponDefs)

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

--------------------------
-- MODULE EXPORT
--------------------------

return {
	UnitDef_Post           = unitDef_Post,
	WeaponDef_Post         = weaponDef_Post,
	ExplosionDef_Post      = explosionDef_Post,
	ModOptions_Post        = modOptions_Post,
	PrebakeUnitDefs        = prebakeUnitDefs,
}
