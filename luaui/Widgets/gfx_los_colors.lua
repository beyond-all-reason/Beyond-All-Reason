local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "LOS colors",
		desc      = "custom colors for LOS",
		author    = "[teh]decay (thx to Floris, BrainDamage, hokomoko, [teh]Teddy, Buttons840)",
		date      = "23 jul 2015",
		license   = "public domain",
		layer     = 0,
		version   = 3,
		enabled   = true
	}
end

--Changelog
-- v2 Changed colors + remember ; mode + fix keybindings for non english layouts + 2 color presets (/loswithcolors)
-- v3 Radar shading is always visible, and there is no option to colorize it.
--    Most players do not know about these settings, they are not in the setting UI, and do not have keybinds in grid.

local opacity = 0.88

local losColors = {
	fog =    {0.40, 0.40, 0.40},
	los =    {0.60, 0.60, 0.60},
	radar =  {0.00, 0.00, 0.00}, -- not used
	jam =    {0.08, -0.08, -0.08},
	radar2 = {0.40, 0.40, 0.40},
}


local always, LOS, radar, jam, radar2
local spSetLosViewColors = Spring.SetLosViewColors


local function lerp(a, b, t)
	return a + (b - a) * t
end

local function applyOpacity(colors)
	local newColors = table.copy(colors)
	for i,c in pairs(newColors.fog) do
		newColors.fog[i] = lerp(0, c, opacity)
	end
	for i,c in pairs(newColors.radar2) do
		-- move only half way towards opacity to give contract
		-- between radar and full fow
		newColors.radar2[i] = lerp(0, c, lerp(opacity, 1, 0.5))
	end
	return newColors
end

local function updateLOS()
	local colors = applyOpacity(losColors)
	spSetLosViewColors(colors.fog, colors.los, colors.radar, colors.jam, colors.radar2)
end

function widget:Initialize()
	WG['los'] = {}
	WG['los'].getOpacity = function()
		return opacity
	end
	WG['los'].setOpacity = function(value)
		opacity = value
		updateLOS()
	end

	always, LOS, radar, jam, radar2 = Spring.GetLosViewColors()

	updateLOS()
end

function widget:Shutdown()
	spSetLosViewColors(always, LOS, radar, jam, radar2)
end

function widget:SetConfigData(data)
	if data.opacity ~= nil then
		opacity = data.opacity
	end
end

function widget:GetConfigData()
	return {
		opacity = opacity
	}
end
