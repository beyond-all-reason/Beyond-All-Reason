Spring.Echo("Enabled generic atmosphere config")

local mapsizex = Game.mapSizeX
local mapsizez = Game.mapSizeZ
local transitionSpeed = (mapsizez/mapsizex) * 0.66

local windmin = Game.windMin
local windmax = Game.windMax

local fullcyclelenght = math.ceil(mapsizex+mapsizez)*2
local nightlenght = math.ceil(fullcyclelenght*0.66) -- % of the cycle at which night begins and stays until the end of cycle

VFS.Include("luarules/configs/map_biomes.lua")

local currentMapname = Game.mapName:lower()
for i = 1,#snowKeywords do
    if string.find(currentMapname, snowKeywords[i]) then
        snowMaps[currentMapname] = true
        break
    end
end
if snowMaps[currentMapname] then
    snowyMap = true
end


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
    atmospherelevelmult = 1.05
    badweatherchance = 10
    fireflieschance = 25
elseif windmax < 15 then
    atmospherelevelmult = 1.10
    badweatherchance = 20
    fireflieschance = 50
elseif windmax < 20 then
    atmospherelevelmult = 1.15
    badweatherchance = 30
    fireflieschance = 75
else
    atmospherelevelmult = 1.20
    badweatherchance = 50
    fireflieschance = 100
end

-- testing stuff
-- atmospherelevelmult = 1.2
-- badweatherchance = 100
-- fireflieschance = 100

function gadget:GameFrame(n)
    local clock = n%fullcyclelenght

    if clock == 10 then -- new day
        if math.random(0,100) < badweatherchance then
            badweatherplanned = true
            badweatherclockstart = math.random(1,math.floor(fullcyclelenght*0.75))
            badweatherclockend = math.random(badweatherclockstart,fullcyclelenght-1)
            if snowyMap then
                thunderstormenabled = false
            else
                thunderstormenabled = true
            end
        else
            badweatherplanned = false
        end
    end

    if badweatherplanned and clock > badweatherclockstart and clock < badweatherclockend then
        if thunderstormenabled and math.random(1,30) == 1 then
            SpawnCEGInRandomMapPosAvoidUnits("lightningstrike", 0, 128, lightningsounds[math.random(1,#lightningsounds)], 1)
        end
        if clock > nightlenght then
            SendToUnsynced("MapAtmosphereConfigSetSun", 0.3, transitionSpeed, 0.3, 0.3, 0.3*atmospherelevelmult)
            SendToUnsynced("MapAtmosphereConfigSetFog", -0.1, 0.8, transitionSpeed*2.5, transitionSpeed*1.5)
        else
            SendToUnsynced("MapAtmosphereConfigSetSun", 0.8, transitionSpeed, 0.8, 0.8, 0.8)
            SendToUnsynced("MapAtmosphereConfigSetFog", -0.1, 0.8, transitionSpeed*2.5, transitionSpeed*1.5)
        end
    else
        if clock > nightlenght then
            SendToUnsynced("MapAtmosphereConfigSetSun", 0.5, transitionSpeed, 0.5, 0.5, 0.5*atmospherelevelmult)
            SendToUnsynced("MapAtmosphereConfigSetFog", 1, 1, transitionSpeed*2.5, transitionSpeed*1.5)
        else
            SendToUnsynced("MapAtmosphereConfigSetSun", 1, transitionSpeed, 1, 1, 1)
            SendToUnsynced("MapAtmosphereConfigSetFog", 1, 1, transitionSpeed*2.5, transitionSpeed*1.5)
        end
    end
end
