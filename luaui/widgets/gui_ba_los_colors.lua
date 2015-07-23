function widget:GetInfo()
    return {
        name      = "BA LOS colors",
        desc      = "custom colors for LOS",
        author    = "[teh]decay (thx to Floris, gluon, hokomoko)",
        date      = "23 jul 2015",
        license   = "public domain",
        layer     = 0,
        version   = 1,
        enabled   = true  -- loaded by default
    }
end

-- project page: this widget is included in BA repo

--Changelog
-- v2

--TODO: add ability to remember ";" mode


local losColorsWithRadars = {
    fog = {0.1,0.1,0.1},
    los = {0.3,0.3,0.3},
    radar = {0.17,0.17,0.17},
    jam = {0.12,0,0},
    radar2 = {0.17,0.17,0.17},
}

local losColorsWithoutRadars = {
    fog = {0.3,0.3,0.3},
    los = {0.25,0.25,0.25},
    radar = {0,0,0},
    jam = {0.12,0,0},
    radar2 = {0,0,0},
}

function widget:Initialize()
    setLosWithoutRadars()

    Spring.SendCommands('unbindkeyset ;')
    Spring.SendCommands('bind ; loswithradars')

    widgetHandler:AddAction("loswithradars", setLosWithRadars)
    widgetHandler:AddAction("loswithoutradars", setLosWithoutRadars)
end

function setLosWithRadars()
    Spring.SetLosViewColors(losColorsWithRadars.fog, losColorsWithRadars.los, losColorsWithRadars.radar,
        losColorsWithRadars.jam, losColorsWithRadars.radar2)
    Spring.SendCommands('unbindkeyset ;')
    Spring.SendCommands('bind ; loswithoutradars')
end

function setLosWithoutRadars()
    Spring.SetLosViewColors(losColorsWithoutRadars.fog, losColorsWithoutRadars.los, losColorsWithoutRadars.radar,
        losColorsWithoutRadars.jam, losColorsWithoutRadars.radar2)
    Spring.SendCommands('unbindkeyset ;')
    Spring.SendCommands('bind ; loswithradars')
end

function widget:PlayerChanged(playerID)
    local playerID = Spring.GetMyPlayerID()
    local _, _, spec, _, _, _, _, _ = Spring.GetPlayerInfo(playerID)

    if spec then
        setLosWithoutRadars()
    end
    return true
end

function widget:ShutDown()
    Spring.SendCommands('unbindkeyset ;')
end

