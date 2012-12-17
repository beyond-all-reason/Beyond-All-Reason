
function gadget:GetInfo()
	return {
		name      = 'Coop II',
		desc      = 'Implements mo_coop modoption',
		author    = 'Niobium',
		date      = 'May 2011',
		license   = 'GNU GPL, v2 or later',
		layer     = 1,
		enabled   = true
	}
end

-- Modoption check
if (tonumber((Spring.GetModOptions() or {}).mo_coop) or 0) == 0 then
    return false
end

if gadgetHandler:IsSyncedCode() then
    
    ----------------------------------------------------------------
    -- Synced Var
    ----------------------------------------------------------------
    local coopStartPoints = {} -- coopStartPoints[playerID] = {x,y,z} -- Also acts as is-player-a-coop-player
    
    GG.coopStartPoints = coopStartPoints -- Share it to other gadgets
    
    ----------------------------------------------------------------
    -- Synced Callins
    ----------------------------------------------------------------
    
    -- Commented out Initialize due to set of GG.coopMode and layer of 1
    -- Previously layer was -1 (and so initialize ran first), however this made the unsynced drawing code draw UNDER the green startbox
    -- Could have a separate :GetInfo in both synced and unsynced sections, but that is asking for trouble
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
	
	
    local function SetCoopStartPoint(playerID, x, y, z)
        coopStartPoints[playerID] = {x, y, z}
		--Spring.Echo('coop dbg6',playerID,x,y,z,to_string(coopStartPoints))
       
        SendToUnsynced("CoopStartPoint", playerID, x, y, z)
    end
    
    --function gadget:Initialize()
    do
        local coopHasEffect = false
        local teamHasPlayers = {}
        local playerList = Spring.GetPlayerList()
        for i = 1, #playerList do
            local playerID = playerList[i]
            local _, _, isSpec, teamID = Spring.GetPlayerInfo(playerID)
            if not isSpec then
                if teamHasPlayers[teamID] then
                    SetCoopStartPoint(playerID, -1, -1, -1)
                    coopHasEffect = true
                else
                    teamHasPlayers[teamID] = true
                end
            end
        end
        
        if coopHasEffect then
            GG.coopMode = true -- Inform other gadgets that coop needs to be taken into account
        --else
        -- Could remove the gadget here, but spring does not like gadgets removing themselves on initialize.
        -- Get the same problem with trying to remove the unsynced side (It won't be drawing anything though, so it's not too bad)
        end
    end
    
    function gadget:AllowStartPosition(x, y, z, playerID)
		--Spring.Echo('allowstart',x,z,playerID)
		for otherplayerID, startPos in pairs(coopStartPoints) do
			if startPos[1]==x and startPos[3]==z then
				--Spring.Echo('coop dbg8',playerID,'a real start was attempted to be placed on a coop start ',otherplayerID,'at',x,z,'disallowing!')
				return false
			end
		end
        if coopStartPoints[playerID] then
            -- Spring sometimes(?) has each player re-place their start position on their current team start position pre-gamestart
            -- To catch this, we don't recognise a coop start position if it is identical to their teams spring start position
            -- This has the side-effect that a coop player cannot intentionally start directly on their teammate, but this is OK
			
			--Since spring is a bitch, and if the host (the guy who places the real start point) readies up first, and the client second, then the host will have his start point overwritten by the client
			-- this can be prevented by not allowing the host to place on client either.
            local _, _, _, teamID, allyID = Spring.GetPlayerInfo(playerID)
            local osx, _, osz = Spring.GetTeamStartPosition(teamID)
            if x ~= osx or z ~= osz then
                local bx1, bz1, bx2, bz2 = Spring.GetAllyTeamStartBox(allyID)
                x = math.min(math.max(x, bx1), bx2)
                z = math.min(math.max(z, bz1), bz2)
                SetCoopStartPoint(playerID, x, Spring.GetGroundHeight(x, z), z)
            end
			--Spring.Echo('allowstart false',x,z,playerID)
            return false
        end
		---Spring.Echo('allowstart true',x,z,playerID)
           
	   return true
    end
    
    local function SpawnTeamStartUnit(teamID, allyID, x, z)
        local startUnit = Spring.GetTeamRulesParam(teamID, 'startUnit')
        if x <= 0 or z <= 0 then
            local xmin, zmin, xmax, zmax = Spring.GetAllyTeamStartBox(allyID)
            x = 0.5 * (xmin + xmax)
            z = 0.5 * (zmin + zmax)
        end
        Spring.CreateUnit(startUnit, x, Spring.GetGroundHeight(x, z), z, 0, teamID)
    end
    
    function gadget:GameFrame(n)
        
        if GG.coopMode then
			--Spring.Echo('coop dbg7',to_string(coopStartPoints))
            for playerID, startPos in pairs(coopStartPoints) do
                local _, _, _, teamID, allyID = Spring.GetPlayerInfo(playerID)
                SpawnTeamStartUnit(teamID, allyID, startPos[1], startPos[3])
            end
        end
        
        gadgetHandler:RemoveGadget(self)
        SendToUnsynced('RemoveGadget') -- Remove unsynced side too
    end
		

else
    
    ----------------------------------------------------------------
    -- Unsynced Var
    ----------------------------------------------------------------
    local coneList
    
    local playerNames = {} -- playerNames[playerID] = playerName
    local playerTeams = {} -- playerTeams[playerID] = playerTeamID
    local coopStartPoints = {}
    
    ----------------------------------------------------------------
    -- Unsynced speedup
    ----------------------------------------------------------------
    local glPushMatrix = gl.PushMatrix
    local glPopMatrix = gl.PopMatrix
    local glTranslate = gl.Translate
    local glColor = gl.Color
    local glCallList = gl.CallList
    local glBeginText = gl.BeginText
    local glEndText = gl.EndText
    local glText = gl.Text
    local spGetTeamColor = Spring.GetTeamColor
    local spWorldToScreenCoords = Spring.WorldToScreenCoords
    local spGetMyPlayerID = Spring.GetMyPlayerID
    local spGetSpectatingState = Spring.GetSpectatingState
    local spArePlayersAllied = Spring.ArePlayersAllied
    
    ----------------------------------------------------------------
    -- Stolen funcs from from minimap_startbox.lua (And cleaned up a bit)
    ----------------------------------------------------------------
    local function ColorChar(x)
        local c = math.min(math.max(math.floor(x * 255), 1), 255)
        return string.char(c)
    end
    
    local teamColorStrs = {}
    local function GetTeamColorStr(teamID)
        
        local colorStr = teamColorStrs[teamID]
        if colorStr then
            return colorStr
        end
        
        local r, g, b = Spring.GetTeamColor(teamID)
        local colorStr = '\255' .. ColorChar(r) .. ColorChar(g) .. ColorChar(b)
        teamColorStrs[teamID] = colorStr
        return colorStr
    end
    
    local function CoopStartPoint(epicwtf, playerID, x, y, z) --this epicwtf param is used because it seem that when a registered function is locaal, then the registration name is  passed too. if the function is part of gadget: then it is not passed.
    	--Spring.Echo('coop dbg5',epicwtf,playerID,x,y,z,to_string(coopStartPoints))
            
		coopStartPoints[playerID] = {x, y, z}
    end
    
    ----------------------------------------------------------------
    -- Unsynced Callins
    ----------------------------------------------------------------
    function gadget:Initialize()
        gadgetHandler:AddSyncAction("CoopStartPoint", CoopStartPoint)
        -- Speed things up
        local playerList = Spring.GetPlayerList()
        for i = 1, #playerList do
            local playerID = playerList[i]
            local playerName, _, _, teamID = Spring.GetPlayerInfo(playerID)
            playerNames[playerID] = playerName
            playerTeams[playerID] = teamID
			--Spring.Echo('coop dbg2',i,playerName,playerID,teamID,#playerList)
        end
        
        -- Cone code taken directly from minimap_startbox.lua
        coneList = gl.CreateList(function()
                local h = 100
                local r = 25
                local divs = 32
                gl.BeginEnd(GL.TRIANGLE_FAN, function()
                        gl.Vertex( 0, h,  0)
                        for i = 0, divs do
                            local a = i * ((math.pi * 2) / divs)
                            local cosval = math.cos(a)
                            local sinval = math.sin(a)
                            gl.Vertex(r * sinval, 0, r * cosval)
                        end
                    end)
            end)
    end
    
    function gadget:Shutdown()
        gl.DeleteList(coneList)
        gadgetHandler:RemoveSyncAction("CoopStartPoint")
    end
    
    function gadget:DrawWorld()
        local areSpec = spGetSpectatingState()
        local myPlayerID = spGetMyPlayerID()
        for playerID, startPosition in pairs(coopStartPoints) do
		--	Spring.Echo('coop dbg3',myPlayerID,playerID,'klj\n',to_string(coopStartPoints))
            if areSpec or spArePlayersAllied(myPlayerID, playerID) then
                local sx, sy, sz = startPosition[1], startPosition[2], startPosition[3]
                if sx > 0 or sz > 0 then
					--Spring.Echo('coop dbg',playerID,playerTeams[playerID])
                    local tr, tg, tb = spGetTeamColor(playerTeams[playerID])
                    glPushMatrix()
                        glTranslate(sx, sy, sz)
                        glColor(tr, tg, tb, 0.5) -- Alpha would oscillate, but gadgets can't get time
                        glCallList(coneList)
                    glPopMatrix()
                end
            end
        end
    end
    
    function gadget:DrawScreenEffects()
        glBeginText()
        local areSpec = spGetSpectatingState()
        local myPlayerID = spGetMyPlayerID()
        for playerID, startPosition in pairs(coopStartPoints) do
			--Spring.Echo('coop dbg4',myPlayerID,playerID)
          
			if areSpec or spArePlayersAllied(myPlayerID, playerID) then
                local sx, sy, sz = startPosition[1], startPosition[2], startPosition[3]
                if sx > 0 or sz > 0 then
                    local scx, scy, scz = spWorldToScreenCoords(sx, sy + 120, sz)
                    if scz < 1 then
                        local colorStr, outlineStr = GetTeamColorStr(playerTeams[playerID])
                        glText(colorStr .. playerNames[playerID], scx, scy, 18, 'cs')
                    end
                end
            end
        end
        glEndText()
    end
    
    function gadget:RecvFromSynced(arg1, ...)
        if arg1 == 'RemoveGadget' then
            gadgetHandler:RemoveGadget(self)
        end
    end
	
	function to_string(data, indent)
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
end


-- [f=0000000] coop dbg6, 1, 1868, 144.53125, 619, 1:
  -- 1: 1868
  -- 2: 144.53125
  -- 3: 619

-- [f=0000000] coop dbg5, CoopStartPoint, 1, 1868, 144.53125, 
-- [f=0000000] coop dbg3, 1, CoopStartPoint, klj
-- , CoopStartPoint:
  -- 1: 1
  -- 2: 1868
  -- 3: 144.53125
