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

function SpawnCEGInPositionGround(cegname, posx, addposy, posz, sound)
	local posy = spGroundHeight(posx, posz) + (addposy or 0)
	spSCEG(cegname, posx, posy, posz)
end

function SpawnCEGInArea(cegname, midposx, posy, midposz, radius, sound)
	local posx = midposx+mathrandom(-radius,radius)
	local posz = midposz+mathrandom(-radius,radius)
	spSCEG(cegname, posx, posy, posz)
end

function SpawnCEGInAreaGround(cegname, midposx, addposy, midposz, radius, sound)
	local posx = midposx+mathrandom(-radius,radius)
	local posz = midposz+mathrandom(-radius,radius)
	local posy = spGroundHeight(posx, posz) + (addposy or 0)
	spSCEG(cegname, posx, posy, posz)
end

function SpawnCEGInRandomMapPos(cegname, addposy, sound)
	local posx = mathrandom(0,mapsizeX)
	local posz = mathrandom(0,mapsizeZ)
	local posy = spGroundHeight(posx, posz) + (addposy or 0)
	spSCEG(cegname, posx, posy, posz)
end

function SpawnCEGInRandomMapPosBelowY(cegname, addposy, belowposy, sound)
	for i = 1,100 do
		local posx = mathrandom(0,mapsizeX)
		local posz = mathrandom(0,mapsizeZ)
		local groundposy = spGroundHeight(posx, posz)
		local posy = spGroundHeight(posx, posz) + (addposy or 0)
		if groundposy <= belowposy then
			spSCEG(cegname, posx, posy, posz)
			break
		end
	end
end

function SpawnCEGInRandomMapPosPresetY(cegname, posy, sound)
	local posx = mathrandom(0,mapsizeX)
	local posz = mathrandom(0,mapsizeZ)
	spSCEG(cegname, posx, posy, posz)
end

VFS.Include("luarules/gadgets/atmosphereconfigs/" .. mapname .. ".lua")



