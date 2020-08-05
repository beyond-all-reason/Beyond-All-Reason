mapname = Game.mapName
mapsizeX = Game.mapSizeX
mapsizeZ = Game.mapSizeZ
spSCEG = Spring.SpawnCEG
mathrandom = math.random
spGroundHeight = Spring.GetGroundHeight


function gadget:GetInfo()
    return {
      name      = "Map Atmosphere CEGs",
      desc      = "123",
      author    = "Damgam",
      date      = "2020",
      layer     = -100,
      enabled   = true,
    }
end

if (not gadgetHandler:IsSyncedCode()) then
	return false
end

function SpawnCEGInPosition(cegname, posx, posy, posz, sound)
	spSCEG(cegname, posx, posy, posz)
end

function SpawnCEGInArea(cegname, posx, posy, posz, radius, sound)
	spSCEG(cegname, posx+mathrandom(-radius,radius), posy, posz+mathrandom(-radius,radius))
end

function SpawnCEGInRandomMapPos(cegname, addposy, sound)
	local posx = mathrandom(0,mapsizeX)
	local posz = mathrandom(0,mapsizeZ)
	local posy = spGroundHeight(posx, posz) + (addposy or 0)
	spSCEG(cegname, posx, posy, posz)
end

VFS.Include("luarules/gadgets/atmosphereconfigs/" .. mapname .. ".lua")



