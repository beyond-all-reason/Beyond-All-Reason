
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

local enabled = tonumber(Spring.GetModOptions().mo_no_close_spawns) or 1

local spawndist = 300

local mapx = Game.mapX
local mapz = Game.mapY -- misnomer in API
local smallmap = (mapx^2 + mapz^2 < 6^2)

if (enabled == 0) or (Game.startPosType ~= 2) or smallmap then --don't load if modoptions says not too or if start pos placement is not 'choose in game' or if map is small
	return false
end

if gadgetHandler:IsSyncedCode() then
    
    ----------------------------------------------------------------
    -- Synced Var
    ----------------------------------------------------------------
    local startpoints = {} -- StartPoints[playerID] = {x,y,z} 

    ----------------------------------------------------------------
    -- Synced Callins
    ----------------------------------------------------------------
    local function to_string(data, indent)
		local str = ""

		if(indent == nil) then
			indent = 0
		end

		-- Check the type
		if(type(data) == "string") then
			str = str .. (" "):rep(indent) .. data .. "\n"
		elseif(type(data) == "number") then
			str = str .. (" "):rep(indent) .. data .. "\n"
		elseif(type(data) == "boolean") then
			if(data == true) then
				str = str .. "true\n"
			else
				str = str .. "false\n"
			end
		elseif(type(data) == "table") then
			local i, v
			for i, v in pairs(data) do
				-- Check for a table in a table
				if(type(v) == "table") then
					str = str .. (" "):rep(indent) .. i .. ":\n"
					str = str .. to_string(v, indent + 2)
				else
			str = str .. (" "):rep(indent) .. i .. ": " ..to_string(v, 0)
			end
			end
		elseif (data ==nil) then
			str=str..'nil'
		else
		   -- print_debug(1, "Error: unknown data type: %s", type(data))
			--str=str.. "Error: unknown data type:" .. type(data)
			Spring.Echo(type(data) .. 'X data type')
		end

		return str
	end
	
	
    function gadget:AllowStartPosition(x, y, z, playerID)
		--Spring.Echo('allowstart',x,z,playerID,to_string(startpoints))
		for otherplayerID, startPos in pairs(startpoints) do
			if otherplayerID ~= playerID then
				
				--Spring.Echo('vs',x,z,playerID, startPos[1],startPos[3])
				if ((startPos[1]-x)*(startPos[1]-x)+(startPos[2]-y)*(startPos[2]-y)+(startPos[3]-z)*(startPos[3]-z))<spawndist^2 then -- a little more than a dgun range away from everyone else
					Spring.SendMessageToPlayer(playerID,"You cannot place a start position inside of the D-Gun range of an Ally")
				--	Spring.Echo('canceled start')
					return false
				end
			end
		end
		startpoints[playerID]={x,y,z}
	   return true
    end
    
end