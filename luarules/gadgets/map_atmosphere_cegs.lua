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

function SpawnCEGInPosition(cegname, posx, posy, posz, sound, soundvolume)
	spSCEG(cegname, posx, posy, posz)
	if sound then
		Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
	end
end

function SpawnCEGInPositionGround(cegname, posx, groundOffset, posz, sound, soundvolume)
	local posy = spGroundHeight(posx, posz) + (groundOffset or 0)
	spSCEG(cegname, posx, posy, posz)
	if sound then
		Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
	end
end

function SpawnCEGInArea(cegname, midposx, posy, midposz, radius, sound, soundvolume)
	local posx = midposx+mathrandom(-radius,radius)
	local posz = midposz+mathrandom(-radius,radius)
	spSCEG(cegname, posx, posy, posz)
	if sound then
		Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
	end
end

function SpawnCEGInAreaGround(cegname, midposx, groundOffset, midposz, radius, sound, soundvolume)
	local posx = midposx+mathrandom(-radius,radius)
	local posz = midposz+mathrandom(-radius,radius)
	local posy = spGroundHeight(posx, posz) + (groundOffset or 0)
	spSCEG(cegname, posx, posy, posz)
	if sound then
		Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
	end
end

function SpawnCEGInRandomMapPos(cegname, groundOffset, sound, soundvolume)
	local posx = mathrandom(0,mapsizeX)
	local posz = mathrandom(0,mapsizeZ)
	local posy = spGroundHeight(posx, posz) + (groundOffset or 0)
	spSCEG(cegname, posx, posy, posz)
	if sound then
		Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
	end
end

function SpawnCEGInRandomMapPosBelowY(cegname, groundOffset, spawnOnlyBelowY, sound, soundvolume)
	for i = 1,100 do
		local posx = mathrandom(0,mapsizeX)
		local posz = mathrandom(0,mapsizeZ)
		local groundposy = spGroundHeight(posx, posz)
		local posy = spGroundHeight(posx, posz) + (groundOffset or 0)
		if groundposy <= spawnOnlyBelowY then
			spSCEG(cegname, posx, posy, posz)
			if sound then
				Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
			end
			break
		end
	end
end

function SpawnCEGInRandomMapPosPresetY(cegname, posy, sound, soundvolume)
	local posx = mathrandom(0,mapsizeX)
	local posz = mathrandom(0,mapsizeZ)
	spSCEG(cegname, posx, posy, posz)
	if sound then
		Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
	end
end

VFS.Include("luarules/gadgets/atmosphereconfigs/" .. mapname .. ".lua")



