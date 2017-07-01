function widget:GetInfo()
    return {
        name      = "BA LOS colors",
        desc      = "custom colors for LOS",
        author    = "[teh]decay (thx to Floris, gluon, hokomoko, [teh]Teddy)",
        date      = "23 jul 2015",
        license   = "public domain",
        layer     = 0,
        version   = 2,
        enabled   = true  -- loaded by default
    }
end

-- project page: this widget is included in BA repo

--Changelog
-- v2 Changed colors + remember ; mode + fix keybindings for non english layouts + 2 color presets (/loswithcolors)

local cfgLosWithRadarEnabled = true
local colorProfile = "greyscale" -- "colored"
local specDetected = false

local always, LOS, radar, jam, radar2 = Spring.GetLosViewColors()

local losColorsWithRadarsGray = {
    fog =    {0.10, 0.10, 0.10},
    los =    {0.30, 0.30, 0.30},
    radar =  {0.17, 0.17, 0.17},
    jam =    {0.12, 0.00, 0.00},
    radar2 = {0.17, 0.17, 0.17},
}

local losColorsWithRadarsColor = {
    fog =    {0.15, 0.15, 0.15},
    los =    {0.22, 0.14, 0.30},
    radar2 = {0.08, 0.16, 0.00},
    jam =    {0.20, 0.00, 0.00},
    radar =  {0.08, 0.16, 0.00},
}

local losColorsWithoutRadars = {
    fog =    {0.30, 0.30, 0.30},
    los =    {0.25, 0.25, 0.25},
    radar =  {0.00, 0.00, 0.00},
    jam =    {0.12, 0.00, 0.00},
    radar2 = {0.00, 0.00, 0.00},
}

local spSendCommands = Spring.SendCommands
local spSetLosViewColors = Spring.SetLosViewColors

function setLosWithRadars()
    cfgLosWithRadarEnabled = true
    withRadars()
end

function setLosWithoutRadars()
    cfgLosWithRadarEnabled = false
    withoutRadars()
end

function withRadars()
    if colorProfile == "greyscale" then
        updateLOS(losColorsWithRadarsGray)
    else
        updateLOS(losColorsWithRadarsColor)
    end
end

function withoutRadars()
    updateLOS(losColorsWithoutRadars)
end

function updateLOS(colors)
    spSetLosViewColors(colors.fog, colors.los, colors.radar, colors.jam, colors.radar2)
end

function widget:PlayerChanged(playerID)
    local myPlayerId = Spring.GetMyPlayerID()
    local _, _, spec, _, _, _, _, _ = Spring.GetPlayerInfo(myPlayerId)

    if spec then
        specDetected = true
        withoutRadars()
    end
    return true
end

function widget:Shutdown()
    spSendCommands('unbindkeyset Any+;')
    spSetLosViewColors(always, LOS, radar, jam, radar2)
end


function widget:GetConfigData()
    return {
        cfgLosWithRadarEnabled = cfgLosWithRadarEnabled,
        colorProfile = colorProfile
    }
end

function setLosWithColors()
    colorProfile = "colored"
    setLosWithRadars()
end

function setLosWithoutColors()
    colorProfile = "greyscale"
    setLosWithRadars()
end

function toggleLOSRadars()
    if specDetected and cfgLosWithRadarEnabled then
        cfgLosWithRadarEnabled = false
    end
    specDetected = false

    if cfgLosWithRadarEnabled then
        setLosWithoutRadars()
    else
        setLosWithRadars()
    end
end

function toggleLOSColors()
    if colorProfile == "greyscale" then
        setLosWithColors()
    else
        setLosWithoutColors()
    end
end

function widget:SetConfigData(data)
    widgetHandler:AddAction("losradar", toggleLOSRadars)
    widgetHandler:AddAction("loscolor", toggleLOSColors)

    spSendCommands('unbindkeyset Any+;')
    spSendCommands('bind Any+; losradar')

    if data.cfgLosWithRadarEnabled ~= nil then
        cfgLosWithRadarEnabled = data.cfgLosWithRadarEnabled
    else
        cfgLosWithRadarEnabled = false
    end

    if data.colorProfile ~= nil then
        colorProfile = data.colorProfile
    else
        colorProfile = "greyscale"
    end

    if cfgLosWithRadarEnabled == true then
        withRadars()
    else
        withoutRadars()
    end
end

