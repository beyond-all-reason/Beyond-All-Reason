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

local losWithRadarEnabled = true;
local colorProfile = "greyscale" -- "colored"
local specDetected = false

local always, LOS, radar, jam, radar2

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
    losWithRadarEnabled = true
    withRadars()
end

function setLosWithoutRadars()
    losWithRadarEnabled = false
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
    if playerID == Spring.GetMyPlayerID() then
        if Spring.GetSpectatingState() then
            specDetected = true
            withoutRadars()
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
    if specDetected and losWithRadarEnabled then
        losWithRadarEnabled = false
    end
    specDetected = false

    if losWithRadarEnabled then
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

function widget:Initialize()
    widgetHandler:AddAction("losradar", toggleLOSRadars)
    widgetHandler:AddAction("loscolor", toggleLOSColors)

    spSendCommands('unbindkeyset Any+;')
    spSendCommands('bind Any+; losradar')

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

    if data.colorProfile ~= nil then
        colorProfile = data.colorProfile
    else
        colorProfile = "greyscale"
    end
end

