local blueprintConfig = VFS.Include('luarules/gadgets/scavengers/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local tiers = blueprintConfig.Tiers
local types = blueprintConfig.BlueprintTypes
local UDN = UnitDefNames

-- Tech 1
local function t1SeaBase1()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortex_navalenergyconverter_scav.id, xOffset = -24,  zOffset =  24, direction = 1 },
			{ unitDefID = UDN.cortex_navalenergyconverter_scav.id, xOffset = -24,  zOffset = -24, direction = 1 },
			{ unitDefID = UDN.cortex_navalenergyconverter_scav.id, xOffset =  24,  zOffset =  24, direction = 1 },
			{ unitDefID = UDN.cortex_navalenergyconverter_scav.id, xOffset =  24,  zOffset = -24, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armada_navalenergyconverter_scav.id, xOffset = -24,  zOffset = -24, direction = 1 },
			{ unitDefID = UDN.armada_navalenergyconverter_scav.id, xOffset =  24,  zOffset = -24, direction = 1 },
			{ unitDefID = UDN.armada_navalenergyconverter_scav.id, xOffset = -24,  zOffset =  24, direction = 1 },
			{ unitDefID = UDN.armada_navalenergyconverter_scav.id, xOffset =  24,  zOffset =  24, direction = 1 },
		}
	end

	return {
		type = types.Sea,
		tiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3, tiers.T4 },
		radius = 100,
		buildings = buildings,
	}
end

local function t1SeaBase2()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortex_navalmetalstorage_scav.id, xOffset = -32,  zOffset =  32, direction = 1 },
			{ unitDefID = UDN.cortex_navalmetalstorage_scav.id, xOffset =  32,  zOffset = -32, direction = 1 },
			{ unitDefID = UDN.cortex_navalmetalstorage_scav.id, xOffset = -32,  zOffset = -32, direction = 1 },
			{ unitDefID = UDN.cortex_navalmetalstorage_scav.id, xOffset =  32,  zOffset =  32, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armada_navalmetalstorage_scav.id, xOffset = -32,  zOffset = -32, direction = 1 },
			{ unitDefID = UDN.armada_navalmetalstorage_scav.id, xOffset =  32,  zOffset =  32, direction = 1 },
			{ unitDefID = UDN.armada_navalmetalstorage_scav.id, xOffset = -32,  zOffset =  32, direction = 1 },
			{ unitDefID = UDN.armada_navalmetalstorage_scav.id, xOffset =  32,  zOffset = -32, direction = 1 },
		}
	end

    return {
		type = types.Sea,
		tiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3, tiers.T4 },
		radius = 100,
		buildings = buildings,
	}
end

local function t1SeaBase3()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortex_tidalgenerator_scav.id, xOffset =  24,  zOffset = -24, direction = 1 },
			{ unitDefID = UDN.cortex_tidalgenerator_scav.id, xOffset =  24,  zOffset =  24, direction = 1 },
			{ unitDefID = UDN.cortex_tidalgenerator_scav.id, xOffset = -24,  zOffset =  24, direction = 1 },
			{ unitDefID = UDN.cortex_tidalgenerator_scav.id, xOffset = -24,  zOffset = -24, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armada_tidalgenerator_scav.id, xOffset =  24,  zOffset = -24, direction = 1 },
			{ unitDefID = UDN.armada_tidalgenerator_scav.id, xOffset =  24,  zOffset =  24, direction = 1 },
			{ unitDefID = UDN.armada_tidalgenerator_scav.id, xOffset = -24,  zOffset = -24, direction = 1 },
			{ unitDefID = UDN.armada_tidalgenerator_scav.id, xOffset = -24,  zOffset =  24, direction = 1 },
		}
	end

    return {
		type = types.Sea,
		tiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3, tiers.T4 },
		radius = 100,
		buildings = buildings,
	}
end

local function t1SeaBase4()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortex_navalenergystorage_scav.id, xOffset = -32,  zOffset =  32, direction = 1 },
			{ unitDefID = UDN.cortex_navalenergystorage_scav.id, xOffset =  32,  zOffset = -32, direction = 1 },
			{ unitDefID = UDN.cortex_navalenergystorage_scav.id, xOffset = -32,  zOffset = -32, direction = 1 },
			{ unitDefID = UDN.cortex_navalenergystorage_scav.id, xOffset =  32,  zOffset =  32, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armada_navalenergystorage_scav.id, xOffset =  32,  zOffset = -32, direction = 1 },
			{ unitDefID = UDN.armada_navalenergystorage_scav.id, xOffset = -32,  zOffset =  32, direction = 1 },
			{ unitDefID = UDN.armada_navalenergystorage_scav.id, xOffset =  32,  zOffset =  32, direction = 1 },
			{ unitDefID = UDN.armada_navalenergystorage_scav.id, xOffset = -32,  zOffset = -32, direction = 1 },
		}
	end

	return {
		type = types.Sea,
		tiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3, tiers.T4 },
		radius = 100,
		buildings = buildings,
	}
end

local function t1SeaBase5()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset = -24,  zOffset =  24, direction = 1 },
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset =  24,  zOffset = -24, direction = 1 },
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset = -24,  zOffset = -24, direction = 1 },
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset =  24,  zOffset =  24, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset =  24,  zOffset =  24, direction = 1 },
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset = -24,  zOffset = -24, direction = 1 },
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset =  24,  zOffset = -24, direction = 1 },
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset = -24,  zOffset =  24, direction = 1 },
		}
	end

	return {
		type = types.Sea,
		tiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3, tiers.T4 },
		radius = 100,
		buildings = buildings,
	}
end

local function t1seaBase6()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortex_slingshot_scav.id,   xOffset =   0,  zOffset =   0, direction = 1 },
			{ unitDefID = UDN.cortex_sharksteeth_scav.id, xOffset =  48,  zOffset =  48, direction = 1 },
			{ unitDefID = UDN.cortex_sharksteeth_scav.id, xOffset =  48,  zOffset = -16, direction = 1 },
			{ unitDefID = UDN.cortex_sharksteeth_scav.id, xOffset = -16,  zOffset =  48, direction = 1 },
			{ unitDefID = UDN.cortex_sharksteeth_scav.id, xOffset =  16,  zOffset = -48, direction = 1 },
			{ unitDefID = UDN.cortex_sharksteeth_scav.id, xOffset =  48,  zOffset =  16, direction = 1 },
			{ unitDefID = UDN.cortex_sharksteeth_scav.id, xOffset = -48,  zOffset =  16, direction = 1 },
			{ unitDefID = UDN.cortex_sharksteeth_scav.id, xOffset =  16,  zOffset =  48, direction = 1 },
			{ unitDefID = UDN.cortex_sharksteeth_scav.id, xOffset = -48,  zOffset = -16, direction = 1 },
			{ unitDefID = UDN.cortex_sharksteeth_scav.id, xOffset = -16,  zOffset = -48, direction = 1 },
			{ unitDefID = UDN.cortex_sharksteeth_scav.id, xOffset = -48,  zOffset =  48, direction = 1 },
			{ unitDefID = UDN.cortex_sharksteeth_scav.id, xOffset =  48,  zOffset = -48, direction = 1 },
			{ unitDefID = UDN.cortex_sharksteeth_scav.id, xOffset = -48,  zOffset = -48, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armada_navalnettle_scav.id,   xOffset =   0,  zOffset =   0, direction = 1 },
			{ unitDefID = UDN.armada_sharksteeth_scav.id, xOffset =  16,  zOffset =  48, direction = 1 },
			{ unitDefID = UDN.armada_sharksteeth_scav.id, xOffset =  48,  zOffset = -48, direction = 1 },
			{ unitDefID = UDN.armada_sharksteeth_scav.id, xOffset =  48,  zOffset = -16, direction = 1 },
			{ unitDefID = UDN.armada_sharksteeth_scav.id, xOffset =  48,  zOffset =  16, direction = 1 },
			{ unitDefID = UDN.armada_sharksteeth_scav.id, xOffset = -48,  zOffset = -48, direction = 1 },
			{ unitDefID = UDN.armada_sharksteeth_scav.id, xOffset = -48,  zOffset =  16, direction = 1 },
			{ unitDefID = UDN.armada_sharksteeth_scav.id, xOffset = -48,  zOffset =  48, direction = 1 },
			{ unitDefID = UDN.armada_sharksteeth_scav.id, xOffset =  16,  zOffset = -48, direction = 1 },
			{ unitDefID = UDN.armada_sharksteeth_scav.id, xOffset =  48,  zOffset =  48, direction = 1 },
			{ unitDefID = UDN.armada_sharksteeth_scav.id, xOffset = -48,  zOffset = -16, direction = 1 },
			{ unitDefID = UDN.armada_sharksteeth_scav.id, xOffset = -16,  zOffset = -48, direction = 1 },
			{ unitDefID = UDN.armada_sharksteeth_scav.id, xOffset = -16,  zOffset =  48, direction = 1 },
		}
	end

	return {
		type = types.Sea,
		tiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3, tiers.T4 },
		radius = 100,
		buildings = buildings,
	}
end

local function t1SeaBase7()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortex_urchin_scav.id,   xOffset =  48,  zOffset = 0, direction = 1 },
			{ unitDefID = UDN.cortex_radarsonartower_scav.id, xOffset =   0,  zOffset = 0, direction = 1 },
			{ unitDefID = UDN.cortex_urchin_scav.id,   xOffset = -48,  zOffset = 0, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armada_navalradarsonar_scav.id, xOffset =   0,  zOffset = 0, direction = 1 },
			{ unitDefID = UDN.armada_harpoon_scav.id,   xOffset = -48,  zOffset = 0, direction = 1 },
			{ unitDefID = UDN.armada_harpoon_scav.id,   xOffset =  48,  zOffset = 0, direction = 1 },
		}
	end

	return {
		type = types.Sea,
		tiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3, tiers.T4 },
		radius = 100,
		buildings = buildings,
	}
end

local function t1SeaBase8()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortex_urchin_scav.id,   xOffset = 0,  zOffset = -48, direction = 1 },
			{ unitDefID = UDN.cortex_coral_scav.id, xOffset = 0,  zOffset =   0, direction = 1 },
			{ unitDefID = UDN.cortex_urchin_scav.id,   xOffset = 0,  zOffset =  48, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armada_harpoon_scav.id,   xOffset =  8,  zOffset =  56, direction = 1 },
			{ unitDefID = UDN.armada_harpoon_scav.id,   xOffset = -8,  zOffset = -56, direction = 1 },
			{ unitDefID = UDN.armada_manta_scav.id, xOffset =  0,  zOffset =   0, direction = 1 },
		}
	end

	return {
		type = types.Sea,
		tiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3, tiers.T4 },
		radius = 100,
		buildings = buildings,
	}
end

-- Tech 2
local function t2SeaBase1()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortex_navaladvancedenergyconverter_scav.id, xOffset =  40,  zOffset =  40, direction = 0 },
			{ unitDefID = UDN.cortex_navaladvancedenergyconverter_scav.id, xOffset =  40,  zOffset = -40, direction = 0 },
			{ unitDefID = UDN.cortex_navaladvancedenergyconverter_scav.id, xOffset = -40,  zOffset =  40, direction = 0 },
			{ unitDefID = UDN.cortex_navaladvancedenergyconverter_scav.id, xOffset = -40,  zOffset = -40, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armada_navaladvancedenergyconverter_scav.id, xOffset = -40,  zOffset =  32, direction = 0 },
			{ unitDefID = UDN.armada_navaladvancedenergyconverter_scav.id, xOffset = -40,  zOffset = -32, direction = 0 },
			{ unitDefID = UDN.armada_navaladvancedenergyconverter_scav.id, xOffset =  40,  zOffset = -32, direction = 0 },
			{ unitDefID = UDN.armada_navaladvancedenergyconverter_scav.id, xOffset =  40,  zOffset =  32, direction = 0 },
		}
	end

	return {
		type = types.Sea,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 100,
		buildings = buildings,
	}
end

local function t2SeaBase2()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortex_hardenedmetalstorage_scav.id, xOffset =  32,  zOffset =  32, direction = 0 },
			{ unitDefID = UDN.cortex_hardenedmetalstorage_scav.id, xOffset = -32,  zOffset = -32, direction = 0 },
			{ unitDefID = UDN.cortex_hardenedmetalstorage_scav.id, xOffset =  32,  zOffset = -32, direction = 0 },
			{ unitDefID = UDN.cortex_hardenedmetalstorage_scav.id, xOffset = -32,  zOffset =  32, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armada_hardenedmetalstorage_scav.id, xOffset =  32,  zOffset =  32, direction = 0 },
			{ unitDefID = UDN.armada_hardenedmetalstorage_scav.id, xOffset =  32,  zOffset = -32, direction = 0 },
			{ unitDefID = UDN.armada_hardenedmetalstorage_scav.id, xOffset = -32,  zOffset =  32, direction = 0 },
			{ unitDefID = UDN.armada_hardenedmetalstorage_scav.id, xOffset = -32,  zOffset = -32, direction = 0 },
		}
	end

	return {
		type = types.Sea,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 100,
		buildings = buildings,
	}
end

local function t2SeaBase3()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortex_navalfusionreactor_scav.id, xOffset = -40,  zOffset = -40, direction = 0 },
			{ unitDefID = UDN.cortex_navalfusionreactor_scav.id, xOffset = -40,  zOffset =  40, direction = 0 },
			{ unitDefID = UDN.cortex_navalfusionreactor_scav.id, xOffset =  40,  zOffset =  40, direction = 0 },
			{ unitDefID = UDN.cortex_navalfusionreactor_scav.id, xOffset =  40,  zOffset = -40, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armada_navalfusionreactor_scav.id, xOffset =  48,  zOffset = -32, direction = 0 },
			{ unitDefID = UDN.armada_navalfusionreactor_scav.id, xOffset = -48,  zOffset =  32, direction = 0 },
			{ unitDefID = UDN.armada_navalfusionreactor_scav.id, xOffset =  48,  zOffset =  32, direction = 0 },
			{ unitDefID = UDN.armada_navalfusionreactor_scav.id, xOffset = -48,  zOffset = -32, direction = 0 },
		}
	end

	return {
		type = types.Sea,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 100,
		buildings = buildings,
	}
end

local function t2SeaBase4()

	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortex_hardenedenergystorage_scav.id, xOffset = -40,  zOffset = -40, direction = 0 },
			{ unitDefID = UDN.cortex_hardenedenergystorage_scav.id, xOffset =  40,  zOffset = -40, direction = 0 },
			{ unitDefID = UDN.cortex_hardenedenergystorage_scav.id, xOffset =  40,  zOffset =  40, direction = 0 },
			{ unitDefID = UDN.cortex_hardenedenergystorage_scav.id, xOffset = -40,  zOffset =  40, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armada_hardenedenergystorage_scav.id, xOffset = -32,  zOffset =  32, direction = 0 },
			{ unitDefID = UDN.armada_hardenedenergystorage_scav.id, xOffset =  32,  zOffset =  32, direction = 0 },
			{ unitDefID = UDN.armada_hardenedenergystorage_scav.id, xOffset =  32,  zOffset = -32, direction = 0 },
			{ unitDefID = UDN.armada_hardenedenergystorage_scav.id, xOffset = -32,  zOffset = -32, direction = 0 },
		}
	end

	return {
		type = types.Sea,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 100,
		buildings = buildings,
	}
end

local function t2SeaBase5()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortex_devastator_scav.id, xOffset =   0,  zOffset =   0, direction = 0 },
			{ unitDefID = UDN.cortex_navalbirdshot_scav.id,  xOffset =   0,  zOffset =  80, direction = 0 },
			{ unitDefID = UDN.cortex_lamprey_scav.id,   xOffset = -72,  zOffset =   8, direction = 0 },
			{ unitDefID = UDN.cortex_navalbirdshot_scav.id,  xOffset =   0,  zOffset = -80, direction = 0 },
			{ unitDefID = UDN.cortex_lamprey_scav.id,   xOffset =  72,  zOffset =  -8, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.cortex_devastator_scav.id, xOffset =   0,  zOffset =   0, direction = 0 },
			{ unitDefID = UDN.armada_moray_scav.id,   xOffset = -80,  zOffset =   0, direction = 0 },
			{ unitDefID = UDN.armada_navalarbalest_scav.id, xOffset =  -8,  zOffset = -72, direction = 0 },
			{ unitDefID = UDN.armada_moray_scav.id,   xOffset =  80,  zOffset =   0, direction = 0 },
			{ unitDefID = UDN.armada_navalarbalest_scav.id, xOffset =   8,  zOffset =  72, direction = 0 },
		}
	end

	return {
		type = types.Sea,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 100,
		buildings = buildings,
	}
end

local function t2SeaFactory1()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortex_shipyard_scav.id,         xOffset =    0,  zOffset =  6, direction = 0 },
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset = -104,  zOffset = -2, direction = 0 },
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset =  104,  zOffset = -2, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armada_shipyard_scav.id,         xOffset =    0,  zOffset =  6, direction = 0 },
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset =  104,  zOffset = -2, direction = 0 },
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset = -104,  zOffset = -2, direction = 0 },
		}
	end

	return {
		type = types.Sea,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 104,
		buildings = buildings,
	}
end

local function t2SeaFactory2()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortex_navalhovercraftplatform_scav.id,        xOffset =    0,  zOffset = 0, direction = 0 },
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset =  104,  zOffset = 0, direction = 0 },
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset = -104,  zOffset = 0, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armada_navalhovercraftplatform_scav.id,        xOffset =    0,  zOffset = 0, direction = 0 },
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset =  104,  zOffset = 0, direction = 0 },
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset = -104,  zOffset = 0, direction = 0 },
		}
	end

	return {
		type = types.Sea,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 104,
		buildings = buildings,
	}
end

local function t2SeaFactory3()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortex_amphibiouscomplex_scav.id,      xOffset =    0,  zOffset = -5, direction = 0 },
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset =  104,  zOffset =  3, direction = 0 },
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset = -104,  zOffset =  3, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armada_amphibiouscomplex_scav.id,      xOffset =   6,  zOffset = -16, direction = 0 },
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset =  94,  zOffset =   8, direction = 0 },
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset = -98,  zOffset =   8, direction = 0 },
		}
	end

	return {
		type = types.Sea,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 104,
		buildings = buildings,
	}
end

local function t2SeaFactory4()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortex_seaplaneplatform_scav.id,       xOffset =   0,  zOffset = 0, direction = 0 },
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset =  96,  zOffset = 0, direction = 0 },
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset = -96,  zOffset = 0, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armada_seaplaneplatform_scav.id,       xOffset =   0,  zOffset = 0, direction = 0 },
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset = -96,  zOffset = 0, direction = 0 },
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset =  96,  zOffset = 0, direction = 0 },
		}
	end

	return {
		type = types.Sea,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 96,
		buildings = buildings,
	}
end

local function t2SeaFactory5()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortex_advancedshipyard_scav.id,        xOffset =    0,  zOffset = -5, direction = 0 },
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset = -136,  zOffset =  3, direction = 0 },
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset =  136,  zOffset =  3, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armada_advancedshipyard_scav.id,        xOffset =    0,  zOffset = -5, direction = 0 },
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset =  136,  zOffset =  3, direction = 0 },
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset = -136,  zOffset =  3, direction = 0 },
		}
	end

	return {
		type = types.Sea,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 136,
		buildings = buildings,
	}
end

-- Tech 3
local function t3SeaFactory1()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortex_underwaterexperimentalgantry_scav.id,     xOffset =    0,  zOffset =   0, direction = 0 },
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset = -112,  zOffset =   0, direction = 0 },
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset =  112,  zOffset =   0, direction = 0 },
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset =  112,  zOffset = -48, direction = 0 },
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset = -112,  zOffset = -48, direction = 0 },
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset =  112,  zOffset =  48, direction = 0 },
			{ unitDefID = UDN.cortex_navalconstructionturret_scav.id, xOffset = -112,  zOffset =  48, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armada_experimentalgantryuw_scav.id,    xOffset =    0,  zOffset =   0, direction = 0 },
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset = -112,  zOffset = -48, direction = 0 },
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset =  112,  zOffset =  48, direction = 0 },
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset = -112,  zOffset =  48, direction = 0 },
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset =  112,  zOffset = -48, direction = 0 },
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset = -112,  zOffset =   0, direction = 0 },
			{ unitDefID = UDN.armada_navalconstructionturret_scav.id, xOffset =  112,  zOffset =   0, direction = 0 },
		}
	end

	return {
		type = types.Sea,
		tiers = { tiers.T3, tiers.T4 },
		radius = 112,
		buildings = buildings,
	}
end

return {
	t1SeaBase1,
	t1SeaBase2,
	t1SeaBase3,
	t1SeaBase4,
	t1SeaBase5,
	t1seaBase6,
	t1SeaBase7,
	t1SeaBase8,
	t2SeaBase1,
	t2SeaBase2,
	t2SeaBase3,
	t2SeaBase4,
	t2SeaBase5,
	t2SeaFactory1,
	t2SeaFactory2,
	t2SeaFactory3,
	t2SeaFactory4,
	t2SeaFactory5,
	t3SeaFactory1,
}