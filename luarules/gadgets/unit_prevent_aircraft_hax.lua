--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Prevent outside-of-map hax",
    desc      = "Prevent outside-of-map hax",
    author    = "Beherith",
    date      = "3 27 2011",
    license   = "CC BY SA",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local SpringGetUnitPosition = Spring.GetUnitPosition
local SpringGetAllUnits     = Spring.GetAllUnits

if (not gadgetHandler:IsSyncedCode()) then
  return false
end

local mapX = Game.mapSizeX
local mapZ = Game.mapSizeZ

function gadget:GameFrame(f)
	if (f%61==0) then
		local all_units = SpringGetAllUnits()
		for _,unitID in pairs(all_units) do
			x,y,z = SpringGetUnitPosition(unitID)
			if (z==nil or x==nil) then
			else
				if ( z <-1500 or x< -1500 or z> mapZ+1500 or x> mapX+1500) then
						Spring.DestroyUnit(unitID)
				end
			end
		end
	end
end