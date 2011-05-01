--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Prevent Outside Aircraft hacks",
    desc      = "Prevent Outside Aircraft hacks",
    author    = "Beherith",
    date      = "3 27 2011",
    license   = "CC BY SA",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local SpringGetUnitPosition =Spring.GetUnitPosition
local SpringGetAllUnits =Spring.GetAllUnits

if (not gadgetHandler:IsSyncedCode()) then
  return false
end
mapX = Game.mapSizeX
mapZ = Game.mapSizeZ
function gadget:GameFrame (f)
	if (f%61==0) then
		local all_units = SpringGetAllUnits ()
		for i in pairs(all_units) do
			x,y,z = SpringGetUnitPosition(all_units[i])
			if (z==nil or x==nil) then
			else
				if ( z <-2500 or x< -2500 or z> mapZ+2500 or x> mapX+2500) then
						Spring.DestroyUnit (all_units[i])
				end
			end
			-- if (z < 0 or x< 0 or x>2000) then
				-- Spring.DestroyUnit (all_units[i])
				-- Spring.Echo(to_string(all_units[i]))
			-- end
		end
	end
end