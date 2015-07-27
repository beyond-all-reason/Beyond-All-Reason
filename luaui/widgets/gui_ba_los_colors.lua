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
-- v2 Changed colors + remember ; mode + fix keybindings for non english layouts

local losWithRadarEnabled = false;

local losColorsWithRadars = {
    fog =    {0.15, 0.15, 0.15},
    los =    {0.22, 0.14, 0.30},
    radar2 = {0.08, 0.16, 0.00},
    jam =    {0.20, 0.00, 0.00},
    radar =  {0.00, 0.00, 0.00},
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
    spSetLosViewColors(losColorsWithRadars.fog, losColorsWithRadars.los, losColorsWithRadars.radar,
        losColorsWithRadars.jam, losColorsWithRadars.radar2)
    spSendCommands('unbindkeyset Any+;')
    spSendCommands('bind Any+; loswithoutradars')
end

function setLosWithoutRadars()
    losWithRadarEnabled = false
    spSetLosViewColors(losColorsWithoutRadars.fog, losColorsWithoutRadars.los, losColorsWithoutRadars.radar,
        losColorsWithoutRadars.jam, losColorsWithoutRadars.radar2)
    spSendCommands('unbindkeyset Any+;')
    spSendCommands('bind Any+; loswithradars')
end

function widget:PlayerChanged(playerID)
    local playerID = Spring.GetMyPlayerID()
    local _, _, spec, _, _, _, _, _ = Spring.GetPlayerInfo(playerID)

    if spec then
        spSetLosViewColors(losColorsWithoutRadars.fog, losColorsWithoutRadars.los, losColorsWithoutRadars.radar,
            losColorsWithoutRadars.jam, losColorsWithoutRadars.radar2)
        spSendCommands('unbindkeyset Any+;')
        spSendCommands('bind Any+; loswithradars')
    end
    return true
end

function widget:ShutDown()
    spSendCommands('unbindkeyset Any+;')
end


function widget:GetConfigData()
    return { losWithRadarEnabled = losWithRadarEnabled }
end

function widget:SetConfigData(data)
    widgetHandler:AddAction("loswithradars", setLosWithRadars)
    widgetHandler:AddAction("loswithoutradars", setLosWithoutRadars)

    if data.losWithRadarEnabled ~= nil then
        losWithRadarEnabled = data.losWithRadarEnabled
    else
        losWithRadarEnabled = false
    end

    if losWithRadarEnabled == true then
        setLosWithRadars()
    else
        setLosWithoutRadars()
    end
end

