local unitlist={--- Human friendly list. Automatically converted to unitdef IDs on init
 -- BA

{'armmex','armuwmex', 'cormex','coruwmex'},-- test that it is allright when unit can't really be built
{'armmakr','armfmkr'},
{'cormakr','corfmkr'},
{'armeyes','armsonar'},
{'coreyes','corsonar'},
--{'armdrag','armfdrag'},  --both can be built in shallow water -> do not touch
--{'cordrag','corfdrag'},  --both can be built in shallow water -> do not touch
{'armmstor', 'armuwms'},
{'armestor', 'armuwes'},
{'cormstor', 'coruwms'},
{'corestor', 'coruwes'},
{'armrl','armfrt'},
{'corrl','corfrt'},
--{'armdl','armtl'},  --its ambiguous with armllt -> armtl
--{'cordl','cortl'},  --its ambiguous with armllt -> armtl
{'armhp','armfhp'},
{'corhp','corfhp'},
{'armrad','armfrad'},
{'corrad','corfrad'},
{'armhlt','armfhlt'},
{'corhlt','corfhlt'},
{'armtarg','armfatf'},
{'cortarg','corfatf'},
{'armmmmkr','armuwmmm'},
{'cormmmkr','coruwmmm'},
{'armfus','armuwfus'},
{'corfus','coruwfus'},
{'armflak','armfflak'},
{'corflak','corfflak'},
{'armmoho','armuwmme'},
{'cormoho','coruwmme'},
{'armsolar','armtide'},
{'corsolar','cortide'},
{'armlab','armsy'},
{'corlab','corsy'},
{'armllt','armtl'},
{'corllt','cortl'},
{'corsonar','corrad'},
{'armsonar','armrad'},


-- XTA - arm

{'arm_solar_collector', 'arm_underwater_tidal_generator', 'arm_tidal_generator'},
{'arm_metal_extractor', 'arm_underwater_metal_extractor'},
{'arm_light_laser_tower', 'arm_floating_light_laser_tower'},
{'arm_dragons_teeth', 'arm_floating_dragons_teeth'},
{'arm_energy_storage', 'arm_underwater_energy_storage'},
{'arm_metal_storage', 'arm_underwater_metal_storage'},
{'arm_metal_maker', 'arm_floating_metal_maker'},
{'arm_radar_tower', 'arm_floating_radar'},
{'arm_sentinel', 'arm_stingray'},
{'arm_defender', 'arm_sentry'},
{'arm_moho_mine', 'arm_underwater_moho_mine'},
{'arm_protector', 'arm_repulsor'},

-- XTA - core

{'core_solar_collector', 'core_underwater_tidal_generator', 'core_tidal_generator'},
{'core_metal_extractor', 'core_underwater_metal_extractor'},
{'core_light_laser_tower', 'core_floating_light_laser_tower'},
{'core_dragons_teeth', 'core_floating_dragons_teeth'},
{'core_energy_storage', 'core_underwater_energy_storage'},
{'core_metal_storage', 'core_underwater_metal_storage'},
{'core_metal_maker', 'core_floating_metal_maker'},
{'core_radar_tower', 'core_floating_radar'},
{'core_gaat_gun', 'core_thunderbolt'},
{'core_pulverizer', 'core_stinger'},
{'core_moho_mine', 'core_underwater_moho_mine'},
{'core_fortitude_missile_defense', 'core_resistor'},

}

function widget:GetInfo()
	return {
		name = "Context Build",
		desc = "Toggles buildings between buildings automagically" ,
		author = "dizekat and BD",
		date = "30 July 2009",
		license = "GNU LGPL, v2.1 or later",
		layer = 1,
		enabled = true
	}
end
local TestBuildOrder		= Spring.TestBuildOrder
local GetActiveCommand		= Spring.GetActiveCommand
local SetActiveCommand		= Spring.SetActiveCommand
local GetMouseState			= Spring.GetMouseState
local TraceScreenRay		= Spring.TraceScreenRay
local TestBuildOrder		= Spring.TestBuildOrder
local GetFPS				= Spring.GetFPS

local alternative_units = {}-- unit def id --> list of alternative unit def ids
local updateRate = 8/30
local timeCounter = 0

function widget:Initialize()
	local unitnameToUnitDefID = {}--- unit name or humanName --> unit def id
	for index,def in ipairs(UnitDefs) do
		unitnameToUnitDefID[def.name]=index
	end
	for _,unitNames in ipairs(unitlist) do
		local list={}
		for _,unitName in ipairs(unitNames) do
			local unitDefID=unitnameToUnitDefID[unitName]
			if unitDefID then
				table.insert(list,unitDefID)
			end
		end
		for _,unitDefID in ipairs(list) do
			local tempcopy = list
			table.remove(tempcopy,unitDefID) -- exclude itself from the alternatives
			alternative_units[unitDefID]=tempcopy
		end

	end
end


function widget:Update(deltaTime)
	timeCounter = timeCounter + deltaTime
	-- update only x times per second
	if timeCounter >= updateRate then
		timeCounter = 0
	else
		return
	end

	local _, cmd_id = GetActiveCommand()
	if (not cmd_id) or (cmd_id>=0) then
		return
	end
	local unitDefID = -cmd_id

	local alternatives = alternative_units[unitDefID]
	if (not alternatives) then
		return
	end

	local mx, my = GetMouseState()
	local _, coords = TraceScreenRay(mx, my, true, true)
	if (not coords) then
		return
	end

	if TestBuildOrder(unitDefID, coords[1], coords[2], coords[3], 1) == 0 then
		--Spring.Echo('cant build, looking for alternatives')
		for _,alt_id in ipairs(alternatives) do --- try all alternatives
			if TestBuildOrder(alt_id, coords[1], coords[2], coords[3], 1) ~= 0 then
				if SetActiveCommand('buildunit_'..UnitDefs[alt_id].name) then
					return
				end
			end
		end
	end

end
