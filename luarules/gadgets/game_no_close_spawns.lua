
function gadget:GetInfo()
	return {
		name      = 'No close spawns',
		desc      = 'Disallows spawning inside allies dgun range',
		author    = 'Beherith',
		date      = 'Jan 2013',
		license   = 'GNU GPL, v2 or later',
		layer     = -1,
		enabled   = true
	}
end

-- todo: add modoption

if gadgetHandler:IsSyncedCode() then
    
    ----------------------------------------------------------------
    -- Synced Var
    ----------------------------------------------------------------
    local startpoints = {} -- StartPoints[playerID] = {x,y,z} 

    ----------------------------------------------------------------
    -- Synced Callins
    ----------------------------------------------------------------
    
    function gadget:AllowStartPosition(x, y, z, playerID)
		--Spring.Echo('allowstart',x,z,playerID)
		for otherplayerID, startPos in pairs(coopStartPoints) do
			if otherplayerID ~= playerID then
				if ((startPos[1]-x)*(startPos[1]-x)+(startPos[2]-y)*(startPos[2]-y)+(startPos[3]-z)*(startPos[3]-z))<250*250 then --at least dgun range away from everyone else
					Spring.SendMessageToPlayer(playerID,"You cannot place a start position inside of the D-Gun range of an Ally")
					return false
				end
			end
		end
		startpoints[playerID]={x,y,z}
	   return true
    end
    
end