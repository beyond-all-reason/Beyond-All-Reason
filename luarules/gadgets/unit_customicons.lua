--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    ico_customicons.lua
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
-- This gadget checks through the attributes of each unitdef and assigns an appropriate icon for use in the minimap & zoomed out mode.
--
-- The reason that this is a gadget (it could also be a widget) and not part of weapondefs_post.lua/iconTypes.lua is the following:
-- the default valuesfor UnitDefs attributes that are not specified in our unitdefs lua files are only loaded into UnitDefs AFTER
-- unitdefs_post.lua and iconTypes.lua have been processed. For example, at the time of unitdefs_post, for most units ud.speed is
-- nil and not a number, so we can't e.g. compare it to zero. Also, it's more modularized as a widget/gadget.
-- [We could set the default values up in unitdefs_post to match engine defaults but thats just too hacky.]
--
-- Bluestone 27/04/2013
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name = "CustomIcons",
		desc = "Sets custom unit icons",
		author = "trepan,BD,TheFatController,Floris",
		date = "Jan 8, 2007",
		license = "GNU GPL, v2 or later",
		layer = -100,
		enabled = true  --  loaded by default?
	}
end


--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then
	return false
end

--------------------------------------------------------------------------------

local iconScale = 1.05
if Spring.GetConfigFloat then
	iconScale = Spring.GetConfigFloat("UnitIconScale", 1.05)
end

local spSetUnitDefIcon = Spring.SetUnitDefIcon
local spAddUnitIcon = Spring.AddUnitIcon
local spFreeUnitIcon = Spring.FreeUnitIcon

local icons = {
	-- ID,   icon png file,   scale
	{ "armcom.user", "armcom", 1.75 },
	{ "corcom.user", "corcom", 1.75 },

	{ "mine1.user", "mine", 0.36 },
	{ "mine2.user", "mine", 0.44 },
	{ "mine3.user", "mine", 0.53 },

	{ "sub_t1.user", "sub", 1.33 },
	{ "sub_t2.user", "sub", 1.7 },
	{ "sub_t3.user", "sub", 2 },
	{ "sub_t1_worker.user", "sub_worker", 1.33 },
	{ "sub_t2_worker.user", "sub_worker", 1.66 },

	{ "beacon.user", "beacon", 1.66 },
	{ "lootboxbronze.user", "lootbox", 1.0 },
	{ "lootboxsilver.user", "lootboxt2", 1.1 },
	{ "lootboxgold.user", "lootboxt3", 1.15 },
	{ "lootboxplatinum.user", "lootboxt4", 1.2 },

	{ "wind.user", "wind", 1 },
	{ "energy1.user", "solar", 1.5 },
	{ "energy2.user", "energy", 1.63 },
	{ "energy3.user", "fusion", 1.4 },
	{ "energy4.user", "hazardous", 1.8 },
	{ "energy5.user", "fusion", 1.8 },
	{ "energy6.user", "energy", 2.05 },

	{ "eye.user", "eyes", 0.85 },
	{ "spy.user", "eye", 1.18 },

	{ "hover_t1.user", "hover", 1.15 },
	{ "hover_raid.user", "hover", 1.05 },
	{ "hover_gun.user", "hover", 1.05 },
	{ "hover_t1_worker.user", "hover_worker", 1.2 },
	{ "hover_t1_aa.user", "hover_aa", 1.1 },
	{ "hover_t1_missile.user", "hover", 1.35 },
	{ "hover_t2.user", "hover", 1.5 },
	{ "hover_t3.user", "hover", 1.75 },
	{ "hover_transport.user", "hovertrans", 1.7 },

	{ "ship_tiny.user", "ship", 0.8 },
	{ "ship_raid.user", "ship", 1.1 },
	{ "ship.user", "ship", 1.2 },
	{ "ship_pship.user", "ship", 1.2 },
	{ "ship_torpedo.user", "ship", 1.25 },
	{ "ship_destroyer.user", "ship", 1.44 },
	{ "ship_t1_worker.user", "ship_worker", 1.33 },
	{ "ship_aa.user", "ship_aa", 1.2 },
	{ "ship_t2.user", "ship", 1.65 },
	{ "ship_t2_jammer.user", "ship_jammer", 1.65 },
	{ "ship_t2_worker.user", "ship_worker", 1.65 },
	{ "ship_t2_aa.user", "ship_aa", 1.65 },
	{ "ship_t2_cruiser.user", "ship", 2.15 },
	{ "ship_t2_missile.user", "ship", 2 },
	{ "ship_t2_carrier.user", "ship", 2.4 },
	{ "ship_t2_battleship.user", "ship", 2.55 },
	{ "ship_t2_flagship.user", "ship", 3.3 },
	{ "ship_engineer.user", "shipengineer", 1.5 },
	{ "ship_transport.user", "shiptrans", 2 },

	{ "engineer.user", "wrench", 1.3 },
	{ "engineer_small.user", "wrench", 0.9 },

	{ "commandtower.user", "mission_command_tower", 2.35 },

	{ "amphib_t1.user", "amphib", 1.15 },
	{ "amphib_tank.user", "amphib", 1.2 },
	{ "amphib_t1_aa.user", "amphib_aa", 1.2 },
	{ "amphib_t1_worker.user", "amphib_worker", 1.3 },
	{ "amphib_t2.user", "amphib", 1.6 },
	{ "amphib_t2_aa.user", "amphib_aa", 1.6 },
	{ "amphib_t3.user", "amphib", 2.1 },

	{ "shield.user", "shield", 1.5 },

	{ "targetting.user", "targetting", 1.3 },
	{ "seismic.user", "seismic", 1.4 },

	{ "radar_t1.user", "radar", 0.9 },
	{ "jammer_t1.user", "jammer", 0.9 },
	{ "radar_t2.user", "radar", 1.2 },
	{ "jammer_t2.user", "jammer", 1.2 },

	{ "korgoth.user", "mech", 3.3 },
	{ "bantha.user", "bantha", 2.7 },
	{ "juggernaut.user", "juggernaut", 3.0 },
	{ "juggernaut2.user", "bot", 2.75 },
	{ "commando.user", "commando", 1.35 },
	{ "commando2.user", "mech", 1.3 }, -- old

	{ "mex_t1.user", "mex", 0.77 },
	{ "mex_t2.user", "mex", 1.15 },

	{ "metalmaker_t1.user", "metalmaker", 0.75 },
	{ "metalmaker_t2.user", "metalmaker", 1.15 },

	{ "energystorage.user", "estore", 1.05 },
	{ "energystorage_t2.user", "estore", 1.25 },
	{ "metalstorage.user", "mstore", 1.05 },
	{ "metalstorage_t2.user", "mstore", 1.25 },

	{ "emp.user", "emp", 1.8 },
	{ "tacnuke.user", "tacnuke", 1.8 },
	{ "nuke.user", "nuke", 1.8 },
	{ "nuke_big.user", "nuke", 2.4 },
	{ "antinuke.user", "antinuke", 1.6 },
	{ "antinuke_mobile.user", "antinukemobile", 1.4 },

	{ "aa1.user", "aa", 0.85 },
	{ "aa2.user", "aa", 1.1 },
	{ "aa_flak.user", "aa", 1.4 },
	{ "aa_longrange.user", "aa", 1.8 },

	{ "worker.user", "worker", 0.85 },

	{ "allterrain_t1.user", "allterrain", 1 },
	{ "allterrain_emp.user", "allterrain", 1 },
	{ "allterrain_t2.user", "allterrain", 1.33 },
	{ "allterrain_t3.user", "allterrain", 1.95 },
	{ "allterrain_vanguard.user", "allterrain", 2.3 },

	{ "bot_t1_flea.user", "bot", 0.51 },
	{ "bot_t1_tinyworker.user", "worker", 0.66 },
	{ "bot_t1_raid.user", "bot", 0.7 },
	{ "bot_t1.user", "bot", 0.95 },
	{ "bot_t1_big.user", "bot", 1.1 },
	{ "bot_t1_worker.user", "bot_worker", 0.95 },
	{ "bot_t1_aa.user", "bot_aa", 0.95 },
	{ "bot_t2_raid.user", "bot", 1.1 },
	{ "bot_t2.user", "bot", 1.28 },
	{ "bot_t2_radar.user", "bot_radar", 1.28 },
	{ "bot_t2_jammer.user", "bot_jammer", 1.28 },
	{ "bot_t2_big.user", "bot", 1.47 },
	{ "bot_t2_worker.user", "bot_worker", 1.33 },
	{ "bot_t2_aa.user", "bot_aa", 1.28 },
	{ "bot_t3.user", "bot", 1.9 },

	{ "vehicle_t1_flea.user", "vehicle", 0.55 },
	{ "vehicle_t1_raid.user", "vehicle", 0.85 },
	{ "vehicle_t1.user", "vehicle", 1 },
	{ "vehicle_t1_tank.user", "vehicle", 1.1 },
	{ "vehicle_t1_missile.user", "vehicle", 1 },
	{ "vehicle_t1_big.user", "vehicle", 1.18 },
	{ "vehicle_t1_aa.user", "vehicle_aa", 1 },
	{ "vehicle_t2.user", "vehicle", 1.3 },
	{ "vehicle_t2_radar.user", "vehicle_radar", 1.3 },
	{ "vehicle_t2_jammer.user", "vehicle_jammer", 1.3 },
	{ "vehicle_t2_tank.user", "vehicle", 1.4 },
	{ "vehicle_t2_aa.user", "vehicle_aa", 1.3 },
	{ "vehicle_t2_big.user", "vehicle", 1.5 },
	{ "vehicle_t1_worker.user", "vehicle_worker", 0.95 },
	{ "vehicle_t2_worker.user", "vehicle_worker", 1.3 },

	{ "vehicle_trans.user", "vehicle_trans", 1.7 },

	{ "building_t1.user", "building", 1 },
	{ "building_t2.user", "building", 1.3 },

	{ "factory_t1.user", "factory", 1.45 },
	{ "factory_t2.user", "factory", 1.85 },
	{ "factory_t3.user", "factory", 2.4 },
	{ "factory_t1_vehicle.user", "factory_vehicle", 1.45 },
	{ "factory_t2_vehicle.user", "factory_vehicle_t2", 1.85 },
	{ "factory_t1_bot.user", "factory_bot", 1.45 },
	{ "factory_t2_bot.user", "factory_bot_t2", 1.85 },
	{ "factory_t1_ship.user", "factory_ship", 1.45 },
	{ "factory_t2_ship.user", "factory_ship_t2", 1.85 },
	{ "factory_t1_air.user", "factory_air", 1.45 },
	{ "factory_t2_air.user", "factory_air_t2", 1.85 },
	{ "factory_hover.user", "factory_hover", 1.45 },
	{ "factory_amph.user", "factory_amph", 1.45 },
	{ "factory_gantry.user", "factory_gantry", 2.4 },

	{ "lrpc.user", "lrpc", 2.35 },
	{ "lrpc_lolcannon.user", "lrpc", 3.5 },

	{ "chicken1.user", "chicken", 0.9 },
	{ "chicken2.user", "chicken", 1.2 },
	{ "chicken3.user", "chicken", 1.5 },
	{ "chicken4.user", "chicken", 2.6 },
	{ "chicken_air.user", "chicken_air", 1.3 },
	{ "chicken_air2.user", "chicken_air", 1.7 },
	{ "chicken_roost.user", "chicken_roost", 1.5 },
	{ "chicken_queen.user", "chicken_queen", 4 },

	{ "meteor.user", "blank", 1 },

	{ "wall.user", "building", 0.5 },

	{ "air_t1.user", "air", 0.82 },
	{ "air_t1_worker.user", "air_worker", 1.2 },
	{ "air_t1_hover.user", "air_hover", 1.2 },
	{ "air_t1_bomber.user", "air_bomber", 1.35 },
	{ "air_t1_transport.user", "air_trans", 1.3 },
	{ "air_t1_scout.user", "air_los", 0.75 },
	{ "air_t2.user", "air", 0.98 },
	{ "air_t2_worker.user", "air_worker", 1.55 },
	{ "air_t2_hover.user", "air_hover", 1.4 },
	{ "air_t2_hover_missile.user", "air_hover", 1.4 },
	{ "air_t2_bomber.user", "air_bomber", 1.66 },
	{ "air_t2_transport.user", "air_trans", 1.75 },
	{ "air_t2_radar.user", "air_los", 1.33 },
	{ "air_t2_torpbomber.user", "air_hover", 1.6 },
	{ "air_flagship.user", "air_flagship", 3 },
	{ "air_bladew.user", "air_hover_bw", 0.75 },
	{ "air_torp.user", "air_hover", 1.5 },
	{ "air_krow.user", "air_krow", 2 },
	{ "air_liche.user", "air_liche", 2 },
	{ "air_krow2.user", "air_hover", 2 },
	{ "air_liche2.user", "air_bomber", 2 },

	{ "defence_0.user", "defence", 0.8 },
	{ "defence_0_laser.user", "defence", 0.8 },
	{ "defence_0_laser2.user", "defence", 0.94 },
	{ "defence_1.user", "defence", 1.05 },
	{ "defence_1_laser.user", "defence", 1.05 },
	{ "defence_1_arty.user", "arty", 1.3 },
	{ "defence_2.user", "defence", 1.4 },
	{ "defence_2_laser.user", "defence", 1.4 },
	{ "defence_2_arty.user", "arty", 1.5 },
	{ "defence_3.user", "defence", 1.95 },
	{ "defence_1_naval.user", "defence", 1.05 },
	{ "defence_2_naval.user", "defence", 1.4 },

	{ "boss.user", "skull", 2.5 },

	{ "t4_demon.user", "cordemont4", 2.5 },
	{ "t4_invader.user", "armvadert4", 2.5 },
	{ "t4_ratte.user", "armrattet4", 2.95 },
	{ "t4_recluse.user", "armsptkt4", 2.2 },
	{ "t4_karg.user", "corkarganetht4", 3.0 },
	{ "t4_peewee.user", "armpwt4", 2.2 },
	{ "t4_fepoch.user", "air_t4_flagship", 3.2 },
	{ "t4_fblackhy.user", "air_t4_flagship", 3.2 },
	{ "t4_krow.user", "corcrwt4", 3.2 },
	{ "t4_thund.user", "armthundt4", 3.2 },
	{ "t4_armcomboss.user", "armcomboss", 4 },
	{ "t4_corcomboss.user", "corcomboss", 4 },

	{ "lootboxnanot1.user", "scavnanotc_t1", 1.5 },
	{ "lootboxnanot2.user", "scavnanotc_t2", 1.875 },
	{ "lootboxnanot3.user", "scavnanotc_t3", 2.35 },
	{ "lootboxnanot4.user", "scavnanotc_t4", 2.95 },


	{ "blank.user", "blank", 1 },
	{ "unknown.user", "unknown", 2 },
}

-- add inverted icons for scavenger units
if UnitDefNames['armcom_scav'] then
	local scavengerAlternatives = {}
	for i, icon in ipairs(icons) do
		scavengerAlternatives[#scavengerAlternatives + 1] = { 'scav_' .. icon[1], 'inverted/' .. icon[2], icon[3] }
	end
	for i, v in pairs(scavengerAlternatives) do
		icons[#icons + 1] = v
	end
	scavengerAlternatives = nil
end

function getIconID(name)
	-- does not check if file exists
	if string.sub(name, #name - 4) ~= '.user' then
		name = name .. '.user'
	end
	for i, icon in ipairs(icons) do
		local iconName = icon[1]
		if string.sub(iconName, #iconName - 4) ~= '.user' then
			iconName = iconName .. '.user'
		end
		if iconName == name then
			if icon[4] then
				return i
			else
				return false
			end
		end
	end
	return false
end

local iconTypes = {}
function addUnitIcon(icon, file, size)
	spAddUnitIcon(icon, file, size)
	iconTypes[icon] = file
end

function loadUnitIcons()

	-- free up icons
	for icon, file in ipairs(iconTypes) do
		spFreeUnitIcon(icon)
	end
	iconTypes = {}

	-- load icons
	for i, icon in ipairs(icons) do
		icons[i][4] = nil   -- reset
		if VFS.FileExists('icons/' .. icon[2] .. icon[3] .. '.png') then
			-- check if specific custom sized icon is availible
			addUnitIcon(icon[1], 'icons/' .. icon[2] .. icon[3] .. '.png', icon[3] * iconScale)
		else
			addUnitIcon(icon[1], 'icons/' .. icon[2] .. '.png', icon[3] * iconScale)
		end
	end

	-- load custom unit icons when availible
	local files = VFS.DirList('icons', "*.png")
	local files2 = VFS.DirList('icons/inverted', "*.png")
	for k, file in ipairs(files2) do
		files[#files + 1] = file
	end
	for k, file in ipairs(files) do
		local scavPrefix = ''
		local scavSuffix = ''
		local inverted = ''
		if string.find(file, 'inverted') then
			scavPrefix = 'scav_'
			scavSuffix = '_scav'
			inverted = 'inverted/'
		end
		local name = string.gsub(file, 'icons\\', '')   -- when located in spring folder
		name = string.gsub(name, 'icons/', '')   -- when located in game archive
		name = string.gsub(name, 'inverted/', '')   -- when located in game archive
		local iconname = string.gsub(name, '.png', '')
		if iconname then
			local iconname = string.match(iconname, '([a-z0-9-_]*)')
			local scale = string.match(name, '_[0-9.]*%.png')
			if scale ~= nil then
				iconname = string.gsub(name, scale, '')
				scale = string.gsub(scale, '_', '')
				scale = string.gsub(scale, '.png', '')
			end
			for i, icon in ipairs(icons) do
				if string.gsub(icon[1], '.user', '') == iconname then
					local inv = ''
					if string.find(icon[2], 'inverted') then
						inv = 'inverted/'
					end
					local scalenum = icon[3]
					if not scale or scale == '' then
						scale = ''
					else
						scalenum = scale
						scale = '_' .. scale
					end
					addUnitIcon(icon[1], 'icons/' .. inv .. iconname .. scale .. '.png', tonumber(scalenum) * iconScale)
				end
			end
			if unitname and UnitDefNames[unitname] then
				local scale = string.gsub(name, unitname, '')
				scale = string.gsub(scale, '_', '')
				if scale ~= '' then
					addUnitIcon(scavPrefix .. unitname .. ".user", file, tonumber(scale) * iconScale)
				end
			end
		end
	end

	-- tag all icons that have a valid file
	for i, icon in ipairs(icons) do
		if VFS.FileExists('icons/' .. icon[2] .. '.png') then
			icons[i][4] = true
		end
	end

	-- assign (standard) icons
	local weaponDef, iconPrefix
	for udid, ud in pairs(UnitDefs) do
		local name = ud.name
		iconPrefix = ''
		if string.find(name, '_scav') then
			iconPrefix = 'scav_'
			name = string.gsub(name, '_scav', '')
		end

		if ud == nil then
			break
		end
		if ud.weapons[1] then
			weaponDef = WeaponDefs[ud.weapons[1].weaponDef]
		else
			weaponDef = nil
		end

		if name == "meteor" then
			spSetUnitDefIcon(udid, iconPrefix .. "blank.user")
		elseif name == "armcom" or name == "armdecom" then
			spSetUnitDefIcon(udid, iconPrefix .. "armcom.user")
		elseif name == "corcom" or name == "cordecom" then
			spSetUnitDefIcon(udid, iconPrefix .. "corcom.user")
			-- T4 scav units
		elseif name == "armcomboss" then
			spSetUnitDefIcon(udid, iconPrefix .. "t4_armcomboss.user")
		elseif name == "corcomboss" then
			spSetUnitDefIcon(udid, iconPrefix .. "t4_corcomboss.user")
		elseif name == "cordemont4" then
			spSetUnitDefIcon(udid, iconPrefix .. "t4_demon.user")
		elseif name == "armvadert4" then
			spSetUnitDefIcon(udid, iconPrefix .. "t4_invader.user")
		elseif name == "armrattet4" then
			spSetUnitDefIcon(udid, iconPrefix .. "t4_ratte.user")
		elseif name == "armsptkt4" then
			spSetUnitDefIcon(udid, iconPrefix .. "t4_recluse.user")
		elseif name == "armpwt4" then
			spSetUnitDefIcon(udid, iconPrefix .. "t4_peewee.user")
		elseif name == "armfepocht4" then
			spSetUnitDefIcon(udid, iconPrefix .. "t4_fepoch.user")
		elseif name == "corfblackhyt4" then
			spSetUnitDefIcon(udid, iconPrefix .. "t4_fblackhy.user")
		elseif name == "corcrwt4" then
			spSetUnitDefIcon(udid, iconPrefix .. "t4_krow.user")
		elseif name == "corkarganetht4" then
			spSetUnitDefIcon(udid, iconPrefix .. "t4_karg.user")
		elseif name == "armthundt4" then
			spSetUnitDefIcon(udid, iconPrefix .. "t4_thund.user")

			-- Scavenger Printers
		elseif string.find(name, 'lootboxnano') then
			if string.find(name, 't1') then
				spSetUnitDefIcon(udid, iconPrefix .. "lootboxnanot1.user")
			elseif string.find(name, 't2') then
				spSetUnitDefIcon(udid, iconPrefix .. "lootboxnanot2.user")
			elseif string.find(name, 't3') then
				spSetUnitDefIcon(udid, iconPrefix .. "lootboxnanot3.user")
			elseif string.find(name, 't4') then
				spSetUnitDefIcon(udid, iconPrefix .. "lootboxnanot4.user")
			end

			-- Lootboxes / resource generators
		elseif string.find(name, 'lootbox') then
			if string.find(name, 'bronze') then
				spSetUnitDefIcon(udid, iconPrefix .. "lootboxbronze.user")
			elseif string.find(name, 'silver') then
				spSetUnitDefIcon(udid, iconPrefix .. "lootboxsilver.user")
			elseif string.find(name, 'gold') then
				spSetUnitDefIcon(udid, iconPrefix .. "lootboxgold.user")
			elseif string.find(name, 'platinum') then
				spSetUnitDefIcon(udid, iconPrefix .. "lootboxplatinum.user")
			end
		elseif string.find(name, 'boss') then
			spSetUnitDefIcon(udid, iconPrefix .. "boss.user")
		elseif string.find(name, 'beacon') then
			spSetUnitDefIcon(udid, iconPrefix .. "beacon.user")
		elseif string.find(name, 'droppod') then
			spSetUnitDefIcon(udid, iconPrefix .. "mine3.user")
		elseif string.sub(name, 0, 7) == "critter" then
			spSetUnitDefIcon(udid, iconPrefix .. "blank.user")

			-- Scav Custom Units
		elseif string.find(name, 'scavmist') then
			spSetUnitDefIcon(udid, iconPrefix .. "blank.user")

			-- objects
		elseif name == "chip" or name == "dice" or name == "xmasball" or name == "xmasball2" or name == "corstone" or name == "armstone" then
			spSetUnitDefIcon(udid, iconPrefix .. "blank.user")

		elseif name == "mission_command_tower" then
			spSetUnitDefIcon(udid, iconPrefix .. "commandtower.user")

		elseif name == "corkorg" then
			spSetUnitDefIcon(udid, iconPrefix .. "korgoth.user")
		elseif name == "armbanth" then
			spSetUnitDefIcon(udid, iconPrefix .. "bantha.user")
		elseif name == "corjugg" and getIconID(iconPrefix .. 'juggernaut') then
			spSetUnitDefIcon(udid, iconPrefix .. "juggernaut.user")
		elseif name == "corjugg" then
			spSetUnitDefIcon(udid, iconPrefix .. "juggernaut2.user")
		elseif name == "cormando" and getIconID(iconPrefix .. 'commando') then
			spSetUnitDefIcon(udid, iconPrefix .. "commando.user")
		elseif name == "cormando" then
			spSetUnitDefIcon(udid, iconPrefix .. "commando2.user")

			-- chickens
		elseif name == "chickenr3" then
			spSetUnitDefIcon(udid, iconPrefix .. "chicken4.user")
		elseif (ud.moveDef ~= nil and ud.moveDef.name == "chickqueen") then
			spSetUnitDefIcon(udid, iconPrefix .. "chicken_queen.user")
		elseif name == "roost" or name == "chickend1" then
			spSetUnitDefIcon(udid, iconPrefix .. "chicken_roost.user")
		elseif ud.modCategories["chicken"] and ud.canFly and ud.xsize >= 3 then
			spSetUnitDefIcon(udid, iconPrefix .. "chicken_air2.user")
		elseif ud.modCategories["chicken"] and ud.canFly then
			spSetUnitDefIcon(udid, iconPrefix .. "chicken_air.user")
		elseif ud.modCategories["chicken"] and ud.xsize >= 5 then
			spSetUnitDefIcon(udid, iconPrefix .. "chicken3.user")
		elseif ud.modCategories["chicken"] and ud.xsize >= 3 then
			spSetUnitDefIcon(udid, iconPrefix .. "chicken2.user")
		elseif ud.modCategories["chicken"] then
			spSetUnitDefIcon(udid, iconPrefix .. "chicken1.user")

			-- mines
		elseif name == "cormine3" or name == "armmine3" or name == "corfmine3" or name == "armfmine3" or name == "corsktl" then
			spSetUnitDefIcon(udid, iconPrefix .. "mine3.user")
		elseif name == "cormine2" or name == "armmine2" or name == "cormine4" or name == "armmine4" or name == "corroach" or name == "armvader" then
			spSetUnitDefIcon(udid, iconPrefix .. "mine2.user")
		elseif ud.modCategories["mine"] ~= nil then
			spSetUnitDefIcon(udid, iconPrefix .. "mine1.user")

			-- targeting
		elseif ud.targfac then
			spSetUnitDefIcon(udid, iconPrefix .. "targetting.user")

			-- cloak
		elseif name == "armeyes" or name == "coreyes" then
			spSetUnitDefIcon(udid, iconPrefix .. "eye.user")
		elseif name == "armspy" or name == "corspy" or name == "armgremlin" then
			spSetUnitDefIcon(udid, iconPrefix .. "spy.user")
		elseif name == "armpeep" or name == "corfink" then
			spSetUnitDefIcon(udid, iconPrefix .. "air_t1_scout.user")

			-- energy
		elseif name == "armwin" or name == "corwin" then
			spSetUnitDefIcon(udid, iconPrefix .. "wind.user")
		elseif name == "corafus" or name == "armafus" then
			spSetUnitDefIcon(udid, iconPrefix .. "energy5.user")
		elseif name == "armageo" or name == "corageo" then
			spSetUnitDefIcon(udid, iconPrefix .. "energy4.user")
		elseif name == "armgmm" or name == "armfus" or name == "corfus" or name == "armckfus" or name == "armdf" or name == "armuwfus" or name == "coruwfus" or name == "freefusion" then
			spSetUnitDefIcon(udid, iconPrefix .. "energy3.user")
		elseif name == "armgeo" or name == "corgeo" or name == "corbhmth" then
			spSetUnitDefIcon(udid, iconPrefix .. "energy6.user")
		elseif name == "armadvsol" or name == "coradvsol" then
			spSetUnitDefIcon(udid, iconPrefix .. "energy2.user")
		elseif name == "armsolar" or name == "corsolar" or name == "armtide" or name == "cortide" then
			spSetUnitDefIcon(udid, iconPrefix .. "energy1.user")

			-- storages
		elseif name == "armestor" or name == "corestor" or name == "armuwes" or name == "coruwes" then
			spSetUnitDefIcon(udid, iconPrefix .. "energystorage.user")
		elseif name == "armuwadves" or name == "coruwadves" then
			spSetUnitDefIcon(udid, iconPrefix .. "energystorage_t2.user")
		elseif name == "armmstor" or name == "cormstor" or name == "armuwms" or name == "coruwms" then
			spSetUnitDefIcon(udid, iconPrefix .. "metalstorage.user")
		elseif name == "armuwadvms" or name == "coruwadvms" then
			spSetUnitDefIcon(udid, iconPrefix .. "metalstorage_t2.user")

			-- lrpc
		elseif (name == "armvulc") or (name == "corbuzz") then
			spSetUnitDefIcon(udid, iconPrefix .. "lrpc_lolcannon.user")
		elseif (name == "armbrtha") or (name == "corint") then
			spSetUnitDefIcon(udid, iconPrefix .. "lrpc.user")

			--elseif (name=="armclaw") or (name=="cormaw") then
			--  spSetUnitDefIcon(udid, "defence_0.user")

			-- factories
		elseif (ud.isFactory) then

			if (name == "armap" or name == "corap" or name == "armplat" or name == "corplat") and getIconID(iconPrefix .. 'factory_t1_air') then
				spSetUnitDefIcon(udid, iconPrefix .. "factory_t1_air.user")
			elseif (name == "armaap" or name == "coraap") and getIconID(iconPrefix .. 'factory_t1_air') then
				spSetUnitDefIcon(udid, iconPrefix .. "factory_t2_air.user")
			elseif (name == "armlab" or name == "corlab") and getIconID(iconPrefix .. 'factory_t1_bot') then
				spSetUnitDefIcon(udid, iconPrefix .. "factory_t1_bot.user")
			elseif (name == "armalab" or name == "coralab") and getIconID(iconPrefix .. 'factory_t2_bot') then
				spSetUnitDefIcon(udid, iconPrefix .. "factory_t2_bot.user")
			elseif (name == "armvp" or name == "corvp") and getIconID(iconPrefix .. 'factory_t1_vehicle') then
				spSetUnitDefIcon(udid, iconPrefix .. "factory_t1_vehicle.user")
			elseif (name == "armavp" or name == "coravp") and getIconID(iconPrefix .. 'factory_t2_vehicle') then
				spSetUnitDefIcon(udid, iconPrefix .. "factory_t2_vehicle.user")
			elseif (name == "armsy" or name == "corsy") and getIconID(iconPrefix .. 'factory_t1_ship') then
				spSetUnitDefIcon(udid, iconPrefix .. "factory_t1_ship.user")
			elseif (name == "armasy" or name == "corasy") and getIconID(iconPrefix .. 'factory_t2_ship') then
				spSetUnitDefIcon(udid, iconPrefix .. "factory_t2_ship.user")
			elseif (name == "armhp" or name == "corhp" or name == "armfhp" or name == "corfhp") and getIconID(iconPrefix .. 'factory_hover') then
				spSetUnitDefIcon(udid, iconPrefix .. "factory_hover.user")
			elseif (name == "armamsub" or name == "coramsub") and getIconID(iconPrefix .. 'factory_amph') then
				spSetUnitDefIcon(udid, iconPrefix .. "factory_amph.user")
			elseif (name == "armshltx" or name == "armshltxuw" or name == "corgant" or name == "corgantuw") and getIconID(iconPrefix .. 'factory_gantry') then
				spSetUnitDefIcon(udid, iconPrefix .. "factory_gantry.user")

			elseif (name == "armshltx" or name == "armshltxuw" or name == "corgant" or name == "corgantuw") then
				spSetUnitDefIcon(udid, iconPrefix .. "factory_t3.user")
			elseif (name == "armaap" or name == "armavp" or name == "armalab" or name == "armasy" or name == "coraap" or name == "coravp" or name == "coralab" or name == "corasy") then
				spSetUnitDefIcon(udid, iconPrefix .. "factory_t2.user")
			else
				spSetUnitDefIcon(udid, iconPrefix .. "factory_t1.user")
			end

			-- (anti) nuke
		elseif (name == "armemp") and getIconID(iconPrefix .. 'emp') then
			spSetUnitDefIcon(udid, iconPrefix .. "emp.user")
		elseif (name == "cortron") and getIconID(iconPrefix .. 'tacnuke') then
			spSetUnitDefIcon(udid, iconPrefix .. "tacnuke.user")
		elseif (name == "corfmd" or name == "armamd") then
			spSetUnitDefIcon(udid, iconPrefix .. "antinuke.user")
		elseif (name == "cormabm" or name == "armscab") then
			spSetUnitDefIcon(udid, iconPrefix .. "antinuke_mobile.user")
		elseif (name == "armcarry" or name == "corcarry") then
			spSetUnitDefIcon(udid, iconPrefix .. "ship_t2_carrier.user")
		elseif (ud.stockpileWeaponDef ~= nil) and not (name == "armmercury" or name == "corscreamer" or name == "corfmd" or name == "armamd" or name == "cormabm" or name == "armscab") then
			-- nuke( stockpile weapon, but not mercury/screamer or anti nukes)
			if name == "armsilo" or name == "corsilo" then
				spSetUnitDefIcon(udid, iconPrefix .. "nuke_big.user")
			elseif name == "armjuno" or name == "corjuno" then
				spSetUnitDefIcon(udid, "jammer_t2.user")
			else
				spSetUnitDefIcon(udid, iconPrefix .. "nuke.user")
			end

			-- shield
		elseif (ud.shieldWeaponDef) then
			spSetUnitDefIcon(udid, "shield.user")


			-- metal extractors
		elseif ud.extractsMetal > 0 or ud.makesMetal > 0 then
			if ud.extractsMetal > 0.001 then
				spSetUnitDefIcon(udid, iconPrefix .. "mex_t2.user")
			elseif ud.extractsMetal > 0 and ud.extractsMetal <= 0.001 then
				spSetUnitDefIcon(udid, iconPrefix .. "mex_t1.user")
			end

			-- metal makers
		elseif ud.customParams.energyconv_capacity and ud.customParams.energyconv_efficiency then
			if tonumber(ud.customParams.energyconv_capacity) > 200 then
				spSetUnitDefIcon(udid, iconPrefix .. "metalmaker_t2.user")
			else
				spSetUnitDefIcon(udid, iconPrefix .. "metalmaker_t1.user")
			end

		elseif ud.isTransport then
			-- transports
			if name == "armdfly" or name == "corseah" then
				spSetUnitDefIcon(udid, iconPrefix .. "air_t2_transport.user")
			elseif name == "armthovr" or name == "corthovr" then
				spSetUnitDefIcon(udid, iconPrefix .. "hover_transport.user")
			elseif name == "corintr" then
				spSetUnitDefIcon(udid, iconPrefix .. "vehicle_trans.user")
			elseif name == "armtship" or name == "cortship" then
				spSetUnitDefIcon(udid, iconPrefix .. "ship_transport.user")
			else
				spSetUnitDefIcon(udid, iconPrefix .. "air_t1_transport.user")
			end

			-- nanos
		elseif ud.deathExplosion == "nanoboom" then
			spSetUnitDefIcon(udid, iconPrefix .. "worker.user")

			-- amphib & t2 subs
		elseif ud.modCategories["phib"] ~= nil or (ud.modCategories["canbeuw"] ~= nil and ud.modCategories["underwater"] == nil) then
			if name == "armserp" or name == "armsubk" or name == "corshark" or name == "corssub" then
				spSetUnitDefIcon(udid, iconPrefix .. "sub_t2.user")
			elseif name == "armpincer" or name == "corgarp" then
				spSetUnitDefIcon(udid, iconPrefix .. "amphib_tank.user")
			elseif ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '3' then
				spSetUnitDefIcon(udid, iconPrefix .. "amphib_t3.user")
			elseif ud.weapons[1] ~= nil and ud.weapons[1].onlyTargets["vtol"] then
				if ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2' then
					spSetUnitDefIcon(udid, iconPrefix .. "amphib_t2_aa.user")
				else
					spSetUnitDefIcon(udid, iconPrefix .. "amphib_t1_aa.user")
				end
			elseif ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2' then
				if ud.isBuilder then
					spSetUnitDefIcon(udid, iconPrefix .. "amphib_t2_worker.user")
				else
					spSetUnitDefIcon(udid, iconPrefix .. "amphib_t2.user")
				end
			else
				if ud.isBuilder then
					spSetUnitDefIcon(udid, iconPrefix .. "amphib_t1_worker.user")
				else
					spSetUnitDefIcon(udid, iconPrefix .. "amphib_t1.user")
				end
			end

			-- submarines
		elseif ud.modCategories["underwater"] ~= nil and ud.speed > 0 then
			if name == "armacsub" or name == "coracsub" or name == "armrecl" or name == "correcl" then
				spSetUnitDefIcon(udid, iconPrefix .. "sub_t2_worker.user")
			else
				spSetUnitDefIcon(udid, iconPrefix .. "sub_t1.user")
			end

			-- hovers
		elseif ud.modCategories["hover"] ~= nil then
			if ud.isBuilder then
				spSetUnitDefIcon(udid, iconPrefix .. "hover_t1_worker.user")
			elseif ud.weapons[1] ~= nil and ud.weapons[1].onlyTargets["vtol"] then
				spSetUnitDefIcon(udid, iconPrefix .. "hover_t1_aa.user")
			elseif name == "corhal" then
				spSetUnitDefIcon(udid, iconPrefix .. "hover_t2.user")
			elseif name == "armlun" or name == "corsok" then
				spSetUnitDefIcon(udid, iconPrefix .. "hover_t3.user")
			elseif name == "armmh" or name == "cormh" then
				spSetUnitDefIcon(udid, iconPrefix .. "hover_t1_missile.user")
			elseif name == "armsh" or name == "corsh" then
				spSetUnitDefIcon(udid, iconPrefix .. "hover_raid.user")
			elseif name == "armanac" or name == "corsnap" then
				spSetUnitDefIcon(udid, iconPrefix .. "hover_gun.user")
			else
				spSetUnitDefIcon(udid, iconPrefix .. "hover_t1.user")
			end

			-- aircraft
		elseif ud.canFly then

			if name == "armliche" and getIconID(iconPrefix .. 'air_liche') then
				spSetUnitDefIcon(udid, iconPrefix .. "air_liche.user")
			elseif name == "armliche" then
				spSetUnitDefIcon(udid, iconPrefix .. "air_liche2.user")
			elseif name == "corcrw" and getIconID(iconPrefix .. 'air_krow') then
				spSetUnitDefIcon(udid, iconPrefix .. "air_krow.user")
			elseif name == "corcrw" then
				spSetUnitDefIcon(udid, iconPrefix .. "air_krow2.user")
			elseif name == "armstil" then
				spSetUnitDefIcon(udid, iconPrefix .. "air_krow2.user")
			elseif name == "armlance" or name == "cortitan" then
				spSetUnitDefIcon(udid, iconPrefix .. "air_t2_torpbomber.user")
			elseif name == "armseap" or name == "corseap" then
				spSetUnitDefIcon(udid, iconPrefix .. "air_torp.user")
			elseif name == "armawac" or name == "corawac" or name == "armsehak" or name == "corhunt" then
				spSetUnitDefIcon(udid, iconPrefix .. "air_t2_radar.user")
			elseif ud.isBuilder then
				if (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2') then
					spSetUnitDefIcon(udid, iconPrefix .. "air_t2_worker.user")
				else
					spSetUnitDefIcon(udid, iconPrefix .. "air_t1_worker.user")
				end
			elseif ud.hoverAttack then
				if name == "corbw" then
					spSetUnitDefIcon(udid, iconPrefix .. "air_bladew.user")
				elseif name == "armblade" or name == "corape" then
					spSetUnitDefIcon(udid, iconPrefix .. "air_t2_hover_missile.user")
				elseif ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2' then
					spSetUnitDefIcon(udid, iconPrefix .. "air_t2_hover.user")
				else
					spSetUnitDefIcon(udid, iconPrefix .. "air_t1_hover.user")
				end
			elseif #ud.weapons > 0 and WeaponDefs[ud.weapons[1].weaponDef].type == "AircraftBomb" then
				if name == "armpnix" or name == "corhurc" then
					spSetUnitDefIcon(udid, iconPrefix .. "air_t2_bomber.user")
				else
					spSetUnitDefIcon(udid, iconPrefix .. "air_t1_bomber.user")
				end
			else
				if (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2') then
					spSetUnitDefIcon(udid, iconPrefix .. "air_t2.user")
				else
					spSetUnitDefIcon(udid, iconPrefix .. "air_t1.user")
				end
			end

			-- ships
		elseif ud.modCategories["ship"] ~= nil then
			if name == "armroy" or name == "corroy" then
				spSetUnitDefIcon(udid, iconPrefix .. "ship_destroyer.user")
			elseif name == "armdecade" or name == "coresupp" then
				spSetUnitDefIcon(udid, iconPrefix .. "ship_raid.user")
			elseif name == "armmship" or name == "cormship" then
				spSetUnitDefIcon(udid, iconPrefix .. "ship_t2_missile.user")
			elseif name == "armcrus" or name == "corcrus" then
				spSetUnitDefIcon(udid, iconPrefix .. "ship_t2_cruiser.user")
			elseif name == "armbats" or name == "corbats" then
				spSetUnitDefIcon(udid, iconPrefix .. "ship_t2_battleship.user")
			elseif name == "armepoch" or name == "corblackhy" then
				spSetUnitDefIcon(udid, iconPrefix .. "ship_t2_flagship.user")
			elseif name == "armsjam" or name == "corsjam" then
				spSetUnitDefIcon(udid, iconPrefix .. "ship_t2_jammer.user")
			elseif name == "armpt" or name == "corpt" then
				spSetUnitDefIcon(udid, iconPrefix .. "ship_tiny.user")
			elseif name == "armpship" or name == "corpship" then
				spSetUnitDefIcon(udid, iconPrefix .. "ship_pship.user")
			elseif ud.isBuilder then
				if name == "armmls" or name == "cormls" then
					spSetUnitDefIcon(udid, iconPrefix .. "ship_engineer.user")
				elseif ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2' then
					spSetUnitDefIcon(udid, iconPrefix .. "ship_t2_worker.user")
				else
					spSetUnitDefIcon(udid, iconPrefix .. "ship_t1_worker.user")
				end
			elseif ud.weapons[1] ~= nil and ud.weapons[1].onlyTargets["vtol"] then
				if ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2' then
					spSetUnitDefIcon(udid, iconPrefix .. "ship_t2_aa.user")
				else
					spSetUnitDefIcon(udid, iconPrefix .. "ship_aa.user")
				end
			else
				if ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2' then
					spSetUnitDefIcon(udid, iconPrefix .. "ship_t2.user")
				else
					spSetUnitDefIcon(udid, iconPrefix .. "ship.user")
				end
			end

			-- sensors
		elseif ud.seismicRadius > 1 then
			spSetUnitDefIcon(udid, iconPrefix .. "seismic.user")
		elseif (ud.radarRadius > 1 or ud.sonarRadius > 1) and ud.speed <= 0 and #ud.weapons <= 0 then
			if name == "armarad" or name == "armason" or name == "corarad" or name == "corason" then
				spSetUnitDefIcon(udid, iconPrefix .. "radar_t2.user")
			else
				spSetUnitDefIcon(udid, iconPrefix .. "radar_t1.user")
			end

			-- jammer buildings
		elseif (ud.jammerRadius > 1 or ud.sonarJamRadius > 1) and ud.speed <= 0 then
			if name == "corshroud" or name == "armveil" then
				spSetUnitDefIcon(udid, iconPrefix .. "jammer_t2.user")
			else
				spSetUnitDefIcon(udid, iconPrefix .. "jammer_t1.user")
			end

			-- defenders and other buildings
		elseif ud.isBuilding or ud.speed <= 0 then
			if #ud.weapons <= 0 then
				if ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2' then
					spSetUnitDefIcon(udid, iconPrefix .. "building_t2.user")
				else
					spSetUnitDefIcon(udid, iconPrefix .. "building_t1.user")
				end
			else
				if ud.weapons[1] ~= nil and ud.weapons[1].onlyTargets["vtol"] then
					if name == "armmercury" or name == "corscreamer" then
						spSetUnitDefIcon(udid, iconPrefix .. "aa_longrange.user")
					elseif WeaponDefs[ud.weapons[1].weaponDef].cegTag == 'flaktrailaa' then
						spSetUnitDefIcon(udid, iconPrefix .. "aa_flak.user")
					elseif name == "corerad" or name == "armcir" or name == "armferret" or name == "cormadsam" then
						spSetUnitDefIcon(udid, iconPrefix .. "aa2.user")
					else
						spSetUnitDefIcon(udid, iconPrefix .. "aa1.user")
					end
				else
					if name == "armanni" or name == "cordoom" then
						spSetUnitDefIcon(udid, iconPrefix .. "defence_3.user")
					elseif (name == "armguard" or name == "corpun") and getIconID(iconPrefix .. 'defence_1_arty') then
						spSetUnitDefIcon(udid, iconPrefix .. "defence_1_arty.user")
					elseif (name == "armamb" or name == "cortoast") and getIconID(iconPrefix .. 'defence_2_arty') then
						spSetUnitDefIcon(udid, iconPrefix .. "defence_2_arty.user")
					elseif name == "armtl" or name == "cortl" or name == "armptl" or name == "corptl" or name == "armdl" or name == "cordl" then
						spSetUnitDefIcon(udid, iconPrefix .. "defence_1_naval.user")
					elseif name == "armatl" or name == "coratl" then
						spSetUnitDefIcon(udid, iconPrefix .. "defence_2_naval.user")
					elseif name == "armhlt" or name == "corhlt" or name == "armfhlt" or name == "corfhlt" then
						spSetUnitDefIcon(udid, iconPrefix .. "defence_1_laser.user")
					elseif name == "armbeamer" or name == "corhllt" then
						spSetUnitDefIcon(udid, iconPrefix .. "defence_0_laser2.user")
					elseif (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2') or name == "armguard" or name == "corpun" then
						if weaponDef and weaponDef.type == 'BeamLaser' then
							spSetUnitDefIcon(udid, iconPrefix .. "defence_2_laser.user")
						elseif weaponDef and weaponDef.type == 'MissileLauncher' then
							spSetUnitDefIcon(udid, iconPrefix .. "defence_2_missile.user")
						else
							spSetUnitDefIcon(udid, iconPrefix .. "defence_2.user")
						end
					else
						if weaponDef and weaponDef.type == 'BeamLaser' then
							spSetUnitDefIcon(udid, iconPrefix .. "defence_0_laser.user")
						else
							spSetUnitDefIcon(udid, iconPrefix .. "defence_0.user")
						end
					end
				end
			end

			-- vehicles
		elseif ud.modCategories["tank"] ~= nil then

			if name == "armmanni" or name == "corgol" or name == "cortrem" then
				spSetUnitDefIcon(udid, iconPrefix .. "vehicle_t2_big.user")
			elseif name == "corvrad" or name == "armseer" then
				spSetUnitDefIcon(udid, iconPrefix .. "vehicle_t2_radar.user")
			elseif name == "coreter" or name == "armjam" then
				spSetUnitDefIcon(udid, iconPrefix .. "vehicle_t2_jammer.user")
			elseif name == "corfav" or name == "armfav" then
				spSetUnitDefIcon(udid, iconPrefix .. "vehicle_t1_flea.user")
			elseif name == "armsam" or name == "cormist" then
				spSetUnitDefIcon(udid, iconPrefix .. "vehicle_t1_missile.user")
			elseif name == "armflash" or name == "corgator" then
				spSetUnitDefIcon(udid, iconPrefix .. "vehicle_t1_raid.user")
			elseif name == "armjanus" or name == "corlevlr" then
				spSetUnitDefIcon(udid, iconPrefix .. "vehicle_t1_big.user")
			elseif name == "armbull" or name == "correap" then
				spSetUnitDefIcon(udid, iconPrefix .. "vehicle_t2_tank.user")
			elseif name == "armstump" or name == "corraid" then
				spSetUnitDefIcon(udid, iconPrefix .. "vehicle_t1_tank.user")
			elseif ud.isBuilder then
				if name == "armconsul" then
					spSetUnitDefIcon(udid, iconPrefix .. "engineer.user")
				elseif ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2' then
					spSetUnitDefIcon(udid, iconPrefix .. "vehicle_t2_worker.user")
				else
					spSetUnitDefIcon(udid, iconPrefix .. "vehicle_t1_worker.user")
				end
			elseif ud.weapons[1] ~= nil and ud.weapons[1].onlyTargets["vtol"] then
				if ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2' then
					spSetUnitDefIcon(udid, iconPrefix .. "vehicle_t2_aa.user")
				else
					spSetUnitDefIcon(udid, iconPrefix .. "vehicle_aa.user")
				end
			else
				if (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2') then
					spSetUnitDefIcon(udid, iconPrefix .. "vehicle_t2.user")
				else
					spSetUnitDefIcon(udid, iconPrefix .. "vehicle_t1.user")
				end
			end

			-- all terrain
		elseif ud.moveDef.name == "tbot2" or ud.moveDef.name == "tbot3" or ud.moveDef.name == "htbot4" then

			if name == "armvang" then
				spSetUnitDefIcon(udid, iconPrefix .. "allterrain_vanguard.user")
			elseif name == "armspid" then
				spSetUnitDefIcon(udid, iconPrefix .. "allterrain_emp.user")
			elseif (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '3') then
				spSetUnitDefIcon(udid, iconPrefix .. "allterrain_t3.user")
			elseif (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2') then
				spSetUnitDefIcon(udid, iconPrefix .. "allterrain_t2.user")
			else
				spSetUnitDefIcon(udid, iconPrefix .. "allterrain_t1.user")
			end

			-- bots
		elseif ud.modCategories["bot"] ~= nil then

			if name == "corsumo" then
				spSetUnitDefIcon(udid, iconPrefix .. "bot_t2_big.user")
			elseif name == "armflea" then
				spSetUnitDefIcon(udid, iconPrefix .. "bot_t1_flea.user")
			elseif name == "corak" or name == "armpw" then
				spSetUnitDefIcon(udid, iconPrefix .. "bot_t1_raid.user")
			elseif name == "armfast" then
				spSetUnitDefIcon(udid, iconPrefix .. "bot_t2_raid.user")
			elseif name == "corvoyr" or name == "armmark" then
				spSetUnitDefIcon(udid, iconPrefix .. "bot_t2_radar.user")
			elseif name == "corspec" or name == "armaser" then
				spSetUnitDefIcon(udid, iconPrefix .. "bot_t2_jammer.user")
			elseif name == "armham" or name == "armwar" or name == "corthud" then
				spSetUnitDefIcon(udid, iconPrefix .. "bot_t1_big.user")
			elseif ud.isBuilder then
				if name == "cornecro" or name == "armrectr" then
					spSetUnitDefIcon(udid, iconPrefix .. "bot_t1_tinyworker.user")
				elseif name == "armfark" or name == "corfast" then
					spSetUnitDefIcon(udid, iconPrefix .. "engineer_small.user")
				elseif ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2' then
					spSetUnitDefIcon(udid, iconPrefix .. "bot_t2_worker.user")
				else
					spSetUnitDefIcon(udid, iconPrefix .. "bot_t1_worker.user")
				end
			elseif ud.weapons[1] ~= nil and ud.weapons[1].onlyTargets["vtol"] then
				if ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2' then
					spSetUnitDefIcon(udid, iconPrefix .. "bot_t2_aa.user")
				else
					spSetUnitDefIcon(udid, iconPrefix .. "bot_aa.user")
				end
			else
				if ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '3' then
					spSetUnitDefIcon(udid, iconPrefix .. "bot_t3.user")
				elseif ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2' then
					spSetUnitDefIcon(udid, iconPrefix .. "bot_t2.user")
				else
					spSetUnitDefIcon(udid, iconPrefix .. "bot_t1.user")
				end
			end

		else

			-- unknown
			spSetUnitDefIcon(udid, iconPrefix .. "unknown.user")
		end

	end

	-- Walls
	spSetUnitDefIcon(UnitDefNames["cordrag"].id, "wall.user")
	spSetUnitDefIcon(UnitDefNames["armdrag"].id, "wall.user")
	spSetUnitDefIcon(UnitDefNames["corfort"].id, "wall.user")
	spSetUnitDefIcon(UnitDefNames["armfort"].id, "wall.user")
	spSetUnitDefIcon(UnitDefNames["corfdrag"].id, "wall.user")
	spSetUnitDefIcon(UnitDefNames["armfdrag"].id, "wall.user")
	if UnitDefNames["cordrag_scav"] then
		spSetUnitDefIcon(UnitDefNames["cordrag_scav"].id, "wall.user")
		spSetUnitDefIcon(UnitDefNames["armdrag_scav"].id, "wall.user")
		spSetUnitDefIcon(UnitDefNames["corfort_scav"].id, "wall.user")
		spSetUnitDefIcon(UnitDefNames["armfort_scav"].id, "wall.user")
		spSetUnitDefIcon(UnitDefNames["corfdrag_scav"].id, "wall.user")
		spSetUnitDefIcon(UnitDefNames["armfdrag_scav"].id, "wall.user")
	end

	-- load and assign custom unit icons when availible
	local customUnitIcons = {}
	local files = VFS.DirList('icons', "*.png")
	local files2 = VFS.DirList('icons/inverted', "*.png")
	for k, file in ipairs(files2) do
		files[#files + 1] = file
	end

	-- add inverted icons for scavenger units
	for k, file in ipairs(files) do
		local scavPrefix = ''
		local scavSuffix = ''
		if string.find(file, 'inverted') then
			scavPrefix = 'scav_'
			scavSuffix = '_scav'
		end
		local name = string.gsub(file, 'icons\\', '')   -- when located in spring folder
		name = string.gsub(name, 'icons/', '')   -- when located in game archive
		name = string.gsub(name, 'inverted/', '')   -- when located in game archive
		name = string.gsub(name, '.png', '')
		if name then
			local unitname = string.match(name, '([a-z0-9]*)')
			if unitname and UnitDefNames[unitname] then
				local scale = string.gsub(name, unitname, '')
				scale = string.gsub(scale, '_', '')
				if scale ~= '' and UnitDefNames[unitname .. scavSuffix] then
					addUnitIcon(scavPrefix .. unitname .. ".user", file, tonumber(scale) * iconScale)
					if unitname == 'armcom' then
						Spring.Echo(unitname, UnitDefNames[unitname .. scavSuffix].id, scavSuffix, scavPrefix .. unitname .. ".user")
					end
					spSetUnitDefIcon(UnitDefNames[unitname .. scavSuffix].id, scavPrefix .. unitname .. ".user")
				end
			end
		end
	end
end

local myPlayerID = Spring.GetMyPlayerID()

function gadget:GotChatMsg(msg, playerID)
	if playerID == myPlayerID then
		if string.sub(msg, 1, 14) == "uniticonscale " then
			iconScale = tonumber(string.sub(msg, 15))
			Spring.SetConfigFloat("UnitIconScale", iconScale)
			loadUnitIcons()
			--Spring.SendCommands("minimap unitsize "..Spring.GetConfigFloat("MinimapIconScale", 3.5-(iconScale-1)))
		end
	end
end

function GetIconTypes()
	return iconTypes
end

function gadget:Initialize()
	gadgetHandler:RegisterGlobal('GetIconTypes', GetIconTypes)
	if Spring.GetGameFrame() == 0 then
		loadUnitIcons()
	end
end


