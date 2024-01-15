--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Airmesh Fix",
		version   = "1.0",
		desc      = "Calculates and fixes garbage Airmesh",
		author    = "Beherith",
		date      = "2021 jan",
		license   = "GNU GPL, v2 or later",
		layer     = 0,	--higher layer is loaded last
		enabled   = false, --REMOVE THIS GADGET ONCE ENGINE IS FIXED
	}
end


-- synced only
if (not gadgetHandler:IsSyncedCode()) then
	return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:Initialize()
  --Spring.Echo("Airmesh fix starting")
  --Spring.LevelSmoothMesh( 100, 100, 200, 200, 1000)

  Spring.SetSmoothMeshFunc(function()
    local smoothheightresolution = Game.squareSize * 2
    local toolow = 0
    local toohigh = 0
    local toohighfixed = 0
    for z=0, Game.mapSizeZ, smoothheightresolution do
        for x=0,Game.mapSizeX, smoothheightresolution do
            local trueheight = Spring.GetGroundHeight(x,z)
            local oldsmoothheight = Spring.GetSmoothMeshHeight(x,z)

            if trueheight > oldsmoothheight then
              Spring.SetSmoothMesh(x,z, trueheight)
              toolow = toolow + 1
            end

--            if trueheight < oldsmoothheight - 10 then
--              toohigh = toohigh + 1
--              local nearmax = 0;
--              local steepness = 0.5;

--              for offset = -320, 320 , smoothheightresolution *2 do
--                local h = Spring.GetGroundHeight(x+offset, z+offset)
--                if (h - steepness* math.abs(offset)) > nearmax then
--                  nearmax = (h - steepness* math.abs(offset))

--                end
--                h = Spring.GetGroundHeight(x+offset, z-offset)
--                if  (h - math.abs(offset)) > nearmax then
--                  nearmax = (h - steepness* math.abs(offset))
--                end
--              end
--              if oldsmoothheight > nearmax then
--                Spring.SetSmoothMesh(x,z,math.max(trueheight, nearmax))
--                toohighfixed = toohighfixed + 1
--              end
--            end
        end
    end
    Spring.Echo("Airmesh Fix: Height Map smoothing complete, too low entries:",toolow, "too high entries:",toohigh, 'too high fixed:',toohighfixed)
  end)
  --Spring.Echo("Airmesh fix completed in")--,Spring.DiffTimers(Spring.GetTimer(),t0))
end


--------------------------------------------------------------------
--------------------------------------------------------------------------------
