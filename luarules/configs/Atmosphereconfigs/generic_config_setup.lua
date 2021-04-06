local mapsizex = Game.mapSizeX
local mapsizez = Game.mapSizeZ
local transitionSpeed = mapsizez/mapsizex

local windmin = Game.windMin
local windmax = Game.windMax

local daylenght = math.ceil(mapsizex+mapsizez)*2
local nightlenght = math.ceil(daylenght*0.50) -- higher = shorter night (yes, i know, counterintuitive)

local lightningsounds = {
	"thunder1",
	"thunder2",
	"thunder3",
	"thunder4",
	"thunder5",
	"thunder6",
}  

local badweatherplanned = false

if windmax < 5 then
    atmospherelevelmult = 1
    badweatherchance = 0
    fireflieschance = 0
elseif windmax < 10 then
    atmospherelevelmult = 1.1
    badweatherchance = 10
    fireflieschance = 10
elseif windmax < 15 then
    atmospherelevelmult = 1.2
    badweatherchance = 30
    fireflieschance = 50
elseif windmax < 20 then
    atmospherelevelmult = 1.3
    badweatherchance = 40
    fireflieschance = 75
else
    atmospherelevelmult = 1.4
    badweatherchance = 60
    fireflieschance = 100
end

-- testing stuff
-- atmospherelevelmult = 1.4
-- badweatherchance = 100
-- fireflieschance = 100

function gadget:GameFrame(n)
    local clock = n%daylenght
    
    if clock == 10 then -- new day
        if math.random(0,100) < badweatherchance then
            badweatherplanned = true
            badweatherclockstart = math.random(1,daylenght*0.75)
            badweatherclockend = math.random(badweatherclockstart,daylenght-1)
            if math.random(1,2) == 1 then
                thunderstormenabled = true
            else
                thunderstormenabled = false
            end
        else
            badweatherplanned = false
        end
    end

    if badweatherplanned and clock > badweatherclockstart and clock < badweatherclockend then
        if thunderstormenabled and math.random(1,15) == 1 then
            SpawnCEGInRandomMapPosAvoidUnits("lightningstrike", 0, 128, lightningsounds[math.random(1,#lightningsounds)], 1)
        end
        if clock > nightlenght then
            SendToUnsynced("MapAtmosphereConfigSetSun", 0.5, transitionSpeed, 1, 0.5*atmospherelevelmult, 0.5, 0.5)
            SendToUnsynced("MapAtmosphereConfigSetFog", -0.5, 1, transitionSpeed*2.5, transitionSpeed*1.5)
        else
            SendToUnsynced("MapAtmosphereConfigSetSun", 0.8, transitionSpeed, 0.8*atmospherelevelmult, 0.8, 0.8)
            SendToUnsynced("MapAtmosphereConfigSetFog", -0.5, 1, transitionSpeed*2.5, transitionSpeed*1.5)
        end
    else
        if clock > nightlenght then
            SendToUnsynced("MapAtmosphereConfigSetSun", 0.7, transitionSpeed, 0.7*atmospherelevelmult, 0.7, 0.7)
            SendToUnsynced("MapAtmosphereConfigSetFog", 1, 1, transitionSpeed*2.5, transitionSpeed*1.5)
        else
            SendToUnsynced("MapAtmosphereConfigSetSun", 1, transitionSpeed, 1, 1, 1)
            SendToUnsynced("MapAtmosphereConfigSetFog", 1, 1, transitionSpeed*2.5, transitionSpeed*1.5)
        end
    end
end
