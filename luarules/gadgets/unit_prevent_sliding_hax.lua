function gadget:GetInfo()
  return {
    name      = "Prevent sliding hax",
    desc      = "prevents sliding hax",
    author    = "Bluestone",
    date      = "08/12/2013",
    license   = "horse has fallen over, again",
    layer     = 0,
    enabled   = true
  }
end

--hotfix for http://springrts.com/mantis/view.php?id=4200

if (not gadgetHandler:IsSyncedCode()) then return end

local directControlUnits = {}
local maxSpeeds = {}
local prevPos = {}
local reg = 15 -- check every x frames

function gadget:AllowDirectUnitControl(unitID, unitDefID, unitTeam, playerID)
	directControlUnits[unitID] = playerID
	maxSpeeds[unitID] = UnitDefs[unitDefID].speed
	return true
end

function gadget:GameFrame(n)
	if n % reg == 0 then
		for unitID,playerID in pairs(directControlUnits) do
			
			--check its not travelling to fast & stop it dead if so
			local x,y,z = Spring.GetUnitPosition(unitID)
			if x and prevPos[unitID] then
				local sqrSpeed = (x-prevPos[unitID][1])^2+(y-prevPos[unitID][2])^2+(z-prevPos[unitID][3])^2
				local sqrMaxSpeed = (reg*maxSpeeds[unitID]/30)^2 -- /30 because ud.speed comes in elmos 'per second' = 30 frames
				--Spring.Echo(math.sqrt(sqrSpeed), math.sqrt(sqrMaxSpeed))
				if (0.9)^2*sqrSpeed >= sqrMaxSpeed and Spring.ValidUnitID(unitID) then 
					Spring.SetUnitVelocity(unitID,0,0,0)
				end
			end
			prevPos[unitID] = {x,y,z}
			
			--check if still in fps mode
			local uID = Spring.GetPlayerControlledUnit(playerID)
			if unitID ~= uID or (not Spring.ValidUnitID(unitID)) then
				directControlUnits[unitID] = nil
				prevPos[unitID] = nil
				maxSpeeds[unitID] = nil
			end
			
		end
	end
end


