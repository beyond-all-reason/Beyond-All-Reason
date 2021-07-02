--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west

local UDN = UnitDefNames

local function redBase1()
	local randomturrets = {UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corhllt_scav.id, UDN.corhlt_scav.id, BPWallOrPopup("scav"), UDN.corrl_scav.id, UDN.cornanotc_scav.id,}
	local factoryID

	local r = math.random(0,1)
	if r == 0 then
		factoryID = UDN.corlab_scav.id
	else
		factoryID = UDN.corvp_scav.id
	end

	return {
		radius = 196,
		buildings = {
			-- Defences / Nanos
			{ unitDefID = randomturrets[math.random(1, #randomturrets)],	xOffset = -196, yOffset = 0, zOffset =  -64, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)],	xOffset = -196, yOffset = 0, zOffset =   64, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)],	xOffset = -196, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)],	xOffset = -196, yOffset = 0, zOffset = -128, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)],	xOffset = -196, yOffset = 0, zOffset =  128, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)],	xOffset =  196, yOffset = 0, zOffset =  -64, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)],	xOffset =  196, yOffset = 0, zOffset =   64, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)],	xOffset =  196, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)],	xOffset =  196, yOffset = 0, zOffset = -128, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)],	xOffset =  196, yOffset = 0, zOffset =  128, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)],	xOffset =   96, yOffset = 0, zOffset =  -48, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)],	xOffset =   96, yOffset = 0, zOffset =   48, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)],	xOffset =   96, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)],	xOffset =   96, yOffset = 0, zOffset =  -48, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)],	xOffset =   96, yOffset = 0, zOffset =   48, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)],	xOffset =   96, yOffset = 0, zOffset =    0, direction = 0 },

			-- Utility
			{ unitDefID = factoryID, xOffset = 0, yOffset = 0, zOffset = 0, direction = 0 },

			-- Walls
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -136, yOffset = 0, zOffset = -32, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -136, yOffset = 0, zOffset =  32, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -136, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -136, yOffset = 0, zOffset = -64, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -136, yOffset = 0, zOffset =  64, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  136, yOffset = 0, zOffset = -32, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  136, yOffset = 0, zOffset =  32, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  136, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  136, yOffset = 0, zOffset = -64, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  136, yOffset = 0, zOffset =  64, direction = 0 },
		}
	}
end

local function blueBase1()
	local randomturrets = {UDN.armllt_scav.id, UDN.armllt_scav.id, UDN.armhlt_scav.id, BPWallOrPopup("scav"), UDN.armrl_scav.id, UDN.armnanotc_scav.id,}
	local factoryID

	local r = math.random(0,1)
	if r == 0 then
		factoryID = UDN.armlab_scav.id
	else
		factoryID = UDN.armvp_scav.id
	end

	return {
		radius = 196,
		buildings = {
			-- Defences / Nanos
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset = -196, yOffset = 0, zOffset =  -64, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset = -196, yOffset = 0, zOffset =   64, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset = -196, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset = -196, yOffset = 0, zOffset = -128, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset = -196, yOffset = 0, zOffset =  128, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =  196, yOffset = 0, zOffset =  -64, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =  196, yOffset = 0, zOffset =   64, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =  196, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =  196, yOffset = 0, zOffset = -128, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =  196, yOffset = 0, zOffset =  128, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =  -96, yOffset = 0, zOffset =  -48, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =  -96, yOffset = 0, zOffset =   48, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =  -96, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =   96, yOffset = 0, zOffset =  -48, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =   96, yOffset = 0, zOffset =   48, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =   96, yOffset = 0, zOffset =    0, direction = 0 },

			-- Utility
			{ unitDefID = factoryID, xOffset = 0, yOffset = 0, zOffset = 0, direction = 0 },

			-- Walls
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -136, yOffset = 0, zOffset = -32, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -136, yOffset = 0, zOffset =  32, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -136, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -136, yOffset = 0, zOffset = -64, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -136, yOffset = 0, zOffset =  64, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  136, yOffset = 0, zOffset = -32, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  136, yOffset = 0, zOffset =  32, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  136, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  136, yOffset = 0, zOffset = -64, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  136, yOffset = 0, zOffset =  64, direction = 0 },
		}
	}
end

local function blueBase2()
	return {
		radius = 192,
		buildings = {
			-- Nanos
			{ unitDefID = UDN.armnanotc_scav.id, xOffset = -24, yOffset = 0, zOffset =  24, direction = 1 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset = -24, yOffset = 0, zOffset = -24, direction = 1 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  24, yOffset = 0, zOffset =  24, direction = 1 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  24, yOffset = 0, zOffset = -24, direction = 1 },

			-- Defences
			{ unitDefID = UDN.armllt_scav.id,	 xOffset =  -64, yOffset = 0, zOffset = -160, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id, xOffset =   72, yOffset = 0, zOffset =   72, direction = 3 },
			{ unitDefID = UDN.armbeamer_scav.id, xOffset = -160, yOffset = 0, zOffset = -128, direction = 3 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset =  128, yOffset = 0, zOffset =  160, direction = 0 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset =  160, yOffset = 0, zOffset =   64, direction = 1 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset =   64, yOffset = 0, zOffset =  160, direction = 0 },
			{ unitDefID = UDN.armferret_scav.id, xOffset =   72, yOffset = 0, zOffset =  -72, direction = 3 },
			{ unitDefID = UDN.armbeamer_scav.id, xOffset =  128, yOffset = 0, zOffset = -160, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id, xOffset =  -72, yOffset = 0, zOffset =   72, direction = 3 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset = -160, yOffset = 0, zOffset =  128, direction = 3 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset = -160, yOffset = 0, zOffset =  -64, direction = 3 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset = -128, yOffset = 0, zOffset = -160, direction = 2 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset =   64, yOffset = 0, zOffset = -160, direction = 2 },
			{ unitDefID = UDN.armbeamer_scav.id, xOffset =  160, yOffset = 0, zOffset =  128, direction = 1 },
			{ unitDefID = UDN.armbeamer_scav.id, xOffset = -128, yOffset = 0, zOffset =  160, direction = 0 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset =  -64, yOffset = 0, zOffset =  160, direction = 0 },
			{ unitDefID = UDN.armferret_scav.id, xOffset =  -72, yOffset = 0, zOffset =  -72, direction = 3 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset =  160, yOffset = 0, zOffset =  -64, direction = 1 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset =  160, yOffset = 0, zOffset = -128, direction = 1 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset = -160, yOffset = 0, zOffset =   64, direction = 3 },

			-- Walls
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  160, yOffset = 0, zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -192, yOffset = 0, zOffset =   64, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  128, yOffset = 0, zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -128, yOffset = 0, zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   64, yOffset = 0, zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -64, yOffset = 0, zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -192, yOffset = 0, zOffset = -160, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -64, yOffset = 0, zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -192, yOffset = 0, zOffset =  -96, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset = -128, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -96, yOffset = 0, zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -192, yOffset = 0, zOffset =  128, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   64, yOffset = 0, zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -192, yOffset = 0, zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset =   64, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -192, yOffset = 0, zOffset =   96, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -160, yOffset = 0, zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -160, yOffset = 0, zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -192, yOffset = 0, zOffset =  -64, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   96, yOffset = 0, zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  160, yOffset = 0, zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -192, yOffset = 0, zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -192, yOffset = 0, zOffset = -128, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -128, yOffset = 0, zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   96, yOffset = 0, zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset =  -96, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset =  128, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset = -160, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset =  -64, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset =  160, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -192, yOffset = 0, zOffset =  160, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset =   96, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  128, yOffset = 0, zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -96, yOffset = 0, zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset =  192, direction = 1 },
		}
	}
end

local function redBase2()
	return {
		radius = 192,
		buildings = {
			-- Nanos
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  24, yOffset = 0, zOffset =  24, direction = 3 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  24, yOffset = 0, zOffset = -24, direction = 3 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset = -24, yOffset = 0, zOffset =  24, direction = 3 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset = -24, yOffset = 0, zOffset = -24, direction = 3 },

			-- Defences
			{ unitDefID = UDN.corerad_scav.id, xOffset =  -80, yOffset = 0, zOffset =  -80, direction = 0 },
			{ unitDefID = UDN.corhllt_scav.id, xOffset = -128, yOffset = 0, zOffset =  160, direction = 0 },
			{ unitDefID = UDN.corerad_scav.id, xOffset =   80, yOffset = 0, zOffset =  -80, direction = 0 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset = -160, yOffset = 0, zOffset =  -64, direction = 3 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset = -160, yOffset = 0, zOffset =   64, direction = 3 },
			{ unitDefID = UDN.corhllt_scav.id, xOffset =  128, yOffset = 0, zOffset = -160, direction = 2 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset = -160, yOffset = 0, zOffset =  128, direction = 3 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset =  160, yOffset = 0, zOffset =  -64, direction = 1 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset =   64, yOffset = 0, zOffset =  160, direction = 0 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset =   64, yOffset = 0, zOffset = -160, direction = 2 },
			{ unitDefID = UDN.corerad_scav.id, xOffset =  -80, yOffset = 0, zOffset =   80, direction = 0 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset =  128, yOffset = 0, zOffset =  160, direction = 0 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset =  -64, yOffset = 0, zOffset =  160, direction = 0 },
			{ unitDefID = UDN.corerad_scav.id, xOffset =   80, yOffset = 0, zOffset =   80, direction = 0 },
			{ unitDefID = UDN.corhllt_scav.id, xOffset = -160, yOffset = 0, zOffset = -128, direction = 3 },
			{ unitDefID = UDN.corhllt_scav.id, xOffset =  160, yOffset = 0, zOffset =  128, direction = 1 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset =  160, yOffset = 0, zOffset = -128, direction = 1 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset = -128, yOffset = 0, zOffset = -160, direction = 2 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset =  -64, yOffset = 0, zOffset = -160, direction = 2 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset =  160, yOffset = 0, zOffset =   64, direction = 1 },

			-- Walls
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -160, yOffset = 0, zOffset =  192, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -192, yOffset = 0, zOffset = -128, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  160, yOffset = 0, zOffset =  192, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  128, yOffset = 0, zOffset =  192, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -192, yOffset = 0, zOffset =   96, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   96, yOffset = 0, zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   64, yOffset = 0, zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -192, yOffset = 0, zOffset =  -96, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset =  128, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -96, yOffset = 0, zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -192, yOffset = 0, zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -192, yOffset = 0, zOffset =  128, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -192, yOffset = 0, zOffset = -160, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset = -128, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -192, yOffset = 0, zOffset =  192, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  160, yOffset = 0, zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset =  160, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -96, yOffset = 0, zOffset =  192, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset =  192, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -128, yOffset = 0, zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  128, yOffset = 0, zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset =   96, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -160, yOffset = 0, zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   96, yOffset = 0, zOffset =  192, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset =  -64, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -128, yOffset = 0, zOffset =  192, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   64, yOffset = 0, zOffset =  192, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset =   64, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset =  -96, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -64, yOffset = 0, zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset = -160, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -192, yOffset = 0, zOffset =   64, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -192, yOffset = 0, zOffset =  -64, direction = 3 },
		}
	}
end

return {
	RedBase1 = redBase1,
	RedBase2 = redBase2,
	BlueBase1 = blueBase1,
	BlueBase2 = blueBase2,
}