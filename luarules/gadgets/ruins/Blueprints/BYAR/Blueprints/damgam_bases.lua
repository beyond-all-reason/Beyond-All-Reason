local blueprintConfig = VFS.Include('luarules/gadgets/ruins/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local tiers = blueprintConfig.Tiers
local types = blueprintConfig.BlueprintTypes
local UDN = UnitDefNames

--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west

local function redBase1()
	local randomturrets = {UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corhllt_scav.id, UDN.corhlt_scav.id, BPWallOrPopup('scav', 1, "land"), UDN.corrl_scav.id, UDN.cornanotc_scav.id,}
	local factoryID

	local r = math.random(0,1)
	if r == 0 then
		factoryID = UDN.corlab_scav.id
	else
		factoryID = UDN.corvp_scav.id
	end

	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3 },
		radius = 196,
		buildings = {
			-- Defences / Nanos
			{ unitDefID = randomturrets[math.random(1, #randomturrets)], xOffset = -196,  zOffset =  -64, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)], xOffset = -196,  zOffset =   64, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)], xOffset = -196,  zOffset =    0, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)], xOffset = -196,  zOffset = -128, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)], xOffset = -196,  zOffset =  128, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)], xOffset =  196,  zOffset =  -64, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)], xOffset =  196,  zOffset =   64, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)], xOffset =  196,  zOffset =    0, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)], xOffset =  196,  zOffset = -128, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)], xOffset =  196,  zOffset =  128, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)], xOffset =   96,  zOffset =  -48, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)], xOffset =   96,  zOffset =   48, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)], xOffset =   96,  zOffset =    0, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)], xOffset =   96,  zOffset =  -48, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)], xOffset =   96,  zOffset =   48, direction = 0 },
			{ unitDefID = randomturrets[math.random(1, #randomturrets)], xOffset =   96,  zOffset =    0, direction = 0 },

			-- Utility
			{ unitDefID = factoryID, xOffset = 0,  zOffset = 0, direction = 0 },

			-- Walls
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -136,  zOffset = -32, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -136,  zOffset =  32, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -136,  zOffset =   0, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -136,  zOffset = -64, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -136,  zOffset =  64, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  136,  zOffset = -32, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  136,  zOffset =  32, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  136,  zOffset =   0, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  136,  zOffset = -64, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  136,  zOffset =  64, direction = 0 },
		}
	}
end

local function blueBase1()
	local randomturrets = {UDN.armllt_scav.id, UDN.armllt_scav.id, UDN.armhlt_scav.id, BPWallOrPopup('scav', 1, "land"), UDN.armrl_scav.id, UDN.armnanotc_scav.id,}
	local factoryID

	local r = math.random(0,1)
	if r == 0 then
		factoryID = UDN.armlab_scav.id
	else
		factoryID = UDN.armvp_scav.id
	end

	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3 },
		radius = 196,
		buildings = {
			-- Defences / Nanos
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset = -196,  zOffset =  -64, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset = -196,  zOffset =   64, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset = -196,  zOffset =    0, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset = -196,  zOffset = -128, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset = -196,  zOffset =  128, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =  196,  zOffset =  -64, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =  196,  zOffset =   64, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =  196,  zOffset =    0, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =  196,  zOffset = -128, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =  196,  zOffset =  128, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =  -96,  zOffset =  -48, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =  -96,  zOffset =   48, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =  -96,  zOffset =    0, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =   96,  zOffset =  -48, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =   96,  zOffset =   48, direction = 0 },
			{ unitDefID = randomturrets[math.random(1,#randomturrets)], xOffset =   96,  zOffset =    0, direction = 0 },

			-- Utility
			{ unitDefID = factoryID, xOffset = 0,  zOffset = 0, direction = 0 },

			-- Walls
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -136,  zOffset = -32, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -136,  zOffset =  32, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -136,  zOffset =   0, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -136,  zOffset = -64, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -136,  zOffset =  64, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  136,  zOffset = -32, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  136,  zOffset =  32, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  136,  zOffset =   0, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  136,  zOffset = -64, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  136,  zOffset =  64, direction = 0 },
		}
	}
end

local function blueBase2()
	return {
		type = types.Land,
		tiers = { tiers.T1, tiers.T2, tiers.T3 },
		radius = 192,
		buildings = {
			-- Nanos
			{ unitDefID = UDN.armnanotc_scav.id, xOffset = -24,  zOffset =  24, direction = 1 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset = -24,  zOffset = -24, direction = 1 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  24,  zOffset =  24, direction = 1 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  24,  zOffset = -24, direction = 1 },

			-- Defences
			{ unitDefID = UDN.armllt_scav.id,	 xOffset =  -64,  zOffset = -160, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id, xOffset =   72,  zOffset =   72, direction = 3 },
			{ unitDefID = UDN.armbeamer_scav.id, xOffset = -160,  zOffset = -128, direction = 3 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset =  128,  zOffset =  160, direction = 0 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset =  160,  zOffset =   64, direction = 1 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset =   64,  zOffset =  160, direction = 0 },
			{ unitDefID = UDN.armferret_scav.id, xOffset =   72,  zOffset =  -72, direction = 3 },
			{ unitDefID = UDN.armbeamer_scav.id, xOffset =  128,  zOffset = -160, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id, xOffset =  -72,  zOffset =   72, direction = 3 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset = -160,  zOffset =  128, direction = 3 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset = -160,  zOffset =  -64, direction = 3 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset = -128,  zOffset = -160, direction = 2 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset =   64,  zOffset = -160, direction = 2 },
			{ unitDefID = UDN.armbeamer_scav.id, xOffset =  160,  zOffset =  128, direction = 1 },
			{ unitDefID = UDN.armbeamer_scav.id, xOffset = -128,  zOffset =  160, direction = 0 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset =  -64,  zOffset =  160, direction = 0 },
			{ unitDefID = UDN.armferret_scav.id, xOffset =  -72,  zOffset =  -72, direction = 3 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset =  160,  zOffset =  -64, direction = 1 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset =  160,  zOffset = -128, direction = 1 },
			{ unitDefID = UDN.armllt_scav.id,	 xOffset = -160,  zOffset =   64, direction = 3 },

			-- Walls
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  160,  zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192,  zOffset =   64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  128,  zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -128,  zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   64,  zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -64,  zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192,  zOffset = -160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -64,  zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192,  zOffset =  -96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset = -128, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -96,  zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192,  zOffset =  128, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   64,  zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192,  zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset =   64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192,  zOffset =   96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -160,  zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -160,  zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192,  zOffset =  -64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   96,  zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  160,  zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192,  zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192,  zOffset = -128, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -128,  zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   96,  zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset =  -96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset =  128, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset = -160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset =  -64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset =  160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192,  zOffset =  160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset =   96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  128,  zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -96,  zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset =  192, direction = 1 },
		}
	}
end

local function redBase2()
	return {
		type = types.Land,
		tiers = { tiers.T1, tiers.T2, tiers.T3 },
		radius = 192,
		buildings = {
			-- Nanos
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  24,  zOffset =  24, direction = 3 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  24,  zOffset = -24, direction = 3 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset = -24,  zOffset =  24, direction = 3 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset = -24,  zOffset = -24, direction = 3 },

			-- Defences
			{ unitDefID = UDN.corerad_scav.id, xOffset =  -80,  zOffset =  -80, direction = 0 },
			{ unitDefID = UDN.corhllt_scav.id, xOffset = -128,  zOffset =  160, direction = 0 },
			{ unitDefID = UDN.corerad_scav.id, xOffset =   80,  zOffset =  -80, direction = 0 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset = -160,  zOffset =  -64, direction = 3 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset = -160,  zOffset =   64, direction = 3 },
			{ unitDefID = UDN.corhllt_scav.id, xOffset =  128,  zOffset = -160, direction = 2 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset = -160,  zOffset =  128, direction = 3 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset =  160,  zOffset =  -64, direction = 1 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset =   64,  zOffset =  160, direction = 0 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset =   64,  zOffset = -160, direction = 2 },
			{ unitDefID = UDN.corerad_scav.id, xOffset =  -80,  zOffset =   80, direction = 0 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset =  128,  zOffset =  160, direction = 0 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset =  -64,  zOffset =  160, direction = 0 },
			{ unitDefID = UDN.corerad_scav.id, xOffset =   80,  zOffset =   80, direction = 0 },
			{ unitDefID = UDN.corhllt_scav.id, xOffset = -160,  zOffset = -128, direction = 3 },
			{ unitDefID = UDN.corhllt_scav.id, xOffset =  160,  zOffset =  128, direction = 1 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset =  160,  zOffset = -128, direction = 1 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset = -128,  zOffset = -160, direction = 2 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset =  -64,  zOffset = -160, direction = 2 },
			{ unitDefID = UDN.corllt_scav.id,  xOffset =  160,  zOffset =   64, direction = 1 },

			-- Walls
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -160,  zOffset =  192, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192,  zOffset = -128, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  160,  zOffset =  192, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  128,  zOffset =  192, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192,  zOffset =   96, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   96,  zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   64,  zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192,  zOffset =  -96, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset =  128, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -96,  zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192,  zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192,  zOffset =  128, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192,  zOffset = -160, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset = -128, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192,  zOffset =  192, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  160,  zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset =  160, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -96,  zOffset =  192, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset =  192, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -128,  zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  128,  zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset =   96, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -160,  zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   96,  zOffset =  192, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset =  -64, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -128,  zOffset =  192, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   64,  zOffset =  192, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset =   64, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset =  -96, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -64,  zOffset = -192, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  192,  zOffset = -160, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192,  zOffset =   64, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192,  zOffset =  -64, direction = 3 },
		}
	}
end

return {
	redBase1,
	redBase2,
	blueBase1,
	blueBase2,
}