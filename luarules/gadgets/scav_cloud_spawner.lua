function gadget:GetInfo()
	return {
		name = "Scav Cloud Spawner",
		desc = "Spawns Cloud that represents Scav spawning area",
		author = "Damgam",
		date = "2023",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() or not Spring.Utilities.Gametype.IsScavengers() then
 return
end

local mapx = Game.mapSizeX
local mapz = Game.mapSizeZ
local cloudMult = math.ceil(((mapx+mapz)*0.5)/4000)

function gadget:GameFrame(frame)
    for _ = 1, cloudMult do
        local randomx = math.random(0, mapx)
        local randomz = math.random(0, mapz)
        local randomy = Spring.GetGroundHeight(randomx, randomz)
        if GG.IsPosInRaptorScum(randomx, randomy, randomz) then
            Spring.SpawnCEG("scavradiation",randomx,randomy+100,randomz,0,0,0)
        end

        local randomx = math.random(0, mapx)
        local randomz = math.random(0, mapz)
        local randomy = Spring.GetGroundHeight(randomx, randomz)
        if GG.IsPosInRaptorScum(randomx, randomy, randomz) then
            Spring.SpawnCEG("scavradiation-lightning",randomx,randomy+100,randomz,0,0,0)
        end
    end
end