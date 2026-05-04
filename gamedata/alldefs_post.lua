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
local processRaptorsUnit = VFS.Include("unitbasedefs/raptor_unitdefs_post.lua").Tweaks
local scavUnitsForPlayers = VFS.Include("unitbasedefs/scavenger_units_for_players.lua").Tweaks
local legionSimpleMexes = VFS.Include("unitbasedefs/legion_simplified_mexes.lua").Tweaks
local lateGameRebalance = VFS.Include("unitbasedefs/lategame_rebalance.lua").Tweaks
local junoReworkTweaks = VFS.Include("unitbasedefs/juno_rework.lua").Tweaks
local navalBalanceTweaks = VFS.Include("unitbasedefs/naval_balance_tweaks.lua").Tweaks
local skyshiftUnitTweaks = VFS.Include("unitbasedefs/skyshiftunits_post.lua").skyshiftUnitTweaks
local proposed_unit_reworksTweaks = VFS.Include("unitbasedefs/proposed_unit_reworks_defs.lua").proposed_unit_reworksTweaks
local communityBalanceTweaks = VFS.Include("unitbasedefs/community_balance_patch_defs.lua").communityBalanceTweaks
local techsplitTweaks = VFS.Include("unitbasedefs/techsplit_defs.lua").techsplitTweaks
local techsplit_balanceTweaks = VFS.Include("unitbasedefs/techsplit_balance_defs.lua").techsplit_balanceTweaks

local airRework = VFS.Include("unitbasedefs/air_rework_defs.lua")
local airReworkUnitTweaks = airRework.UnitTweaks
local airReworkWeaponTweaks = airRework.WeaponTweaks
local empRework = VFS.Include("unitbasedefs/emp_rework.lua")
local empReworkUnitTweaks = empRework.UnitTweaks
local empReworkWeaponTweaks = empRework.WeaponTweaks

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

	--- beta tractorbeam mod option
	if modOptions.beta_tractorbeam == true then
		if uDef.transportcapacity then
			uDef.transportcapacity = 1000
			uDef.transportsize = 1000
			uDef.transportunloadmethod = 0
			uDef.transportmass = 100000
			uDef.holdsteady = true
			uDef.releaseheld = true
			uDef.loadingRadius = 512
			uDef.objectname = "units/" .. name .. "_tractorbeam.s3o"
			if name == "armdfly" or name == "legstronghold" then
				uDef.script = "units/weaponized_air_transport_lus.lua"
			else
				uDef.script = "units/generic_air_transport_lus.lua"
			end
		end
	end

	-- Cache holiday checks for performance
	if not holidays then
		holidays = Spring.Utilities.Gametype.GetCurrentHolidays()
		isAprilFools = holidays["aprilfools"]
		isHalloween = holidays["halloween"]
		isXmas = holidays["xmas"]
	end

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
		evocomTweaks(name, uDef, modOptions) -- also adds effigies for higher-level commanders
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
		processRaptorsUnit(uDef)
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
		junoReworkTweaks(name, uDef)
	end

	--- EMP rework
	if modOptions.emprework == true then
		empReworkUnitTweaks(name, uDef)
	end

	--Air rework
	if modOptions.air_rework == true then
		uDef = airReworkUnitTweaks(name, uDef)
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
		legionSimpleMexes(name, uDef)
	end

	-- Naval Balance Adjustments, if anything breaks here blame ZephyrSkies
	if modOptions.naval_balance_tweaks == true then
		navalBalanceTweaks(name, uDef)
	end

	--Lategame Rebalance
	if modOptions.lategame_rebalance == true then
		lateGameRebalance(name, uDef)
	end

	-- Factory costs test

	if modOptions.factory_costs == true then

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
			empReworkWeaponTweaks(name, wDef)
		end

		--Air rework
		if modOptions.air_rework == true then
			airReworkWeaponTweaks(wDef)
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

				if wDef.stages == nil then
					wDef.stages = 10
					if damage and damage.default and wDef.areaofeffect then
						wDef.stages = math.floor(7.5 + math.min(damage.default * 0.0033, wDef.areaofeffect * 0.13))
						wDef.alphadecay = 1 - ((1 / wDef.stages) / 1.5)
						wDef.sizedecay = 0.4 / wDef.stages
					end
				end

				-- Store original visual properties before zeroing (GL4 gadget reads WeaponDefs at runtime)
				if not wDef.customparams then wDef.customparams = {} end
				wDef.customparams.plasma_size_orig = wDef.size or 2

				-- Hide engine cannon projectile rendering (GL4 gadget replaces it)
				-- Keep size tiny but non-zero so projectile stays in GetVisibleProjectiles
				wDef.size = 0.001
				wDef.stages = 1
				wDef.alphadecay = 1
				wDef.sizedecay = 1
				wDef.texture1 = "plasma_gl4_invis"
			else
				if wDef.stages == nil then
					wDef.stages = 10
					if damage and damage.default and wDef.areaofeffect then
						wDef.stages = math.floor(7.5 + math.min(damage.default * 0.0033, wDef.areaofeffect * 0.13))
						wDef.alphadecay = 1 - ((1 / wDef.stages) / 1.5)
						wDef.sizedecay = 0.4 / wDef.stages
					end
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
			-- Store original visual properties before zeroing (GL4 gadget reads WeaponDefs at runtime)
			if not wDef.customparams then wDef.customparams = {} end
			wDef.customparams.beam_thickness_orig = wDef.thickness or 2
			wDef.customparams.beam_corethickness_orig = wDef.corethickness or 0.3
			wDef.customparams.beam_laserflaresize_orig = wDef.laserflaresize or 7
			if wDef.corethickness then
				wDef.customparams.beam_corethickness_orig = wDef.corethickness * 1.21
			end
			if wDef.thickness then
				wDef.customparams.beam_thickness_orig = wDef.thickness * 1.27
			end
			if wDef.laserflaresize then
				wDef.customparams.beam_laserflaresize_orig = wDef.laserflaresize * 1.15
			end
			-- Hide engine beam rendering (GL4 gadget replaces it)
			wDef.thickness = 0.001
			wDef.corethickness = 0
			wDef.laserflaresize = 0
			wDef.texture1 = "beam_gl4_invis"   -- nonexistent texture -> engine Draw() early-outs
			wDef.texture3 = "beam_gl4_invis"
			wDef.texture4 = "beam_gl4_invis"
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
