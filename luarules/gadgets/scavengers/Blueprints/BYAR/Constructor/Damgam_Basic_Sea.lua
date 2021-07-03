local UDN = UnitDefNames

-- Tech 1
local function t1SeaBase1()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.corfmkr_scav.id, xOffset = -24, yOffset = 0, zOffset =  24, direction = 1 },
			{ unitDefID = UDN.corfmkr_scav.id, xOffset = -24, yOffset = 0, zOffset = -24, direction = 1 },
			{ unitDefID = UDN.corfmkr_scav.id, xOffset =  24, yOffset = 0, zOffset =  24, direction = 1 },
			{ unitDefID = UDN.corfmkr_scav.id, xOffset =  24, yOffset = 0, zOffset = -24, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armfmkr_scav.id, xOffset = -24, yOffset = 0, zOffset = -24, direction = 1 },
			{ unitDefID = UDN.armfmkr_scav.id, xOffset =  24, yOffset = 0, zOffset = -24, direction = 1 },
			{ unitDefID = UDN.armfmkr_scav.id, xOffset = -24, yOffset = 0, zOffset =  24, direction = 1 },
			{ unitDefID = UDN.armfmkr_scav.id, xOffset =  24, yOffset = 0, zOffset =  24, direction = 1 },
		}
	end

	return {
		radius = 100,
		buildings = buildings,
	}
end

local function t1SeaBase2()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.coruwms_scav.id, xOffset = -32, yOffset = 0, zOffset =  32, direction = 1 },
			{ unitDefID = UDN.coruwms_scav.id, xOffset =  32, yOffset = 0, zOffset = -32, direction = 1 },
			{ unitDefID = UDN.coruwms_scav.id, xOffset = -32, yOffset = 0, zOffset = -32, direction = 1 },
			{ unitDefID = UDN.coruwms_scav.id, xOffset =  32, yOffset = 0, zOffset =  32, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armuwms_scav.id, xOffset = -32, yOffset = 0, zOffset = -32, direction = 1 },
			{ unitDefID = UDN.armuwms_scav.id, xOffset =  32, yOffset = 0, zOffset =  32, direction = 1 },
			{ unitDefID = UDN.armuwms_scav.id, xOffset = -32, yOffset = 0, zOffset =  32, direction = 1 },
			{ unitDefID = UDN.armuwms_scav.id, xOffset =  32, yOffset = 0, zOffset = -32, direction = 1 },
		}
	end

    return {
		radius = 100,
		buildings = buildings,
	}
end

local function t1SeaBase3()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortide_scav.id, xOffset =  24, yOffset = 0, zOffset = -24, direction = 1 },
			{ unitDefID = UDN.cortide_scav.id, xOffset =  24, yOffset = 0, zOffset =  24, direction = 1 },
			{ unitDefID = UDN.cortide_scav.id, xOffset = -24, yOffset = 0, zOffset =  24, direction = 1 },
			{ unitDefID = UDN.cortide_scav.id, xOffset = -24, yOffset = 0, zOffset = -24, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armtide_scav.id, xOffset =  24, yOffset = 0, zOffset = -24, direction = 1 },
			{ unitDefID = UDN.armtide_scav.id, xOffset =  24, yOffset = 0, zOffset =  24, direction = 1 },
			{ unitDefID = UDN.armtide_scav.id, xOffset = -24, yOffset = 0, zOffset = -24, direction = 1 },
			{ unitDefID = UDN.armtide_scav.id, xOffset = -24, yOffset = 0, zOffset =  24, direction = 1 },
		}
	end

    return {
		radius = 100,
		buildings = buildings,
	}
end

local function t1SeaBase4()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.coruwes_scav.id, xOffset = -32, yOffset = 0, zOffset =  32, direction = 1 },
			{ unitDefID = UDN.coruwes_scav.id, xOffset =  32, yOffset = 0, zOffset = -32, direction = 1 },
			{ unitDefID = UDN.coruwes_scav.id, xOffset = -32, yOffset = 0, zOffset = -32, direction = 1 },
			{ unitDefID = UDN.coruwes_scav.id, xOffset =  32, yOffset = 0, zOffset =  32, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armuwes_scav.id, xOffset =  32, yOffset = 0, zOffset = -32, direction = 1 },
			{ unitDefID = UDN.armuwes_scav.id, xOffset = -32, yOffset = 0, zOffset =  32, direction = 1 },
			{ unitDefID = UDN.armuwes_scav.id, xOffset =  32, yOffset = 0, zOffset =  32, direction = 1 },
			{ unitDefID = UDN.armuwes_scav.id, xOffset = -32, yOffset = 0, zOffset = -32, direction = 1 },
		}
	end

	return {
		radius = 100,
		buildings = buildings,
	}
end

local function t1SeaBase5()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset = -24, yOffset = 0, zOffset =  24, direction = 1 },
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset =  24, yOffset = 0, zOffset = -24, direction = 1 },
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset = -24, yOffset = 0, zOffset = -24, direction = 1 },
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset =  24, yOffset = 0, zOffset =  24, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset =  24, yOffset = 0, zOffset =  24, direction = 1 },
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset = -24, yOffset = 0, zOffset = -24, direction = 1 },
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset =  24, yOffset = 0, zOffset = -24, direction = 1 },
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset = -24, yOffset = 0, zOffset =  24, direction = 1 },
		}
	end

	return {
		radius = 100,
		buildings = buildings,
	}
end

local function t1seaBase6()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.corfrt_scav.id,   xOffset =   0, yOffset = 0, zOffset =   0, direction = 1 },
			{ unitDefID = UDN.corfdrag_scav.id, xOffset =  48, yOffset = 0, zOffset =  48, direction = 1 },
			{ unitDefID = UDN.corfdrag_scav.id, xOffset =  48, yOffset = 0, zOffset = -16, direction = 1 },
			{ unitDefID = UDN.corfdrag_scav.id, xOffset = -16, yOffset = 0, zOffset =  48, direction = 1 },
			{ unitDefID = UDN.corfdrag_scav.id, xOffset =  16, yOffset = 0, zOffset = -48, direction = 1 },
			{ unitDefID = UDN.corfdrag_scav.id, xOffset =  48, yOffset = 0, zOffset =  16, direction = 1 },
			{ unitDefID = UDN.corfdrag_scav.id, xOffset = -48, yOffset = 0, zOffset =  16, direction = 1 },
			{ unitDefID = UDN.corfdrag_scav.id, xOffset =  16, yOffset = 0, zOffset =  48, direction = 1 },
			{ unitDefID = UDN.corfdrag_scav.id, xOffset = -48, yOffset = 0, zOffset = -16, direction = 1 },
			{ unitDefID = UDN.corfdrag_scav.id, xOffset = -16, yOffset = 0, zOffset = -48, direction = 1 },
			{ unitDefID = UDN.corfdrag_scav.id, xOffset = -48, yOffset = 0, zOffset =  48, direction = 1 },
			{ unitDefID = UDN.corfdrag_scav.id, xOffset =  48, yOffset = 0, zOffset = -48, direction = 1 },
			{ unitDefID = UDN.corfdrag_scav.id, xOffset = -48, yOffset = 0, zOffset = -48, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armfrt_scav.id,   xOffset =   0, yOffset = 0, zOffset =   0, direction = 1 },
			{ unitDefID = UDN.armfdrag_scav.id, xOffset =  16, yOffset = 0, zOffset =  48, direction = 1 },
			{ unitDefID = UDN.armfdrag_scav.id, xOffset =  48, yOffset = 0, zOffset = -48, direction = 1 },
			{ unitDefID = UDN.armfdrag_scav.id, xOffset =  48, yOffset = 0, zOffset = -16, direction = 1 },
			{ unitDefID = UDN.armfdrag_scav.id, xOffset =  48, yOffset = 0, zOffset =  16, direction = 1 },
			{ unitDefID = UDN.armfdrag_scav.id, xOffset = -48, yOffset = 0, zOffset = -48, direction = 1 },
			{ unitDefID = UDN.armfdrag_scav.id, xOffset = -48, yOffset = 0, zOffset =  16, direction = 1 },
			{ unitDefID = UDN.armfdrag_scav.id, xOffset = -48, yOffset = 0, zOffset =  48, direction = 1 },
			{ unitDefID = UDN.armfdrag_scav.id, xOffset =  16, yOffset = 0, zOffset = -48, direction = 1 },
			{ unitDefID = UDN.armfdrag_scav.id, xOffset =  48, yOffset = 0, zOffset =  48, direction = 1 },
			{ unitDefID = UDN.armfdrag_scav.id, xOffset = -48, yOffset = 0, zOffset = -16, direction = 1 },
			{ unitDefID = UDN.armfdrag_scav.id, xOffset = -16, yOffset = 0, zOffset = -48, direction = 1 },
			{ unitDefID = UDN.armfdrag_scav.id, xOffset = -16, yOffset = 0, zOffset =  48, direction = 1 },
		}
	end

	return {
		radius = 100,
		buildings = buildings,
	}
end

local function t1SeaBase7()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortl_scav.id,   xOffset =  48, yOffset = 0, zOffset = 0, direction = 1 },
			{ unitDefID = UDN.corfrad_scav.id, xOffset =   0, yOffset = 0, zOffset = 0, direction = 1 },
			{ unitDefID = UDN.cortl_scav.id,   xOffset = -48, yOffset = 0, zOffset = 0, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armfrad_scav.id, xOffset =   0, yOffset = 0, zOffset = 0, direction = 1 },
			{ unitDefID = UDN.armtl_scav.id,   xOffset = -48, yOffset = 0, zOffset = 0, direction = 1 },
			{ unitDefID = UDN.armtl_scav.id,   xOffset =  48, yOffset = 0, zOffset = 0, direction = 1 },
		}
	end

	return {
		radius = 100,
		buildings = buildings,
	}
end

local function t1SeaBase8()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cortl_scav.id,   xOffset = 0, yOffset = 0, zOffset = -48, direction = 1 },
			{ unitDefID = UDN.corfhlt_scav.id, xOffset = 0, yOffset = 0, zOffset =   0, direction = 1 },
			{ unitDefID = UDN.cortl_scav.id,   xOffset = 0, yOffset = 0, zOffset =  48, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armtl_scav.id,   xOffset =  8, yOffset = 0, zOffset =  56, direction = 1 },
			{ unitDefID = UDN.armtl_scav.id,   xOffset = -8, yOffset = 0, zOffset = -56, direction = 1 },
			{ unitDefID = UDN.armfhlt_scav.id, xOffset =  0, yOffset = 0, zOffset =   0, direction = 1 },
		}
	end

	return {
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
			{ unitDefID = UDN.coruwmmm_scav.id, xOffset =  40, yOffset = 0, zOffset =  40, direction = 0 },
			{ unitDefID = UDN.coruwmmm_scav.id, xOffset =  40, yOffset = 0, zOffset = -40, direction = 0 },
			{ unitDefID = UDN.coruwmmm_scav.id, xOffset = -40, yOffset = 0, zOffset =  40, direction = 0 },
			{ unitDefID = UDN.coruwmmm_scav.id, xOffset = -40, yOffset = 0, zOffset = -40, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armuwmmm_scav.id, xOffset = -40, yOffset = 0, zOffset =  32, direction = 0 },
			{ unitDefID = UDN.armuwmmm_scav.id, xOffset = -40, yOffset = 0, zOffset = -32, direction = 0 },
			{ unitDefID = UDN.armuwmmm_scav.id, xOffset =  40, yOffset = 0, zOffset = -32, direction = 0 },
			{ unitDefID = UDN.armuwmmm_scav.id, xOffset =  40, yOffset = 0, zOffset =  32, direction = 0 },
		}
	end

	return {
		radius = 100,
		buildings = buildings,
	}
end

local function t2SeaBase2()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.coruwadvms_scav.id, xOffset =  32, yOffset = 0, zOffset =  32, direction = 0 },
			{ unitDefID = UDN.coruwadvms_scav.id, xOffset = -32, yOffset = 0, zOffset = -32, direction = 0 },
			{ unitDefID = UDN.coruwadvms_scav.id, xOffset =  32, yOffset = 0, zOffset = -32, direction = 0 },
			{ unitDefID = UDN.coruwadvms_scav.id, xOffset = -32, yOffset = 0, zOffset =  32, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armuwadvms_scav.id, xOffset =  32, yOffset = 0, zOffset =  32, direction = 0 },
			{ unitDefID = UDN.armuwadvms_scav.id, xOffset =  32, yOffset = 0, zOffset = -32, direction = 0 },
			{ unitDefID = UDN.armuwadvms_scav.id, xOffset = -32, yOffset = 0, zOffset =  32, direction = 0 },
			{ unitDefID = UDN.armuwadvms_scav.id, xOffset = -32, yOffset = 0, zOffset = -32, direction = 0 },
		}
	end

	return {
		radius = 100,
		buildings = buildings,
	}
end

local function t2SeaBase3()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.coruwfus_scav.id, xOffset = -40, yOffset = 0, zOffset = -40, direction = 0 },
			{ unitDefID = UDN.coruwfus_scav.id, xOffset = -40, yOffset = 0, zOffset =  40, direction = 0 },
			{ unitDefID = UDN.coruwfus_scav.id, xOffset =  40, yOffset = 0, zOffset =  40, direction = 0 },
			{ unitDefID = UDN.coruwfus_scav.id, xOffset =  40, yOffset = 0, zOffset = -40, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armuwfus_scav.id, xOffset =  48, yOffset = 0, zOffset = -32, direction = 0 },
			{ unitDefID = UDN.armuwfus_scav.id, xOffset = -48, yOffset = 0, zOffset =  32, direction = 0 },
			{ unitDefID = UDN.armuwfus_scav.id, xOffset =  48, yOffset = 0, zOffset =  32, direction = 0 },
			{ unitDefID = UDN.armuwfus_scav.id, xOffset = -48, yOffset = 0, zOffset = -32, direction = 0 },
		}
	end

	return {
		radius = 100,
		buildings = buildings,
	}
end

local function t2SeaBase4()

	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.coruwadves_scav.id, xOffset = -40, yOffset = 0, zOffset = -40, direction = 0 },
			{ unitDefID = UDN.coruwadves_scav.id, xOffset =  40, yOffset = 0, zOffset = -40, direction = 0 },
			{ unitDefID = UDN.coruwadves_scav.id, xOffset =  40, yOffset = 0, zOffset =  40, direction = 0 },
			{ unitDefID = UDN.coruwadves_scav.id, xOffset = -40, yOffset = 0, zOffset =  40, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armuwadves_scav.id, xOffset = -32, yOffset = 0, zOffset =  32, direction = 0 },
			{ unitDefID = UDN.armuwadves_scav.id, xOffset =  32, yOffset = 0, zOffset =  32, direction = 0 },
			{ unitDefID = UDN.armuwadves_scav.id, xOffset =  32, yOffset = 0, zOffset = -32, direction = 0 },
			{ unitDefID = UDN.armuwadves_scav.id, xOffset = -32, yOffset = 0, zOffset = -32, direction = 0 },
		}
	end

	return {
		radius = 100,
		buildings = buildings,
	}
end

local function t2SeaBase5()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.corfdoom_scav.id, xOffset =   0, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = UDN.corenaa_scav.id,  xOffset =   0, yOffset = 0, zOffset =  80, direction = 0 },
			{ unitDefID = UDN.coratl_scav.id,   xOffset = -72, yOffset = 0, zOffset =   8, direction = 0 },
			{ unitDefID = UDN.corenaa_scav.id,  xOffset =   0, yOffset = 0, zOffset = -80, direction = 0 },
			{ unitDefID = UDN.coratl_scav.id,   xOffset =  72, yOffset = 0, zOffset =  -8, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.corfdoom_scav.id, xOffset =   0, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = UDN.armatl_scav.id,   xOffset = -80, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = UDN.armfflak_scav.id, xOffset =  -8, yOffset = 0, zOffset = -72, direction = 0 },
			{ unitDefID = UDN.armatl_scav.id,   xOffset =  80, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = UDN.armfflak_scav.id, xOffset =   8, yOffset = 0, zOffset =  72, direction = 0 },
		}
	end

	return {
		radius = 100,
		buildings = buildings,
	}
end

local function t2SeaFactory1()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.corsy_scav.id,         xOffset =    0, yOffset = 0, zOffset =  6, direction = 0 },
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset = -104, yOffset = 0, zOffset = -2, direction = 0 },
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset =  104, yOffset = 0, zOffset = -2, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armsy_scav.id,         xOffset =    0, yOffset = 0, zOffset =  6, direction = 0 },
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset =  104, yOffset = 0, zOffset = -2, direction = 0 },
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset = -104, yOffset = 0, zOffset = -2, direction = 0 },
		}
	end

	return {
		radius = 104,
		buildings = buildings,
	}
end

local function t2SeaFactory2()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.corfhp_scav.id,        xOffset =    0, yOffset = 0, zOffset = 0, direction = 0 },
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset =  104, yOffset = 0, zOffset = 0, direction = 0 },
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset = -104, yOffset = 0, zOffset = 0, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armfhp_scav.id,        xOffset =    0, yOffset = 0, zOffset = 0, direction = 0 },
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset =  104, yOffset = 0, zOffset = 0, direction = 0 },
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset = -104, yOffset = 0, zOffset = 0, direction = 0 },
		}
	end

	return {
		radius = 104,
		buildings = buildings,
	}
end

local function t2SeaFactory3()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.coramsub_scav.id,      xOffset =    0, yOffset = 0, zOffset = -5, direction = 0 },
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset =  104, yOffset = 0, zOffset =  3, direction = 0 },
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset = -104, yOffset = 0, zOffset =  3, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armamsub_scav.id,      xOffset =   6, yOffset = 0, zOffset = -16, direction = 0 },
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset =  94, yOffset = 0, zOffset =   8, direction = 0 },
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset = -98, yOffset = 0, zOffset =   8, direction = 0 },
		}
	end

	return {
		radius = 104,
		buildings = buildings,
	}
end

local function t2SeaFactory4()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.corplat_scav.id,       xOffset =   0, yOffset = 0, zOffset = 0, direction = 0 },
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset =  96, yOffset = 0, zOffset = 0, direction = 0 },
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset = -96, yOffset = 0, zOffset = 0, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armplat_scav.id,       xOffset =   0, yOffset = 0, zOffset = 0, direction = 0 },
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset = -96, yOffset = 0, zOffset = 0, direction = 0 },
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset =  96, yOffset = 0, zOffset = 0, direction = 0 },
		}
	end

	return {
		radius = 96,
		buildings = buildings,
	}
end

local function t2SeaFactory5()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.corasy_scav.id,        xOffset =    0, yOffset = 0, zOffset = -5, direction = 0 },
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset = -136, yOffset = 0, zOffset =  3, direction = 0 },
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset =  136, yOffset = 0, zOffset =  3, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armasy_scav.id,        xOffset =    0, yOffset = 0, zOffset = -5, direction = 0 },
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset =  136, yOffset = 0, zOffset =  3, direction = 0 },
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset = -136, yOffset = 0, zOffset =  3, direction = 0 },
		}
	end

	return {
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
			{ unitDefID = UDN.corgantuw_scav.id,     xOffset =    0, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset = -112, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset =  112, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset =  112, yOffset = 0, zOffset = -48, direction = 0 },
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset = -112, yOffset = 0, zOffset = -48, direction = 0 },
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset =  112, yOffset = 0, zOffset =  48, direction = 0 },
			{ unitDefID = UDN.cornanotcplat_scav.id, xOffset = -112, yOffset = 0, zOffset =  48, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armshltxuw_scav.id,    xOffset =    0, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset = -112, yOffset = 0, zOffset = -48, direction = 0 },
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset =  112, yOffset = 0, zOffset =  48, direction = 0 },
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset = -112, yOffset = 0, zOffset =  48, direction = 0 },
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset =  112, yOffset = 0, zOffset = -48, direction = 0 },
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset = -112, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = UDN.armnanotcplat_scav.id, xOffset =  112, yOffset = 0, zOffset =   0, direction = 0 },
		}
	end

	return {
		radius = 112,
		buildings = buildings,
	}
end

return {
	T1SeaBase1 = t1SeaBase1,
	T1SeaBase2 = t1SeaBase2,
	T1SeaBase3 = t1SeaBase3,
	T1SeaBase4 = t1SeaBase4,
	T1SeaBase5 = t1SeaBase5,
	T1seaBase6 = t1seaBase6,
	T1SeaBase7 = t1SeaBase7,
	T1SeaBase8 = t1SeaBase8,
	T2SeaBase1 = t2SeaBase1,
	T2SeaBase2 = t2SeaBase2,
	T2SeaBase3 = t2SeaBase3,
	T2SeaBase4 = t2SeaBase4,
	T2SeaBase5 = t2SeaBase5,
	T2SeaFactory1 = t2SeaFactory1,
	T2SeaFactory2 = t2SeaFactory2,
	T2SeaFactory3 = t2SeaFactory3,
	T2SeaFactory4 = t2SeaFactory4,
	T2SeaFactory5 = t2SeaFactory5,
	T3SeaFactory1 = t3SeaFactory1,
}