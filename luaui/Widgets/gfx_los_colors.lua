function widget:GetInfo()
    return {
        name      = "LOS colors",
        desc      = "custom colors for LOS",
        author    = "[teh]decay (thx to Floris, BrainDamage, hokomoko, [teh]Teddy)",
        date      = "23 jul 2015",
        license   = "public domain",
        layer     = 0,
        version   = 2,
        enabled   = true  -- loaded by default
    }
end

--Changelog
-- v2 Changed colors + remember ; mode + fix keybindings for non english layouts + 2 color presets (/loswithcolors)

local losWithRadarEnabled = false
local colorize = false
local specDetected = false
local opacity = 1

local always, LOS, radar, jam, radar2

local losColorsWithRadarsGray = {
    fog =    {0.20, 0.20, 0.20},
    los =    {0.25, 0.25, 0.25},
    radar =  {0.12, 0.12, 0.12},
    jam =    {0.10, 0.02, 0.02},
    radar2 = {0.40, 0.40, 0.40},
}

local losColorsWithRadarsColor = {
    fog =    {0.17, 0.17, 0.17},
    los =    {0.30, 0.30, 0.30},
    radar2 = {0.08, 0.16, 0.00},
    jam =    {0.20, 0.00, 0.00},
    radar =  {0.08, 0.16, 0.00},
}

local losColorsWithoutRadars = {
    fog =    {0.30, 0.30, 0.30},
    los =    {0.20, 0.20, 0.20},
    radar =  {0.00, 0.00, 0.00},
    jam =    {0.10, 0.02, 0.02},
    radar2 = {0.00, 0.00, 0.00},
}

local spSendCommands = Spring.SendCommands
local spSetLosViewColors = Spring.SetLosViewColors

function setLosWithRadars()
    losWithRadarEnabled = true
    withRadars()
end

function setLosWithoutRadars()
    losWithRadarEnabled = false
    withoutRadars()
end

function withRadars()
    if not colorize then
        updateLOS(losColorsWithRadarsGray)
    else
        updateLOS(losColorsWithRadarsColor)
    end
end

function withoutRadars()
    updateLOS(losColorsWithoutRadars)
end


function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

function applyOpacity(colors)
	local newColors = deepcopy(colors)
	for i,c in pairs(newColors.fog) do
		newColors.fog[i] = c * opacity
	end
	return newColors
end

function updateLOS(colors)
	colors = applyOpacity(colors)
    spSetLosViewColors(colors.fog, colors.los, colors.radar, colors.jam, colors.radar2)
end

function widget:PlayerChanged(playerID)
    if playerID == Spring.GetMyPlayerID() then
        if Spring.GetSpectatingState() then
            specDetected = true
            if losWithRadarEnabled then
                withRadars()
            else
                withoutRadars()
            end
        end
    end
end

function widget:Shutdown()
    spSendCommands('unbindkeyset Any+;')
    spSetLosViewColors(always, LOS, radar, jam, radar2)
end


function widget:GetConfigData()
    return {
        losWithRadarEnabled = losWithRadarEnabled,
        colorize = colorize
    }
end

function refreshLOS()
	if losWithRadarEnabled then
		setLosWithRadars()
	else
		setLosWithoutRadars()
	end
end

function setLosWithColors()
    colorize = true
    setLosWithRadars()
end

function setLosWithoutColors()
    colorize = false
    setLosWithRadars()
end

function toggleLOSRadars()
    if losWithRadarEnabled then
        setLosWithoutRadars()
    else
        setLosWithRadars()
    end
end

function toggleLOSColors()
    if not colorize then
        setLosWithColors()
    else
        setLosWithoutColors()
    end
end

function widget:Initialize()
    widgetHandler:AddAction("losradar", toggleLOSRadars)
    widgetHandler:AddAction("loscolor", toggleLOSColors)

    spSendCommands('unbindkeyset Any+;')
    spSendCommands('bind Any+; losradar')

	WG['los'] = {}
	WG['los'].getColorize = function()
		return colorize
	end
	WG['los'].setColorize = function(value)
		colorize = value
		if not losWithRadarEnabled or not specDetected then
			refreshLOS()
		end
	end
	WG['los'].getOpacity = function()
		return opacity
	end
	WG['los'].setOpacity = function(value)
		opacity = value
		if not losWithRadarEnabled or not specDetected then
			refreshLOS()
		end
	end

    always, LOS, radar, jam, radar2 = Spring.GetLosViewColors()

    if losWithRadarEnabled == true then
        setLosWithRadars()
    else
        setLosWithoutRadars()
    end
end

function widget:SetConfigData(data)
    if data.losWithRadarEnabled ~= nil then
        losWithRadarEnabled = data.losWithRadarEnabled
    else
        losWithRadarEnabled = true
    end

	if data.colorize ~= nil then
		colorize = data.colorize
	end
	if data.opacity ~= nil then
		opacity = data.opacity
	end
end

