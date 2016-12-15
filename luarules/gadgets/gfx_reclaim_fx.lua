   function gadget:GetInfo()
      return {
        name      = "Reclaim effecg",
        desc      = "Nice unit reclaim effect",
        author    = "Floris",
        date      = "December 2016",
        license   = "PD",
        layer     = 0,
        enabled   = true,
      }
    end
     
if (not gadgetHandler:IsSyncedCode()) then
  return
end

local random = math.random

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if attackerID == nil then -- if reclaimed
		local ux,uy,uz = Spring.GetUnitPosition(unitID)
		if ux ~= nil then
			local udef = UnitDefs[unitDefID]
			local x,y,z = ux,uy,uz
			Spring.SpawnCEG("wreckshards1", x, y, z)
			
			-- add more effects depending on unit cost
			local numFx = math.floor(UnitDefs[unitDefID].metalCost/170)
			local posMultiplier = 0.5
			for i=1, numFx, 1 do
				x = ux + (random(udef.model.minx, udef.model.maxx)*posMultiplier)
				z = uz + (random(udef.model.minz, udef.model.maxz)*posMultiplier)
				y = uy + (random() * udef.model.maxy*posMultiplier)
				Spring.SpawnCEG("wreckshards"..(((i+1)%3)+1), x, y, z)
			end
		end
	end
end

