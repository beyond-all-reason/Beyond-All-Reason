local mapsizex = Game.mapSizeX
local mapsizez = Game.mapSizeZ
local transitionSpeed = mapsizez/mapsizex

local windmin = Game.windMin
local windmax = Game.windMax

local daylenght = math.ceil(mapsizex+mapsizez)*2
local nightlenght = math.ceil(daylenght*0.4)

if windmax < 5 then
    atmosphere = 1
elseif windmax < 10 then
    atmosphere = 1.20
elseif windmax < 20 then
    atmosphere = 1.40
else
    atmosphere = 1.60
end

function gadget:GameFrame(n)
    if n%daylenght > nightlenght then
		SendToUnsynced("MapAtmosphereConfigSetSun", 0.65, transitionSpeed, 0.65*atmosphere)
	else
		SendToUnsynced("MapAtmosphereConfigSetSun", 1, transitionSpeed, 1)
	end
end
